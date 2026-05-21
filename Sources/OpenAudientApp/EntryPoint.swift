import Foundation
import AppKit
import OpenAudient

/// Single entry point: with no arguments it launches the SwiftUI app; with a
/// subcommand it runs headless (`oa cut on`, `oa dump`, …) and exits.
@main
enum EntryPoint {
    static func main() {
        let arguments = Array(CommandLine.arguments.dropFirst())
        if arguments.isEmpty {
            MixerApp.main()
        } else {
            exit(runHeadless(arguments))
        }
    }

    private static func runHeadless(_ arguments: [String]) -> Int32 {
        let result = Locked<Int32>(0)
        let done = DispatchSemaphore(value: 0)
        Task {
            result.value = await CommandRunner.run(arguments)
            done.signal()
        }
        done.wait()
        return result.value
    }
}

/// Tiny mutable box so the detached task can hand a value back across the wait.
private final class Locked<T>: @unchecked Sendable {
    var value: T
    init(_ value: T) { self.value = value }
}
