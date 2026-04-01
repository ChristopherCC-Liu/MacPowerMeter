// PowerCollector.swift
// MacPowerMeter
//
// 功耗采集 facade
// 优先使用 IOReport 私有框架，fallback 到 SMC 直读
// 两种方式均不可用时优雅降级 (isAvailable = false)

import Foundation
import Darwin

/// 功耗采集结果
struct PowerMetrics: Sendable {
    let totalPower: Double
    let cpuPower: Double
    let gpuPower: Double
    let anePower: Double

    static let zero = PowerMetrics(totalPower: 0, cpuPower: 0, gpuPower: 0, anePower: 0)
}

/// 功耗采集器 (Facade)
/// 优先 IOReport，fallback SMC，均不可用则降级
final class PowerCollector: DataProvider, @unchecked Sendable {

    private let strategy: (any PowerStrategy)?
    private(set) var isAvailable: Bool = false

    init() {
        // 优先 IOReport
        let ioReport = IOReportPowerStrategy()
        if ioReport.isAvailable {
            strategy = ioReport
            isAvailable = true
            return
        }

        // Fallback: SMC 直读
        let smc = SMCPowerCollector()
        if smc.isAvailable {
            strategy = smc
            isAvailable = true
            return
        }

        // 均不可用
        strategy = nil
    }

    // MARK: - DataProvider

    func collect() async throws -> PowerMetrics {
        guard let strategy else { return .zero }
        return try await strategy.collect()
    }
}

// MARK: - IOReport 策略实现

/// 通过 IOReport 私有框架采集功耗数据
/// 使用 dlopen/dlsym 动态加载 Energy Model channel
/// Apple Silicon 通道名: PCPU (P-core) / ECPU (E-core) / GPU / ANE / DRAM
final class IOReportPowerStrategy: PowerStrategy, @unchecked Sendable {

    private(set) var isAvailable: Bool = false

    // MARK: - IOReport 函数指针类型

    private typealias IOReportCopyChannelsInGroupFn = @convention(c) (
        CFString?, CFString?
    ) -> Unmanaged<CFDictionary>?

    private typealias IOReportCreateSubscriptionFn = @convention(c) (
        CFAllocator?, CFDictionary, CFDictionary?,
        UnsafeMutablePointer<Unmanaged<CFDictionary>?>?, UnsafeMutableRawPointer?
    ) -> Unmanaged<CFDictionary>?

    private typealias IOReportCreateSamplesFn = @convention(c) (
        CFDictionary, CFDictionary?, UnsafeMutablePointer<Unmanaged<CFDictionary>?>?
    ) -> Unmanaged<CFDictionary>?

    private typealias IOReportCreateSamplesDeltaFn = @convention(c) (
        CFDictionary, CFDictionary, UnsafeMutablePointer<Unmanaged<CFDictionary>?>?
    ) -> Unmanaged<CFDictionary>?

    private typealias IOReportChannelGetGroupFn = @convention(c) (
        CFDictionary
    ) -> Unmanaged<CFString>?

    private typealias IOReportChannelGetChannelNameFn = @convention(c) (
        CFDictionary
    ) -> Unmanaged<CFString>?

    private typealias IOReportSimpleGetIntegerValueFn = @convention(c) (
        CFDictionary, Int32
    ) -> Int64

    // MARK: - 函数指针

    private var copyChannelsInGroup: IOReportCopyChannelsInGroupFn?
    private var createSubscription: IOReportCreateSubscriptionFn?
    private var createSamples: IOReportCreateSamplesFn?
    private var createSamplesDelta: IOReportCreateSamplesDeltaFn?
    private var channelGetGroup: IOReportChannelGetGroupFn?
    private var channelGetChannelName: IOReportChannelGetChannelNameFn?
    private var simpleGetIntegerValue: IOReportSimpleGetIntegerValueFn?

    /// IOReport 订阅句柄
    private var subscription: CFDictionary?

    // MARK: - 采样间隔

    /// 两次采样之间的间隔（秒）
    /// 500ms 是 Stats/asitop 等成熟工具验证过的可靠间隔
    private let sampleInterval: TimeInterval = 0.5

    // MARK: - 初始化

    init() {
        loadIOReport()
    }

    // MARK: - 加载 IOReport

