# Implementation Plan: macOS System-Level Privacy Protection

## Overview

This implementation plan transforms Privarion from an application-level privacy tool into a comprehensive system-level privacy protection system. The implementation leverages macOS System Extensions, Endpoint Security Framework, Network Extensions, and Virtualization Framework to provide SIP-compliant, system-wide protection with hardware isolation capabilities.

The implementation is organized into discrete, incremental tasks that build upon each other. Each task includes specific requirements references for traceability. Testing tasks are marked as optional with "*" to allow for faster MVP delivery while maintaining the option for comprehensive testing.

## Implementation Strategy

1. Start with foundational infrastructure (configuration, error handling, data models)
2. Build core system extension components (installation, lifecycle management)
3. Implement security monitoring (Endpoint Security Framework integration)
4. Add network protection (Network Extensions, DNS filtering, transparent proxy)
5. Implement VM isolation (Virtualization Framework, hardware profiles)
6. Integrate with existing Privarion components (CLI, GUI)
7. Add migration support for existing users
8. Finalize with documentation and distribution preparation

## Tasks

- [x] 1. Set up project structure and foundational components
  - Create new Swift Package Manager modules for system extensions
  - Define module structure: PrivarionSystemExtension, PrivarionNetworkExtension, PrivarionVM, PrivarionAgent
  - Configure Package.swift with dependencies and targets
  - Set up entitlements files for each module
  - Create shared data models module for cross-component communication
  - _Requirements: 1.1, 12.1-12.9_

- [x] 2. Implement core data models and error handling
  - [x] 2.1 Create error enums for all components
    - Implement SystemExtensionError with installation, activation, and entitlement cases
    - Implement EndpointSecurityError with client initialization and event processing cases
    - Implement NetworkExtensionError with tunnel and proxy cases
    - Implement VMError with configuration, resource, and lifecycle cases
    - Implement ConfigurationError with parsing and validation cases
    - _Requirements: 1.5, 2.9, 3.11, 8.9, 15.6, 19.1-19.11_

  - [x] 2.2 Create security event data models
    - Implement SecurityEvent struct with id, timestamp, type, processID, executablePath, action, result
    - Implement ProcessExecutionEvent struct with process details and parent information
    - Implement FileAccessEvent struct with file path and access type
    - Implement NetworkEvent struct with source/destination IP, ports, protocol
    - _Requirements: 2.1-2.10_

  - [x] 2.3 Create network data models
    - Implement NetworkRequest struct with connection details
    - Implement DNSQuery and DNSResponse structs with query types and caching support
    - Implement NetworkProtocol enum (tcp, udp, icmp)
    - Implement DNSQueryType enum (A, AAAA, CNAME, MX)
    - _Requirements: 3.1-3.12, 4.1-4.12_

  - [x] 2.4 Create VM and hardware profile data models
    - Implement HardwareProfile struct conforming to Codable and HardwareProfileProtocol
    - Implement VMSnapshot struct with disk image and memory state paths
    - Implement VMResourceUsage struct with CPU, memory, disk, and network metrics
    - Add validation methods to HardwareProfile
    - _Requirements: 8.1-8.14, 9.1-9.11_

  - [x] 2.5 Write unit tests for data models
    - Test data model serialization/deserialization
    - Test validation logic for HardwareProfile
    - Test error enum descriptions
    - _Requirements: 20.1_


- [x] 3. Implement configuration management system
  - [x] 3.1 Create configuration data structures
    - Implement SystemExtensionConfiguration struct with version, policies, profiles, blocklists, network settings, logging settings
    - Implement BlocklistConfiguration struct with tracking/fingerprinting domains and telemetry endpoints
    - Implement NetworkConfiguration struct with proxy ports and DNS settings
    - Implement LoggingConfiguration struct with log level, rotation, and size limits
    - All configuration structs must conform to Codable for JSON serialization
    - _Requirements: 15.1-15.11, 16.1-16.10_

  - [x] 3.2 Implement SystemExtensionConfigurationManager
    - Implement loadConfiguration() to parse JSON from /Library/Application Support/Privarion/config.json
    - Implement validateConfiguration() with schema validation
    - Implement saveConfiguration() with atomic write and backup
    - Implement reloadConfiguration() for hot-reload support
    - Implement exportConfiguration() and importConfiguration() for backup/restore
    - Handle missing configuration file by creating default configuration
    - _Requirements: 15.1-15.11_

  - [x] 3.3 Implement configuration validation
    - Validate JSON schema before parsing
    - Validate policy rules for consistency
    - Validate hardware profile identifiers for realistic format
    - Return descriptive validation errors with line numbers
    - _Requirements: 15.5-15.6, 9.7-9.8_

  - [x] 3.4 Implement JSON pretty printer
    - Format JSON with 2-space indentation
    - Sort keys alphabetically for consistency
    - Support JSON5 format for comments
    - Limit line length to 100 characters with wrapping
    - Format arrays with one element per line when array has more than 3 elements
    - _Requirements: 16.1-16.10_

  - [x] 3.5 Write property test for configuration round-trip
    - **Property 1: Configuration Round-Trip Consistency**
    - **Validates: Requirements 16.8**
    - Test that parsing then printing configuration produces equivalent object
    - Use swift-check with minimum 100 iterations
    - _Requirements: 16.8, 20.11_

  - [x] 3.6 Write unit tests for configuration manager
    - Test loading valid configuration
    - Test handling invalid JSON
    - Test handling missing configuration file
    - Test configuration reload
    - Test backup and restore
    - _Requirements: 20.1_


- [x] 4. Implement Protection Policy Engine
  - [x] 4.1 Create protection policy data structures
    - Implement ProtectionPolicy struct with identifier, protectionLevel, networkFiltering, dnsFiltering, hardwareSpoofing, requiresVMIsolation, parentPolicy
    - Implement ProtectionLevel enum (none, basic, standard, strict, paranoid)
    - Implement NetworkFilteringRules struct with action and domain lists
    - Implement DNSFilteringRules struct with blocking options
    - Implement FilterAction enum (allow, block, monitor)
    - Implement HardwareSpoofingLevel enum (none, basic, full)
    - All structs must conform to Codable
    - _Requirements: 11.1-11.12_

  - [x] 4.2 Implement ProtectionPolicyEngine
    - Implement evaluatePolicy(for executablePath:) to match application against policy database
    - Implement policy matching with most specific policy selection
    - Implement default policy fallback when no policy matches
    - Implement policy inheritance from parent policies
    - Implement addPolicy(), removePolicy(), loadPolicies(from:)
    - _Requirements: 11.7-11.10_

  - [x] 4.3 Implement policy validation
    - Validate policy rules for consistency before application
    - Validate bundle ID format
    - Validate domain patterns in filtering rules
    - Return descriptive validation errors
    - _Requirements: 11.12_

  - [x] 4.4 Write unit tests for policy engine
    - Test policy matching with exact bundle ID
    - Test policy matching with path
    - Test most specific policy selection
    - Test default policy fallback
    - Test policy inheritance
    - _Requirements: 20.1_


