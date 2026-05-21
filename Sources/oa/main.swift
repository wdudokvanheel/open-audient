import Foundation
import OpenAudient

// Test harness that mirrors the original `id44cut` tool, driven entirely by the
// OpenAudient library. Proves the library against real hardware before any UI.
//
//   oa cut            # status (default)
//   oa cut status
//   oa cut on|mute
//   oa cut off|unmute
//   oa cut toggle

func fail(_ message: String, code: Int32) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(code)
}

func describe(_ on: Bool) -> String { on ? "ON (muted)" : "OFF (live)" }

let arguments = Array(CommandLine.arguments.dropFirst())
let command = arguments.first ?? "cut"

switch command {
case "cut":
    let action = arguments.count > 1 ? arguments[1] : "status"

    let device: AudientDevice
    do {
        device = try AudientDevice.openFirst()
    } catch {
        fail("cannot open iD44: \(error)", code: 2)
    }

    let cut = CutControl()
    do {
        switch action {
        case "status":
            print("Cut: \(describe(try device.read(cut)))")
        case "on", "mute":
            try device.write(cut, true)
            print("Cut ON (speakers muted)")
        case "off", "unmute":
            try device.write(cut, false)
            print("Cut OFF (speakers live)")
        case "toggle":
            print("Cut \(describe(try device.toggle(cut)))")
        default:
            fail("unknown action: \(action)", code: 1)
        }
    } catch {
        fail("\(error)", code: 5)
    }

case "help", "-h", "--help":
    print("usage: oa cut [status|on|off|toggle]")

default:
    fail("unknown command: \(command)\nusage: oa cut [status|on|off|toggle]", code: 1)
}
