// PowerStrategy.swift
// MacPowerMeter
//
// 功耗采集策略协议
// 支持 IOReport 和 SMC 两种采集方式的统一接口

import Foundation

/// 功耗采集策略协议
/// IOReportPowerStrategy 和 SMCPowerCollector 均需 conform 此协议
protocol PowerStrategy: Sendable {
    var isAvailable: Bool { get }
    func collect() async throws -> PowerMetrics
}
