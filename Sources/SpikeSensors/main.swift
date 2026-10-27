// Phase 0 spike: one reading from each private sensor source. Delete once phase 3 lands.
import CPrivate
import Foundation
import IOKit

func hidTemperatures() {
    print("== IOHIDEventSystemClient temperatures")
    guard let client = IOHIDEventSystemClientCreate(kCFAllocatorDefault) else {
        print("  IOHIDEventSystemClientCreate returned NULL")
        return
    }
    let match = ["PrimaryUsagePage": 0xff00, "PrimaryUsage": 5] as CFDictionary
    IOHIDEventSystemClientSetMatching(client, match)
    guard let services = IOHIDEventSystemClientCopyServices(client) as? [AnyObject] else {
        print("  no services")
        return
    }
    var readings: [(String, Double)] = []
    for service in services {
        let ref = unsafeDowncast(service, to: IOHIDServiceClient.self)
        let name = IOHIDServiceClientCopyProperty(ref, "Product" as CFString) as? String ?? "?"
        guard let event = IOHIDServiceClientCopyEvent(ref, Int64(kIOHIDEventTypeTemperature), 0, 0) else { continue }
        let celsius = IOHIDEventGetFloatValue(event, Int32(kIOHIDEventTypeTemperature << 16))
        readings.append((name, celsius))
    }
    print("  \(services.count) services, \(readings.count) readings")
    for (name, celsius) in readings.sorted(by: { $0.0 < $1.0 }) {
        print(String(format: "  %-28@ %6.2f °C", name as NSString, celsius))
    }
}

func fourCC(_ s: String) -> UInt32 {
    s.utf8.reduce(0) { $0 << 8 | UInt32($1) }
}

func smcCall(_ conn: io_connect_t, _ input: inout SMCParamStruct) -> (kern_return_t, SMCParamStruct) {
    var output = SMCParamStruct()
    var size = MemoryLayout<SMCParamStruct>.stride
    let kr = IOConnectCallStructMethod(conn, UInt32(kSMCHandleYPCEvent), &input, size, &output, &size)
    return (kr, output)
}

func smcRead(_ conn: io_connect_t, _ key: String) -> (type: String, bytes: [UInt8])? {
    var input = SMCParamStruct()
    input.key = fourCC(key)
    input.data8 = UInt8(kSMCGetKeyInfo)
    let (kr1, info) = smcCall(conn, &input)
    guard kr1 == KERN_SUCCESS, info.result == 0 else {
        print("  \(key): key info failed kr=\(kr1) result=\(info.result)")
        return nil
    }
    input.keyInfo = info.keyInfo
    input.data8 = UInt8(kSMCReadKey)
    let (kr2, out) = smcCall(conn, &input)
    guard kr2 == KERN_SUCCESS, out.result == 0 else {
        print("  \(key): read failed kr=\(kr2) result=\(out.result)")
        return nil
    }
    let t = info.keyInfo.dataType
    let type = String(bytes: [24, 16, 8, 0].map { UInt8(truncatingIfNeeded: t >> $0) }, encoding: .ascii) ?? "?"
    let bytes = withUnsafeBytes(of: out.bytes) { Array($0.prefix(Int(info.keyInfo.dataSize))) }
    return (type, bytes)
}

func smcFans() {
    print("== AppleSMC fans")
    let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"))
    guard service != 0 else {
        print("  AppleSMC service not found")
        return
    }
    defer { IOObjectRelease(service) }
    var conn: io_connect_t = 0
    let kr = IOServiceOpen(service, mach_task_self_, 0, &conn)
    guard kr == KERN_SUCCESS else {
        print("  IOServiceOpen failed: \(kr)")
        return
    }
    defer { IOServiceClose(conn) }
    guard let fnum = smcRead(conn, "FNum") else { return }
    let count = Int(fnum.bytes.first ?? 0)
    print("  FNum (\(fnum.type)) = \(count)")
    for i in 0..<count {
        let key = "F\(i)Ac"
        guard let r = smcRead(conn, key), r.bytes.count == 4 else { continue }
        // Apple Silicon stores `flt ` keys little-endian.
        let rpm = r.bytes.withUnsafeBytes { $0.loadUnaligned(as: Float.self) }
        print("  \(key) (\(r.type)) = \(rpm) rpm")
    }
    // Extra keys to probe, e.g. SPIKE_SMC_KEYS=PSTR,PDTR
    for key in (ProcessInfo.processInfo.environment["SPIKE_SMC_KEYS"] ?? "").split(separator: ",").map(String.init) {
        guard let r = smcRead(conn, key) else { continue }
        let value: String = r.type == "flt " && r.bytes.count == 4
            ? "\(r.bytes.withUnsafeBytes { $0.loadUnaligned(as: Float.self) })"
            : r.bytes.map { String(format: "%02x", $0) }.joined()
        print("  \(key) (\(r.type)) = \(value)")
    }
}