- [ ] 5. Implement System Extension Manager
  - [x] 5.1 Create SystemExtensionCoordinator
    - Implement submitRequest(_:) to handle OSSystemExtensionRequest submission
    - Implement validateEntitlements() to check for required entitlements before installation
    - Implement handleActivationResult(_:) to process activation success/failure
    - Use async/await for asynchronous operations
    - _Requirements: 1.1-1.8, 12.1-12.10_

  - [x] 5.2 Implement PrivarionSystemExtension class
    - Conform to OSSystemExtensionRequestDelegate protocol
    - Implement installExtension() to create and submit installation request
    - Implement activateExtension() to activate installed extension
    - Implement deactivateExtension() to deactivate running extension
    - Implement checkStatus() to query current extension status
    - Handle user approval/denial in delegate methods
    - _Requirements: 1.1-1.8_

  - [x] 5.3 Implement extension status management
    - Create ExtensionStatus enum (notInstalled, installed, active, activating, deactivating, error)
    - Implement SystemExtensionStatusObserver protocol for status change notifications
    - Implement status persistence across app restarts
    - _Requirements: 1.3, 1.7_

  - [~] 5.4 Implement extension lifecycle protocols
    - Create SystemExtensionLifecycle protocol with willActivate, didActivate, willDeactivate, didDeactivate, didFailWithError methods
    - Implement lifecycle event logging to /var/log/privarion/system-extension.log
    - _Requirements: 1.8, 17.1_

  - [~] 5.5 Write unit tests for System Extension Manager
    - Test installation request creation
    - Test entitlement validation
    - Test status transitions
    - Test error handling for missing entitlements
    - _Requirements: 20.1_


- [ ] 6. Implement Endpoint Security Framework integration
  - [ ] 6.1 Create EndpointSecurityManager
    - Implement initialize() to create ES client using es_new_client()
    - Implement subscribe(to:) to subscribe to event types (ES_EVENT_TYPE_AUTH_EXEC, ES_EVENT_TYPE_AUTH_OPEN, ES_EVENT_TYPE_NOTIFY_WRITE, ES_EVENT_TYPE_NOTIFY_EXIT)
    - Implement unsubscribe() to cleanup ES client
    - Handle ES client initialization errors with proper error codes
    - Store ES client as OpaquePointer
    - _Requirements: 2.1-2.10, 14.6_

  - [ ] 6.2 Implement SecurityEventProcessor
    - Implement processEvent(_:) to handle incoming es_message_t events
    - Implement handleProcessExecution(_:) for process launch events
    - Implement handleFileAccess(_:) for file access events
    - Implement handleNetworkEvent(_:) for network events
    - Return ESAuthResult (allow, deny, allowWithModification) within 100ms
    - Use async/await for event processing
    - Implement thread-safe concurrent event handling
    - _Requirements: 2.5-2.8, 18.1_

  - [ ] 6.3 Integrate with ProtectionPolicyEngine
    - Query ProtectionPolicyEngine for policy matching in handleProcessExecution
    - Apply protection rules based on policy (allow, deny, require VM isolation)
    - Log policy application decisions
    - _Requirements: 2.6-2.7, 11.7_

  - [ ] 6.4 Implement SecurityEventHandler protocol
    - Create protocol with canHandle(_:) and handle(_:) methods
    - Allow pluggable event handlers for extensibility
    - _Requirements: 2.5_

  - [ ] 6.5 Implement event logging
    - Log all subscribed events with timestamp, process ID, event type, and action taken
    - Write logs to /var/log/privarion/system-extension.log
    - Include executable path and result in log entries
    - _Requirements: 2.10, 17.4_

  - [ ] 6.6 Write unit tests for Endpoint Security Manager
    - Test ES client initialization with mock client
    - Test event subscription
    - Test process execution event handling
    - Test policy application
    - Test event processing latency (<100ms)
    - _Requirements: 20.1-20.2_

  - [ ] 6.7 Write integration tests for Endpoint Security
    - Test complete flow: process launch → policy evaluation → protection application
    - Test with various applications (Safari, Chrome, native apps)
    - Test error handling for Full Disk Access denial
    - _Requirements: 20.2, 20.8_


- [ ] 7. Checkpoint - Verify core system extension functionality
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 8. Implement DNS filtering and proxy
  - [ ] 8.1 Create DNSFilter class
    - Implement filterDNSQuery(_:) to process DNS queries
    - Implement isBlocked(_:) to check domain against blocklist
    - Implement isFingerprintingDomain(_:) to detect fingerprinting domains
    - Implement createFakeResponse(for:) to generate fake DNS responses for fingerprinting domains
    - Return NXDOMAIN for blocked tracking domains
    - Return fake IP addresses for fingerprinting domains
    - _Requirements: 4.1-4.12_

  - [ ] 8.2 Implement DNSCache
    - Create DNSCacheProtocol with get, set, clear methods
    - Implement in-memory cache with TTL support (300 seconds default)
    - Implement cache eviction for expired entries
    - Thread-safe cache access using actors or locks
    - _Requirements: 4.9, 18.9_

  - [ ] 8.3 Implement BlocklistManager
    - Load blocklist from configuration (tracking domains, fingerprinting domains)
    - Support pattern matching for domains (*.analytics.*, *.telemetry.*, *.tracking.*)
    - Implement addToBlocklist and removeFromBlocklist methods
    - Persist blocklist changes to configuration
    - _Requirements: 4.3-4.4, 10.1_

  - [ ] 8.4 Implement DNS proxy server
    - Bind to localhost port 53 for DNS query interception
    - Parse incoming DNS queries to extract domain name
    - Forward allowed queries to upstream DNS server
    - Support DNS over HTTPS (DoH) for upstream queries
    - Implement connection pooling for upstream DNS connections
    - _Requirements: 4.1-4.2, 4.7-4.8, 18.8_

  - [ ] 8.5 Implement DNS query logging
    - Log blocked domains with timestamp and requesting process
    - Write logs to /var/log/privarion/network-extension.log
    - _Requirements: 4.10, 17.3, 17.5_

  - [ ] 8.6 Write property test for DNS filtering idempotence
    - **Property 2: DNS Filtering Idempotence**
    - **Validates: Requirements 4.3-4.6**
    - Test that filtering a query twice produces same result as filtering once
    - Use swift-check with minimum 100 iterations
    - _Requirements: 20.12_

  - [ ] 8.7 Write unit tests for DNS filter
    - Test tracking domain blocking (return NXDOMAIN)
    - Test fingerprinting domain faking (return fake IP)
    - Test allowed domain forwarding
    - Test cache hit performance (<50ms)
    - Test cache miss performance (<200ms)
    - _Requirements: 20.1, 18.3_


