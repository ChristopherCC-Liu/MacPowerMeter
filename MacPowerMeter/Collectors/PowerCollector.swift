// PowerCollector.swift
// MacPowerMeter
//
// 通过 IOReport 私有框架采集系统功耗数据
// 使用 dlopen/dlsym 动态加载，不可用时优雅降级

import Foundation
import Darwin

/// 功耗采集结果
struct PowerMetrics: Sendable {
    let totalPower: Double
    let cpuPower: Double
    let gpuPower: Double
    let anePower: Double
}

/// 功耗采集器
/// 主方案: 使用 IOReport "Energy Model" channel 订阅获取实时功耗
/// 降级方案: IOReport 不可用时返回全零，isAvailable = false
final class PowerCollector: DataProvider, @unchecked Sendable {

    /// IOReport 是否成功加载
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

    /// 保护内部状态的锁
    private let lock = NSLock()

    // MARK: - 采样间隔

    /// 两次采样之间的间隔（秒）
    private let sampleInterval: TimeInterval = 0.1

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

    // MARK: - DataProvider

    func collect() async throws -> PowerMetrics {
        guard isAvailable else {
            return PowerMetrics(totalPower: 0, cpuPower: 0, gpuPower: 0, anePower: 0)
        }

        return try lock.withLock {
            try samplePower()
        }
    }

    // MARK: - 采样

    /// 执行两次采样并计算 delta，得到实时功耗
    private func samplePower() throws -> PowerMetrics {
        guard let sub = subscription,
              let createSamples,
              let createSamplesDelta,
              let channelGetChannelName,
              let simpleGetIntegerValue
        else {
            throw CollectorError.ioReportUnavailable
        }

        // 第一次采样
        guard let sample1 = createSamples(sub, nil, nil)?.takeRetainedValue() else {
            throw CollectorError.ioReportUnavailable
        }

        // 等待采样间隔
        Thread.sleep(forTimeInterval: sampleInterval)

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
            return PowerMetrics(totalPower: 0, cpuPower: 0, gpuPower: 0, anePower: 0)
        }

        // delta 实际上是一个 CFDictionary，其中包含 IOReportChannels 数组
        guard let nsDict = delta as? NSDictionary,
              let channels = nsDict["IOReportChannels"] as? [NSDictionary]
        else {
            return PowerMetrics(totalPower: 0, cpuPower: 0, gpuPower: 0, anePower: 0)
        }

        var cpuEnergy: Int64 = 0
        var gpuEnergy: Int64 = 0
        var aneEnergy: Int64 = 0
        var totalEnergy: Int64 = 0

        for channelDict in channels {
            guard let cfDict = channelDict as CFDictionary as CFDictionary? else { continue }

            let name = channelGetChannelName(cfDict)?.takeUnretainedValue() as String? ?? ""
            let value = simpleGetIntegerValue(cfDict, 0)

            let lowerName = name.lowercased()

            if lowerName.contains("cpu") && lowerName.contains("energy") {
                cpuEnergy += value
            } else if lowerName.contains("gpu") && lowerName.contains("energy") {
                gpuEnergy += value
            } else if lowerName.contains("ane") && lowerName.contains("energy") {
                aneEnergy += value
            }

            // 累计总能量
            if lowerName.contains("energy") {
                totalEnergy += value
            }
        }

        // IOReport 返回的能量单位通常是 mJ（毫焦耳），除以间隔得到 mW，再转 W
        let toWatts = 1.0 / (interval * 1000.0)
        let cpuPower = Double(cpuEnergy) * toWatts
        let gpuPower = Double(gpuEnergy) * toWatts
        let anePower = Double(aneEnergy) * toWatts
        let totalPower = Double(totalEnergy) * toWatts

        return PowerMetrics(
            totalPower: max(totalPower, 0),
            cpuPower: max(cpuPower, 0),
            gpuPower: max(gpuPower, 0),
            anePower: max(anePower, 0)
        )
    }
}
