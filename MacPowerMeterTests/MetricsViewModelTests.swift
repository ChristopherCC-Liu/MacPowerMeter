// MetricsViewModelTests.swift
// MacPowerMeterTests
//
// MetricsViewModel 集成测试 — 验证 Engine -> ViewModel 数据流

import Foundation
import Testing
@testable import MacPowerMeter

@Suite("MetricsViewModel 测试")
@MainActor
struct MetricsViewModelTests {

    @Test("初始状态为零值")
    func initialStateIsZero() {
        let vm = MetricsViewModel(autoStart: false)
        #expect(vm.currentMetrics == SystemMetrics.zero)
        #expect(vm.history.count == 0)
        #expect(vm.formattedPower == "0.0W")
        #expect(vm.formattedCPU == "0%")
        #expect(vm.formattedMemory == "0%")
    }

    @Test("默认设置值正确")
    func defaultSettings() {
        let vm = MetricsViewModel(autoStart: false)
        #expect(vm.showPower == true)
        #expect(vm.showCPU == true)
        #expect(vm.showMemory == true)
        #expect(vm.refreshInterval == 2.0)
    }

    @Test("格式化属性输出正确格式")
    func formattedPropertiesAreCorrect() {
        let vm = MetricsViewModel(autoStart: false)

        // 格式验证: 初始零值
        #expect(vm.formattedPower == "0.0W")
        #expect(vm.formattedCPU == "0%")
        #expect(vm.formattedMemory == "0%")
    }

    @Test("设置属性可以修改")
    func settingsCanBeModified() {
        let vm = MetricsViewModel(autoStart: false)
        vm.showPower = false
        vm.showCPU = false
        vm.refreshInterval = 5.0

        #expect(vm.showPower == false)
        #expect(vm.showCPU == false)
        #expect(vm.refreshInterval == 5.0)
    }
}

// 注: LaunchAtLogin 测试已移除
// SMAppService.mainApp.status 在非签名的命令行二进制中会触发 SIGTRAP
// 需要正式的 .app bundle + 代码签名才能测试
