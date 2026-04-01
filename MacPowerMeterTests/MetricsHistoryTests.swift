// MetricsHistoryTests.swift
// MacPowerMeterTests
//
// MetricsHistory 环形缓冲区测试

import Foundation
import Testing
@testable import MacPowerMeter

@Suite("MetricsHistory 环形缓冲区测试")
struct MetricsHistoryTests {

    // MARK: - 辅助方法

    /// 创建带有指定功耗值的测试指标（用功耗值区分不同记录）
    private func makeMetrics(power: Double) -> SystemMetrics {
        SystemMetrics(
            timestamp: Date(),
            totalPower: power,
            cpuPower: 0, gpuPower: 0, anePower: 0,
            cpuUsage: 0, perCoreCPU: [],
            memoryUsage: 0,
            activeMemory: 0, wiredMemory: 0, compressedMemory: 0, totalMemory: 0
        )
    }

    // MARK: - 初始状态

    @Test("新建的 History 应该为空")
    func emptyHistory() {
        let history = MetricsHistory(capacity: 10)

        #expect(history.count == 0)
        #expect(history.entries.isEmpty)
        #expect(history.latest == nil)
    }

    @Test("默认容量应该为 60")
    func defaultCapacity() {
        let history = MetricsHistory()
        #expect(history.capacity == 60)
    }

    // MARK: - 追加测试

    @Test("追加一条记录后 count 应为 1")
    func appendOne() {
        var history = MetricsHistory(capacity: 5)
        history.append(makeMetrics(power: 10.0))

        #expect(history.count == 1)
        #expect(history.latest?.totalPower == 10.0)
        #expect(history.entries.count == 1)
    }

    @Test("追加多条记录，entries 应按顺序排列")
    func appendMultiple() {
        var history = MetricsHistory(capacity: 5)

        for i in 1...3 {
            history.append(makeMetrics(power: Double(i)))
        }

        #expect(history.count == 3)
        #expect(history.entries.count == 3)

        let powers = history.entries.map(\.totalPower)
        #expect(powers == [1.0, 2.0, 3.0])
        #expect(history.latest?.totalPower == 3.0)
    }

    // MARK: - 溢出测试

    @Test("超过容量时应覆盖最旧的记录")
    func overflow() {
        var history = MetricsHistory(capacity: 3)

        // 插入 5 条，容量只有 3
        for i in 1...5 {
            history.append(makeMetrics(power: Double(i)))
        }

        #expect(history.count == 3)
        #expect(history.entries.count == 3)

        // 最旧的 1.0 和 2.0 应该已被覆盖
        let powers = history.entries.map(\.totalPower)
        #expect(powers == [3.0, 4.0, 5.0])
        #expect(history.latest?.totalPower == 5.0)
    }

    @Test("恰好填满容量时应正确工作")
    func exactlyFull() {
        var history = MetricsHistory(capacity: 3)

        for i in 1...3 {
            history.append(makeMetrics(power: Double(i)))
        }

        #expect(history.count == 3)
        let powers = history.entries.map(\.totalPower)
        #expect(powers == [1.0, 2.0, 3.0])
    }

    // MARK: - entries 顺序测试

    @Test("溢出后 entries 仍按最旧在前排列")
    func entriesOrderAfterOverflow() {
        var history = MetricsHistory(capacity: 4)

        // 插入 7 条，应保留最后 4 条
        for i in 1...7 {
            history.append(makeMetrics(power: Double(i)))
        }

        let powers = history.entries.map(\.totalPower)
        #expect(powers == [4.0, 5.0, 6.0, 7.0])
    }

    @Test("多次溢出后 latest 始终指向最新记录")
    func latestAfterMultipleOverflows() {
        var history = MetricsHistory(capacity: 2)

        for i in 1...10 {
            history.append(makeMetrics(power: Double(i)))
            #expect(history.latest?.totalPower == Double(i))
        }
    }

    // MARK: - 容量为 1 的边界情况

    @Test("容量为 1 时应只保留最新记录")
    func capacityOne() {
        var history = MetricsHistory(capacity: 1)

        history.append(makeMetrics(power: 1.0))
        #expect(history.count == 1)
        #expect(history.latest?.totalPower == 1.0)

        history.append(makeMetrics(power: 2.0))
        #expect(history.count == 1)
        #expect(history.latest?.totalPower == 2.0)
        #expect(history.entries.count == 1)
    }
}
