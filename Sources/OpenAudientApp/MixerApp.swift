import SwiftUI
import AppKit
import OpenAudient

struct MixerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var controller = AudientController()

    var body: some Scene {
        // A single-instance Window, so "Show Open Audient" focuses the existing
        // mixer instead of opening another copy (WindowGroup creates one per call).
        Window("Open Audient", id: "mixer") {
            ContentView()
                .environmentObject(controller)
                .frame(minWidth: 560, idealWidth: 980, minHeight: 520, idealHeight: 760)
                .preferredColorScheme(.dark)
                .task { controller.start() }
        }

        MenuBarExtra {
            MixerMenu()
                .environmentObject(controller)
        } label: {
            Image(systemName: "slider.vertical.3")
                .accessibilityLabel("Open Audient")
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Keep OpenAudient available from the menu bar without occupying the Dock.
        NSApp.setActivationPolicy(.accessory)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}

private struct MixerMenu: View {
    @Environment(\.openWindow) private var openWindow
    @EnvironmentObject private var controller: AudientController

    var body: some View {
        Text(controller.isConnected ? "USB mixer online" : "Waiting for interface")

        Divider()

        Button("Show Open Audient") {
            openWindow(id: "mixer")
            NSApp.activate(ignoringOtherApps: true)
        }
        .keyboardShortcut("o")

        Button("Hide Open Audient") {
            NSApp.hide(nil)
        }
        .keyboardShortcut("h")

        Divider()

        Button("Quit Open Audient") {
            NSApp.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}