    private func loadIOReport() {
        guard let handle = dlopen("/usr/lib/libIOReport.dylib", RTLD_LAZY) else {
            isAvailable = false
            return
        }

        guard
            let sym1 = dlsym(handle, "IOReportCopyChannelsInGroup"),
            let sym2 = dlsym(handle, "IOReportCreateSubscription"),
            let sym3 = dlsym(handle, "IOReportCreateSamples"),
            let sym4 = dlsym(handle, "IOReportCreateSamplesDelta"),
            let sym5 = dlsym(handle, "IOReportChannelGetGroup"),
            let sym6 = dlsym(handle, "IOReportChannelGetChannelName"),
            let sym7 = dlsym(handle, "IOReportSimpleGetIntegerValue")
        else {
            dlclose(handle)
            isAvailable = false
            return
        }

        copyChannelsInGroup = unsafeBitCast(sym1, to: IOReportCopyChannelsInGroupFn.self)
        createSubscription = unsafeBitCast(sym2, to: IOReportCreateSubscriptionFn.self)
        createSamples = unsafeBitCast(sym3, to: IOReportCreateSamplesFn.self)
        createSamplesDelta = unsafeBitCast(sym4, to: IOReportCreateSamplesDeltaFn.self)
        channelGetGroup = unsafeBitCast(sym5, to: IOReportChannelGetGroupFn.self)
        channelGetChannelName = unsafeBitCast(sym6, to: IOReportChannelGetChannelNameFn.self)
        simpleGetIntegerValue = unsafeBitCast(sym7, to: IOReportSimpleGetIntegerValueFn.self)

        // 创建 Energy Model channel 订阅
        guard let channels = copyChannelsInGroup?("Energy Model" as CFString, nil)?.takeRetainedValue() else {
            isAvailable = false
            return
        }

        guard let sub = createSubscription?(kCFAllocatorDefault, channels, nil, nil, nil)?.takeRetainedValue() else {
            isAvailable = false
            return
        }

        subscription = sub
        isAvailable = true
    }

    // MARK: - PowerStrategy

    func collect() async throws -> PowerMetrics {
        guard isAvailable else {
            return .zero
        }
        return try await samplePower()
    }

    // MARK: - 采样

    /// 执行两次采样并计算 delta，得到实时功耗
    private func samplePower() async throws -> PowerMetrics {
        guard let sub = subscription,
              let createSamples,
              let createSamplesDelta,
              self.channelGetChannelName != nil,
              self.simpleGetIntegerValue != nil
        else {
            throw CollectorError.ioReportUnavailable
        }

        // 第一次采样
        guard let sample1 = createSamples(sub, nil, nil)?.takeRetainedValue() else {
            throw CollectorError.ioReportUnavailable
        }

        // 异步等待采样间隔（不阻塞线程）
        try await Task.sleep(for: .seconds(sampleInterval))

        // 第二次采样
        guard let sample2 = createSamples(sub, nil, nil)?.takeRetainedValue() else {
            throw CollectorError.ioReportUnavailable
        }

        // 计算 delta
        guard let delta = createSamplesDelta(sample1, sample2, nil)?.takeRetainedValue() else {
            throw CollectorError.ioReportUnavailable
        }

        // 解析 delta 中的功耗数据
        return parsePowerFromDelta(delta, interval: sampleInterval)
    }

    /// 从 delta 样本中解析各组件的功耗
    private func parsePowerFromDelta(_ delta: CFDictionary, interval: TimeInterval) -> PowerMetrics {
        guard let channelGetChannelName, let simpleGetIntegerValue else {
            return .zero
        }

        // delta 是 CFDictionary，toll-free bridge 到 NSDictionary
        let nsDict = delta as NSDictionary
        guard let channelsArray = nsDict["IOReportChannels"] as? NSArray else {
            return .zero
        }

        var cpuEnergy: Int64 = 0
        var gpuEnergy: Int64 = 0
        var aneEnergy: Int64 = 0
        var totalEnergy: Int64 = 0

        for i in 0..<channelsArray.count {
            guard let channelDict = channelsArray[i] as? NSDictionary else { continue }
            let cfDict = channelDict as CFDictionary

            let name = channelGetChannelName(cfDict)?.takeUnretainedValue() as String? ?? ""
            let value = simpleGetIntegerValue(cfDict, 0)

            // 跳过负值或零值
            guard value > 0 else { continue }

            let lowerName = name.lowercased()

            // Apple Silicon 通道名: pcpu, ecpu, gpu, ane, dram
            if lowerName.contains("cpu") {
                cpuEnergy += value
            } else if lowerName.contains("gpu") {
                gpuEnergy += value
            } else if lowerName.contains("ane") {
                aneEnergy += value
            }

            // 累计所有 Energy Model 通道的能量
            totalEnergy += value
        }

        // IOReport 返回的能量单位是 mJ（毫焦耳）
        // 功率(W) = 能量(mJ) / (时间间隔(s) * 1000)
        let toWatts = 1.0 / (interval * 1000.0)

        return PowerMetrics(
            totalPower: max(Double(totalEnergy) * toWatts, 0),
            cpuPower: max(Double(cpuEnergy) * toWatts, 0),
            gpuPower: max(Double(gpuEnergy) * toWatts, 0),
            anePower: max(Double(aneEnergy) * toWatts, 0)
        )
    }
}
