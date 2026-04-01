// SettingsView.swift
// MacPowerMeter
//
// 设置面板 — 刷新间隔、显示项开关、开机自启、退出

import SwiftUI

/// 设置视图
/// 提供刷新间隔选择、显示项开关、开机自启和退出按钮
struct SettingsView: View {

    /// 刷新间隔（秒）
    @AppStorage("refreshInterval") private var refreshInterval: Double = 2
    /// 是否显示功耗
    @AppStorage("showPower") private var showPower = true
    /// 是否显示 CPU
    @AppStorage("showCPU") private var showCPU = true
    /// 是否显示内存
    @AppStorage("showMemory") private var showMemory = true
    /// 开机自启
    @AppStorage("launchAtLogin") private var launchAtLogin = false

    var body: some View {
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
                Picker("", selection: $refreshInterval) {
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

                Toggle("Power", isOn: $showPower)
                    .toggleStyle(.switch)
                    .controlSize(.small)

                Toggle("CPU", isOn: $showCPU)
                    .toggleStyle(.switch)
                    .controlSize(.small)

                Toggle("Memory", isOn: $showMemory)
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
