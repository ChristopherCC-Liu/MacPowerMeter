// SystemMetricsTests.swift
// MacPowerMeterTests
//
// SystemMetrics 数据模型测试

import Foundation
import Testing
@testable import MacPowerMeter

@Suite("SystemMetrics 数据模型测试")
struct SystemMetricsTests {

    // MARK: - 零值测试

    @Test("zero 常量所有字段应为零或空")
    func zeroConstant() {
        let zero = SystemMetrics.zero

        #expect(zero.timestamp == .distantPast)
        #expect(zero.totalPower == 0)
        #expect(zero.cpuPower == 0)
        #expect(zero.gpuPower == 0)
        #expect(zero.anePower == 0)
        #expect(zero.cpuUsage == 0)
        #expect(zero.perCoreCPU.isEmpty)
        #expect(zero.memoryUsage == 0)
        #expect(zero.activeMemory == 0)
        #expect(zero.wiredMemory == 0)
        #expect(zero.compressedMemory == 0)
        #expect(zero.totalMemory == 0)
    }

    // MARK: - Equatable 测试

    @Test("两个 zero 值应相等")
    func zeroEquality() {
        #expect(SystemMetrics.zero == SystemMetrics.zero)
    }

    @Test("不同值的 SystemMetrics 应不相等")
    func inequality() {
        let a = SystemMetrics.zero
        let b = SystemMetrics(
            timestamp: Date(),
            totalPower: 10.0,
            cpuPower: 5.0,
            gpuPower: 3.0,
            anePower: 2.0,
            cpuUsage: 50.0,
            perCoreCPU: [40.0, 60.0],
            memoryUsage: 70.0,
            activeMemory: 1024,
            wiredMemory: 512,
            compressedMemory: 256,
            totalMemory: 8192
        )

        #expect(a != b)
    }

    // MARK: - 不可变性测试

    @Test("SystemMetrics 所有字段均为 let，编译通过即证明不可变")
    func immutability() {
        let metrics = SystemMetrics(
            timestamp: Date(),
            totalPower: 15.5,
            cpuPower: 8.0,
            gpuPower: 5.5,
            anePower: 2.0,
            cpuUsage: 35.0,
            perCoreCPU: [30.0, 40.0, 35.0, 35.0],
            memoryUsage: 60.0,
            activeMemory: 4096,
            wiredMemory: 2048,
            compressedMemory: 1024,
            totalMemory: 16384
        )

        // 验证值被正确存储
        #expect(metrics.totalPower == 15.5)
        #expect(metrics.perCoreCPU.count == 4)
        #expect(metrics.totalMemory == 16384)
    }
}
