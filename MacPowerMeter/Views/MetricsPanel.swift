// MetricsPanel.swift
// MacPowerMeter
//
// 下拉详情面板 — 功耗、CPU、内存三张卡片 + 趋势图

import SwiftUI

/// 指标详情面板
/// 下拉弹窗主视图，包含功耗/CPU/内存卡片和历史趋势图
struct MetricsPanel: View {

    let metrics: SystemMetrics
    let history: MetricsHistory

    var body: some View {
        VStack(spacing: 8) {
            powerCard
            cpuCard
            memoryCard
            trendsSection
        }
        .padding(12)
        .frame(width: 320)
        .background(ColorTheme.panelBackground)
    }

    // MARK: - 功耗卡片

    private var powerCard: some View {
        MetricCard(title: "Power", icon: { PowerIcon(size: 14, color: .orange) }) {
            VStack(alignment: .leading, spacing: 6) {
                // 总功耗大字
                HStack(alignment: .firstTextBaseline) {
                    Text(String(format: "%.1f", metrics.totalPower))
                        .font(.system(.title2, design: .rounded, weight: .semibold))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                    Text("W")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.secondary)
                }

                // 分项功耗
                powerSubItem(label: "CPU", value: metrics.cpuPower, total: metrics.totalPower)
                powerSubItem(label: "GPU", value: metrics.gpuPower, total: metrics.totalPower)
                powerSubItem(label: "ANE", value: metrics.anePower, total: metrics.totalPower)
            }
        }
    }

    private func powerSubItem(label: String, value: Double, total: Double) -> some View {
        HStack {
            Text(label)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 30, alignment: .leading)
            EnergyBar(
                value: total > 0 ? value / total : 0,
                style: .power,
                height: 6
            )
            Text(String(format: "%.1fW", value))
                .font(.system(.caption2, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: 42, alignment: .trailing)
        }
    }

    // MARK: - CPU 卡片

    private var cpuCard: some View {
        MetricCard(title: "CPU", icon: { CPUIcon(size: 14, color: .blue) }) {
            VStack(alignment: .leading, spacing: 6) {
                // 总使用率
                HStack(alignment: .firstTextBaseline) {
                    Text(String(format: "%.0f", metrics.cpuUsage))
                        .font(.system(.title2, design: .rounded, weight: .semibold))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                    Text("%")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.secondary)
                }

                // 总使用率进度条
                EnergyBar(value: metrics.cpuUsage / 100, style: .cpu, height: 6)

                // 每核心 mini 进度条
                if !metrics.perCoreCPU.isEmpty {
                    LazyVGrid(
                        columns: Array(
                            repeating: GridItem(.flexible(), spacing: 4),
                            count: min(metrics.perCoreCPU.count, 4)
                        ),
                        spacing: 3
                    ) {
                        ForEach(
                            Array(metrics.perCoreCPU.enumerated()),
                            id: \.offset
                        ) { _, coreValue in
                            EnergyBar(
                                value: coreValue / 100,
                                style: .cpu,
                                height: 3
                            )
                        }
                    }
                }
            }
        }
    }

    // MARK: - 内存卡片

    private var memoryCard: some View {
        MetricCard(title: "Memory", icon: { MemoryIcon(size: 14, color: .green) }) {
            VStack(alignment: .leading, spacing: 6) {
                // 总使用率
                HStack(alignment: .firstTextBaseline) {
                    Text(String(format: "%.0f", metrics.memoryUsage))
                        .font(.system(.title2, design: .rounded, weight: .semibold))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                    Text("%")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(formatBytes(metrics.activeMemory + metrics.wiredMemory + metrics.compressedMemory))
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Text("/")
                        .font(.system(.caption2))
                        .foregroundStyle(.quaternary)
                    Text(formatBytes(metrics.totalMemory))
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.secondary)
                }

                EnergyBar(value: metrics.memoryUsage / 100, style: .memory, height: 6)

                // 内存分项
                memorySubItem(label: "Active", bytes: metrics.activeMemory)
                memorySubItem(label: "Wired", bytes: metrics.wiredMemory)
                memorySubItem(label: "Compressed", bytes: metrics.compressedMemory)
            }
        }
    }

    private func memorySubItem(label: String, bytes: UInt64) -> some View {
        HStack {
            Text(label)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
            Spacer()
            Text(formatBytes(bytes))
                .font(.system(.caption2, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - 趋势图

    private var trendsSection: some View {
        VStack(spacing: 6) {
            let entries = history.entries
            MiniChart(
                data: entries.map(\.totalPower),
                type: .power
            )
            MiniChart(
                data: entries.map(\.cpuUsage),
                type: .cpu
            )
            MiniChart(
                data: entries.map(\.memoryUsage),
                type: .memory
            )
        }
        .padding(.top, 4)
    }

    // MARK: - 格式化

    /// 将字节数格式化为人类可读的字符串
    private func formatBytes(_ bytes: UInt64) -> String {
        let gb = Double(bytes) / 1_073_741_824
        if gb >= 1 {
            return String(format: "%.1f GB", gb)
        }
        let mb = Double(bytes) / 1_048_576
        return String(format: "%.0f MB", mb)
    }
}

// MARK: - 通用卡片容器

/// 带标题和图标的圆角卡片
private struct MetricCard<Icon: View, Content: View>: View {

    let title: String
    @ViewBuilder let icon: () -> Icon
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                icon()
                Text(title)
                    .font(.system(.caption, design: .rounded, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            content()
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ColorTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 2, y: 1)
    }
}
