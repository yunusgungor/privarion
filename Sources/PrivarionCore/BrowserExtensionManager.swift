import Foundation

public class BrowserExtensionManager: @unchecked Sendable {
    
    public enum ExtensionError: Error, LocalizedError {
        case installationFailed
        case notSupported
        case invalidManifest
        case exportFailed
        
        public var errorDescription: String? {
            switch self {
            case .installationFailed:
                return "Browser extension installation failed"
            case .notSupported:
                return "Browser not supported"
            case .invalidManifest:
                return "Invalid browser extension manifest"
            case .exportFailed:
                return "Failed to export browser extension"
            }
        }
    }
    
    public enum Browser: String, CaseIterable {
        case chrome = "chrome"
        case firefox = "firefox"
        case safari = "safari"
        case edge = "edge"
        
        public var displayName: String {
            switch self {
            case .chrome: return "Google Chrome"
            case .firefox: return "Mozilla Firefox"
            case .safari: return "Safari"
            case .edge: return "Microsoft Edge"
            }
        }
        
        public var extensionDirectory: String {
            switch self {
            case .chrome, .edge: return "extensions"
            case .firefox: return "extensions"
            case .safari: return "Safari Extension"
            }
        }
    }
    
    public struct ExtensionManifest: Codable {
        public var manifestVersion: Int
        public var name: String
        public var version: String
        public var description: String
        public var permissions: [String]
        public var contentScripts: [ContentScript]?
        public var background: BackgroundScript?
        
        public init(manifestVersion: Int = 3,
                    name: String = "Privarion Browser Protection",
                    version: String = "1.0.0",
                    description: String = "Browser fingerprinting protection",
                    permissions: [String] = [],
                    contentScripts: [ContentScript]? = nil,
                    background: BackgroundScript? = nil) {
            self.manifestVersion = manifestVersion
            self.name = name
            self.version = version
            self.description = description
            self.permissions = permissions
            self.contentScripts = contentScripts
            self.background = background
        }
        
        public struct ContentScript: Codable {
            public var matches: [String]
            public var js: [String]?
            public var runAt: String?
            
            public init(matches: [String] = ["<all_urls>"],
                       js: [String]? = nil,
                       runAt: String = "document_start") {
                self.matches = matches
                self.js = js
                self.runAt = runAt
            }
        }
        
        public struct BackgroundScript: Codable {
            public var serviceWorker: String?
            
            public init(serviceWorker: String? = nil) {
                self.serviceWorker = serviceWorker
            }
        }
    }
    
    private let logger: PrivarionLogger
    private let userAgentManager: UserAgentSpoofingManager
    private let canvasManager: CanvasFingerprintMaskingManager
    private let exportDirectory: URL
    
    public init(userAgentManager: UserAgentSpoofingManager,
                canvasManager: CanvasFingerprintMaskingManager,
                logger: PrivarionLogger = PrivarionLogger.shared,
                exportDirectory: URL? = nil) {
        self.logger = logger
        self.userAgentManager = userAgentManager
        self.canvasManager = canvasManager
        
        if let customDir = exportDirectory {
            self.exportDirectory = customDir
        } else {
            let homeDir = FileManager.default.homeDirectoryForCurrentUser
            self.exportDirectory = homeDir.appendingPathComponent(".privarion/browser-extensions")
        }
    }
    
    public func generateExtension(for browser: Browser) throws -> URL {
        logger.info("Generating browser extension for \(browser.displayName)")
        
        try createExportDirectory()
        
        let manifest = generateManifest(for: browser)
        try exportManifest(manifest, for: browser)
        
        try exportContentScript(for: browser)
        
        if browser == .chrome || browser == .edge || browser == .firefox {
            try exportBackgroundScript(for: browser)
        }
        
        if browser == .safari {
            try exportSafariExtensionFiles()
        }
        
        logger.info("Browser extension generated successfully")
        
        return exportDirectory.appendingPathComponent(browser.extensionDirectory)
    }
    
    public func getExtensionStatus() -> [Browser: Bool] {
        var status: [Browser: Bool] = [:]
        
        for browser in Browser.allCases {
            let extensionPath = exportDirectory
                .appendingPathComponent(browser.extensionDirectory)
                .appendingPathComponent("manifest.json")
            status[browser] = FileManager.default.fileExists(atPath: extensionPath.path)
        }
        
        return status
    }
    
