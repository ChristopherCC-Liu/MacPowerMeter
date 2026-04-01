// PowerIcon.swift
// MacPowerMeter
//
// 棱角闪电图标 — 自定义矢量绘制，不使用 SF Symbols

import SwiftUI

/// 棱角闪电形状
/// 两段折线构成闪电，中间有切口，线条粗犷棱角分明
struct PowerIconShape: Shape {

    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height

        // 闪电整体由一个多边形构成，8 个锚点
        // 形成经典的 Z 字闪电轮廓，中间有水平切口分隔上下段
        var path = Path()

        // 从顶部开始，顺时针描绘闪电轮廓
        path.move(to: CGPoint(x: w * 0.58, y: 0))           // 顶点
        path.addLine(to: CGPoint(x: w * 0.18, y: h * 0.42)) // 左上折角
        path.addLine(to: CGPoint(x: w * 0.48, y: h * 0.42)) // 切口左端
        path.addLine(to: CGPoint(x: w * 0.38, y: h))        // 底部尖端
        path.addLine(to: CGPoint(x: w * 0.82, y: h * 0.58)) // 右下折角
        path.addLine(to: CGPoint(x: w * 0.52, y: h * 0.58)) // 切口右端
        path.closeSubpath()

        return path
    }
}

/// 闪电图标视图，可缩放，默认适配 16pt 状态栏
struct PowerIcon: View {

    var size: CGFloat = 16
    var color: Color = .primary

    var body: some View {
        PowerIconShape()
            .fill(color)
            .frame(width: size, height: size)
    }
}
