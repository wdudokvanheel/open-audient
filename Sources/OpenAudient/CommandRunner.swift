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
            case "routes":   return try await routes()
            case "list":     return list()
            case "watch":    await watch(); return 0
            case "meters":   return try await meters()
            case "get":      return try await get(Array(arguments.dropFirst()))
            case "set":      return try await set(Array(arguments.dropFirst()))
            case "probe":    return try await probe(Array(arguments.dropFirst()))
            case "mixer-scan": return try await mixerScan(Array(arguments.dropFirst()))
            case "mixer-set": return try await mixerSet(Array(arguments.dropFirst()))
            case "meter-probe": return try await meterProbe(Array(arguments.dropFirst()))
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
        for out in 0..<UInt8(device.model.totalOutputs) { await row("Output \(out)", String(format: "0x%02x", try await device.read(Routing.source(output: out)))) }
        return 0
    }

    private static func routes() async throws -> Int32 {
        let device = try await AudientDevice.openFirst()
        print("\(device.model.name) — Output routing —")
        for output in stride(from: 0, to: device.model.totalOutputs, by: 2) {
            let left = try await device.read(Routing.source(output: UInt8(output)))
            let right = try await device.read(Routing.source(output: UInt8(output + 1)))
            let source = Routing.Source.matching(leftOutput: output, leftValue: left, rightValue: right)?.title ?? "Unknown"
            print(String(format: "Output %02d/%02d  %@/%@  %@", output, output + 1, hexByte(UInt32(left)), hexByte(UInt32(right)), source))
        }
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

    private static func meters() async throws -> Int32 {
        let device = try await AudientDevice.openFirst()
        let channels = max(device.model.micInputs, 1)
        print("input meters (\(channels) ch), Ctrl-C to stop…")
        while true {
            let levels = try await device.readInputMeters(channels: channels)
            let row = levels.enumerated().map { i, db in
                let filled = Int((max(0, min(1, (db + 60) / 60))) * 20)
                let bar = String(repeating: "█", count: filled) + String(repeating: "·", count: 20 - filled)
                return String(format: "%d|%@|%5.0f", i + 1, bar, db)
            }.joined(separator: "  ")
            print("\r\(row)", terminator: "")
            fflush(stdout)
            try await Task.sleep(for: .milliseconds(80))
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

    private static func mixerScan(_ args: [String]) async throws -> Int32 {
        let unit = UInt8(hex(args.first ?? "3d") ?? UInt32(Mixer.secondaryUnit))
        let start = UInt8(hex(args.dropFirst().first ?? "0") ?? 0)
        let defaultCount = unit == Mixer.secondaryUnit ? UInt32(Mixer.secondaryChannelCount) : 0x50
        let count = Int(hex(args.dropFirst(2).first ?? String(defaultCount, radix: 16)) ?? defaultCount)
        let device = try await AudientDevice.openFirst()
        print("mixer scan: unit \(hexByte(UInt32(unit))) channels \(hexByte(UInt32(start)))...\(hexByte(UInt32(start) + UInt32(max(count - 1, 0))))")
        for offset in 0..<count {
            let channel = start &+ UInt8(offset)
            do {
                let bytes = try await device.getRaw(unit: unit, selector: Mixer.levelSelector, channel: channel, length: 2)
                print("  ch \(hexByte(UInt32(channel))) -> \(bytesHex(bytes))")
            } catch {
                print("  ch \(hexByte(UInt32(channel))) -> n/a, stopping")
                break
            }
        }
        return 0
    }

    private static func mixerSet(_ args: [String]) async throws -> Int32 {
        guard args.count >= 3, let unitValue = hex(args[0]), let channelValue = hex(args[1]), let db = Double(args[2]) else {
            FileHandle.standardError.write(Data("usage: oa mixer-set <unit> <channel> <dB>\n".utf8)); return 1
        }
        let unit = UInt8(unitValue)
        let channel = UInt8(channelValue)
        let device = try await AudientDevice.openFirst()
        let control = Mixer.level(unit: unit, channel: channel)
        let before = (try? await device.read(control)).map { String(format: "%.1f dB", $0) } ?? "n/a"
        try await device.write(control, db)
        let after = (try? await device.read(control)).map { String(format: "%.1f dB", $0) } ?? "n/a"
        print("Mixer \(hexByte(UInt32(unit))):\(hexByte(UInt32(channel))) \(before) -> \(after)")
        return 0
    }

    private static func meterProbe(_ args: [String]) async throws -> Int32 {
        let units = parseList(args.first, default: [0x3C])
        let offsets = parseList(args.dropFirst().first, default: [0])
        let length = args.count > 2 ? (hex(args[2]).map { UInt16($0) } ?? 0x58) : 0x58
        let intervalMS = args.count > 3 ? (UInt64(hex(args[3]) ?? 250)) : 250

        print("meter probe: units \(units.map(hexByte).joined(separator: ",")) offsets \(offsets.map(hexWord).joined(separator: ",")) len \(length) bytes")
        print("play signal, then watch for moving/non-floor entries (Ctrl-C to stop)")

        let device = try await AudientDevice.openFirst()
        while true {
            print("\n\(Date())")
            for unit in units {
                for offset in offsets {
                    do {
                        let bytes = try await device.readMemory(unit: UInt8(unit), offset: UInt16(offset), length: length)
                        let peaks = Meters.peaks(bytes)
                        let active = peaks.enumerated().compactMap { index, peak -> String? in
                            let db = Meters.dBFS(peak)
                            guard db > -55 else { return nil }
                            return String(format: "%02d:%5.1f", index, db)
                        }
                        let summary = active.isEmpty ? "floor" : active.joined(separator: "  ")
                        print("  unit \(hexByte(unit)) off \(hexWord(offset)) -> \(summary)")
                    } catch {
                        print("  unit \(hexByte(unit)) off \(hexWord(offset)) -> n/a")
                    }
                }
            }
            fflush(stdout)
            try await Task.sleep(for: .milliseconds(intervalMS))
        }
    }

    private static func printUsage() {
        print("""
        usage:
          oa                                 launch the GUI
          oa cut [status|on|off|toggle]
          oa dump
          oa routes
          oa list
          oa watch
          oa meters
          oa get <unit> <selector> <len> [channel]
          oa set <unit> <selector> <channel> <byte[,byte…]>
          oa probe <unit> [firstSel] [lastSel]
          oa mixer-scan [unit] [startChannel] [count]
          oa mixer-set <unit> <channel> <dB>
          oa meter-probe [units] [offsets] [len] [intervalMS]
             units/offsets are comma-separated hex lists; defaults to known-good 0x3c/0x0000/0x58
        (numeric args are hex; quit the Audient iD app first)
        """)
    }

    // MARK: Helpers

    private static func hex(_ s: String) -> UInt32? { UInt32(s.hasPrefix("0x") ? String(s.dropFirst(2)) : s, radix: 16) }
    private static func parseList(_ s: String?, default defaults: [UInt32]) -> [UInt32] {
        guard let s, !s.isEmpty else { return defaults }
        let values = s.split(separator: ",").compactMap { hex(String($0)) }
        return values.isEmpty ? defaults : values
    }
    private static func hexByte(_ value: UInt32) -> String { String(format: "0x%02x", value) }
    private static func hexWord(_ value: UInt32) -> String { String(format: "0x%04x", value) }
    private static func bytesHex(_ bytes: [UInt8]) -> String { bytes.map { String(format: "%02x", $0) }.joined(separator: " ") }
    private static func onoff(_ b: Bool) -> String { b ? "on" : "off" }
}
