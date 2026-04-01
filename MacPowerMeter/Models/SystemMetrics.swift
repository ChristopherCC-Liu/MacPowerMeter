// SystemMetrics.swift
// MacPowerMeter
//
// 系统指标不可变数据模型，包含功耗、CPU、内存三个维度

import Foundation

/// 系统指标快照 — 单次采集的完整数据
/// 不可变值类型，可安全跨 actor 边界传递
struct SystemMetrics: Sendable, Equatable {

    // MARK: - 时间戳

    let timestamp: Date

    // MARK: - 功耗 (Watts)

    /// 系统总功耗
    let totalPower: Double
    /// CPU 功耗
    let cpuPower: Double
    /// GPU 功耗
    let gpuPower: Double
    /// Apple Neural Engine 功耗
    let anePower: Double

    // MARK: - CPU (百分比 0.0-100.0)

    /// CPU 总使用率
    let cpuUsage: Double
    /// 每核心 CPU 使用率
    let perCoreCPU: [Double]

    // MARK: - 内存

    /// 内存使用率 (百分比 0.0-100.0)
    let memoryUsage: Double
    /// 活跃内存 (bytes)
    let activeMemory: UInt64
    /// 固定内存 (bytes)
    let wiredMemory: UInt64
    /// 压缩内存 (bytes)
    let compressedMemory: UInt64
    /// 总物理内存 (bytes)
    let totalMemory: UInt64

    // MARK: - 零值常量

    /// 全零指标，用于初始状态
    static let zero = SystemMetrics(
        timestamp: .distantPast,
        totalPower: 0,
        cpuPower: 0,
        gpuPower: 0,
        anePower: 0,
        cpuUsage: 0,
        perCoreCPU: [],
        memoryUsage: 0,
        activeMemory: 0,
        wiredMemory: 0,
        compressedMemory: 0,
        totalMemory: 0
    )
}
