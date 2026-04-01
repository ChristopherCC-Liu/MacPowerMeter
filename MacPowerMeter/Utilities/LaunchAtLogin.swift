// LaunchAtLogin.swift
// MacPowerMeter
//
// 开机自启管理 — 使用 SMAppService (macOS 13+)

import ServiceManagement

/// 开机自启控制器
/// 基于 SMAppService 实现，macOS 13+ 推荐方式
enum LaunchAtLogin {

    /// 当前开机自启状态
    static var isEnabled: Bool {
        get {
            SMAppService.mainApp.status == .enabled
        }
        set {
            do {
                if newValue {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                // SMAppService 操作失败时记录错误
                // 常见原因: 签名问题、权限不足
                print("LaunchAtLogin: \(newValue ? "register" : "unregister") failed: \(error)")
            }
        }
    }
}
