import SwiftUI
import AppKit
import OpenAudient

struct MixerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var controller = AudientController()

    var body: some Scene {
        WindowGroup("Open Audient") {
            ContentView()
                .environmentObject(controller)
                .frame(minWidth: 560, idealWidth: 980, minHeight: 520, idealHeight: 760)
                .preferredColorScheme(.dark)
                .task { controller.start() }
        }
    }
}

/// A bare SwiftUI executable (not a bundled .app) needs to opt into being a
/// regular foreground app and bring its window forward.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}