- [ ] 9. Implement Network Extension - Packet Tunnel Provider
  - [ ] 9.1 Create PrivarionPacketTunnelProvider
    - Subclass NEPacketTunnelProvider
    - Override startTunnel(options:) to initialize packet tunnel
    - Override stopTunnel(with:) to cleanup tunnel
    - Create virtual network interface for traffic interception
    - _Requirements: 3.1-3.12_

  - [ ] 9.2 Configure tunnel network settings
    - Configure tunnel settings with local address 127.0.0.1
    - Configure DNS settings to route queries through local proxy (127.0.0.1:53)
    - Configure IPv4 settings with included routes for all traffic (0.0.0.0/0)
    - Apply settings using setTunnelNetworkSettings(_:)
    - _Requirements: 3.2-3.4_

  - [ ] 9.3 Implement packet processing loop
    - Read packets from packetFlow in continuous async loop
    - Parse packet headers to extract destination IP and port
    - Filter packets based on Protection_Policy
    - Write filtered packets back to packetFlow
    - Maintain packet processing latency below 10ms for 95% of packets
    - _Requirements: 3.5-3.9, 18.2_

  - [ ] 9.4 Implement PacketFilter class
    - Implement filterPacket(_:protocol:) to evaluate packets against rules
    - Implement extractDestination(_:) to parse packet headers
    - Return FilterResult (allow, drop, modify)
    - Drop packets destined for tracking domains
    - Modify packets destined for fingerprinting domains
    - _Requirements: 3.6-3.8_

  - [ ] 9.5 Implement error handling and graceful shutdown
    - Handle tunnel start failures with descriptive errors
    - Implement cleanup of network settings on shutdown
    - Restore original network configuration
    - _Requirements: 3.11-3.12, 19.2_

  - [ ] 9.6 Write unit tests for Packet Tunnel Provider
    - Test tunnel configuration
    - Test packet filtering (allow, drop, modify)
    - Test packet processing latency (<10ms)
    - Test graceful shutdown
    - _Requirements: 20.1, 20.3_

  - [ ] 9.7 Write integration tests for Network Extension
    - Test complete flow: network request → packet interception → filtering → response
    - Test with various network configurations (Wi-Fi, Ethernet)
    - Test with VPN active
    - _Requirements: 20.3, 20.7_


- [ ] 10. Implement Content Filter Extension
  - [ ] 10.1 Create PrivarionContentFilterProvider
    - Subclass NEFilterDataProvider
    - Override handleNewFlow(_:) to evaluate new network flows
    - Override handleInboundData(from:readBytesStartOffset:readBytes:) to inspect inbound data
    - Override handleOutboundData(from:readBytesStartOffset:readBytes:) to inspect outbound data
    - _Requirements: 5.1-5.10_

  - [ ] 10.2 Implement flow filtering
    - Evaluate flow destination against tracking domain list
    - Return drop verdict for tracking domains
    - Return filter verdict with monitoring for fingerprinting domains
    - Support filtering for Safari and WKWebView
    - _Requirements: 5.2-5.4, 5.9_

  - [ ] 10.3 Implement content inspection
    - Inspect inbound data for fingerprinting patterns (canvas fingerprinting, WebGL, font enumeration)
    - Modify or block data containing fingerprinting code
    - Inspect outbound data for telemetry patterns (analytics payloads, tracking beacons)
    - Block transmission of telemetry data
    - _Requirements: 5.5-5.8_

  - [ ] 10.4 Implement flow logging
    - Log all blocked flows with URL, timestamp, and reason
    - Write logs to /var/log/privarion/network-extension.log
    - _Requirements: 5.10, 17.3_

  - [ ] 10.5 Write unit tests for Content Filter Provider
    - Test flow evaluation (allow, drop, filter)
    - Test fingerprinting pattern detection
    - Test telemetry pattern detection
    - _Requirements: 20.1_


- [ ] 11. Implement Telemetry Blocker
  - [ ] 11.1 Create TelemetryDatabase
    - Implement storage for known telemetry endpoints
    - Implement isKnownTelemetryEndpoint(_:) to check domain against database
    - Implement addEndpoint and removeEndpoint methods
    - Implement loadFromRemote() to update database from remote source
    - _Requirements: 10.1, 10.10_

  - [ ] 11.2 Create TelemetryPattern struct
    - Define pattern structure with type, domainPattern, pathPattern, headerPatterns, payloadPattern
    - Implement TelemetryType enum (analytics, tracking, crashReporting, usageStatistics)
    - _Requirements: 10.2_

  - [ ] 11.3 Implement TelemetryPatternMatcher
    - Implement pattern matching for telemetry domains (*.analytics.*, *.telemetry.*, *.tracking.*)
    - Implement pattern matching for telemetry paths (/api/analytics, /track, /collect)
    - Implement header inspection for telemetry indicators (X-Analytics-*, X-Tracking-*)
    - Implement payload inspection for telemetry JSON structures
    - _Requirements: 10.4-10.7_

  - [ ] 11.4 Implement TelemetryBlocker
    - Implement shouldBlock(_:) to evaluate network requests
    - Implement detectTelemetryPattern(in:) to identify telemetry in data
    - Integrate with NetworkExtension for request blocking
    - Support user-defined telemetry patterns
    - _Requirements: 10.2-10.3, 10.9_

  - [ ] 11.5 Implement telemetry logging
    - Log all blocked telemetry requests with domain, path, and timestamp
    - Write logs to /var/log/privarion/network-extension.log
    - _Requirements: 10.8, 17.5_

  - [ ] 11.6 Write unit tests for Telemetry Blocker
    - Test telemetry domain detection
    - Test telemetry path detection
    - Test header inspection
    - Test payload inspection
    - Test user-defined patterns
    - _Requirements: 20.1_


- [ ] 12. Checkpoint - Verify network protection functionality
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 13. Implement Hardware Profile Manager
  - [ ] 13.1 Create HardwareProfile struct (extend existing)
    - Add id (UUID), name, hardwareModel (Data), machineIdentifier (Data), macAddress, serialNumber, createdAt
    - Implement validate() to check identifier formats
    - Conform to Codable and HardwareProfileProtocol
    - _Requirements: 9.1-9.8_

  - [ ] 13.2 Implement predefined hardware profiles
    - Create static predefinedProfiles() method
    - Define profiles for MacBook Pro 2021, MacBook Air 2022, iMac 2021, Mac Mini 2023, Mac Studio 2022
    - Use realistic hardware model identifiers and serial number formats
    - _Requirements: 9.5_

  - [ ] 13.3 Implement HardwareProfileManager
    - Implement createProfile(name:template:) to create new profiles
    - Implement getProfile(id:), listProfiles(), deleteProfile(id:)
    - Implement exportProfile(_:) and importProfile(_:) for backup/restore
    - Store profiles in /Library/Application Support/Privarion/profiles.json
    - _Requirements: 9.6-9.11_

  - [ ] 13.4 Implement ProfileTemplate enum
    - Define templates: macBookPro2021, macBookAir2022, iMac2021, macMini2023, macStudio2022, custom
    - Each template provides realistic hardware identifiers
    - _Requirements: 9.5-9.6_

  - [ ] 13.5 Write unit tests for Hardware Profile Manager
    - Test profile creation with templates
    - Test profile validation (valid and invalid formats)
    - Test profile serialization/deserialization
    - Test profile import/export
    - _Requirements: 20.1_


