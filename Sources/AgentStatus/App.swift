import SwiftUI
import AppKit
import CoreText

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
            SteampunkFonts.registerBundledFonts()
            IPCServer.shared.start(store: store)
            scheduleStaleSweeps()
        }
    }

    private func scheduleStaleSweeps() {
        let store = self.store
        Task.detached(priority: .utility) {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 30_000_000_000) // 30s
                await MainActor.run { store.sweepStale() }
            }
        }
    }
}
