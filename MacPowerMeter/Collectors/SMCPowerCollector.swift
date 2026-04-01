// SMCPowerCollector.swift
// MacPowerMeter
//
// 通过 IOKit 直接访问 AppleSMC 读取功耗数据
// 作为 IOReport 不可用时的 fallback 方案
// 非沙盒 app 不需要 root 权限

import Foundation
import IOKit

/// SMC 功耗采集器
/// 通过 IOKit IOServiceOpen 访问 AppleSMC 读取功耗 key
final class SMCPowerCollector: PowerStrategy, @unchecked Sendable {

    // MARK: - SMC 常量

    private let kSMCReadKey: UInt8 = 5
    private let kSMCKeyInfoCmd: UInt8 = 9

    // MARK: - SMC 数据结构 (匹配内核接口，总大小 80 字节)

    struct SMCKeyData {
        struct Version {
            var major: UInt8 = 0
            var minor: UInt8 = 0
            var build: UInt8 = 0
            var reserved: UInt8 = 0
            var release: UInt16 = 0
        }

        struct PLimitData {
            var version: UInt16 = 0
            var length: UInt16 = 0
            var cpuPLimit: UInt32 = 0
            var gpuPLimit: UInt32 = 0
            var memPLimit: UInt32 = 0
        }

        struct KeyInfo {
            var dataSize: UInt32 = 0
            var dataType: FourCharCode = 0
            var dataAttributes: UInt8 = 0
            var _pad: (UInt8, UInt8, UInt8) = (0, 0, 0) // 显式 padding 到 12 字节
        }

