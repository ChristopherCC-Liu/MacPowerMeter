// MacPowerMeterApp.swift
// MacPowerMeter
//
// 应用入口 — macOS 状态栏系统监控应用
// 使用 MenuBarExtra(.window) 显示实时功耗、CPU、内存指标

import SwiftUI

@main
struct MacPowerMeterApp: App {

    @State private var viewModel = MetricsViewModel()

    var body: some Scene {
        MenuBarExtra {
            VStack(spacing: 0) {
                MetricsPanel(
                    metrics: viewModel.currentMetrics,
                    history: viewModel.history,
                    isPowerAvailable: viewModel.isPowerAvailable
                )

                Divider()

                SettingsView()
                    .environment(viewModel)
            }
        } label: {
            StatusBarLabel(
                metrics: viewModel.currentMetrics,
                showPower: viewModel.showPower && viewModel.isPowerAvailable,
                showCPU: viewModel.showCPU,
                showMemory: viewModel.showMemory
            )
        }
        .menuBarExtraStyle(.window)
    }
}
