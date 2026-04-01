// ColorTheme.swift
// MacPowerMeter
//
// 配色系统 — 为三种指标类型提供渐变色、状态色、背景色

import SwiftUI

/// 指标类型枚举
enum MetricType: CaseIterable {
    case power
    case cpu
    case memory
}

/// 全局配色方案
/// 支持 light/dark mode，为每种指标类型提供一致的视觉语言
struct ColorTheme {

    // MARK: - 渐变色

    /// 返回指标类型对应的线性渐变
    /// - power: 橙色到黄色（能量、热力感）
    /// - cpu: 蓝色到青色（科技、冷静感）
    /// - memory: 绿色到薄荷（存储、稳定感）
    static func gradient(for type: MetricType) -> LinearGradient {
        let colors: [Color] = switch type {
        case .power:
            [.orange, .yellow]
        case .cpu:
            [.blue, .cyan]
        case .memory:
            [.green, .mint]
        }
        return LinearGradient(
            colors: colors,
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    /// 危险状态渐变（值 > 80% 时使用）
    static let dangerGradient = LinearGradient(
        colors: [.red, .orange],
        startPoint: .leading,
        endPoint: .trailing
    )

    // MARK: - 状态色

    /// 根据值和指标类型返回对应颜色
    /// - value: 0.0-100.0 的百分比值
    /// - type: 指标类型
    /// - Returns: 正常色 / 警告色 / 危险色
    static func color(for value: Double, type: MetricType) -> Color {
        if value > 80 {
            return .red
        }
        if value > 50 {
            return .yellow
        }
        return normalColor(for: type)
    }

    /// 指标类型的正常基色（渐变起始色）
    private static func normalColor(for type: MetricType) -> Color {
        switch type {
        case .power:  .orange
        case .cpu:    .blue
        case .memory: .green
        }
    }

    // MARK: - 背景色

    /// 面板背景色 — 半透明材质底色，适配 light/dark mode
    static var panelBackground: Color {
        Color(.windowBackgroundColor).opacity(0.95)
    }

    /// 卡片背景色 — 比面板稍亮，用于各指标卡片
    static var cardBackground: Color {
        Color(.controlBackgroundColor)
    }

    /// 分隔线颜色
    static var separator: Color {
        Color(.separatorColor)
    }
}
