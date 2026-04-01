// EnergyBar.swift
// MacPowerMeter
//
// 能量柱组件 — 胶囊形渐变进度条，支持弹性动画和危险状态脉冲

import SwiftUI

/// 能量柱进度条
/// 胶囊形圆角，水平渐变填充，支持阈值变色和脉冲动画
struct EnergyBar: View {

    /// 当前值 (0.0-1.0)
    let value: Double
    /// 指标类型，决定渐变配色
    let style: MetricType
    /// 柱体高度，默认 8pt
    var height: CGFloat = 8

    /// 脉冲动画状态
    @State private var isPulsing = false

    var body: some View {
        GeometryReader { geometry in
            let totalWidth = geometry.size.width
            let clampedValue = min(max(value, 0), 1)
            let fillWidth = totalWidth * clampedValue

            ZStack(alignment: .leading) {
                // 背景轨道
                Capsule()
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: height)

                // 前景填充
                Capsule()
                    .fill(fillGradient)
                    .frame(width: fillWidth, height: height)
                    .opacity(pulseOpacity)
            }
            .clipShape(Capsule())
            .frame(height: height)
        }
        .frame(height: height)
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: value)
        .onChange(of: value) { _, newValue in
            updatePulse(for: newValue)
        }
        .onAppear {
            updatePulse(for: value)
        }
    }

    // MARK: - 渐变色

    /// 根据值选择渐变：正常使用指标色，超过 80% 使用危险色
    private var fillGradient: LinearGradient {
        if value > 0.8 {
            return ColorTheme.dangerGradient
        }
        return ColorTheme.gradient(for: style)
    }

    // MARK: - 脉冲动画

    /// 超过 95% 时启用脉冲闪烁
    private var pulseOpacity: Double {
        if value > 0.95 {
            return isPulsing ? 0.6 : 1.0
        }
        return 1.0
    }

    private func updatePulse(for newValue: Double) {
        if newValue > 0.95 {
            withAnimation(
                .easeInOut(duration: 0.8)
                .repeatForever(autoreverses: true)
            ) {
                isPulsing = true
            }
        } else {
            withAnimation(.easeOut(duration: 0.3)) {
                isPulsing = false
            }
        }
    }
}
