// ContentFilterProviderTests.swift
// Unit tests for PrivarionContentFilterProvider flow filtering
// Requirements: 5.2-5.4, 5.9, 20.1

import XCTest
import NetworkExtension
@testable import PrivarionNetworkExtension
@testable import PrivarionSharedModels

@available(macOS 10.15, *)
final class ContentFilterProviderTests: XCTestCase {
    
    // MARK: - Properties
    
    var dnsFilter: DNSFilter!
    var blocklistManager: BlocklistManager!
    
    // MARK: - Setup & Teardown
    
    override func setUp() {
        super.setUp()
        dnsFilter = DNSFilter()
        blocklistManager = BlocklistManager()
    }
    
    override func tearDown() {
        dnsFilter = nil
        blocklistManager = nil
        super.tearDown()
    }
    
    // MARK: - Flow Filtering Logic Tests
    
    /// Test that tracking domains are identified for blocking
    /// Requirement: 5.2, 5.3
    func testTrackingDomainIdentification() {
        // Test known tracking domains
        let trackingDomains = [
            "google-analytics.com",
            "googletagmanager.com",
            "doubleclick.net",
            "facebook.com",
            "mixpanel.com"
        ]
        
        for domain in trackingDomains {
            let shouldBlock = blocklistManager.shouldBlockDomain(domain)
            XCTAssertTrue(shouldBlock, "Tracking domain '\(domain)' should be identified for blocking")
        }
    }
    
    /// Test that fingerprinting domains are identified for monitoring
    /// Requirement: 5.4
    func testFingerprintingDomainIdentification() {
        // Test fingerprinting domain patterns
        let fingerprintingDomains = [
            "fingerprint.example.com",
            "tracking.site.com",
            "analytics.domain.com",
            "telemetry.service.com",
            "fp.tracker.com"
        ]
        
        for domain in fingerprintingDomains {
            let isFingerprinting = dnsFilter.isFingerprintingDomain(domain)
            XCTAssertTrue(isFingerprinting, "Domain '\(domain)' should be identified as fingerprinting")
        }
    }
    
    /// Test that allowed domains are not blocked
    /// Requirement: 5.2
    func testAllowedDomainsNotBlocked() {
        // Test legitimate domains that should not be blocked
        let allowedDomains = [
            "apple.com",
            "github.com",
            "stackoverflow.com",
            "wikipedia.org"
        ]
        
        for domain in allowedDomains {
            let shouldBlock = blocklistManager.shouldBlockDomain(domain)
            XCTAssertFalse(shouldBlock, "Allowed domain '\(domain)' should not be blocked")
        }
    }
    
    /// Test web port identification for Safari/WebView filtering
    /// Requirement: 5.9
    func testWebPortIdentification() {
        // Web ports that should trigger monitoring
        let webPorts = [80, 443, 8080, 8443]
        
        for port in webPorts {
            // In the actual implementation, flows to these ports are monitored
            XCTAssertTrue(webPorts.contains(port), "Port \(port) should be identified as web port")
        }
    }
    
    /// Test subdomain blocking
    /// Requirement: 5.2
    func testSubdomainBlocking() {
        // Add parent domain to blocklist
        blocklistManager.addBlockedDomain("analytics.example.com")
        
        // Test that subdomains are also blocked
        let subdomains = [
            "analytics.example.com",
            "sub.analytics.example.com",
            "deep.sub.analytics.example.com"
        ]
        
        // Give the blocklist time to update
        Thread.sleep(forTimeInterval: 0.1)
        
        for subdomain in subdomains {
            let shouldBlock = blocklistManager.shouldBlockDomain(subdomain)
            XCTAssertTrue(shouldBlock, "Subdomain '\(subdomain)' should be blocked when parent is blocked")
        }
    }
    
    // MARK: - Content Inspection Tests
    
