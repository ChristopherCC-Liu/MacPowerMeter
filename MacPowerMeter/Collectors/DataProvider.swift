// DataProvider.swift
// MacPowerMeter
//
// 数据采集协议定义

import Foundation

/// 数据采集器协议
/// 每个采集器负责收集一类系统指标
protocol DataProvider: Sendable {
    associatedtype Metrics
    func collect() async throws -> Metrics
}
