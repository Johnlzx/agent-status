import SwiftUI
import AppKit

@main
struct AgentStatusApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        MenuBarExtra {
            MenuContentView(store: delegate.store)
        } label: {
            StatusBarLabel(store: delegate.store)
        }
        .menuBarExtraStyle(.window)
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let store = SessionStore()

    nonisolated func applicationDidFinishLaunching(_ notification: Notification) {
        MainActor.assumeIsolated {
            IPCServer.shared.start(store: store)
            CodexScanner.shared.start(store: store)
        }
    }

    nonisolated func applicationWillTerminate(_ notification: Notification) {
        CodexScanner.shared.stop()
    }
}
