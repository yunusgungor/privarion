import SwiftUI
import Logging
import PrivarionCore

/// Main SwiftUI application entry point
/// Following Clean Architecture pattern with centralized state management
@main
struct PrivarionGUIApp: App {
    
    /// Central application state following Context7 research pattern
    @StateObject private var appState = AppState()
    
    /// Application-wide logger using centralized logging
    private let logger = PrivarionLogger.shared
    
    init() {
        logger.info("Privarion GUI Application initializing")
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .task {
                    await appState.initialize()
                }
                .onAppear {
                    logger.info("Main window appeared")
                }
        }
        .windowStyle(.titleBar)
        .commands {
            // Application commands
            CommandGroup(replacing: .appInfo) {
                Button("About Privarion") {
                    // Show about window
                    logger.debug("About Privarion requested")
                }
            }
            
            CommandGroup(after: .appInfo) {
                Divider()
                
                Button("Preferences...") {
                    appState.navigateTo(.settings)
                }
                .keyboardShortcut(",", modifiers: .command)
            }
            
            // Navigation commands
            CommandGroup(before: .windowArrangement) {
                Menu("Navigation") {
                    Button("Dashboard") {
                        appState.navigationManager.navigateTo(.dashboard)
                    }
                    .keyboardShortcut("1", modifiers: .command)
                    
                    Button("Modules") {
                        appState.navigationManager.navigateTo(.modules)
                    }
                    .keyboardShortcut("2", modifiers: .command)
                    
                    Button("Profiles") {
                        appState.navigationManager.navigateTo(.profiles)
                    }
                    .keyboardShortcut("3", modifiers: .command)
                    
                    Button("Logs") {
                        appState.navigationManager.navigateTo(.logs)
                    }
                    .keyboardShortcut("4", modifiers: .command)
                    
                    Divider()
                    
                    Button("Back") {
                        appState.navigationManager.goBack()
                    }
                    .keyboardShortcut("[", modifiers: .command)
                    .disabled(!appState.navigationManager.canGoBack)
                    
                    Button("Forward") {
                        appState.navigationManager.goForward()
                    }
                    .keyboardShortcut("]", modifiers: .command)
                    .disabled(!appState.navigationManager.canGoForward)
                }
            }
            
            // Tools commands
            CommandGroup(before: .help) {
                Menu("Tools") {
                    Button("Command Palette...") {
                        appState.showCommandPalette()
                    }
                    .keyboardShortcut("p", modifiers: [.command, .shift])
                    
                    Button("Refresh All") {
                        Task {
                            await appState.refreshAll()
                        }
                    }
                    .keyboardShortcut("r", modifiers: .command)
                    
                    Divider()
                    
                    Button("Keyboard Shortcuts...") {
                        appState.navigationManager.navigateTo(.shortcuts)
                    }
                    .keyboardShortcut("k", modifiers: [.command, .shift])
                }
                
                Divider()
                
                Button("Send Feedback...") {
                    sendFeedback()
                }
                .keyboardShortcut("f", modifiers: [.command, .shift])
            }
        }
    }
    
    private func sendFeedback() {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        let emailSubject = "Privarion Beta Feedback v\(version) (\(build))"
        let emailBody = """
            Privarion Beta Version: \(version) Build: \(build)
            macOS Version: \(ProcessInfo.processInfo.operatingSystemVersionString)
            
            ---
            Please describe your feedback here:
            
            
            ---
            Do not remove the version info above.
            """
        
        if let url = URL(string: "mailto:feedback@privarion.org?subject=\(emailSubject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&body=\(emailBody.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")") {
            NSWorkspace.shared.open(url)
        }
    }
}
