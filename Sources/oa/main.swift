import Foundation
import OpenAudient

// CLI harness for the OpenAudient library. Mirrors the original id44cut tool and
// adds diagnostics used for reverse-engineering the remaining controls.
//
//   oa cut [status|on|off|toggle]
//   oa monitor [dump]                 # read every mapped monitor control
//   oa monitor <name> [on|off|<num>]  # get/set one monitor control by name
//   oa get <unit> <selector> <len> [channel]          # raw GET_CUR (hex args)
//   oa set <unit> <selector> <channel> <byte[,byte…]> # raw SET_CUR (hex args)
//   oa probe <unit> [firstSel] [lastSel]              # GET_CUR selector sweep
//
// All numeric CLI args are hex (with or without 0x). The Audient iD app must be quit.

func fail(_ message: String, code: Int32) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(code)
}

func hex(_ s: String) -> UInt32? { UInt32(s.hasPrefix("0x") ? String(s.dropFirst(2)) : s, radix: 16) }
func bytesHex(_ bytes: [UInt8]) -> String { bytes.map { String(format: "%02x", $0) }.joined(separator: " ") }
func onoff(_ b: Bool) -> String { b ? "on" : "off" }

func open() -> AudientDevice {
    do { return try AudientDevice.openFirst() }
    catch { fail("cannot open iD44: \(error)", code: 2) }
}

let arguments = Array(CommandLine.arguments.dropFirst())
let command = arguments.first ?? "cut"

do {
    switch command {

    case "cut":
        let device = open()
        let action = arguments.count > 1 ? arguments[1] : "status"
        switch action {
        case "status": print("Cut: \(onoff(try device.read(Monitor.cut)))")
        case "on", "mute": try device.write(Monitor.cut, true); print("Cut on (speakers muted)")
        case "off", "unmute": try device.write(Monitor.cut, false); print("Cut off (speakers live)")
        case "toggle": print("Cut: \(onoff(try device.toggle(Monitor.cut)))")
        default: fail("unknown action: \(action)", code: 1)
        }

    case "monitor":
        let device = open()
        let sub = arguments.count > 1 ? arguments[1] : "dump"
        if sub == "dump" {
            func row(_ name: String, _ value: @autoclosure () throws -> String) {
                let v = (try? value()) ?? "n/a (GET_CUR unsupported)"
                print("\(name.padding(toLength: 20, withPad: " ", startingAt: 0)) \(v)")
            }
            for c in Monitor.allSwitches { row(c.name, onoff(try device.read(c))) }
            for c in Monitor.allBytes    { row(c.name, String(try device.read(c))) }
            for c in Monitor.allLevels   { row(c.name, String(format: "%.2f", try device.read(c))) }
        } else {
            fail("unknown monitor subcommand: \(sub) (try: dump)", code: 1)
        }

    case "dump":
        let device = open()
        func row(_ name: String, _ value: @autoclosure () throws -> String) {
            print("\(name.padding(toLength: 22, withPad: " ", startingAt: 0)) \((try? value()) ?? "n/a")")
        }
        print("— Monitor —")
        for c in Monitor.allSwitches { row(c.name, onoff(try device.read(c))) }
        for c in Monitor.allBytes    { row(c.name, String(try device.read(c))) }
        for c in Monitor.allLevels   { row(c.name, String(format: "%.1f dB", try device.read(c))) }
        print("— Headphones —")
        row("HP Left",  String(format: "%.1f dB", try device.read(Headphones.leftVolume)))
        row("HP Right", String(format: "%.1f dB", try device.read(Headphones.rightVolume)))
        print("— Mixer levels —")
        for ch: UInt8 in 0..<12 { row("Mixer ch \(ch)", String(format: "%.1f dB", try device.read(Mixer.level(channel: ch)))) }
        print("— Routing —")
        for out: UInt8 in 0..<6 { row("Output \(out)", String(format: "0x%02x", try device.read(Routing.source(output: out)))) }

    case "get":
        guard arguments.count >= 4, let u = hex(arguments[1]), let s = hex(arguments[2]), let l = hex(arguments[3]) else {
            fail("usage: oa get <unit> <selector> <len> [channel]", code: 1)
        }
        let ch = arguments.count > 4 ? (hex(arguments[4]) ?? 0) : 0
        let bytes = try open().getRaw(unit: UInt8(u), selector: UInt8(s), channel: UInt8(ch), length: UInt16(l))
        print("GET unit=0x\(String(u, radix: 16)) sel=0x\(String(s, radix: 16)) ch=0x\(String(ch, radix: 16)) -> \(bytesHex(bytes))")

    case "set":
        guard arguments.count >= 5, let u = hex(arguments[1]), let s = hex(arguments[2]), let ch = hex(arguments[3]) else {
            fail("usage: oa set <unit> <selector> <channel> <byte[,byte…]>", code: 1)
        }
        let data = arguments[4].split(separator: ",").compactMap { hex(String($0)).map { UInt8($0 & 0xFF) } }
        try open().setRaw(unit: UInt8(u), selector: UInt8(s), channel: UInt8(ch), data: data)
        print("SET unit=0x\(String(u, radix: 16)) sel=0x\(String(s, radix: 16)) ch=0x\(String(ch, radix: 16)) <- \(bytesHex(data))")

    case "probe":
        guard arguments.count >= 2, let u = hex(arguments[1]) else {
            fail("usage: oa probe <unit> [firstSel] [lastSel]", code: 1)
        }
        let first = arguments.count > 2 ? (hex(arguments[2]) ?? 0) : 0
        let last  = arguments.count > 3 ? (hex(arguments[3]) ?? 0x1f) : 0x1f
        let device = open()
        print("probing unit 0x\(String(u, radix: 16)) selectors 0x\(String(first, radix: 16))..0x\(String(last, radix: 16)) (GET_CUR, len 1 & 2)")
        for sel in first...last {
            for len: UInt16 in [1, 2] {
                if let bytes = try? device.getRaw(unit: UInt8(u), selector: UInt8(sel), channel: 0, length: len) {
                    print("  sel 0x\(String(format: "%02x", sel)) len \(len) -> \(bytesHex(bytes))")
                }
            }
        }

    case "help", "-h", "--help":
        print("""
        usage:
          oa cut [status|on|off|toggle]
          oa monitor [dump]
          oa get <unit> <selector> <len> [channel]
          oa set <unit> <selector> <channel> <byte[,byte…]>
          oa probe <unit> [firstSel] [lastSel]
        (numeric args are hex; quit the Audient iD app first)
        """)

    default:
        fail("unknown command: \(command) (try: oa help)", code: 1)
    }
} catch {
    fail("\(error)", code: 5)
}