- [ ] 14. Implement Virtualization Framework integration
  - [ ] 14.1 Create VMConfigurationBuilder
    - Implement buildConfiguration(profile:) to create VZVirtualMachineConfiguration
    - Implement createPlatformConfiguration(_:) with custom hardware model and machine identifier
    - Implement createNetworkDevice(macAddress:) with custom MAC address
    - Implement createStorageDevice(size:) for VM disk (default 50GB)
    - Configure CPU count (2-8 cores based on host, max 50% of host)
    - Configure memory size (4GB-16GB based on host, max 50% of host)
    - _Requirements: 8.1-8.7_

  - [ ] 14.2 Implement configuration validation
    - Validate configuration using VZVirtualMachineConfiguration.validate()
    - Return descriptive validation errors
    - Check resource limits before VM creation
    - _Requirements: 8.8-8.9_

  - [ ] 14.3 Create VMResourceManager
    - Implement allocateResources(for:) to reserve CPU and memory
    - Implement releaseResources(for:) to free resources on VM shutdown
    - Implement enforceResourceLimits(_:) to limit VM to 50% CPU and 50% memory
    - Implement getResourceUsage(_:) to query VM resource consumption
    - _Requirements: 8.13, 18.6-18.7_

  - [ ] 14.4 Implement VMManager
    - Implement createVM(with:) to create VZVirtualMachine with hardware profile
    - Implement startVM(_:) to start virtual machine
    - Implement stopVM(_:) to gracefully stop virtual machine
    - Implement installApplication(_:in:) to install apps into running VM
    - Implement snapshot(_:) and restore(_:) for VM state management
    - Store VM state in /Library/Application Support/Privarion/vms/
    - Track active VMs in dictionary [UUID: VZVirtualMachine]
    - _Requirements: 8.1-8.12_

  - [ ] 14.5 Implement VM lifecycle observer
    - Create VMLifecycleObserver protocol with vmDidStart, vmDidStop, vmDidCrash methods
    - Implement crash handling with resource cleanup
    - Log VM lifecycle events to /var/log/privarion/vm-manager.log
    - _Requirements: 8.14, 17.6_

  - [ ] 14.6 Write unit tests for VM Manager
    - Test VM configuration building
    - Test configuration validation (valid and invalid)
    - Test resource allocation and limits
    - Test VM lifecycle (create, start, stop)
    - Test snapshot and restore
    - _Requirements: 20.1, 20.4_

  - [ ] 14.7 Write integration tests for VM Manager
    - Test complete flow: VM creation → application installation → execution → hardware verification
    - Test resource limit enforcement
    - Test crash recovery
    - _Requirements: 20.4_


- [ ] 15. Implement Transparent Proxy Architecture
  - [ ] 15.1 Create NetworkSettingsManager
    - Implement configureSystemProxy() to set system-wide proxy settings
    - Implement restoreOriginalSettings() to restore pre-proxy settings
    - Implement backupCurrentSettings() to save current network configuration
    - Implement getActiveInterfaces() to enumerate network interfaces (Wi-Fi, Ethernet, USB)
    - Use networksetup command with admin privileges for configuration
    - _Requirements: 7.4-7.8, 7.11_

  - [ ] 15.2 Create NetworkSettings and ProxyConfiguration structs
    - Implement NetworkSettings with interfaces, dnsServers, webProxy, secureWebProxy
    - Implement ProxyConfiguration with host, port, enabled
    - Implement NetworkInterface struct with name and type
    - _Requirements: 7.6-7.8_

  - [ ] 15.3 Implement TransparentProxyCoordinator
    - Implement start() to start all proxy components (DNS, HTTP, HTTPS)
    - Implement stop() to stop all proxies and restore network settings
    - Implement getStatus() to query proxy status
    - Start DNS proxy on localhost:53
    - Start HTTP proxy on localhost:8080
    - Start HTTPS proxy on localhost:8443
    - Configure system to use local proxies for all active interfaces
    - _Requirements: 7.1-7.9_

  - [ ] 15.4 Implement HTTP/HTTPS proxy servers
    - Create HTTPProxyServer for HTTP traffic proxying
    - Create HTTPSProxyServer for HTTPS traffic proxying with TLS interception
    - Integrate with TelemetryBlocker for request filtering
    - Integrate with ProtectionPolicyEngine for policy application
    - _Requirements: 7.2-7.3_

  - [ ] 15.5 Implement proxy verification
    - Verify proxy functionality after configuration
    - Test DNS resolution through local proxy
    - Test HTTP/HTTPS requests through local proxies
    - _Requirements: 7.12_

  - [ ] 15.6 Write unit tests for Transparent Proxy
    - Test network settings backup and restore
    - Test proxy configuration for multiple interfaces
    - Test proxy start and stop
    - _Requirements: 20.1_

  - [ ] 15.7 Write integration tests for Transparent Proxy
    - Test complete flow: configure proxies → make network request → verify filtering
    - Test with multiple network interfaces
    - Test settings restoration on failure
    - _Requirements: 20.7_


- [ ] 16. Implement Privarion Agent (Launch Agent)
  - [ ] 16.1 Create PermissionManager
    - Implement checkSystemExtensionPermission() to verify extension approval
    - Implement checkFullDiskAccessPermission() to verify FDA permission
    - Implement checkNetworkExtensionPermission() to verify network extension approval
    - Implement requestPermission(_:) to request specific permission
    - Implement openSystemPreferences(for:) to open relevant permission pane
    - Return PermissionStatus (granted, denied, notDetermined)
    - _Requirements: 14.1-14.11_

  - [ ] 16.2 Create AgentStatus struct
    - Include isRunning, systemExtensionStatus, endpointSecurityActive, networkExtensionActive, activeVMCount, permissions
    - Provide comprehensive status snapshot for monitoring
    - _Requirements: 6.9_

  - [ ] 16.3 Implement PrivarionAgent
    - Implement start() to initialize all protection components
    - Initialize EndpointSecurityManager on startup
    - Start NetworkExtension on startup
    - Verify SystemExtension status on startup
    - Prompt user to activate extension if not active
    - Monitor process launches and apply ProtectionPolicy
    - Implement stop() to gracefully shutdown all components
    - Implement restart() to restart agent
    - Implement getStatus() to return AgentStatus
    - _Requirements: 6.1-6.10_

  - [ ] 16.4 Create Launch Agent plist
    - Create com.privarion.agent.plist in ~/Library/LaunchAgents/
    - Configure RunAtLoad=true for automatic startup
    - Configure KeepAlive=true for automatic restart on crash
    - Configure StandardOutPath and StandardErrorPath to /var/log/privarion/
    - Set ProgramArguments to PrivarionAgent executable path
    - _Requirements: 6.1-6.4_

  - [ ] 16.5 Implement agent logging
    - Log startup, shutdown, and crash events to /var/log/privarion/agent.log
    - Log component initialization success/failure
    - Log permission check results
    - _Requirements: 6.10, 17.2_

  - [ ] 16.6 Implement crash recovery
    - Launch Agent automatically restarts agent within 5 seconds on crash
    - Agent logs crash reason before restart
    - Agent attempts to restore previous state after restart
    - _Requirements: 6.11, 19.8_

  - [ ] 16.7 Write unit tests for Privarion Agent
    - Test permission checking
    - Test component initialization
    - Test status reporting
    - Test graceful shutdown
    - _Requirements: 20.1_

  - [ ] 16.8 Write integration tests for Privarion Agent
    - Test complete startup flow: permission check → extension activation → component initialization
    - Test automatic restart on crash
    - Test permission request flow
    - _Requirements: 20.5_


