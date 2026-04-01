// MetricsEngine.swift
// MacPowerMeter
//
// 指标采集引擎 — 整合三个 Collector，通过 AsyncStream 向外提供数据

import Foundation

/// 指标采集引擎
/// 定时调用三个 Collector 采集数据，通过 AsyncStream 推送给消费者
actor MetricsEngine {

    // MARK: - 采集器

    private let cpuCollector: CPUCollector
    private let memoryCollector: MemoryCollector
    private let powerCollector: PowerCollector

    // MARK: - 状态

    /// 当前采样间隔（秒）
    private var interval: TimeInterval

    /// 采集循环 Task 句柄
    private var collectionTask: Task<Void, Never>?

    /// AsyncStream 的 continuation
    private var continuation: AsyncStream<SystemMetrics>.Continuation?

    /// 功耗采集是否可用
    var isPowerAvailable: Bool {
        powerCollector.isAvailable
    }

    // MARK: - 初始化

    init(
        cpuCollector: CPUCollector = CPUCollector(),
        memoryCollector: MemoryCollector = MemoryCollector(),
        powerCollector: PowerCollector = PowerCollector(),
        interval: TimeInterval = 2.0
    ) {
        self.cpuCollector = cpuCollector
        self.memoryCollector = memoryCollector
        self.powerCollector = powerCollector
        self.interval = interval
    }

    // MARK: - 启动 / 停止

    /// 启动采集循环，返回 AsyncStream 供消费者订阅
    /// - Parameter interval: 采样间隔（秒），默认使用初始化时的值
    /// - Returns: 持续推送 SystemMetrics 的异步流
    func start(interval: TimeInterval? = nil) -> AsyncStream<SystemMetrics> {
        // 如果已有运行中的采集，先停止
        stopInternal()

        if let interval {
            self.interval = interval
        }

        let (stream, continuation) = AsyncStream<SystemMetrics>.makeStream()
        self.continuation = continuation

        collectionTask = Task { [weak self] in
            guard let self else { return }
            await self.collectionLoop()
        }

        return stream
    }

    /// 停止采集循环
    func stop() {
        stopInternal()
    }

    /// 动态更新采样间隔
    /// 会重启采集循环以应用新间隔
    func updateInterval(_ newInterval: TimeInterval) {
        guard newInterval > 0 else { return }
        interval = newInterval
    }

    // MARK: - 内部实现

    private func stopInternal() {
        collectionTask?.cancel()
        collectionTask = nil
        continuation?.finish()
        continuation = nil
    }

    /// 采集循环主体
    private func collectionLoop() async {
        // 首次采样前先做一次 CPU 采集来初始化基线
        _ = try? await cpuCollector.collect()

        while !Task.isCancelled {
            let metrics = await collectOnce()
            continuation?.yield(metrics)

            // 使用 Task.sleep 而非 Thread.sleep，支持取消
            do {
                try await Task.sleep(for: .seconds(interval))
            } catch {
                // Task 被取消
                break
            }
        }
    }

    /// 执行一次完整的系统指标采集
    private func collectOnce() async -> SystemMetrics {
        // 并行采集三个维度
        async let cpuResult = cpuCollector.collect()
        async let memoryResult = memoryCollector.collect()
        async let powerResult = powerCollector.collect()

        // 等待所有采集完成，失败时使用默认值
        let cpu = (try? await cpuResult) ?? CPUMetrics(cpuUsage: 0, perCoreCPU: [])
        let memory = (try? await memoryResult) ?? MemoryMetrics(
            memoryUsage: 0, activeMemory: 0, wiredMemory: 0, compressedMemory: 0, totalMemory: 0
        )
        let power = (try? await powerResult) ?? PowerMetrics(
            totalPower: 0, cpuPower: 0, gpuPower: 0, anePower: 0
        )

        return SystemMetrics(
            timestamp: Date(),
            totalPower: power.totalPower,
            cpuPower: power.cpuPower,
            gpuPower: power.gpuPower,
            anePower: power.anePower,
            cpuUsage: cpu.cpuUsage,
            perCoreCPU: cpu.perCoreCPU,
            memoryUsage: memory.memoryUsage,
            activeMemory: memory.activeMemory,
            wiredMemory: memory.wiredMemory,
            compressedMemory: memory.compressedMemory,
            totalMemory: memory.totalMemory
        )
    }
}
