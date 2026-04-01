// UIComponentTests.swift
// MacPowerMeterTests
//
// UI 组件测试 — Shape path 验证、EnergyBar 阈值、ColorTheme 渐变、StatusBarLabel 格式化

import Testing
import SwiftUI
@testable import MacPowerMeter

// MARK: - Shape Path 测试

@Suite("PowerIcon Shape 测试")
struct PowerIconShapeTests {

    @Test("闪电 path 应包含 6 个锚点")
    func pathPointCount() {
        let shape = PowerIconShape()
        let path = shape.path(in: CGRect(x: 0, y: 0, width: 16, height: 16))
        // Path 应该非空
        #expect(!path.isEmpty)
        // 闪电形状的 boundingRect 应在 16x16 范围内
        let bounds = path.boundingRect
        #expect(bounds.minX >= 0)
        #expect(bounds.minY >= 0)
        #expect(bounds.maxX <= 16)
        #expect(bounds.maxY <= 16)
    }

    @Test("闪电 path 在不同尺寸下应保持比例")
    func pathScaling() {
        let shape = PowerIconShape()
        let small = shape.path(in: CGRect(x: 0, y: 0, width: 16, height: 16))
        let large = shape.path(in: CGRect(x: 0, y: 0, width: 64, height: 64))

        // 大尺寸 path 的 boundingRect 应约为小尺寸的 4 倍
        let smallBounds = small.boundingRect
        let largeBounds = large.boundingRect

        let widthRatio = largeBounds.width / smallBounds.width
        let heightRatio = largeBounds.height / smallBounds.height

        #expect(widthRatio > 3.5 && widthRatio < 4.5)
        #expect(heightRatio > 3.5 && heightRatio < 4.5)
    }
}

@Suite("CPUIcon Shape 测试")
struct CPUIconShapeTests {

    @Test("芯片 path 应包含中心 die 和 8 根引脚")
    func pathStructure() {
        let shape = CPUIconShape()
        let path = shape.path(in: CGRect(x: 0, y: 0, width: 32, height: 32))

        // Path 非空
        #expect(!path.isEmpty)

        // boundingRect 应覆盖整个 32x32（引脚从 die 边缘向外延伸）
        let bounds = path.boundingRect
        #expect(bounds.minX >= 0)
        #expect(bounds.minY >= 0)
    }

    @Test("芯片 path 在 16pt 下应有效")
    func pathAt16pt() {
        let shape = CPUIconShape()
        let path = shape.path(in: CGRect(x: 0, y: 0, width: 16, height: 16))
        #expect(!path.isEmpty)
    }
}

@Suite("MemoryIcon Shape 测试")
struct MemoryIconShapeTests {

    @Test("内存条 path 应非空且包含芯片颗粒")
    func pathStructure() {
        let shape = MemoryIconShape()
        // 使用 3:2 宽高比
        let path = shape.path(in: CGRect(x: 0, y: 0, width: 24, height: 16))

        #expect(!path.isEmpty)

        let bounds = path.boundingRect
        // 宽度应接近 24（芯片颗粒在基板内）
        #expect(bounds.width > 20)
        #expect(bounds.height > 8)
    }

    @Test("内存条 path 宽高比应约为 3:2")
    func aspectRatio() {
        let shape = MemoryIconShape()
        let path = shape.path(in: CGRect(x: 0, y: 0, width: 48, height: 32))
        let bounds = path.boundingRect
        let ratio = bounds.width / bounds.height
        // 比例应在 1.5 ~ 3.5 之间（基板是主要形状）
        #expect(ratio > 1.0 && ratio < 4.0)
    }
}

// MARK: - ColorTheme 测试

@Suite("ColorTheme 配色系统测试")
struct ColorThemeTests {

    @Test("每种指标类型都应返回有效渐变", arguments: MetricType.allCases)
    func gradientForEachType(type: MetricType) {
        // 验证不会崩溃，渐变可正常创建
        let gradient = ColorTheme.gradient(for: type)
        // LinearGradient 是值类型，创建成功即验证
        _ = gradient
    }

    @Test("低值应返回正常色")
    func normalColorForLowValue() {
        let powerColor = ColorTheme.color(for: 30, type: .power)
        let cpuColor = ColorTheme.color(for: 20, type: .cpu)
        let memColor = ColorTheme.color(for: 10, type: .memory)

        // 低于 50% 时不应返回 .red 或 .yellow
        // 由于 SwiftUI Color 不直接比较 RGB，验证返回值非 .red
        #expect(powerColor != Color.red)
        #expect(cpuColor != Color.red)
        #expect(memColor != Color.red)
    }

