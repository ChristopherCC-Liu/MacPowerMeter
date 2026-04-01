// CollectorTests.swift
// MacPowerMeterTests
//
// CPU 和 Memory Collector 基本采集测试

import Foundation
import Testing
@testable import MacPowerMeter

@Suite("CPUCollector 测试")
struct CPUCollectorTests {

    @Test("首次采集应返回零值（无基线）")
    func firstCollectionReturnsZero() async throws {
        let collector = CPUCollector()
        let metrics = try await collector.collect()

        // 首次采集没有基线对比，应返回 0
        #expect(metrics.cpuUsage == 0)
        #expect(metrics.perCoreCPU.allSatisfy { $0 == 0 })
    }

    @Test("第二次采集应返回有效的 CPU 使用率")
    func secondCollectionReturnsValidUsage() async throws {
        let collector = CPUCollector()

        // 第一次采集建立基线
        _ = try await collector.collect()

        // 等待一小段时间让 CPU 有活动
        try await Task.sleep(for: .milliseconds(100))

        // 第二次采集应返回有效数据
        let metrics = try await collector.collect()

        #expect(metrics.cpuUsage >= 0)
        #expect(metrics.cpuUsage <= 100)
        #expect(!metrics.perCoreCPU.isEmpty)

        for coreUsage in metrics.perCoreCPU {
            #expect(coreUsage >= 0)
            #expect(coreUsage <= 100)
        }
    }

    @Test("perCoreCPU 应包含所有处理器核心")
    func perCoreCountMatchesProcessorCount() async throws {
        let collector = CPUCollector()
        let metrics = try await collector.collect()

        // 至少应有 1 个核心
        #expect(metrics.perCoreCPU.count >= 1)

        // 核心数应与系统报告的一致
        let processorCount = ProcessInfo.processInfo.activeProcessorCount
        #expect(metrics.perCoreCPU.count == processorCount)
    }
}

@Suite("MemoryCollector 测试")
struct MemoryCollectorTests {

    @Test("采集的内存数据应合理")
    func collectReturnsValidData() async throws {
        let collector = MemoryCollector()
        let metrics = try await collector.collect()

        // 内存使用率应在 0-100 之间
        #expect(metrics.memoryUsage > 0)
        #expect(metrics.memoryUsage <= 100)

        // 总内存应大于 0
        #expect(metrics.totalMemory > 0)

        // 各类内存不应超过总内存
        #expect(metrics.activeMemory <= metrics.totalMemory)
        #expect(metrics.wiredMemory <= metrics.totalMemory)
    }

    @Test("总内存应与 ProcessInfo 报告一致")
    func totalMemoryMatchesProcessInfo() async throws {
        let collector = MemoryCollector()
        let metrics = try await collector.collect()

        let expected = ProcessInfo.processInfo.physicalMemory
        #expect(metrics.totalMemory == expected)
    }

    @Test("多次采集应返回一致的总内存")
    func consistentTotalMemory() async throws {
        let collector = MemoryCollector()

        let first = try await collector.collect()
        let second = try await collector.collect()

        #expect(first.totalMemory == second.totalMemory)
    }
}