- [ ] 17. Implement error handling and recovery mechanisms
  - [ ] 17.1 Implement RetryPolicy class
    - Create RetryPolicy with maxAttempts, baseDelay, maxDelay
    - Implement execute(_:) with exponential backoff
    - Apply to ES client initialization (3 attempts, 1s base delay)
    - Apply to Network Extension tunnel start (3 attempts, 2s base delay)
    - Apply to VM creation (2 attempts, 5s base delay)
    - _Requirements: 19.1_

  - [ ] 17.2 Implement CircuitBreaker class
    - Create CircuitBreaker with state (closed, open, halfOpen), failureCount, threshold, timeout
    - Implement execute(_:) with circuit breaker logic
    - Apply to DNS upstream queries (5 failures, 60s timeout)
    - Apply to telemetry database updates (3 failures, 300s timeout)
    - Apply to VM operations (3 failures, 120s timeout)
    - _Requirements: 19.6-19.7_

  - [ ] 17.3 Implement GracefulDegradationManager
    - Track active and degraded components
    - Implement handleComponentFailure(_:error:) to degrade component
    - Implement attemptRecovery(_:) to restore degraded component
    - Log degradation events and notify user
    - Schedule recovery attempts every 60 seconds
    - Continue operation with reduced functionality when components fail
    - _Requirements: 19.2, 19.8_

  - [ ] 17.4 Implement error logging and reporting
    - Create ErrorLogEntry struct with timestamp, component, errorType, message, stackTrace, context, severity
    - Implement ErrorSeverity enum (recoverable, degraded, critical)
    - Log all errors with structured information
    - Create ErrorNotification struct for user notifications with recovery steps
    - _Requirements: 19.9_

  - [ ] 17.5 Implement resource cleanup
    - Create ResourceCleanup protocol with cleanup() method
    - Implement cleanup for NetworkExtension (restore network settings, close connections)
    - Implement cleanup for EndpointSecurity (unsubscribe, release client)
    - Implement cleanup for VMManager (stop VMs, release resources)
    - Ensure cleanup is called on errors and shutdown
    - _Requirements: 19.3, 18.10_

  - [ ] 17.6 Write unit tests for error handling
    - Test retry policy with exponential backoff
    - Test circuit breaker state transitions
    - Test graceful degradation
    - Test resource cleanup
    - _Requirements: 20.1_


- [ ] 18. Implement logging and monitoring system
  - [ ] 18.1 Create logging infrastructure
    - Configure swift-log for structured logging
    - Create log handlers for file output
    - Set up log rotation (daily, 7-day retention)
    - Implement gzip compression for rotated logs
    - Create log directories: /var/log/privarion/
    - _Requirements: 17.1-17.3, 17.8-17.9_

  - [ ] 18.2 Implement component-specific logging
    - System Extension logs to /var/log/privarion/system-extension.log
    - Privarion Agent logs to /var/log/privarion/agent.log
    - Network Extension logs to /var/log/privarion/network-extension.log
    - VM Manager logs to /var/log/privarion/vm-manager.log
    - _Requirements: 17.1-17.3, 17.6_

  - [ ] 18.3 Implement security event logging
    - Log all Security_Event processing with timestamp, process ID, event type, action taken
    - Log all blocked network requests with domain, timestamp, reason
    - Log all VM creation and destruction events
    - _Requirements: 17.4-17.6_

  - [ ] 18.4 Implement log level support
    - Support log levels: debug, info, warning, error, critical
    - Configure log level from configuration file
    - Filter logs based on configured level
    - _Requirements: 17.7_

  - [ ] 18.5 Implement log sanitization
    - Sanitize logs to remove personally identifiable information (PII)
    - Redact file paths containing usernames
    - Redact IP addresses in logs (optional based on configuration)
    - _Requirements: 17.12_

  - [ ] 18.6 Implement log export functionality
    - Create log export command for support requests
    - Bundle all logs into compressed archive
    - Include system information and configuration (sanitized)
    - _Requirements: 17.11_

  - [ ] 18.7 Implement fallback logging
    - When log directory is not writable, fall back to system log (os_log)
    - Log warning about fallback to system log
    - _Requirements: 17.10_

  - [ ] 18.8 Write unit tests for logging system
    - Test log rotation
    - Test log level filtering
    - Test PII sanitization
    - Test fallback logging
    - _Requirements: 20.1_


- [ ] 19. Checkpoint - Verify error handling and logging
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 20. Implement performance monitoring and optimization
  - [ ] 20.1 Implement performance metrics collection
    - Track event processing latency for Endpoint Security (<100ms target)
    - Track packet processing latency for Network Extension (<10ms target)
    - Track DNS query latency (cached <50ms, non-cached <200ms)
    - Track CPU usage (target <5% average)
    - Track memory usage (target <200MB)
    - Track VM resource usage (CPU, memory, disk, network)
    - _Requirements: 18.1-18.7_

  - [ ] 20.2 Implement connection pooling
    - Create connection pool for upstream DNS queries
    - Reuse connections to reduce latency
    - Configure pool size based on load
    - _Requirements: 18.8_

  - [ ] 20.3 Implement caching strategies
    - DNS response caching with TTL (300 seconds)
    - Policy evaluation result caching
    - Blocklist lookup caching
    - Implement cache eviction for memory management
    - _Requirements: 18.9_

  - [ ] 20.4 Implement resource management
    - Release resources promptly when no longer needed
    - Reduce cache size when system memory is low
    - Monitor memory pressure and adjust behavior
    - _Requirements: 18.10-18.11_

  - [ ] 20.5 Create performance metrics dashboard
    - Expose metrics through API for GUI/CLI consumption
    - Include real-time CPU, memory, network usage
    - Include latency percentiles (p50, p95, p99)
    - Include error counts and rates
    - _Requirements: 18.12_

  - [ ] 20.6 Write performance benchmarks
    - Benchmark event processing latency (target <100ms for 95%)
    - Benchmark packet processing latency (target <10ms for 95%)
    - Benchmark DNS query latency (cached <50ms, non-cached <200ms)
    - Run benchmarks as part of test suite
    - _Requirements: 20.9_


