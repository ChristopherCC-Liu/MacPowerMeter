// MemoryCollector.swift
// MacPowerMeter
//
// 通过 Mach host_statistics64 API 采集内存使用信息

import Foundation
@preconcurrency import Darwin

/// 内存采集结果
struct MemoryMetrics: Sendable {
    let memoryUsage: Double
    let activeMemory: UInt64
    let wiredMemory: UInt64
    let compressedMemory: UInt64
    let totalMemory: UInt64
}

/// 内存使用率采集器
/// 使用 host_statistics64() 获取 vm_statistics64 数据
struct MemoryCollector: DataProvider {

    func collect() async throws -> MemoryMetrics {
        let stats = try readVMStatistics()
        let pageSize = UInt64(vm_kernel_page_size)

        let active = UInt64(stats.active_count) * pageSize
        let wired = UInt64(stats.wire_count) * pageSize
        let compressed = UInt64(stats.compressor_page_count) * pageSize
        let total = ProcessInfo.processInfo.physicalMemory

        // 已使用 = 活跃 + 固定 + 压缩
        let used = active + wired + compressed
        let usage = total > 0 ? Double(used) / Double(total) * 100.0 : 0.0

        return MemoryMetrics(
            memoryUsage: usage,
            activeMemory: active,
            wiredMemory: wired,
            compressedMemory: compressed,
            totalMemory: total
        )
    }

    // MARK: - Mach API

    /// 读取虚拟内存统计信息
    private func readVMStatistics() throws -> vm_statistics64 {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size
        )

        let result = withUnsafeMutablePointer(to: &stats) { statsPtr in
            statsPtr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPtr in
                host_statistics64(
                    mach_host_self(),
                    HOST_VM_INFO64,
                    intPtr,
                    &count
                )
            }
        }

        guard result == KERN_SUCCESS else {
            throw CollectorError.machCallFailed("host_statistics64", result)
        }

        return stats
    }
}
