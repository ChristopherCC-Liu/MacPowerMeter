// SettingsView.swift
// MacPowerMeter
//
// 设置面板 — 刷新间隔、显示项开关、开机自启、退出

import SwiftUI

/// 设置视图
/// 提供刷新间隔选择、显示项开关、开机自启和退出按钮
struct SettingsView: View {

    @Environment(MetricsViewModel.self) private var viewModel

    /// 开机自启（独立于 ViewModel，控制 SMAppService）
    @AppStorage("launchAtLogin") private var launchAtLogin = false

    var body: some View {
        @Bindable var viewModel = viewModel

        VStack(alignment: .leading, spacing: 12) {
            // 标题
            Text("Settings")
                .font(.system(.headline, design: .rounded))

            Divider()

            // 刷新间隔
            HStack {
                Text("Refresh")
                    .font(.system(.body, design: .rounded))
                Spacer()
                Picker("", selection: $viewModel.refreshInterval) {
                    Text("1s").tag(1.0)
                    Text("2s").tag(2.0)
                    Text("5s").tag(5.0)
                    Text("10s").tag(10.0)
                }
                .pickerStyle(.segmented)
                .frame(width: 180)
            }

            Divider()

            // 显示项开关
            VStack(alignment: .leading, spacing: 8) {
                Text("Status Bar")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(.secondary)

                Toggle("Power", isOn: $viewModel.showPower)
                    .toggleStyle(.switch)
                    .controlSize(.small)

                Toggle("CPU", isOn: $viewModel.showCPU)
                    .toggleStyle(.switch)
                    .controlSize(.small)

                Toggle("Memory", isOn: $viewModel.showMemory)
                    .toggleStyle(.switch)
                    .controlSize(.small)
            }

            Divider()

            // 开机自启
            Toggle("Launch at Login", isOn: $launchAtLogin)
                .toggleStyle(.switch)
                .controlSize(.small)

            Divider()

            // 退出按钮
            HStack {
                Spacer()
                Button("Quit MacPowerMeter") {
                    NSApplication.shared.terminate(nil)
                }
                .controlSize(.small)
                Spacer()
            }
        }
        .padding(16)
        .frame(width: 280)
    }
}
