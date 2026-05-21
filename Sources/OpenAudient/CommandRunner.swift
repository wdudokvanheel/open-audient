import Foundation

/// The headless command interface, shared by the CLI entry point and the app's
/// command-line mode. Returns a process exit code instead of calling `exit`, so
/// callers control termination.
public enum CommandRunner {
    public static func run(_ arguments: [String]) async -> Int32 {
        let command = arguments.first ?? "help"
        do {
            switch command {
            case "cut":      return try await cut(Array(arguments.dropFirst()))
            case "dump":     return try await dump()
            case "list":     return list()
            case "watch":    await watch(); return 0
            case "get":      return try await get(Array(arguments.dropFirst()))
            case "set":      return try await set(Array(arguments.dropFirst()))
            case "probe":    return try await probe(Array(arguments.dropFirst()))
            case "help", "-h", "--help": printUsage(); return 0
            default:
                FileHandle.standardError.write(Data("unknown command: \(command)\n".utf8))
                printUsage()
                return 1
            }
        } catch {
            FileHandle.standardError.write(Data("\(error)\n".utf8))
            return 5
        }
    }

    // MARK: Commands

    private static func cut(_ args: [String]) async throws -> Int32 {
        let device = try await AudientDevice.openFirst()
        switch args.first ?? "status" {
        case "status": print("Cut: \(onoff(try await device.read(Monitor.cut)))")
        case "on", "mute": try await device.write(Monitor.cut, true); print("Cut on (speakers muted)")
        case "off", "unmute": try await device.write(Monitor.cut, false); print("Cut off (speakers live)")
        case "toggle": print("Cut: \(onoff(try await device.toggle(Monitor.cut)))")
        case let other: FileHandle.standardError.write(Data("unknown action: \(other)\n".utf8)); return 1
        }
        return 0
    }

    private static func dump() async throws -> Int32 {
        let device = try await AudientDevice.openFirst()
        func row(_ name: String, _ value: @autoclosure () async throws -> String) async {
            print("\(name.padding(toLength: 22, withPad: " ", startingAt: 0)) \((try? await value()) ?? "n/a")")
        }
        print("\(device.model.name) — Monitor —")
        for c in Monitor.allSwitches { await row(c.name, onoff(try await device.read(c))) }
        for c in Monitor.allBytes    { await row(c.name, String(try await device.read(c))) }
        for c in Monitor.allLevels   { await row(c.name, String(format: "%.1f dB", try await device.read(c))) }
        print("— Mixer levels —")
        for ch in 0..<UInt8(12) { await row("Mixer ch \(ch)", String(format: "%.1f dB", try await device.read(Mixer.level(channel: ch)))) }
        print("— Routing —")
        for out in 0..<UInt8(device.model.lineOutputs + 2) { await row("Output \(out)", String(format: "0x%02x", try await device.read(Routing.source(output: out)))) }
        return 0
    }

    private static func list() -> Int32 {
        let models = DeviceDiscovery.connectedModels()
        if models.isEmpty { print("no Audient iD devices connected") }
        for m in models {
            print("\(m.name)  PID 0x\(String(format: "%04x", m.productID))  \(m.totalInputs) in / \(m.totalOutputs) out\(m.isVerified ? "  [verified]" : "")")
        }
        return 0
    }

    private static func watch() async {
        print("watching for device connect/disconnect (Ctrl-C to stop)…")
        let monitor = DeviceMonitor()
        for await event in monitor.events() {
            switch event {
            case .connected(let m): print("+ connected: \(m.name)")
            case .disconnected(let m): print("- disconnected: \(m.name)")
            }
        }
    }

    private static func get(_ args: [String]) async throws -> Int32 {
        guard args.count >= 3, let u = hex(args[0]), let s = hex(args[1]), let l = hex(args[2]) else {
            FileHandle.standardError.write(Data("usage: oa get <unit> <selector> <len> [channel]\n".utf8)); return 1
        }
        let ch = args.count > 3 ? (hex(args[3]) ?? 0) : 0
        let bytes = try await AudientDevice.openFirst().getRaw(unit: UInt8(u), selector: UInt8(s), channel: UInt8(ch), length: UInt16(l))
        print("GET unit=0x\(String(u, radix: 16)) sel=0x\(String(s, radix: 16)) ch=0x\(String(ch, radix: 16)) -> \(bytesHex(bytes))")
        return 0
    }

    private static func set(_ args: [String]) async throws -> Int32 {
        guard args.count >= 4, let u = hex(args[0]), let s = hex(args[1]), let ch = hex(args[2]) else {
            FileHandle.standardError.write(Data("usage: oa set <unit> <selector> <channel> <byte[,byte…]>\n".utf8)); return 1
        }
        let data = args[3].split(separator: ",").compactMap { hex(String($0)).map { UInt8($0 & 0xFF) } }
        try await AudientDevice.openFirst().setRaw(unit: UInt8(u), selector: UInt8(s), channel: UInt8(ch), data: data)
        print("SET unit=0x\(String(u, radix: 16)) sel=0x\(String(s, radix: 16)) ch=0x\(String(ch, radix: 16)) <- \(bytesHex(data))")
        return 0
    }

    private static func probe(_ args: [String]) async throws -> Int32 {
        guard let first = args.first, let u = hex(first) else {
            FileHandle.standardError.write(Data("usage: oa probe <unit> [firstSel] [lastSel]\n".utf8)); return 1
        }
        let lo = args.count > 1 ? (hex(args[1]) ?? 0) : 0
        let hi = args.count > 2 ? (hex(args[2]) ?? 0x1f) : 0x1f
        let device = try await AudientDevice.openFirst()
        print("probing unit 0x\(String(u, radix: 16)) selectors 0x\(String(lo, radix: 16))..0x\(String(hi, radix: 16))")
        for sel in lo...hi {
            for len: UInt16 in [1, 2] {
                if let bytes = try? await device.getRaw(unit: UInt8(u), selector: UInt8(sel), channel: 0, length: len) {
                    print("  sel 0x\(String(format: "%02x", sel)) len \(len) -> \(bytesHex(bytes))")
                }
            }
        }
        return 0
    }

    private static func printUsage() {
        print("""
        usage:
          oa                                 launch the GUI
          oa cut [status|on|off|toggle]
          oa dump
          oa list
          oa watch
          oa get <unit> <selector> <len> [channel]
          oa set <unit> <selector> <channel> <byte[,byte…]>
          oa probe <unit> [firstSel] [lastSel]
        (numeric args are hex; quit the Audient iD app first)
        """)
    }

    // MARK: Helpers

    private static func hex(_ s: String) -> UInt32? { UInt32(s.hasPrefix("0x") ? String(s.dropFirst(2)) : s, radix: 16) }
    private static func bytesHex(_ bytes: [UInt8]) -> String { bytes.map { String(format: "%02x", $0) }.joined(separator: " ") }
    private static func onoff(_ b: Bool) -> String { b ? "on" : "off" }
}