- [ ] 21. Integrate with existing CLI (PrivacyCtl)
  - [ ] 21.1 Add extension management commands
    - Add `privacyctl extension install` command to install System Extension
    - Add `privacyctl extension status` command to check extension status
    - Add `privacyctl extension activate` command to activate extension
    - Add `privacyctl extension deactivate` command to deactivate extension
    - _Requirements: 21.1-21.2_

  - [ ] 21.2 Add protection control commands
    - Add `privacyctl protection start` command to start all protection components
    - Add `privacyctl protection stop` command to stop all protection components
    - Add `privacyctl protection status` command to show protection status
    - _Requirements: 21.3-21.4_

  - [ ] 21.3 Add policy management commands
    - Add `privacyctl policy add` command to add protection policy
    - Add `privacyctl policy remove` command to remove policy
    - Add `privacyctl policy list` command to list all policies
    - Add `privacyctl policy show <id>` command to show policy details
    - _Requirements: 21.5_

  - [ ] 21.4 Add blocklist management commands
    - Add `privacyctl blocklist add <domain>` command to add domain to blocklist
    - Add `privacyctl blocklist remove <domain>` command to remove domain
    - Add `privacyctl blocklist list` command to list blocked domains
    - Add `privacyctl blocklist import <file>` command to import blocklist
    - _Requirements: 21.6_

  - [ ] 21.5 Add VM management commands
    - Add `privacyctl vm create <profile>` command to create VM with hardware profile
    - Add `privacyctl vm start <id>` command to start VM
    - Add `privacyctl vm stop <id>` command to stop VM
    - Add `privacyctl vm list` command to list all VMs with status
    - Add `privacyctl vm snapshot <id>` command to create VM snapshot
    - Add `privacyctl vm restore <snapshot-id>` command to restore snapshot
    - _Requirements: 21.7_

  - [ ] 21.6 Add utility commands
    - Add `privacyctl logs show` command to view recent logs with filtering
    - Add `privacyctl logs export` command to export logs for support
    - Add `privacyctl permissions status` command to check all permissions
    - Add `privacyctl metrics show` command to display performance metrics
    - _Requirements: 21.8-21.10_

  - [ ] 21.7 Add JSON output support
    - Add `--format json` flag to all commands for scripting
    - Output structured JSON for machine parsing
    - _Requirements: 21.11_

  - [ ] 21.8 Add shell completion
    - Generate bash completion script
    - Generate zsh completion script
    - Install completion scripts during setup
    - _Requirements: 21.12_

  - [ ] 21.9 Write integration tests for CLI commands
    - Test all extension commands
    - Test all protection commands
    - Test policy and blocklist management
    - Test VM management
    - Test JSON output format
    - _Requirements: 20.1_


- [ ] 22. Integrate with existing GUI (PrivarionGUI)
  - [ ] 22.1 Create System Extension status view
    - Display extension status (active, inactive, error) with visual indicator
    - Add "Install Extension" button that calls SystemExtensionManager
    - Add "Activate Extension" button for installed but inactive extensions
    - Show extension version and installation date
    - _Requirements: 22.1-22.2_

  - [ ] 22.2 Create permissions status view
    - Display status for all required permissions (System Extension, Full Disk Access, Network Extension)
    - Use color-coded indicators (green=granted, yellow=notDetermined, red=denied)
    - Add "Open System Preferences" buttons for each permission
    - Deep link to specific permission panes in System Preferences
    - _Requirements: 22.3-22.4_

  - [ ] 22.3 Create protection policy management view
    - Display list of active Protection_Policy entries in table
    - Add "New Policy" button to open policy creation form
    - Implement policy creation form with fields: identifier, protection level, filtering rules, VM isolation
    - Add edit and delete actions for existing policies
    - Support policy import/export
    - _Requirements: 22.5-22.6_

  - [ ] 22.4 Create network monitoring view
    - Display list of blocked domains with timestamps in scrollable list
    - Add search/filter functionality
    - Show statistics: total blocked requests, top blocked domains
    - Add "Export Logs" button
    - _Requirements: 22.7_

  - [ ] 22.5 Create VM management view
    - Display list of running VMs with resource usage (CPU, memory, network)
    - Show VM status indicators (running, stopped, error)
    - Add controls for starting/stopping VMs
    - Add "Create VM" button to open VM creation dialog
    - Display VM hardware profile information
    - _Requirements: 22.8-22.9_

  - [ ] 22.6 Create performance metrics dashboard
    - Display real-time CPU usage graph
    - Display real-time memory usage graph
    - Display network throughput graph
    - Show event processing latency metrics
    - Show packet processing latency metrics
    - Update metrics every 2 seconds
    - _Requirements: 22.10_

  - [ ] 22.7 Create logs viewer
    - Display recent log entries (last 100) with auto-refresh
    - Add log level filtering (debug, info, warning, error, critical)
    - Add component filtering (System Extension, Agent, Network Extension, VM Manager)
    - Add search functionality
    - Add "Export Logs" button
    - _Requirements: 22.11_

  - [ ] 22.8 Implement dark mode support
    - Ensure all views support dark mode and light mode
    - Use system color scheme
    - Test all views in both modes
    - _Requirements: 22.12_

  - [ ] 22.9 Write UI tests for GUI integration
    - Test extension installation flow
    - Test permission request flow
    - Test policy creation and management
    - Test VM creation and management
    - _Requirements: 20.1_


- [ ] 23. Checkpoint - Verify CLI and GUI integration
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 24. Implement migration from current implementation
  - [ ] 24.1 Create migration detection
    - Detect existing Privarion configuration in ~/.privarion/
    - Check for existing identity profiles
    - Check for existing network rules
    - Check for existing blocklists
    - _Requirements: 23.1_

  - [ ] 24.2 Implement identity profile migration
    - Parse existing identity profiles from old format
    - Convert to HardwareProfile format with UUID and metadata
    - Validate migrated profiles
    - Save to /Library/Application Support/Privarion/profiles.json
    - _Requirements: 23.2_

  - [ ] 24.3 Implement network rules migration
    - Parse existing network rules from old format
    - Convert to ProtectionPolicy format
    - Map old protection levels to new protection levels
    - Save to configuration file
    - _Requirements: 23.3_

  - [ ] 24.4 Implement blocklist migration
    - Parse existing blocklists from old format
    - Convert to new blocklist format (tracking domains, fingerprinting domains, telemetry endpoints)
    - Merge with default blocklists
    - Save to configuration file
    - _Requirements: 23.4_

  - [ ] 24.5 Implement migration backup
    - Backup old configuration to ~/.privarion/backup/ before migration
    - Include timestamp in backup directory name
    - Preserve original configuration for rollback
    - _Requirements: 23.5_

  - [ ] 24.6 Implement migration validation
    - Validate migrated configuration before activation
    - Check for missing required fields
    - Check for invalid values
    - Report validation errors to user
    - _Requirements: 23.6_

  - [ ] 24.7 Implement migration error handling
    - When migration fails, preserve original configuration
    - Log detailed error information
    - Provide rollback option to user
    - _Requirements: 23.7, 23.9_

  - [ ] 24.8 Create migration status report
    - Show number of migrated profiles, policies, blocklist entries
    - Show any items that failed to migrate
    - Display report in GUI and CLI
    - _Requirements: 23.8_

  - [ ] 24.9 Write integration tests for migration
    - Test migration with various old configuration formats
    - Test migration validation
    - Test migration error handling
    - Test rollback functionality
    - _Requirements: 20.6_


- [ ] 25. Implement entitlements and provisioning
  - [ ] 25.1 Create entitlements files
    - Create SystemExtension.entitlements with com.apple.developer.system-extension.install
    - Add com.apple.developer.endpoint-security.client entitlement
    - Add com.apple.security.files.user-selected.read-write for Full Disk Access
    - Create NetworkExtension.entitlements with com.apple.developer.networking.networkextension (packet-tunnel-provider, content-filter-provider)
    - Create VMManager.entitlements with com.apple.security.virtualization
    - _Requirements: 12.1-12.6_

  - [ ] 25.2 Configure code signing
    - Configure signing with Developer ID certificate
    - Set up provisioning profiles for each target
    - Enable hardened runtime for all targets
    - _Requirements: 12.7-12.8, 13.1_

  - [ ] 25.3 Implement entitlement validation
    - Validate entitlements during System Extension installation
    - Return descriptive error when entitlement is missing
    - Log entitlement validation results
    - _Requirements: 12.9-12.10_

  - [ ] 25.4 Write tests for entitlement validation
    - Test validation with all required entitlements
    - Test validation with missing entitlements
    - Test error messages
    - _Requirements: 20.1_


