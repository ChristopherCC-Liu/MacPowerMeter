// MemoryIcon.swift
// MacPowerMeter
//
// DIMM 内存条侧视图图标 — PCB 基板 + 芯片颗粒 + 防呆缺口

import SwiftUI

/// DIMM 内存条侧视图形状
/// 长方形 PCB 基板，上方 4 个等距小矩形芯片颗粒，底边防呆缺口
struct MemoryIconShape: Shape {

    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height

        // PCB 基板比例约 3:1（宽:高），在给定 rect 内居中
        // 基板占据整个 rect 宽度，高度为 rect 的 60%，垂直居中偏下
        let pcbHeight = h * 0.55
        let pcbY = h * 0.35  // 基板顶边 y 坐标

        var path = Path()

        // PCB 基板主体（带微小圆角）
        let pcbCorner = min(w, h) * 0.05
        let notchWidth = w * 0.06
        let notchHeight = pcbHeight * 0.25
        // 防呆缺口位于底边偏右 1/3 处
        let notchX = w * 0.62

        // 用 Path 手动绘制带缺口的基板
        // 从左上角开始顺时针
        path.move(to: CGPoint(x: pcbCorner, y: pcbY))
        // 顶边
        path.addLine(to: CGPoint(x: w - pcbCorner, y: pcbY))
        // 右上角
        path.addQuadCurve(
            to: CGPoint(x: w, y: pcbY + pcbCorner),
            control: CGPoint(x: w, y: pcbY)
        )
        // 右边
        path.addLine(to: CGPoint(x: w, y: pcbY + pcbHeight - pcbCorner))
        // 右下角
        path.addQuadCurve(
            to: CGPoint(x: w - pcbCorner, y: pcbY + pcbHeight),
            control: CGPoint(x: w, y: pcbY + pcbHeight)
        )
        // 底边（带缺口）— 从右到缺口右侧
        path.addLine(to: CGPoint(x: notchX + notchWidth, y: pcbY + pcbHeight))
        // 缺口右侧向上
        path.addLine(to: CGPoint(x: notchX + notchWidth, y: pcbY + pcbHeight - notchHeight))
        // 缺口顶部
        path.addLine(to: CGPoint(x: notchX, y: pcbY + pcbHeight - notchHeight))
        // 缺口左侧向下
        path.addLine(to: CGPoint(x: notchX, y: pcbY + pcbHeight))
        // 底边剩余部分到左下角
        path.addLine(to: CGPoint(x: pcbCorner, y: pcbY + pcbHeight))
        // 左下角
        path.addQuadCurve(
            to: CGPoint(x: 0, y: pcbY + pcbHeight - pcbCorner),
            control: CGPoint(x: 0, y: pcbY + pcbHeight)
        )
        // 左边
        path.addLine(to: CGPoint(x: 0, y: pcbY + pcbCorner))
        // 左上角
        path.addQuadCurve(
            to: CGPoint(x: pcbCorner, y: pcbY),
            control: CGPoint(x: 0, y: pcbY)
        )
        path.closeSubpath()

        // 芯片颗粒 x4 — 等距排列在基板上方区域
        let chipCount = 4
        let chipMarginH = w * 0.08          // 左右边距
        let chipAreaWidth = w - 2 * chipMarginH
        let chipWidth = chipAreaWidth * 0.16  // 每个芯片宽度
        let chipSpacing = (chipAreaWidth - CGFloat(chipCount) * chipWidth) / CGFloat(chipCount - 1)
        let chipHeight = pcbHeight * 0.45
        let chipY = pcbY + pcbHeight * 0.12  // 芯片在基板内的垂直位置

        for i in 0..<chipCount {
            let chipX = chipMarginH + CGFloat(i) * (chipWidth + chipSpacing)
            path.addRoundedRect(
                in: CGRect(x: chipX, y: chipY, width: chipWidth, height: chipHeight),
                cornerSize: CGSize(width: pcbCorner * 0.5, height: pcbCorner * 0.5)
            )
        }

        return path
    }
}

/// 内存条图标视图，可缩放，默认适配 16pt 状态栏
struct MemoryIcon: View {

    var size: CGFloat = 16
    var color: Color = .primary

    var body: some View {
        MemoryIconShape()
            .fill(color)
            .frame(width: size * 1.5, height: size)  // 保持约 3:2 宽高比
    }
}
