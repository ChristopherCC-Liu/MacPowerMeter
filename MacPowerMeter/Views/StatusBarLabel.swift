// StatusBarLabel.swift
// MacPowerMeter
//
// 状态栏标签 — 显示 PowerIcon 12.3W | CPUIcon 23% | MemoryIcon 67%

import SwiftUI

/// 状态栏紧凑标签视图
/// 根据用户偏好显示功耗、CPU、内存指标，用自定义图标 + 等宽数字
struct StatusBarLabel: View {

    let metrics: SystemMetrics
    var showPower: Bool = true
    var showCPU: Bool = true
    var showMemory: Bool = true

    var body: some View {
        HStack(spacing: 4) {
            if showPower {
                powerSegment
            }

            if showPower && (showCPU || showMemory) {
                divider
            }

            if showCPU {
                cpuSegment
            }

            if showCPU && showMemory {
                divider
            }

            if showMemory {
                memorySegment
            }
        }
    }

    // MARK: - 各指标段

    private var powerSegment: some View {
        HStack(spacing: 2) {
            PowerIcon(size: 12, color: ColorTheme.color(for: metrics.totalPower, type: .power))
            Text(formatWatts(metrics.totalPower))
                .font(.system(.caption, design: .monospaced))
                .monospacedDigit()
                .contentTransition(.numericText())
        }
    }

    private var cpuSegment: some View {
        HStack(spacing: 2) {
            CPUIcon(size: 12, color: ColorTheme.color(for: metrics.cpuUsage, type: .cpu))
            Text(formatPercent(metrics.cpuUsage))
                .font(.system(.caption, design: .monospaced))
                .monospacedDigit()
                .contentTransition(.numericText())
        }
    }

    private var memorySegment: some View {
        HStack(spacing: 2) {
            MemoryIcon(size: 12, color: ColorTheme.color(for: metrics.memoryUsage, type: .memory))
            Text(formatPercent(metrics.memoryUsage))
                .font(.system(.caption, design: .monospaced))
                .monospacedDigit()
                .contentTransition(.numericText())
        }
    }

    // MARK: - 分隔符

    private var divider: some View {
        Text("|")
            .font(.system(.caption2))
            .foregroundStyle(.secondary.opacity(0.5))
    }

    // MARK: - 格式化

    /// 格式化功耗值: "12.3W"
    private func formatWatts(_ watts: Double) -> String {
        String(format: "%.1fW", watts)
    }

    /// 格式化百分比值: "23%"
    private func formatPercent(_ percent: Double) -> String {
        String(format: "%.0f%%", percent)
    }
}