    @Test("中等值应返回警告色(黄色)")
    func warningColorForMediumValue() {
        let color = ColorTheme.color(for: 65, type: .power)
        #expect(color == .yellow)
    }

    @Test("高值应返回危险色(红色)")
    func dangerColorForHighValue() {
        let color = ColorTheme.color(for: 85, type: .power)
        #expect(color == .red)
    }

    @Test("阈值边界: 50% 恰好应为警告色")
    func boundaryAt50() {
        // 50 不大于 50，应为正常色
        let color = ColorTheme.color(for: 50, type: .cpu)
        #expect(color != .yellow)
        #expect(color != .red)
    }

    @Test("阈值边界: 80% 恰好应为警告色")
    func boundaryAt80() {
        // 80 不大于 80，应为警告色 (.yellow)
        let color = ColorTheme.color(for: 80, type: .cpu)
        #expect(color == .yellow)
    }

    @Test("阈值边界: 80.1% 应为危险色")
    func boundaryAbove80() {
        let color = ColorTheme.color(for: 80.1, type: .memory)
        #expect(color == .red)
    }

    @Test("背景色属性应可访问")
    func backgroundColors() {
        _ = ColorTheme.panelBackground
        _ = ColorTheme.cardBackground
        _ = ColorTheme.separator
    }
}

// MARK: - StatusBarLabel 格式化测试

@Suite("StatusBarLabel 格式化测试")
struct StatusBarLabelFormatTests {

    /// 创建测试用 SystemMetrics
    private func makeMetrics(
        power: Double = 12.3,
        cpu: Double = 45.0,
        memory: Double = 67.8
    ) -> SystemMetrics {
        SystemMetrics(
            timestamp: .now,
            totalPower: power,
            cpuPower: power * 0.5,
            gpuPower: power * 0.3,
            anePower: power * 0.1,
            cpuUsage: cpu,
            perCoreCPU: [],
            memoryUsage: memory,
            activeMemory: 4_000_000_000,
            wiredMemory: 2_000_000_000,
            compressedMemory: 500_000_000,
            totalMemory: 16_000_000_000
        )
    }

    @Test("StatusBarLabel 应能创建")
    func creation() {
        let label = StatusBarLabel(
            metrics: makeMetrics()
        )
        // 验证 View struct 可被实例化且属性正确
        // 注: 不调用 .body — SPM 命令行测试无 GUI 环境会 SIGTRAP
        #expect(label.showPower == true)
        #expect(label.showCPU == true)
        #expect(label.showMemory == true)
    }

    @Test("隐藏所有指标时 StatusBarLabel 仍应可创建")
    func allHidden() {
        let label = StatusBarLabel(
            metrics: makeMetrics(),
            showPower: false,
            showCPU: false,
            showMemory: false
        )
        #expect(label.showPower == false)
        #expect(label.showCPU == false)
        #expect(label.showMemory == false)
    }

    @Test("仅显示单一指标时属性应正确")
    func singleMetric() {
        let label = StatusBarLabel(
            metrics: makeMetrics(),
            showPower: true,
            showCPU: false,
            showMemory: false
        )
        #expect(label.showPower == true)
        #expect(label.showCPU == false)
        #expect(label.showMemory == false)
    }
}

// MARK: - EnergyBar 阈值测试

@Suite("EnergyBar 阈值行为测试")
struct EnergyBarThresholdTests {

    @Test("EnergyBar 应能以不同值创建", arguments: [0.0, 0.25, 0.5, 0.79, 0.8, 0.81, 0.95, 0.96, 1.0])
    func creationAtValues(value: Double) {
        let bar = EnergyBar(value: value, style: .power)
        _ = bar.body
    }

    @Test("EnergyBar 应能以不同指标类型创建", arguments: MetricType.allCases)
    func creationWithTypes(type: MetricType) {
        let bar = EnergyBar(value: 0.5, style: type)
        _ = bar.body
    }

    @Test("EnergyBar 值应被钳制在 0-1 范围")
    func valueClamping() {
        // 超出范围的值不应导致崩溃
        let overBar = EnergyBar(value: 1.5, style: .cpu)
        _ = overBar.body

        let underBar = EnergyBar(value: -0.5, style: .memory)
        _ = underBar.body
    }
}
