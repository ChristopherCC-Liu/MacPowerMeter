// MetricsHistory.swift
// MacPowerMeter
//
// 指标历史环形缓冲区，固定容量，自动淘汰最旧数据

import Foundation

/// 固定容量的指标历史记录
/// 当缓冲区满时，新数据自动替换最旧的数据
struct MetricsHistory: Sendable {

    /// 环形缓冲区存储
    private var buffer: [SystemMetrics]

    /// 缓冲区最大容量
    let capacity: Int

    /// 下一个写入位置
    private var writeIndex: Int

    /// 当前已存储的元素数量（未满时 < capacity）
    private var storedCount: Int

    // MARK: - 初始化

    /// 创建指定容量的历史缓冲区
    /// - Parameter capacity: 最大存储条目数，默认 60
    init(capacity: Int = 60) {
        precondition(capacity > 0, "MetricsHistory 容量必须大于 0")
        self.capacity = capacity
        self.buffer = []
        self.buffer.reserveCapacity(capacity)
        self.writeIndex = 0
        self.storedCount = 0
    }

    // MARK: - 写入

    /// 追加一条指标记录
    /// 当缓冲区已满时，覆盖最旧的记录
    mutating func append(_ metrics: SystemMetrics) {
        if buffer.count < capacity {
            // 缓冲区未满，直接追加
            buffer.append(metrics)
            storedCount = buffer.count
            writeIndex = storedCount % capacity
        } else {
            // 缓冲区已满，覆盖最旧位置
            buffer[writeIndex] = metrics
            writeIndex = (writeIndex + 1) % capacity
        }
    }

    // MARK: - 读取

    /// 按时间顺序返回所有记录（最旧在前）
    var entries: [SystemMetrics] {
        guard storedCount > 0 else { return [] }

        if storedCount < capacity {
            // 缓冲区未满，buffer 本身就是顺序的
            return buffer
        }

        // 缓冲区已满，从 writeIndex 开始读取一圈
        // writeIndex 指向最旧的元素（即下一个要被覆盖的位置）
        let oldest = Array(buffer[writeIndex...])
        let newer = Array(buffer[..<writeIndex])
        return oldest + newer
    }

    /// 最新一条记录
    var latest: SystemMetrics? {
        guard storedCount > 0 else { return nil }

        if storedCount < capacity {
            return buffer.last
        }

        // writeIndex 指向下一个写入位置，前一个就是最新的
        let latestIndex = (writeIndex - 1 + capacity) % capacity
        return buffer[latestIndex]
    }

    /// 当前存储的记录数
    var count: Int {
        storedCount
    }
}
