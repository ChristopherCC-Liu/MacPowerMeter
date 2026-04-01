// MetricsViewModel.swift
// MacPowerMeter
//
// 核心 ViewModel — 连接 MetricsEngine 和 UI 层
// 订阅 AsyncStream，维护 MetricsHistory，提供格式化属性

import SwiftUI

/// 系统指标视图模型
/// 管理 MetricsEngine 生命周期，通过 @Observable 驱动 UI 更新
@MainActor
@Observable
final class MetricsViewModel {

    // MARK: - 公开状态

    /// 最新一次采集的指标
    private(set) var currentMetrics: SystemMetrics = .zero

    /// 历史指标数据（最近 60 条）
    private(set) var history: MetricsHistory = MetricsHistory()

    /// 功耗采集是否可用
    private(set) var isPowerAvailable: Bool = false

    // MARK: - 设置（与 SettingsView 的 @AppStorage 同步）

    /// 刷新间隔（秒）
    var refreshInterval: TimeInterval = 2.0 {
        didSet {
            UserDefaults.standard.set(refreshInterval, forKey: "refreshInterval")
            Task { await engine.updateInterval(refreshInterval) }
        }
    }

    /// 是否显示功耗
    var showPower: Bool = true {
        didSet { UserDefaults.standard.set(showPower, forKey: "showPower") }
    }

    /// 是否显示 CPU
    var showCPU: Bool = true {
        didSet { UserDefaults.standard.set(showCPU, forKey: "showCPU") }
    }

    /// 是否显示内存
    var showMemory: Bool = true {
        didSet { UserDefaults.standard.set(showMemory, forKey: "showMemory") }
    }

    // MARK: - 私有状态

    private let engine: MetricsEngine
    nonisolated(unsafe) private var streamTask: Task<Void, Never>?

    // MARK: - 初始化

    init(engine: MetricsEngine = MetricsEngine(), autoStart: Bool = true) {
        self.engine = engine
        syncFromUserDefaults()
        if autoStart {
            Task {
                await self.start()
            }
        }
    }

    deinit {
        streamTask?.cancel()
    }

    // MARK: - 生命周期

    /// 启动指标采集
    /// 从 MetricsEngine 获取 AsyncStream 并开始消费
    func start() async {
        isPowerAvailable = await engine.isPowerAvailable

        let stream = await engine.start(interval: refreshInterval)

        streamTask = Task {
            for await metrics in stream {
                guard !Task.isCancelled else { break }
                self.currentMetrics = metrics
                self.history.append(metrics)
            }
        }
    }

    /// 停止指标采集
    func stop() {
        streamTask?.cancel()
        streamTask = nil
        Task {
            await engine.stop()
        }
    }

    // MARK: - 格式化属性

    /// 格式化功耗: "12.3W"
    var formattedPower: String {
        String(format: "%.1fW", currentMetrics.totalPower)
    }

    /// 格式化 CPU 使用率: "23%"
    var formattedCPU: String {
        String(format: "%.0f%%", currentMetrics.cpuUsage)
    }

    /// 格式化内存使用率: "67%"
    var formattedMemory: String {
        String(format: "%.0f%%", currentMetrics.memoryUsage)
    }

    // MARK: - UserDefaults 同步

    /// 从 UserDefaults 读取初始设置
    private func syncFromUserDefaults() {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: "refreshInterval") != nil {
            refreshInterval = defaults.double(forKey: "refreshInterval")
        }
        showPower = defaults.object(forKey: "showPower") != nil
            ? defaults.bool(forKey: "showPower") : true
        showCPU = defaults.object(forKey: "showCPU") != nil
            ? defaults.bool(forKey: "showCPU") : true
        showMemory = defaults.object(forKey: "showMemory") != nil
            ? defaults.bool(forKey: "showMemory") : true
    }

}
