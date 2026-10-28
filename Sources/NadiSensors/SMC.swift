import CPrivate
import IOKit

/// AppleSMC user client. Not thread-safe: owned by one reader, used from the Sampler actor.
final class SMC {
    struct KeyInfo {
        var size: UInt32
        var type: UInt32
        var attributes: UInt8
    }

    private var connection: io_connect_t = 0
    private var infoCache: [UInt32: KeyInfo] = [:]

    init?() {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"))
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }
        guard IOServiceOpen(service, mach_task_self_, 0, &connection) == KERN_SUCCESS else { return nil }
    }

    deinit {
        IOServiceClose(connection)
    }

    static func code(_ key: String) -> UInt32 {
        key.utf8.reduce(0) { $0 << 8 | UInt32($1) }
    }

    static func name(_ code: UInt32) -> String {
        String(decoding: [24, 16, 8, 0].map { UInt8(truncatingIfNeeded: code >> $0) }, as: UTF8.self)
    }

    /// Every key the SMC exposes. Slow (one call per key); use once at startup.
    func allKeys() -> [String] {
        guard let count = readUInt("#KEY") else { return [] }
        return (0..<UInt32(clamping: count)).compactMap { index in
            var input = SMCParamStruct()
            input.data8 = UInt8(kSMCGetKeyFromIndex)
            input.data32 = index
            guard let output = call(&input) else { return nil }
            return Self.name(output.key)
        }
    }

    func readDouble(_ key: String) -> Double? {
        guard let (info, bytes) = read(key) else { return nil }
        switch Self.name(info.type) {
        case "flt ":
            guard bytes.count == 4 else { return nil }
            // Apple Silicon stores floats little-endian, unlike the big-endian integer types.
            let value = Double(bytes.withUnsafeBytes { $0.loadUnaligned(as: Float.self) })
            return value.isFinite ? value : nil
        case "ui8 ", "ui16", "ui32":
            return Double(bytes.reduce(UInt64(0)) { $0 << 8 | UInt64($1) })
        case "sp78":
            guard bytes.count == 2 else { return nil }
            return Double(Int16(bitPattern: UInt16(bytes[0]) << 8 | UInt16(bytes[1]))) / 256
        case "fpe2":
            guard bytes.count == 2 else { return nil }
            return Double(UInt16(bytes[0]) << 8 | UInt16(bytes[1])) / 4
        default:
            return nil
        }
    }

    func readUInt(_ key: String) -> UInt64? {
        guard let (_, bytes) = read(key), !bytes.isEmpty else { return nil }
        return bytes.reduce(UInt64(0)) { $0 << 8 | UInt64($1) }
    }

    private func read(_ key: String) -> (KeyInfo, [UInt8])? {
        let code = Self.code(key)
        guard let info = keyInfo(code) else { return nil }
        var input = SMCParamStruct()
        input.key = code
        input.keyInfo.dataSize = info.size
        input.data8 = UInt8(kSMCReadKey)
        guard let output = call(&input) else { return nil }
        let bytes = withUnsafeBytes(of: output.bytes) { Array($0.prefix(Int(min(info.size, 32)))) }
        return (info, bytes)
    }

    private func keyInfo(_ code: UInt32) -> KeyInfo? {
        if let cached = infoCache[code] { return cached }
        var input = SMCParamStruct()
        input.key = code
        input.data8 = UInt8(kSMCGetKeyInfo)
        guard let output = call(&input) else { return nil }
        let info = KeyInfo(size: output.keyInfo.dataSize, type: output.keyInfo.dataType, attributes: output.keyInfo.dataAttributes)
        infoCache[code] = info
        return info
    }

    private func call(_ input: inout SMCParamStruct) -> SMCParamStruct? {
        var output = SMCParamStruct()
        var size = MemoryLayout<SMCParamStruct>.stride
        let kr = IOConnectCallStructMethod(connection, UInt32(kSMCHandleYPCEvent), &input, size, &output, &size)
        guard kr == KERN_SUCCESS, output.result == 0 else { return nil }
        return output
    }
}