- [ ] 26. Implement notarization and distribution
  - [ ] 26.1 Configure build for notarization
    - Enable hardened runtime for all targets
    - Configure code signing with Developer ID Application certificate
    - Set up build settings for notarization compatibility
    - _Requirements: 13.1-13.2_

  - [ ] 26.2 Create distribution package
    - Package application in DMG or ZIP format
    - Include installer script for Launch Agent setup
    - Include README with installation instructions
    - _Requirements: 13.3_

  - [ ] 26.3 Implement notarization workflow
    - Create script to submit package to Apple notarization service
    - Use `xcrun notarytool submit` for notarization
    - Poll for notarization completion
    - Download notarization log on failure
    - _Requirements: 13.4-13.6_

  - [ ] 26.4 Implement notarization ticket stapling
    - Staple notarization ticket to application using `xcrun stapler`
    - Verify stapling success
    - _Requirements: 13.5_

  - [ ] 26.5 Verify Gatekeeper compatibility
    - Test application launch on clean macOS installation
    - Verify no Gatekeeper warnings appear
    - Verify developer signature is displayed in System Preferences
    - _Requirements: 13.7-13.8_

  - [ ] 26.6 Document distribution process
    - Document notarization steps
    - Document App Store distribution requirements (if applicable)
    - Document troubleshooting for notarization failures
    - _Requirements: 13.9-13.10_


- [ ] 27. Implement comprehensive testing suite
  - [ ] 27.1 Create test infrastructure
    - Set up XCTest framework for all modules
    - Create mock objects for external dependencies (ES client, VZVirtualMachine, NEPacketTunnelProvider)
    - Set up test fixtures and sample data
    - Configure test coverage reporting
    - _Requirements: 20.1_

  - [ ] 27.2 Implement unit test suites
    - Unit tests for all data models (already marked in previous tasks)
    - Unit tests for configuration management (already marked)
    - Unit tests for policy engine (already marked)
    - Unit tests for all managers (already marked)
    - Target 80% code coverage minimum
    - _Requirements: 20.1, 20.10_

  - [ ] 27.3 Implement property-based tests
    - Configuration round-trip test (already marked in task 3.5)
    - DNS filtering idempotence test (already marked in task 8.6)
    - Use swift-check library with minimum 100 iterations
    - _Requirements: 20.11-20.12_

  - [ ] 27.4 Implement integration test suites
    - Endpoint Security integration tests (already marked)
    - Network Extension integration tests (already marked)
    - VM Manager integration tests (already marked)
    - Privarion Agent integration tests (already marked)
    - Migration integration tests (already marked)
    - _Requirements: 20.2-20.5_

  - [ ] 27.5 Implement end-to-end tests
    - Test complete protection workflow: install extension → activate → protect application
    - Test permission request flow: check permissions → request → verify grant
    - Test VM isolation flow: create VM → install app → execute → verify hardware
    - Test network filtering flow: make request → intercept → filter → verify block
    - _Requirements: 20.5_

  - [ ] 27.6 Implement compatibility tests
    - Test on macOS 13.0 (Ventura)
    - Test on macOS 14.0 (Sonoma)
    - Test on macOS 15.0 (Sequoia)
    - Test with various network configurations (Wi-Fi, Ethernet, USB tethering, VPN active)
    - Test with multiple network interfaces
    - _Requirements: 20.6-20.7_

  - [ ] 27.7 Implement application compatibility tests
    - Test with Safari
    - Test with Chrome
    - Test with Firefox
    - Test with native macOS apps (Mail, Messages, Calendar)
    - Test with third-party apps
    - _Requirements: 20.8_

  - [ ] 27.8 Implement performance benchmarks
    - Benchmark event processing latency (already marked in task 20.6)
    - Benchmark packet processing latency (already marked)
    - Benchmark DNS query latency (already marked)
    - Run benchmarks as part of CI/CD pipeline
    - _Requirements: 20.9_


- [ ] 28. Create comprehensive documentation
  - [ ] 28.1 Write installation guide
    - Document system requirements (macOS 13.0+, Apple Developer Program)
    - Provide step-by-step installation instructions with screenshots
    - Document entitlement requirements
    - Document code signing and notarization process
    - _Requirements: 24.1_

  - [ ] 28.2 Write permission setup guide
    - Document all required permissions (System Extension, Full Disk Access, Network Extension)
    - Provide step-by-step permission grant instructions with screenshots
    - Document how to verify permission status
    - Document troubleshooting for permission issues
    - _Requirements: 24.2_

  - [ ] 28.3 Write configuration guide
    - Document configuration file format and location
    - Provide example configurations for common use cases
    - Document all configuration options with descriptions
    - Document policy configuration with examples
    - Document hardware profile configuration
    - Document blocklist configuration
    - _Requirements: 24.3_

  - [ ] 28.4 Write troubleshooting guide
    - Document common issues and solutions
    - Document error messages and their meanings
    - Document how to collect logs for support
    - Document how to verify component status
    - Document recovery procedures for component failures
    - _Requirements: 24.4_

  - [ ] 28.5 Write API documentation
    - Document all public interfaces with Swift DocC
    - Include code examples for each API
    - Document parameters, return values, and errors
    - Generate API reference documentation
    - _Requirements: 24.5_

  - [ ] 28.6 Write architecture documentation
    - Document system architecture with diagrams
    - Document component interactions and data flows
    - Document design decisions and rationale
    - Document extension points for customization
    - _Requirements: 24.6_

  - [ ] 28.7 Write security documentation
    - Document protection mechanisms (Endpoint Security, Network Extensions, VM isolation)
    - Document threat model and security boundaries
    - Document privacy guarantees
    - Document limitations and known issues
    - _Requirements: 24.7_

  - [ ] 28.8 Write performance tuning guide
    - Document performance characteristics and targets
    - Document configuration options for performance tuning
    - Document resource limits and how to adjust them
    - Document monitoring and profiling techniques
    - _Requirements: 24.8_

  - [ ] 28.9 Write CLI reference
    - Document all CLI commands with syntax and examples
    - Document all command options and flags
    - Document output formats (text, JSON)
    - Document shell completion setup
    - _Requirements: 24.9_

  - [ ] 28.10 Write FAQ
    - Document answers to common questions
    - Document comparison with current implementation
    - Document migration process
    - Document App Store distribution considerations
    - _Requirements: 24.10_

  - [ ] 28.11 Write migration guide
    - Document migration process from old implementation
    - Document what gets migrated and what doesn't
    - Document rollback procedure
    - Document testing migration before committing
    - _Requirements: 23.10_

  - [ ] 28.12 Ensure documentation quality
    - Write all documentation in English
    - Keep documentation synchronized with code changes
    - Review documentation for accuracy and completeness
    - Add table of contents and navigation
    - _Requirements: 24.11-24.12_


