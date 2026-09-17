import SwiftUI

@main
struct OrquestradorLocalApp: App {
    @StateObject private var coordinator = OrchestrationCoordinator()
    // Test-only visual override. Finder launches do not set it, so the system theme remains default.
    private let forcedColorScheme: ColorScheme? = {
        switch ProcessInfo.processInfo.environment["ORQ_FORCE_APPEARANCE"] {
        case "dark": return .dark
        case "light": return .light
        default: return nil
        }
    }()
    private let compactVisualTest = ProcessInfo.processInfo.environment["ORQ_COMPACT_WINDOW"] == "1"

    var body: some Scene {
        WindowGroup("Orquestrador Local", id: "main-window") {
            MainWindowView()
                .environmentObject(coordinator)
                .preferredColorScheme(forcedColorScheme)
                .frame(minWidth: 720, minHeight: 480)
                .onAppear {
                    Task { await coordinator.start() }
                }
        }
        .defaultSize(width: compactVisualTest ? 720 : 860, height: compactVisualTest ? 480 : 580)
        .commands {
            CommandGroup(replacing: .newItem) {
                // Prevent unwanted new window commands
            }
        }

        MenuBarExtra {
            MenuBarPopoverView()
                .environmentObject(coordinator)
        } label: {
            Image(systemName: "square.stack.3d.up")
                .accessibilityLabel("Orquestrador Local")
        }
        .menuBarExtraStyle(.window)
    }
}