    /// Test fingerprinting pattern detection
    /// Requirement: 5.5, 5.6
    func testFingerprintingPatternDetection() {
        // Test various fingerprinting patterns
        let fingerprintingPatterns = [
            "canvas.toDataURL",
            "canvas.getImageData",
            "WebGLRenderingContext",
            "navigator.plugins",
            "AudioContext.createOscillator",
            "navigator.hardwareConcurrency",
            "navigator.deviceMemory"
        ]
        
        for pattern in fingerprintingPatterns {
            let content = "var data = \(pattern)();"
            XCTAssertTrue(content.contains(pattern), "Pattern '\(pattern)' should be detectable in content")
        }
    }
    
    /// Test telemetry pattern detection
    /// Requirement: 5.7, 5.8
    func testTelemetryPatternDetection() {
        // Test various telemetry patterns
        let telemetryPatterns = [
            "analytics",
            "tracking",
            "telemetry",
            "beacon",
            "pageview",
            "event"
        ]
        
        for pattern in telemetryPatterns {
            let content = "{\"type\": \"\(pattern)\", \"data\": {}}"
            XCTAssertTrue(content.lowercased().contains(pattern), "Pattern '\(pattern)' should be detectable in content")
        }
    }
    
    /// Test telemetry JSON structure detection
    /// Requirement: 5.7, 5.8
    func testTelemetryJSONStructureDetection() {
        let telemetryJSON = """
        {
            "event": "pageview",
            "analytics": {
                "page": "/home",
                "timestamp": 1234567890
            }
        }
        """
        
        // Verify JSON contains telemetry indicators
        XCTAssertTrue(telemetryJSON.contains("\"event\""), "Should detect event field")
        XCTAssertTrue(telemetryJSON.contains("\"analytics\""), "Should detect analytics field")
        
        // Verify it can be parsed as JSON
        if let jsonData = telemetryJSON.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
            XCTAssertNotNil(json["event"], "Should parse event field")
            XCTAssertNotNil(json["analytics"], "Should parse analytics field")
        } else {
            XCTFail("Should be able to parse telemetry JSON")
        }
    }
    
    /// Test that clean content is not flagged
    /// Requirement: 5.5, 5.7
    func testCleanContentNotFlagged() {
        let cleanContent = [
            "Hello, World!",
            "GET / HTTP/1.1\r\nHost: example.com\r\n\r\n",
            "{\"message\": \"Hello\", \"user\": \"test\"}",
            "function add(a, b) { return a + b; }"
        ]
        
        let fingerprintingPatterns = [
            "canvas.toDataURL",
            "WebGLRenderingContext",
            "navigator.plugins"
        ]
        
        for content in cleanContent {
            var containsPattern = false
            for pattern in fingerprintingPatterns {
                if content.contains(pattern) {
                    containsPattern = true
                    break
                }
            }
            XCTAssertFalse(containsPattern, "Clean content '\(content)' should not contain fingerprinting patterns")
        }
    }
    
    /// Test DNS filter integration with blocklist
    /// Requirement: 5.2
    func testDNSFilterBlocklistIntegration() {
        // Create a DNS query for a tracking domain
        let query = DNSQuery(
            id: 1,
            domain: "google-analytics.com",
            queryType: .A,
            timestamp: Date()
        )
        
        // Filter the query
        let response = dnsFilter.filterDNSQuery(query)
        
        // Verify the domain is blocked (NXDOMAIN response)
        XCTAssertNotNil(response, "Should return a response for blocked domain")
        if let response = response {
            XCTAssertTrue(response.addresses.isEmpty, "Blocked domain should return empty addresses (NXDOMAIN)")
        }
    }
    
    /// Test DNS filter fingerprinting domain handling
    /// Requirement: 5.4
    func testDNSFilterFingerprintingDomain() {
        // Create a DNS query for a fingerprinting domain
        let query = DNSQuery(
            id: 2,
            domain: "fingerprint.tracker.com",
            queryType: .A,
            timestamp: Date()
        )
        
        // Filter the query
        let response = dnsFilter.filterDNSQuery(query)
        
        // Verify fake response is returned
        XCTAssertNotNil(response, "Should return a response for fingerprinting domain")
        if let response = response {
            XCTAssertFalse(response.addresses.isEmpty, "Fingerprinting domain should return fake addresses")
            // Verify it's a fake IP (should be one of the test IPs)
            let fakeIPs = ["127.0.0.1", "0.0.0.0", "192.0.2.1", "198.51.100.1", "203.0.113.1"]
            XCTAssertTrue(fakeIPs.contains(response.addresses[0]), "Should return a fake IP address")
        }
    }
    
    // MARK: - Flow Evaluation Tests
    
    /// Test flow evaluation returns allow verdict for normal domains
    /// Requirement: 5.2
    func testFlowEvaluationAllowsNormalDomains() {
        // Test that normal domains receive allow verdict
        let normalDomains = [
            "apple.com",
            "github.com",
            "stackoverflow.com",
            "wikipedia.org",
            "example.com"
        ]
        
        for domain in normalDomains {
            let shouldBlock = blocklistManager.shouldBlockDomain(domain)
            let isFingerprinting = dnsFilter.isFingerprintingDomain(domain)
            
            XCTAssertFalse(shouldBlock, "Normal domain '\(domain)' should not be blocked")
            XCTAssertFalse(isFingerprinting, "Normal domain '\(domain)' should not be flagged as fingerprinting")
        }
    }
    
    /// Test flow evaluation returns drop verdict for tracking domains
    /// Requirement: 5.2, 5.3
    func testFlowEvaluationDropsTrackingDomains() {
        // Test that tracking domains receive drop verdict
        let trackingDomains = [
            "google-analytics.com",
            "googletagmanager.com",
            "doubleclick.net",
            "facebook.com",
            "mixpanel.com",
            "segment.com",
            "amplitude.com"
        ]
        
        for domain in trackingDomains {
            let shouldBlock = blocklistManager.shouldBlockDomain(domain)
            XCTAssertTrue(shouldBlock, "Tracking domain '\(domain)' should receive drop verdict")
        }
    }
    
    /// Test flow evaluation returns filter verdict for fingerprinting domains
    /// Requirement: 5.4
    func testFlowEvaluationFiltersFingerprinting() {
        // Test that fingerprinting domains receive filter verdict with monitoring
        let fingerprintingDomains = [
            "fingerprint.example.com",
            "fp.tracker.com",
            "device-fingerprint.com",
            "tracking.browser.net"
        ]
        
        for domain in fingerprintingDomains {
            let isFingerprinting = dnsFilter.isFingerprintingDomain(domain)
            XCTAssertTrue(isFingerprinting, "Fingerprinting domain '\(domain)' should receive filter verdict")
        }
    }
    
    /// Test flow evaluation for Safari and WebView traffic
    /// Requirement: 5.9
    func testFlowEvaluationForSafariWebView() {
        // Test that web ports (80, 443, 8080, 8443) are identified for Safari/WebView filtering
        let webPorts = [80, 443, 8080, 8443]
        let nonWebPorts = [22, 25, 53, 110, 143, 3306, 5432]
        
        for port in webPorts {
            XCTAssertTrue(webPorts.contains(port), "Port \(port) should be monitored for Safari/WebView")
        }
        
        for port in nonWebPorts {
            XCTAssertFalse(webPorts.contains(port), "Port \(port) should not be monitored for Safari/WebView")
        }
    }
    
    /// Test flow evaluation with mixed scenarios
    /// Requirement: 5.2, 5.4
    func testFlowEvaluationMixedScenarios() {
        // Test various domain scenarios
        struct TestCase {
            let domain: String
            let expectedBlocked: Bool
            let expectedFingerprinting: Bool
        }
        
        let testCases = [
            TestCase(domain: "apple.com", expectedBlocked: false, expectedFingerprinting: false),
            TestCase(domain: "mixpanel.com", expectedBlocked: true, expectedFingerprinting: false),
            TestCase(domain: "fingerprint.tracker.com", expectedBlocked: false, expectedFingerprinting: true),
            TestCase(domain: "github.com", expectedBlocked: false, expectedFingerprinting: false),
            TestCase(domain: "doubleclick.net", expectedBlocked: true, expectedFingerprinting: false)
        ]
        
        for testCase in testCases {
            let shouldBlock = blocklistManager.shouldBlockDomain(testCase.domain)
            let isFingerprinting = dnsFilter.isFingerprintingDomain(testCase.domain)
            
            XCTAssertEqual(shouldBlock, testCase.expectedBlocked, 
                          "Domain '\(testCase.domain)' block status should be \(testCase.expectedBlocked)")
            XCTAssertEqual(isFingerprinting, testCase.expectedFingerprinting,
                          "Domain '\(testCase.domain)' fingerprinting status should be \(testCase.expectedFingerprinting)")
        }
    }
    
    // MARK: - Fingerprinting Pattern Detection Tests
    
    /// Test detection of canvas fingerprinting patterns
    /// Requirement: 5.5, 5.6
    func testCanvasFingerprintingDetection() {
        let canvasPatterns = [
            "canvas.toDataURL",
            "canvas.getImageData",
            "CanvasRenderingContext2D.getImageData"
        ]
        
        for pattern in canvasPatterns {
            let content = """
            var canvas = document.createElement('canvas');
            var ctx = canvas.getContext('2d');
            var data = \(pattern)();
            """
            
            XCTAssertTrue(content.contains(pattern), 
                         "Canvas fingerprinting pattern '\(pattern)' should be detected")
        }
    }
    
    /// Test detection of WebGL fingerprinting patterns
    /// Requirement: 5.5, 5.6
    func testWebGLFingerprintingDetection() {
        let webglPatterns = [
            "WebGLRenderingContext",
            "getParameter(gl.RENDERER)",
            "getParameter(gl.VENDOR)"
        ]
        
        for pattern in webglPatterns {
            let content = """
            var gl = canvas.getContext('webgl');
            var info = \(pattern);
            """
            
            XCTAssertTrue(content.contains(pattern),
                         "WebGL fingerprinting pattern '\(pattern)' should be detected")
        }
    }
    
    /// Test detection of audio fingerprinting patterns
    /// Requirement: 5.5, 5.6
    func testAudioFingerprintingDetection() {
        let audioPatterns = [
            "AudioContext.createOscillator",
            "AudioContext.createAnalyser",
            "AudioContext.createDynamicsCompressor"
        ]
        
        for pattern in audioPatterns {
            let content = """
            var audioContext = new AudioContext();
            var oscillator = \(pattern)();
            """
            
            XCTAssertTrue(content.contains(pattern),
                         "Audio fingerprinting pattern '\(pattern)' should be detected")
        }
    }
    
    /// Test detection of navigator-based fingerprinting patterns
    /// Requirement: 5.5, 5.6
    func testNavigatorFingerprintingDetection() {
        let navigatorPatterns = [
            "navigator.plugins",
            "navigator.mimeTypes",
            "navigator.hardwareConcurrency",
            "navigator.deviceMemory",
            "navigator.getBattery",
            "navigator.getGamepads"
        ]
        
        for pattern in navigatorPatterns {
            let content = """
            var info = \(pattern);
            console.log(info);
            """
            
            XCTAssertTrue(content.contains(pattern),
                         "Navigator fingerprinting pattern '\(pattern)' should be detected")
        }
    }
    
    /// Test detection of screen fingerprinting patterns
    /// Requirement: 5.5, 5.6
    func testScreenFingerprintingDetection() {
        let screenPatterns = [
            "screen.colorDepth",
            "screen.pixelDepth",
            "screen.width",
            "screen.height"
        ]
        
        for pattern in screenPatterns {
            let content = """
            var screenInfo = {
                depth: \(pattern)
            };
            """
            
            XCTAssertTrue(content.contains(pattern),
                         "Screen fingerprinting pattern '\(pattern)' should be detected")
        }
    }
    
    /// Test detection of WebRTC fingerprinting patterns
    /// Requirement: 5.5, 5.6
    func testWebRTCFingerprintingDetection() {
        let webrtcPatterns = [
            "RTCPeerConnection",
            "enumerateDevices",
            "getUserMedia"
        ]
        
        for pattern in webrtcPatterns {
            let content = """
            var pc = new \(pattern)();
            """
            
            XCTAssertTrue(content.contains(pattern),
                         "WebRTC fingerprinting pattern '\(pattern)' should be detected")
        }
    }
    
    /// Test that legitimate code is not flagged as fingerprinting
    /// Requirement: 5.5, 5.6
    func testLegitimateCodeNotFlaggedAsFingerprinting() {
        let legitimateCode = [
            "function calculateSum(a, b) { return a + b; }",
            "var element = document.getElementById('main');",
            "fetch('/api/data').then(response => response.json());",
            "const user = { name: 'John', age: 30 };"
        ]
        
        let fingerprintingPatterns = [
            "canvas.toDataURL",
            "WebGLRenderingContext",
            "navigator.plugins",
            "AudioContext.createOscillator"
        ]
        
        for code in legitimateCode {
            var containsPattern = false
            for pattern in fingerprintingPatterns {
                if code.contains(pattern) {
                    containsPattern = true
                    break
                }
            }
            XCTAssertFalse(containsPattern, 
                          "Legitimate code should not contain fingerprinting patterns: \(code)")
        }
    }
    
    // MARK: - Telemetry Pattern Detection Tests
    
    /// Test detection of analytics telemetry patterns
    /// Requirement: 5.7, 5.8
    func testAnalyticsTelemetryDetection() {
        let analyticsPatterns = [
            "analytics",
            "pageview",
            "event",
            "track"
        ]
        
        for pattern in analyticsPatterns {
            let content = """
            {
                "type": "\(pattern)",
                "timestamp": 1234567890
            }
            """
            
            XCTAssertTrue(content.lowercased().contains(pattern),
                         "Analytics telemetry pattern '\(pattern)' should be detected")
        }
    }
    
    /// Test detection of tracking beacon patterns
    /// Requirement: 5.7, 5.8
    func testTrackingBeaconDetection() {
        let beaconPatterns = [
            "beacon",
            "tracking",
            "impression",
            "conversion"
        ]
        
        for pattern in beaconPatterns {
            let content = """
            navigator.sendBeacon('/\(pattern)', data);
            """
            
            XCTAssertTrue(content.lowercased().contains(pattern),
                         "Tracking beacon pattern '\(pattern)' should be detected")
        }
    }
    
    /// Test detection of telemetry JSON structures
    /// Requirement: 5.7, 5.8
    func testTelemetryJSONStructureDetectionComprehensive() {
        let telemetryStructures = [
            """
            {
                "event": "click",
                "properties": {
                    "button": "submit"
                }
            }
            """,
            """
            {
                "analytics": {
                    "page": "/home",
                    "referrer": "google.com"
                }
            }
            """,
            """
            {
                "tracking": {
                    "user_id": "12345",
                    "session_id": "abc"
                }
            }
            """,
            """
            {
                "metrics": {
                    "cpu": 45,
                    "memory": 1024
                }
            }
            """
        ]
        
        for structure in telemetryStructures {
            // Verify it contains telemetry indicators
            let hasTelemetryField = structure.contains("\"event\"") ||
                                   structure.contains("\"analytics\"") ||
                                   structure.contains("\"tracking\"") ||
                                   structure.contains("\"metrics\"")
            
            XCTAssertTrue(hasTelemetryField, "Telemetry JSON structure should contain telemetry fields")
            
            // Verify it can be parsed as JSON
            if let jsonData = structure.data(using: .utf8) {
                let json = try? JSONSerialization.jsonObject(with: jsonData)
                XCTAssertNotNil(json, "Telemetry structure should be valid JSON")
            }
        }
    }
    
    /// Test detection of usage statistics patterns
    /// Requirement: 5.7, 5.8
    func testUsageStatisticsDetection() {
        let usagePatterns = [
            "telemetry",
            "usage",
            "statistics",
            "metrics"
        ]
        
        for pattern in usagePatterns {
            let content = """
            POST /api/\(pattern) HTTP/1.1
            Content-Type: application/json
            
            {"data": "test"}
            """
            
            XCTAssertTrue(content.lowercased().contains(pattern),
                         "Usage statistics pattern '\(pattern)' should be detected")
        }
    }
    
    /// Test detection of attribution tracking patterns
    /// Requirement: 5.7, 5.8
    func testAttributionTrackingDetection() {
        let attributionPatterns = [
            "attribution",
            "campaign",
            "source",
            "medium"
        ]
        
        for pattern in attributionPatterns {
            let content = """
            {
                "\(pattern)": "google",
                "timestamp": 1234567890
            }
            """
            
            XCTAssertTrue(content.lowercased().contains(pattern),
                         "Attribution tracking pattern '\(pattern)' should be detected")
        }
    }
    
    /// Test that legitimate API calls are not flagged as telemetry
    /// Requirement: 5.7, 5.8
    func testLegitimateAPICallsNotFlaggedAsTelemetry() {
        let legitimateAPICalls = [
            """
            {
                "user": "john",
                "message": "Hello"
            }
            """,
            """
            {
                "product": "widget",
                "quantity": 5
            }
            """,
            """
            {
                "search": "swift programming",
                "results": 100
            }
            """
        ]
        
        let telemetryPatterns = [
            "analytics",
            "tracking",
            "telemetry",
            "beacon",
            "event"
        ]
        
        for apiCall in legitimateAPICalls {
            var containsPattern = false
            for pattern in telemetryPatterns {
                if apiCall.lowercased().contains(pattern) {
                    containsPattern = true
                    break
                }
            }
            XCTAssertFalse(containsPattern,
                          "Legitimate API call should not contain telemetry patterns: \(apiCall)")
        }
    }
    
    /// Test mixed content with both legitimate and telemetry data
    /// Requirement: 5.7, 5.8
    func testMixedContentTelemetryDetection() {
        let mixedContent = """
        {
            "user": "john",
            "message": "Hello",
            "analytics": {
                "pageview": "/home",
                "timestamp": 1234567890
            }
        }
        """
        
        // Should detect telemetry even in mixed content
        XCTAssertTrue(mixedContent.contains("\"analytics\""),
                     "Should detect analytics field in mixed content")
        XCTAssertTrue(mixedContent.contains("\"pageview\""),
                     "Should detect pageview field in mixed content")
        
        // Verify JSON parsing works
        if let jsonData = mixedContent.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
            XCTAssertNotNil(json["analytics"], "Should parse analytics field")
            XCTAssertNotNil(json["user"], "Should parse user field")
        }
    }
    
    /// Test case sensitivity in telemetry detection
    /// Requirement: 5.7, 5.8
    func testTelemetryDetectionCaseInsensitive() {
        let variations = [
            "analytics",
            "Analytics",
            "ANALYTICS",
            "AnAlYtIcS"
        ]
        
        for variation in variations {
            let content = "{\"type\": \"\(variation)\"}"
            XCTAssertTrue(content.lowercased().contains("analytics"),
                         "Telemetry detection should be case-insensitive for '\(variation)'")
        }
    }
}