- [ ] 29. Final integration and wiring
  - [ ] 29.1 Wire System Extension components together
    - Connect SystemExtensionManager with PrivarionAgent
    - Connect EndpointSecurityManager with ProtectionPolicyEngine
    - Connect EndpointSecurityManager with VMManager for VM isolation
    - Set up XPC communication between extension and agent
    - _Requirements: 1.7, 2.6-2.7, 11.7_

  - [ ] 29.2 Wire Network Extension components together
    - Connect PacketTunnelProvider with DNSFilter
    - Connect PacketTunnelProvider with TelemetryBlocker
    - Connect ContentFilterProvider with ProtectionPolicyEngine
    - Connect all network components with TransparentProxyCoordinator
    - _Requirements: 3.6-3.8, 5.2-5.8_

  - [ ] 29.3 Wire VM components together
    - Connect VMManager with HardwareProfileManager
    - Connect VMManager with ProtectionPolicyEngine for VM isolation decisions
    - Connect VMManager with EndpointSecurityManager for process launch interception
    - _Requirements: 8.11, 11.6_

  - [ ] 29.4 Wire Agent with all components
    - Connect PrivarionAgent with SystemExtensionManager
    - Connect PrivarionAgent with EndpointSecurityManager
    - Connect PrivarionAgent with NetworkExtensionCoordinator
    - Connect PrivarionAgent with VMManager
    - Connect PrivarionAgent with ConfigurationManager
    - Connect PrivarionAgent with PermissionManager
    - _Requirements: 6.5-6.7_

  - [ ] 29.5 Wire CLI with backend services
    - Connect all CLI commands with PrivarionAgent via XPC
    - Implement command handlers for extension, protection, policy, blocklist, VM, logs, permissions, metrics commands
    - Handle errors and display user-friendly messages
    - _Requirements: 21.1-21.12_

  - [ ] 29.6 Wire GUI with backend services
    - Connect all GUI views with PrivarionAgent via XPC or direct API calls
    - Implement view models for all views (MVVM pattern)
    - Set up reactive bindings for real-time updates
    - Handle errors and display user-friendly alerts
    - _Requirements: 22.1-22.12_

  - [ ] 29.7 Implement XPC service for inter-process communication
    - Create XPC service interface for agent communication
    - Implement XPC connection management with reconnection logic
    - Implement security validation for XPC connections
    - Handle XPC errors gracefully
    - _Requirements: 6.5_

  - [ ] 29.8 Write integration tests for complete system
    - Test end-to-end flow: install → activate → configure → protect
    - Test all component interactions
    - Test error propagation across components
    - Test graceful degradation when components fail
    - _Requirements: 20.5_


- [ ] 30. Final checkpoint - Complete system validation
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 31. Prepare for production deployment
  - [ ] 31.1 Verify all entitlements are configured
    - Check SystemExtension.entitlements
    - Check NetworkExtension.entitlements
    - Check VMManager.entitlements
    - Verify code signing configuration
    - _Requirements: 12.1-12.10_

  - [ ] 31.2 Verify notarization readiness
    - Verify hardened runtime is enabled
    - Verify Developer ID certificate is configured
    - Test notarization workflow with test build
    - Verify Gatekeeper compatibility
    - _Requirements: 13.1-13.10_

  - [ ] 31.3 Create default configuration files
    - Create default config.json with sensible defaults
    - Create default policies.json with common application policies
    - Create default profiles.json with predefined hardware profiles
    - Create default blocklists.json with known tracking/fingerprinting domains
    - _Requirements: 15.7_

  - [ ] 31.4 Create installation package
    - Package application in DMG with installer
    - Include Launch Agent plist
    - Include installation script for directory setup
    - Include README and license
    - _Requirements: 13.3_

  - [ ] 31.5 Verify logging infrastructure
    - Verify log directories are created on first run
    - Verify log rotation is working
    - Verify log sanitization is working
    - Test log export functionality
    - _Requirements: 17.1-17.12_

  - [ ] 31.6 Verify performance targets
    - Run performance benchmarks
    - Verify event processing latency <100ms for 95%
    - Verify packet processing latency <10ms for 95%
    - Verify DNS query latency targets
    - Verify CPU usage <5% average
    - Verify memory usage <200MB
    - _Requirements: 18.1-18.7_

  - [ ] 31.7 Create release checklist
    - Document pre-release verification steps
    - Document release process
    - Document rollback procedure
    - Document post-release monitoring
    - _Requirements: 24.4_


## Notes

- Tasks marked with `*` are optional testing tasks and can be skipped for faster MVP delivery
- Each task references specific requirements for traceability
- Checkpoints ensure incremental validation at key milestones
- Property tests validate universal correctness properties (configuration round-trip, DNS filtering idempotence)
- Unit tests validate specific examples and edge cases
- Integration tests validate component interactions
- End-to-end tests validate complete workflows
- The implementation follows existing Privarion conventions: XCTest with mocks, custom error enums, no `try?` silently
- All new code integrates with existing PrivarionCore, PrivacyCtl, and PrivarionGUI modules
- Performance targets are enforced through benchmarks: <100ms event processing, <10ms packet processing, <5% CPU, <200MB memory
- Security is paramount: proper entitlements, code signing, notarization, and permission management
- The system supports graceful degradation: components can fail independently without bringing down the entire system

## Implementation Dependencies

The tasks are ordered to minimize dependencies and enable parallel work where possible:

1. Tasks 1-4: Foundation (data models, configuration, policy engine) - can be done in parallel
2. Tasks 5-6: System Extension and Endpoint Security - depends on tasks 1-4
3. Tasks 8-11: Network protection (DNS, packet tunnel, content filter, telemetry) - depends on tasks 1-4
4. Tasks 13-14: VM and hardware profiles - depends on tasks 1-4
5. Task 15: Transparent proxy - depends on tasks 8-11
6. Task 16: Privarion Agent - depends on tasks 5-6, 8-11, 13-14
7. Tasks 17-18: Error handling and logging - can be done in parallel with other tasks
8. Task 20: Performance monitoring - depends on all core components
9. Tasks 21-22: CLI and GUI integration - depends on task 16
10. Task 24: Migration - depends on tasks 1-4
11. Tasks 25-26: Entitlements and notarization - can be done in parallel with implementation
12. Task 27: Testing - ongoing throughout implementation
13. Task 28: Documentation - ongoing throughout implementation
14. Task 29: Final integration - depends on all component tasks
15. Task 31: Production preparation - depends on all tasks

## Success Criteria

The implementation is complete when:

1. All non-optional tasks are completed
2. All unit tests pass with 80%+ code coverage
3. All integration tests pass
4. Performance benchmarks meet targets
5. System Extension installs and activates successfully
6. Endpoint Security monitors system-wide events
7. Network Extension filters traffic system-wide
8. VM Manager creates isolated environments with custom hardware IDs
9. CLI commands work for all operations
10. GUI displays all status and controls
11. Migration from old implementation works
12. Application is notarized and passes Gatekeeper
13. Documentation is complete and accurate
14. All 24 requirements are satisfied

