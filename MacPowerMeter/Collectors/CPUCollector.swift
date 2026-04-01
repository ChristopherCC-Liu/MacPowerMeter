// CPUCollector.swift
// MacPowerMeter
//
// 通过 Mach host_processor_info API 采集 CPU 使用率

import Foundation
import Darwin

/// CPU 采集结果
struct CPUMetrics: Sendable {
    let cpuUsage: Double
    let perCoreCPU: [Double]
}

/// CPU 使用率采集器
/// 使用 host_processor_info() 获取每核心 CPU tick 数据，
/// 通过前后两次采样的差值计算实时使用率
final class CPUCollector: DataProvider, @unchecked Sendable {

    /// 上一次采样的每核心 CPU ticks
    private var previousTicks: [(user: UInt64, system: UInt64, idle: UInt64, nice: UInt64)]?

    /// 保护 previousTicks 的锁
    private let lock = NSLock()

    func collect() async throws -> CPUMetrics {
        let currentTicks = try readProcessorTicks()

        let result: CPUMetrics = lock.withLock {
            guard let previous = previousTicks else {
                // 第一次采集，无法计算增量，返回 0
                previousTicks = currentTicks
                return CPUMetrics(
                    cpuUsage: 0,
                    perCoreCPU: Array(repeating: 0, count: currentTicks.count)
                )
            }

            var perCore: [Double] = []
            var totalUsed: UInt64 = 0
            var totalAll: UInt64 = 0

            for i in 0..<min(currentTicks.count, previous.count) {
                let cur = currentTicks[i]
                let prev = previous[i]

                let userDelta = cur.user &- prev.user
                let systemDelta = cur.system &- prev.system
                let idleDelta = cur.idle &- prev.idle
                let niceDelta = cur.nice &- prev.nice

                let used = userDelta + systemDelta + niceDelta
                let total = used + idleDelta

                let usage = total > 0 ? Double(used) / Double(total) * 100.0 : 0.0
                perCore.append(usage)

                totalUsed += used
                totalAll += total
            }

            let overallUsage = totalAll > 0 ? Double(totalUsed) / Double(totalAll) * 100.0 : 0.0

            previousTicks = currentTicks
            return CPUMetrics(cpuUsage: overallUsage, perCoreCPU: perCore)
        }

        return result
    }

    // MARK: - Mach API

    /// 读取所有处理器核心的 CPU tick 数据
    private func readProcessorTicks() throws -> [(user: UInt64, system: UInt64, idle: UInt64, nice: UInt64)] {
        var processorCount: natural_t = 0
        var processorInfo: processor_info_array_t?
        var processorInfoCount: mach_msg_type_number_t = 0

        let result = host_processor_info(
            mach_host_self(),
            PROCESSOR_CPU_LOAD_INFO,
            &processorCount,
            &processorInfo,
            &processorInfoCount
        )

        guard result == KERN_SUCCESS, let info = processorInfo else {
            throw CollectorError.machCallFailed("host_processor_info", result)
        }

        defer {
            // 释放 Mach 分配的内存
            vm_deallocate(
                mach_task_self_,
                vm_address_t(bitPattern: info),
                vm_size_t(Int(processorInfoCount) * MemoryLayout<Int32>.size)
            )
        }

        var ticks: [(user: UInt64, system: UInt64, idle: UInt64, nice: UInt64)] = []

        for i in 0..<Int(processorCount) {
            let offset = i * Int(CPU_STATE_MAX)
            let user = UInt64(info[offset + Int(CPU_STATE_USER)])
            let system = UInt64(info[offset + Int(CPU_STATE_SYSTEM)])
            let idle = UInt64(info[offset + Int(CPU_STATE_IDLE)])
            let nice = UInt64(info[offset + Int(CPU_STATE_NICE)])
            ticks.append((user: user, system: system, idle: idle, nice: nice))
        }

        return ticks
    }
}

/// 采集器错误类型
enum CollectorError: Error, LocalizedError {
    case machCallFailed(String, kern_return_t)
    case ioReportUnavailable

    var errorDescription: String? {
        switch self {
        case .machCallFailed(let api, let code):
            return "Mach API \(api) 调用失败，错误码: \(code)"
        case .ioReportUnavailable:
            return "IOReport 框架不可用"
        }
    }
}