func ioReportWatts() {
    print("== IOReport Energy Model")
    guard let channels = IOReportCopyChannelsInGroup("Energy Model" as CFString, nil, 0, 0, 0) else {
        print("  IOReportCopyChannelsInGroup returned NULL")
        return
    }
    var subscribed: Unmanaged<CFMutableDictionary>?
    guard let sub = IOReportCreateSubscription(nil, channels, &subscribed, 0, nil),
          let subbed = subscribed?.takeRetainedValue() else {
        print("  IOReportCreateSubscription failed")
        return
    }
    let interval = Double(ProcessInfo.processInfo.environment["SPIKE_INTERVAL"] ?? "") ?? 0.5
    guard let first = IOReportCreateSamples(sub, subbed, nil) else { return }
    Thread.sleep(forTimeInterval: interval)
    guard let second = IOReportCreateSamples(sub, subbed, nil),
          let delta = IOReportCreateSamplesDelta(first, second, nil) as? [String: Any],
          let items = delta["IOReportChannels"] as? [CFDictionary] else {
        print("  sampling failed")
        return
    }
    for item in items {
        let name = IOReportChannelGetChannelName(item) as String? ?? "?"
        guard ProcessInfo.processInfo.environment["SPIKE_ALL"] != nil || name == "CPU Energy" || name == "GPU Energy" || name.hasPrefix("ANE") else { continue }
        let unit = (IOReportChannelGetUnitLabel(item) as String? ?? "").trimmingCharacters(in: .whitespaces)
        let value = Double(IOReportSimpleGetIntegerValue(item, 0))
        let joules: Double = switch unit {
        case "mJ": value / 1e3
        case "uJ": value / 1e6
        case "nJ": value / 1e9
        default: .nan
        }
        print(String(format: "  %-12@ %8.3f W  (%.0f %@ over %.1f s)", name as NSString, joules / interval, value, unit as NSString, interval))
    }
}

func smartBattery() {
    print("== AppleSmartBattery")
    let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
    guard service != 0 else {
        print("  AppleSmartBattery not found")
        return
    }
    defer { IOObjectRelease(service) }
    var props: Unmanaged<CFMutableDictionary>?
    guard IORegistryEntryCreateCFProperties(service, &props, kCFAllocatorDefault, 0) == KERN_SUCCESS,
          let dict = props?.takeRetainedValue() as? [String: Any] else {
        print("  could not read properties")
        return
    }
    let telemetry = dict["PowerTelemetryData"] as? [String: Any]
    let adapter = dict["AdapterDetails"] as? [String: Any]
    let charger = dict["ChargerData"] as? [String: Any]
    print("  PowerTelemetryData.SystemPowerIn = \(telemetry?["SystemPowerIn"] ?? "missing") mW")
    print("  PowerTelemetryData.SystemLoad    = \(telemetry?["SystemLoad"] ?? "missing") mW")
    print("  AdapterDetails.Watts             = \(adapter?["Watts"] ?? "missing")")
    print("  ChargerData.NotChargingReason    = \(charger?["NotChargingReason"] ?? "missing")")
    print("  CurrentCapacity = \(dict["CurrentCapacity"] ?? "?") %, IsCharging = \(dict["IsCharging"] ?? "?"), ExternalConnected = \(dict["ExternalConnected"] ?? "?")")
}

hidTemperatures()
smcFans()
ioReportWatts()
smartBattery()