        var key: FourCharCode = 0                    // 4 bytes, offset 0
        var vers: Version = Version()                  // 6 bytes, offset 4
        var _versPad: UInt16 = 0                       // 2 bytes padding, offset 10
        var pLimitData: PLimitData = PLimitData()      // 16 bytes, offset 12
        var keyInfo: KeyInfo = KeyInfo()               // 12 bytes, offset 28
        var result: UInt8 = 0                          // 1 byte, offset 40
        var status: UInt8 = 0                          // 1 byte, offset 41
        var data8: UInt8 = 0                           // 1 byte, offset 42
        var _data8Pad: UInt8 = 0                       // 1 byte padding, offset 43
        var data32: UInt32 = 0                         // 4 bytes, offset 44
        var bytes: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                    UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                    UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                    UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8) = (
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
        )                                              // 32 bytes, offset 48, total = 80
    }

    // MARK: - 状态

    private var connection: io_connect_t = 0
    private(set) var isAvailable: Bool = false

    // MARK: - 生命周期

    init() {
        openSMC()
    }

    deinit {
        if connection != 0 {
            IOServiceClose(connection)
        }
    }

    // MARK: - SMC 连接

    private func openSMC() {
        let service = IOServiceGetMatchingService(
            kIOMainPortDefault,
            IOServiceMatching("AppleSMC")
        )
        guard service != IO_OBJECT_NULL else {
            isAvailable = false
            return
        }
        defer { IOObjectRelease(service) }

        let result = IOServiceOpen(service, mach_task_self_, 0, &connection)
        guard result == kIOReturnSuccess else {
            isAvailable = false
            return
        }

        // 验证至少能读取一个功耗 key
        isAvailable = readKey("PSTR") != nil
            || readKey("PCPT") != nil
            || readKey("PHPC") != nil
            || readKey("PCAM") != nil
    }

    // MARK: - 功耗采集

    func collect() async throws -> PowerMetrics {
        guard isAvailable else { return .zero }

        let totalPower = readKey("PSTR") ?? readKey("PCAM") ?? 0
        let cpuPower = readKey("PCPT") ?? readKey("PHPC") ?? 0
        let gpuPower = readKey("PCPG") ?? 0

        return PowerMetrics(
            totalPower: totalPower,
            cpuPower: cpuPower,
            gpuPower: gpuPower,
            anePower: 0 // SMC 没有 ANE 功率 key
        )
    }

    // MARK: - SMC Key 读取

    /// 读取一个 SMC key 的值，返回 Double (瓦特)
    func readKey(_ keyName: String) -> Double? {
        let fourCC = fourCharCode(keyName)

        // 第一步: 获取 key 的 dataSize 和 dataType
        var inputData = SMCKeyData()
        inputData.key = fourCC
        inputData.data8 = kSMCKeyInfoCmd

        var outputData = SMCKeyData()
        let result = callSMC(input: &inputData, output: &outputData)
        guard result == kIOReturnSuccess else { return nil }

        let dataSize = outputData.keyInfo.dataSize
        let dataType = outputData.keyInfo.dataType
        guard dataSize > 0 else { return nil }

        // 第二步: 读取实际值
        var readInput = SMCKeyData()
        readInput.key = fourCC
        readInput.data8 = kSMCReadKey
        readInput.keyInfo.dataSize = dataSize

        var readOutput = SMCKeyData()
        let readResult = callSMC(input: &readInput, output: &readOutput)
        guard readResult == kIOReturnSuccess else { return nil }

        // 第三步: 根据 dataType 解码
        return decodeValue(bytes: readOutput.bytes, dataType: dataType, dataSize: dataSize)
    }

    // MARK: - SMC 底层调用

    private func callSMC(input: inout SMCKeyData, output: inout SMCKeyData) -> kern_return_t {
        let inputSize = MemoryLayout<SMCKeyData>.size
        var outputSize = MemoryLayout<SMCKeyData>.size

        return IOConnectCallStructMethod(
            connection,
            2, // kSMCHandleYPCEvent
            &input,
            inputSize,
            &output,
            &outputSize
        )
    }

    // MARK: - FourCharCode 转换

    private func fourCharCode(_ s: String) -> FourCharCode {
        var result: FourCharCode = 0
        for char in s.utf8.prefix(4) {
            result = (result << 8) | FourCharCode(char)
        }
        return result
    }

    // MARK: - 值解码

    /// 根据 SMC dataType 解码字节为 Double
    private func decodeValue(
        bytes: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8),
        dataType: FourCharCode,
        dataSize: UInt32
    ) -> Double? {
        let sp78Type = fourCharCode("sp78")
        let fltType = fourCharCode("flt ")
        let ui16Type = fourCharCode("ui16")
        let ui32Type = fourCharCode("ui32")

        // Apple Silicon SMC 使用原生 little-endian 字节序
        // Intel Mac SMC 使用 big-endian 字节序
        // 使用条件编译处理两种架构
        switch dataType {
        case sp78Type:
            // signed 7.8 fixed-point: 高字节整数 + 低字节小数/256
            guard dataSize >= 2 else { return nil }
            #if arch(arm64)
            let raw = Int16(Int16(bytes.1) << 8 | Int16(bytes.0))
            #else
            let raw = Int16(Int16(bytes.0) << 8 | Int16(bytes.1))
            #endif
            return Double(raw) / 256.0

        case fltType:
            // 32-bit IEEE 754 float
            guard dataSize >= 4 else { return nil }
            #if arch(arm64)
            let raw = UInt32(bytes.3) << 24
                | UInt32(bytes.2) << 16
                | UInt32(bytes.1) << 8
                | UInt32(bytes.0)
            #else
            let raw = UInt32(bytes.0) << 24
                | UInt32(bytes.1) << 16
                | UInt32(bytes.2) << 8
                | UInt32(bytes.3)
            #endif
            return Double(Float(bitPattern: raw))

        case ui16Type:
            guard dataSize >= 2 else { return nil }
            #if arch(arm64)
            let raw = UInt16(bytes.1) << 8 | UInt16(bytes.0)
            #else
            let raw = UInt16(bytes.0) << 8 | UInt16(bytes.1)
            #endif
            return Double(raw)

        case ui32Type:
            guard dataSize >= 4 else { return nil }
            #if arch(arm64)
            let raw = UInt32(bytes.3) << 24
                | UInt32(bytes.2) << 16
                | UInt32(bytes.1) << 8
                | UInt32(bytes.0)
            #else
            let raw = UInt32(bytes.0) << 24
                | UInt32(bytes.1) << 16
                | UInt32(bytes.2) << 8
                | UInt32(bytes.3)
            #endif
            return Double(raw)

        default:
            // 未知类型，尝试作为 flt 解码
            guard dataSize >= 4 else { return nil }
            #if arch(arm64)
            let raw = UInt32(bytes.3) << 24
                | UInt32(bytes.2) << 16
                | UInt32(bytes.1) << 8
                | UInt32(bytes.0)
            #else
            let raw = UInt32(bytes.0) << 24
                | UInt32(bytes.1) << 16
                | UInt32(bytes.2) << 8
                | UInt32(bytes.3)
            #endif
            let floatVal = Float(bitPattern: raw)
            // 合理性检查: 功率值应在 0-1000W 范围
            if floatVal >= 0 && floatVal < 1000 {
                return Double(floatVal)
            }
            return nil
        }
    }
}
