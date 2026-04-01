// MiniChart.swift
// MacPowerMeter
//
// 迷你折线图 — 使用 Swift Charts 绘制历史趋势，无坐标轴

import SwiftUI
import Charts

/// 迷你折线趋势图
/// 折线 + 下方渐变填充，无坐标轴和标签，最新值标注小圆点
struct MiniChart: View {

    /// 历史值数组（按时间顺序）
    let data: [Double]
    /// 指标类型，决定渐变色
    let type: MetricType
    /// 图表高度，默认 40pt
    var height: CGFloat = 40

    var body: some View {
        Chart {
            ForEach(Array(data.enumerated()), id: \.offset) { index, value in
                // 折线
                LineMark(
                    x: .value("Time", index),
                    y: .value("Value", value)
                )
                .foregroundStyle(ColorTheme.gradient(for: type))
                .lineStyle(StrokeStyle(lineWidth: 1.5))
                .interpolationMethod(.catmullRom)

                // 下方渐变填充区域
                AreaMark(
                    x: .value("Time", index),
                    y: .value("Value", value)
                )
                .foregroundStyle(
                    ColorTheme.gradient(for: type).opacity(0.2)
                )
                .interpolationMethod(.catmullRom)
            }

            // 最新值标注小圆点
            if let lastValue = data.last {
                PointMark(
                    x: .value("Time", data.count - 1),
                    y: .value("Value", lastValue)
                )
                .foregroundStyle(ColorTheme.color(for: lastValue, type: type))
                .symbolSize(20)
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartLegend(.hidden)
        .chartYScale(domain: 0...chartMaxY)
        .frame(height: height)
    }

    /// Y 轴上限 — 取数据最大值的 1.2 倍，保证折线不贴顶
    private var chartMaxY: Double {
        let maxVal = data.max() ?? 100
        return max(maxVal * 1.2, 1)
    }
}
