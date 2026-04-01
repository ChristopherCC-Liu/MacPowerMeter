// CPUIcon.swift
// MacPowerMeter
//
// 芯片俯视图图标 — 中心正方形 die + 上下左右各 2 根引脚

import SwiftUI

/// 芯片俯视图形状
/// 中心正方形代表芯片 die，四边各有 2 根短粗矩形引脚
struct CPUIconShape: Shape {

    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height

        // 芯片 die 占中心 50% 区域
        let dieInset: CGFloat = 0.25
        let dieRect = CGRect(
            x: w * dieInset,
            y: h * dieInset,
            width: w * (1 - 2 * dieInset),
            height: h * (1 - 2 * dieInset)
        )

        // 引脚尺寸
        let pinWidth = w * 0.10   // 引脚宽度
        let pinLength = w * 0.15  // 引脚长度（从 die 边缘向外延伸）
        let pinGap = w * 0.06     // 引脚之间的间距

        // 两根引脚的中心偏移（相对于 die 中心线）
        let offset = (pinWidth + pinGap) / 2

        var path = Path()

        // 中心芯片 die（带微小圆角）
        let cornerRadius = w * 0.04
        path.addRoundedRect(
            in: dieRect,
            cornerSize: CGSize(width: cornerRadius, height: cornerRadius)
        )

        // 顶部引脚 x2
        for dx in [-offset, offset] {
            let pinX = w * 0.5 + dx - pinWidth / 2
            path.addRect(CGRect(
                x: pinX,
                y: dieRect.minY - pinLength,
                width: pinWidth,
                height: pinLength
            ))
        }

        // 底部引脚 x2
        for dx in [-offset, offset] {
            let pinX = w * 0.5 + dx - pinWidth / 2
            path.addRect(CGRect(
                x: pinX,
                y: dieRect.maxY,
                width: pinWidth,
                height: pinLength
            ))
        }

        // 左侧引脚 x2
        for dy in [-offset, offset] {
            let pinY = h * 0.5 + dy - pinWidth / 2
            path.addRect(CGRect(
                x: dieRect.minX - pinLength,
                y: pinY,
                width: pinLength,
                height: pinWidth
            ))
        }

        // 右侧引脚 x2
        for dy in [-offset, offset] {
            let pinY = h * 0.5 + dy - pinWidth / 2
            path.addRect(CGRect(
                x: dieRect.maxX,
                y: pinY,
                width: pinLength,
                height: pinWidth
            ))
        }

        return path
    }
}

/// 芯片图标视图，可缩放，默认适配 16pt 状态栏
struct CPUIcon: View {

    var size: CGFloat = 16
    var color: Color = .primary

    var body: some View {
        CPUIconShape()
            .fill(color)
            .frame(width: size, height: size)
    }
}