    private func generateManifest(for browser: Browser) -> ExtensionManifest {
        var permissions: [String] = ["storage", "activeTab"]
        
        if userAgentManager.getCurrentUserAgent() != nil {
            permissions.append("webRequest")
        }
        
        var contentScripts: [ExtensionManifest.ContentScript]? = nil
        var background: ExtensionManifest.BackgroundScript? = nil
        
        switch browser {
        case .chrome, .edge:
            contentScripts = [
                ExtensionManifest.ContentScript(
                    matches: ["<all_urls>"],
                    js: ["content.js"],
                    runAt: "document_start"
                )
            ]
            background = ExtensionManifest.BackgroundScript(serviceWorker: "background.js")
            
        case .firefox:
            contentScripts = [
                ExtensionManifest.ContentScript(
                    matches: ["<all_urls>"],
                    js: ["content.js"],
                    runAt: "document_start"
                )
            ]
            background = ExtensionManifest.BackgroundScript(serviceWorker: "background.js")
            
        case .safari:
            contentScripts = [
                ExtensionManifest.ContentScript(
                    matches: ["<all_urls>"],
                    js: ["content.js"],
                    runAt: "document_start"
                )
            ]
        }
        
        return ExtensionManifest(
            manifestVersion: 3,
            name: "Privarion Browser Protection",
            version: "1.0.0",
            description: "Protects against browser fingerprinting",
            permissions: permissions,
            contentScripts: contentScripts,
            background: background
        )
    }
    
    private func exportManifest(_ manifest: ExtensionManifest, for browser: Browser) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        let data = try encoder.encode(manifest)
        
        let manifestPath = exportDirectory
            .appendingPathComponent(browser.extensionDirectory)
            .appendingPathComponent("manifest.json")
        
        try data.write(to: manifestPath)
    }
    
    private func exportContentScript(for browser: Browser) throws {
        let userAgentScript = userAgentManager.generateSpoofingScript()
        let canvasScript = canvasManager.generateMaskingScript()
        
        let combinedScript = """
        (function() {
            'use strict';
            
            \(userAgentScript)
            
            \(canvasScript)
            
        })();
        """
        
        let scriptPath = exportDirectory
            .appendingPathComponent(browser.extensionDirectory)
            .appendingPathComponent("content.js")
        
        try combinedScript.write(to: scriptPath, atomically: true, encoding: .utf8)
    }
    
    private func exportBackgroundScript(for browser: Browser) throws {
        let backgroundScript = """
        // Privarion Browser Protection - Background Service Worker
        
        browser.runtime.onInstalled.addListener((details) => {
            console.log('[Privarion] Extension installed:', details.reason);
        });
        
        browser.runtime.onMessage.addListener((message, sender, sendResponse) => {
            if (message.type === 'getStatus') {
                sendResponse({
                    userAgent: navigator.userAgent,
                    canvasEnabled: true
                });
            }
            return true;
        });
        
        console.log('[Privarion] Background service worker started');
        """
        
        let scriptPath = exportDirectory
            .appendingPathComponent(browser.extensionDirectory)
            .appendingPathComponent("background.js")
        
        try backgroundScript.write(to: scriptPath, atomically: true, encoding: .utf8)
    }
    
    private func exportSafariExtensionFiles() throws {
        let safariInfo = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>CFBundleDevelopmentRegion</key>
            <string>en</string>
            <key>CFBundleDisplayName</key>
            <string>Privarion Browser Protection</string>
            <key>CFBundleExecutable</key>
            <string>$(EXECUTABLE_NAME)</string>
            <key>CFBundleIdentifier</key>
            <string>com.privarion.browser-protection</string>
            <key>CFBundleInfoDictionaryVersion</key>
            <string>6.0</string>
            <key>CFBundleName</key>
            <string>Privarion Browser Protection</string>
            <key>CFBundlePackageType</key>
            <string>BNDL</string>
            <key>CFBundleShortVersionString</key>
            <string>1.0.0</string>
            <key>CFBundleVersion</key>
            <string>1</string>
            <key>NSHumanReadableCopyright</key>
            <string>Copyright © 2024 Privarion. All rights reserved.</string>
            <key>NSPrincipalClass</key>
            <string>BrowserExtensionHandler</string>
        </dict>
        </plist>
        """
        
        let infoPlistPath = exportDirectory
            .appendingPathComponent("Safari Extension")
            .appendingPathComponent("Info.plist")
        
        try safariInfo.write(to: infoPlistPath, atomically: true, encoding: .utf8)
    }
    
    private func createExportDirectory() throws {
        let fileManager = FileManager.default
        
        for browser in Browser.allCases {
            let browserDir = exportDirectory.appendingPathComponent(browser.extensionDirectory)
            if !fileManager.fileExists(atPath: browserDir.path) {
                try fileManager.createDirectory(at: browserDir, withIntermediateDirectories: true)
            }
        }
    }
}
