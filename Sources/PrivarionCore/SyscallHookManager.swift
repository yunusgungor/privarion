import PrivarionHook
import Foundation
import Logging

// MARK: - Global State for Hook Functions

/// Thread-safe global state for hook functions to access fake data
/// Since C function pointers cannot capture context, we need global state
internal final class SyscallHookGlobalState {
    static let shared = SyscallHookGlobalState()
    
    private let lock = NSLock()
    private var _fakeData: FakeDataDefinitions?
    
    private init() {}
    
    func updateConfiguration(_ fakeData: FakeDataDefinitions) {
        lock.lock()
        defer { lock.unlock() }
        _fakeData = fakeData
    }
    
    func getFakeData() -> FakeDataDefinitions? {
        lock.lock()
        defer { lock.unlock() }
        return _fakeData
    }
}

// MARK: - C-Compatible Hook Functions

/// C-compatible uname hook function
@_cdecl("hooked_uname")
func hooked_uname(_ unamePtr: UnsafeMutablePointer<utsname>) -> Int32 {
    guard let fakeData = SyscallHookGlobalState.shared.getFakeData() else {
        // Fallback to original if no fake data available
        return -1
    }
    
    let fakeInfo = fakeData.systemInfo
    
    // Zero out the structure
    memset(unamePtr, 0, MemoryLayout<utsname>.size)
    
    // Copy fake data to the structure
    _ = withUnsafeMutablePointer(to: &unamePtr.pointee.sysname) { ptr in
        fakeInfo.sysname.withCString { cStr in
            strncpy(UnsafeMutableRawPointer(ptr).assumingMemoryBound(to: CChar.self), cStr, 255)
        }
    }
    
    _ = withUnsafeMutablePointer(to: &unamePtr.pointee.nodename) { ptr in
        fakeInfo.nodename.withCString { cStr in
            strncpy(UnsafeMutableRawPointer(ptr).assumingMemoryBound(to: CChar.self), cStr, 255)
        }
    }
    
    _ = withUnsafeMutablePointer(to: &unamePtr.pointee.release) { ptr in
        fakeInfo.release.withCString { cStr in
            strncpy(UnsafeMutableRawPointer(ptr).assumingMemoryBound(to: CChar.self), cStr, 255)
        }
    }
    
    _ = withUnsafeMutablePointer(to: &unamePtr.pointee.version) { ptr in
        fakeInfo.version.withCString { cStr in
            strncpy(UnsafeMutableRawPointer(ptr).assumingMemoryBound(to: CChar.self), cStr, 255)
        }
    }
    
    _ = withUnsafeMutablePointer(to: &unamePtr.pointee.machine) { ptr in
        fakeInfo.machine.withCString { cStr in
            strncpy(UnsafeMutableRawPointer(ptr).assumingMemoryBound(to: CChar.self), cStr, 255)
        }
    }
    
    return 0 // Success
}

/// C-compatible gethostname hook function
@_cdecl("hooked_gethostname")
func hooked_gethostname(_ buffer: UnsafeMutablePointer<CChar>, _ size: Int32) -> Int32 {
    guard let fakeData = SyscallHookGlobalState.shared.getFakeData() else {
        return -1
    }
    
    let fakeHostname = fakeData.hostname
    let maxSize = min(Int(size), fakeHostname.count + 1)
    
    fakeHostname.withCString { cStr in
        strncpy(buffer, cStr, maxSize - 1)
        buffer[maxSize - 1] = 0 // Null terminate
    }
    
    return 0 // Success
}

/// C-compatible getuid hook function
@_cdecl("hooked_getuid")
func hooked_getuid() -> uid_t {
    guard let fakeData = SyscallHookGlobalState.shared.getFakeData() else {
        return 0 // Fallback UID
    }
    
    return uid_t(fakeData.userId)
}

/// C-compatible getgid hook function
@_cdecl("hooked_getgid")
func hooked_getgid() -> gid_t {
    guard let fakeData = SyscallHookGlobalState.shared.getFakeData() else {
        return 0 // Fallback GID
    }
    
    return gid_t(fakeData.groupId)
}

/// Swift wrapper for the Privarion Hook System
/// Provides type-safe interface to the underlying C hook library
public final class SyscallHookManager {
    
    // MARK: - Types
    
    /// Errors that can occur during hook operations
    public enum HookError: Error, LocalizedError {
        case invalidParameter
        case functionNotFound(String)
        case alreadyHooked(String)
        case notHooked(String)
        case memoryError
        case permissionDenied
        case unsupportedPlatform
        case systemNotInitialized
        case configurationNotSet
        case unsupportedOperation
        case unknownError(Int32)
        
        public var errorDescription: String? {
            switch self {
            case .invalidParameter:
                return "Invalid parameter provided"
            case .functionNotFound(let name):
                return "Function '\(name)' not found"
            case .alreadyHooked(let name):
                return "Function '\(name)' is already hooked"
            case .notHooked(let name):
                return "Function '\(name)' is not hooked"
            case .memoryError:
                return "Memory allocation error"
            case .permissionDenied:
                return "Permission denied"
            case .unsupportedPlatform:
                return "Platform not supported"
            case .systemNotInitialized:
                return "Hook system not initialized"
            case .configurationNotSet:
                return "Hook configuration not set"
            case .unsupportedOperation:
                return "Unsupported operation"
            case .unknownError(let code):
                return "Unknown error (code: \(code))"
            }
        }
    }
    
    /// Represents a system call that can be hooked
    public enum SyscallFunction: String, CaseIterable {
        case uname = "uname"
        case gethostname = "gethostname"
        case getuid = "getuid"
        case getgid = "getgid"
        
        public var description: String {
            switch self {
            case .uname:
                return "System information (uname)"
            case .gethostname:
                return "Hostname (gethostname)"
            case .getuid:
                return "User ID (getuid)"
            case .getgid:
                return "Group ID (getgid)"
            }
        }
    }
    
    /// Handle for managing individual hooks
    public struct HookHandle {
        let rawHandle: PHookHandle
        public let functionName: String
        public let id: UInt32
        
        internal init(rawHandle: PHookHandle) {
            self.rawHandle = rawHandle
            self.functionName = withUnsafePointer(to: rawHandle.function_name) { ptr in
                String(cString: UnsafeRawPointer(ptr).assumingMemoryBound(to: CChar.self))
            }
            self.id = rawHandle.id
        }
        
        public var isValid: Bool {
            return rawHandle.is_valid
        }
    }
    
    // MARK: - Properties
    
    private static var _shared: SyscallHookManager?
    private static let lock = NSLock()
    
    public static var shared: SyscallHookManager {
        lock.lock()
        defer { lock.unlock() }
        
        if let existing = _shared {
            return existing
        }
        
        let manager = SyscallHookManager()
        _shared = manager
        return manager
    }
    
    private let logger: Logger
    private var isInitialized = false
    private let initializationLock = NSLock()
    private let configurationManager: SyscallHookConfigurationManager
    
    /// Current hook configuration (computed property)
    private var currentHookConfig: SyscallHookConfiguration? {
        return try? configurationManager.loadConfiguration()
    }
    
    // MARK: - Initialization
    
    private init() {
        self.logger = Logger(label: "com.privarion.syscall-hook-manager")
        self.configurationManager = SyscallHookConfigurationManager(configurationManager: ConfigurationManager.shared)
    }
    
    deinit {
        cleanup()
    }
    
    // MARK: - Public Interface
    
    /// Initialize the hook system
    /// Must be called before any hook operations
    public func initialize() throws {
        initializationLock.lock()
        defer { initializationLock.unlock() }
        
        guard !isInitialized else {
            logger.info("Hook system already initialized")
            return
        }
        
        logger.info("Initializing Privarion Hook System")
        
        let result = ph_initialize()
        try self.throwIfError(result)
        
        isInitialized = true
        logger.info("Hook system initialized successfully")
    }
    
    /// Cleanup and shutdown the hook system
    public func cleanup() {
        initializationLock.lock()
        defer { initializationLock.unlock() }
        
        guard isInitialized else { return }
        
        logger.info("Cleaning up hook system")
        ph_cleanup()
        isInitialized = false
        logger.info("Hook system cleanup completed")
    }
    
    /// Install a hook for a specific system call (Deprecated - use configuration-driven approach)
    private func installHook<T>(
        for function: SyscallFunction,
        replacement: T
    ) throws -> HookHandle {
        try ensureInitialized()
        
        logger.debug("Installing hook for function: \(function.rawValue)")
        
        // NOTE: This method is deprecated due to unsafeBitCast issues with Swift function to C function pointer conversion
        // Use configuration-driven approach instead
        throw HookError.unsupportedOperation
    }
    
    /// Install hooks based on current configuration
    public func installConfiguredHooks() throws -> [String: HookHandle] {
        try ensureInitialized()
        
        guard let hookConfig = currentHookConfig else {
            throw HookError.configurationNotSet
        }
        
        logger.info("Installing hooks based on configuration - getuid: \(hookConfig.hooks.getuid), getgid: \(hookConfig.hooks.getgid), gethostname: \(hookConfig.hooks.gethostname), uname: \(hookConfig.hooks.uname)")
        
        var installedHooks: [String: HookHandle] = [:]
        
        // Prepare configuration data for C layer
        var configData = PHookConfigData()
        configData.user_id = uid_t(hookConfig.fakeData.userId)
        configData.group_id = gid_t(hookConfig.fakeData.groupId)
        
        // Convert String to C string for hostname
        hookConfig.fakeData.hostname.withCString { hostnamePtr in
            strncpy(&configData.hostname.0, hostnamePtr, 255)
            configData.hostname.255 = 0 // Ensure null termination
        }
        
        // Convert system info to C strings
        hookConfig.fakeData.systemInfo.sysname.withCString { systemPtr in
            strncpy(&configData.system_name.0, systemPtr, 255)
            configData.system_name.255 = 0
        }
        
        hookConfig.fakeData.systemInfo.machine.withCString { machinePtr in
            strncpy(&configData.machine.0, machinePtr, 255)
            configData.machine.255 = 0
        }
        
        hookConfig.fakeData.systemInfo.release.withCString { releasePtr in
            strncpy(&configData.release.0, releasePtr, 255)
            configData.release.255 = 0
        }
        
        hookConfig.fakeData.systemInfo.version.withCString { versionPtr in
            strncpy(&configData.version.0, versionPtr, 511)
            configData.version.511 = 0
        }
        
        // Install hooks based on configuration
        if hookConfig.hooks.getuid {
            var handle = PHookHandle()
            let result = ph_install_getuid_hook(&configData, &handle)
            try throwIfError(result)
            installedHooks["getuid"] = HookHandle(rawHandle: handle)
            logger.debug("Installed getuid hook with fake UID: \(hookConfig.fakeData.userId)")
        }
        
        if hookConfig.hooks.getgid {
            var handle = PHookHandle()
            let result = ph_install_getgid_hook(&configData, &handle)
            try throwIfError(result)
            installedHooks["getgid"] = HookHandle(rawHandle: handle)
            logger.debug("Installed getgid hook with fake GID: \(hookConfig.fakeData.groupId)")
        }
        
        if hookConfig.hooks.gethostname {
            var handle = PHookHandle()
            let result = ph_install_gethostname_hook(&configData, &handle)
            try throwIfError(result)
            installedHooks["gethostname"] = HookHandle(rawHandle: handle)
            logger.debug("Installed gethostname hook with fake hostname: \(hookConfig.fakeData.hostname)")
        }
        
        if hookConfig.hooks.uname {
            var handle = PHookHandle()
            let result = ph_install_uname_hook(&configData, &handle)
            try throwIfError(result)
            installedHooks["uname"] = HookHandle(rawHandle: handle)
            logger.debug("Installed uname hook with fake system info")
        }
        
        logger.info("Hook installation completed - total hooks: \(installedHooks.count)")
        
        return installedHooks
    }
    
    /// Remove a previously installed hook
    public func removeHook(_ handle: HookHandle) throws {
        try ensureInitialized()
        
        logger.debug("Removing hook for function: \(handle.functionName)")
        
        var mutableHandle = handle.rawHandle
        let result = ph_remove_hook(&mutableHandle)
        try throwIfError(result)
        
        logger.info("Hook removed successfully for \(handle.functionName)")
    }
    
    /// Remove all installed hooks
    public func removeAllHooks() throws {
        try ensureInitialized()
        
        logger.debug("Removing all installed hooks")
        
        ph_cleanup()
        
        logger.info("All hooks removed successfully")
    }
    
    /// Get pointer to original function
    public func getOriginalFunction<T>(_ handle: HookHandle, as type: T.Type) -> T? {
        var mutableHandle = handle.rawHandle
        guard let originalPtr = ph_get_original(&mutableHandle) else {
            return nil
        }
        
        return unsafeBitCast(originalPtr, to: type)
    }
    
    /// Check if a function is currently hooked
    public func isHooked(_ function: SyscallFunction) -> Bool {
        return function.rawValue.withCString { namePtr in
            ph_is_hooked(namePtr)
        }
    }
    
    /// Get the number of currently active hooks
    public var activeHookCount: UInt32 {
        return ph_get_active_hook_count()
    }
    
    /// Get list of all active hook function names
    public var activeHooks: [String] {
        let bufferSize = 4096
        let buffer = UnsafeMutablePointer<CChar>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }
        
        let count = ph_get_active_hooks(buffer, bufferSize)
        
        var hooks: [String] = []
        var offset = 0
        
        for _ in 0..<count {
            let functionName = String(cString: buffer + offset)
            hooks.append(functionName)
            offset += functionName.count + 1
        }
        
        return hooks
    }
    
    /// Enable or disable debug logging
    public func setDebugLogging(enabled: Bool) {
        ph_set_debug_logging(enabled)
        logger.info("Debug logging \(enabled ? "enabled" : "disabled")")
    }
    
    /// Get version information
    public var version: String {
        return String(cString: ph_get_version())
    }
    
    /// Check if the current platform is supported
    public var isPlatformSupported: Bool {
        return ph_is_platform_supported()
    }
    
    // MARK: - Configuration Management
    
    /// Get current hook configuration
    public var hookConfiguration: SyscallHookConfiguration? {
        return try? configurationManager.loadConfiguration()
    }
    
    /// Update hook configuration
    public func updateConfiguration(_ config: SyscallHookConfiguration) throws {
        try ensureInitialized()
        try configurationManager.validateConfiguration(config)
        try configurationManager.saveConfiguration(config)
        logger.info("Hook configuration updated")
    }
    
    /// Install hooks based on current configuration
    public func installConfiguredHooks(for bundleId: String? = nil) throws -> [String: HookHandle] {
        try ensureInitialized()
        
        let config = try configurationManager.loadConfiguration()
        let rules = try configurationManager.getEffectiveRules(for: bundleId)
        
        var installedHooks: [String: HookHandle] = [:]
        
        logger.info("Installing hooks based on configuration for bundleId: \(bundleId ?? "global") - uname: \(rules.uname), gethostname: \(rules.gethostname), getuid: \(rules.getuid), getgid: \(rules.getgid)")
        
        // Store fake data globally for C functions to access
        SyscallHookGlobalState.shared.updateConfiguration(config.fakeData)
        
        // Install uname hook if enabled
        if rules.uname {
            let handle = try installHook(for: .uname, replacement: hooked_uname)
            installedHooks["uname"] = handle
        }
        
        // Install gethostname hook if enabled
        if rules.gethostname {
            let handle = try installHook(for: .gethostname, replacement: hooked_gethostname)
            installedHooks["gethostname"] = handle
        }
        
        // Install getuid hook if enabled
        if rules.getuid {
            let handle = try installHook(for: .getuid, replacement: hooked_getuid)
            installedHooks["getuid"] = handle
        }
        
        // Install getgid hook if enabled
        if rules.getgid {
            let handle = try installHook(for: .getgid, replacement: hooked_getgid)
            installedHooks["getgid"] = handle
        }
        
        logger.info("Installed \(installedHooks.count) hooks successfully")
        return installedHooks
    }
     // MARK: - Mock Implementations (Deprecated - kept for reference)

    private func mockUname(_ unamePtr: UnsafeMutablePointer<utsname>, fakeInfo: FakeSystemInfo) -> Int32 {
        logger.debug("Intercepted uname() call - returning fake system info")
        
        // Zero out the structure
        memset(unamePtr, 0, MemoryLayout<utsname>.size)
        
        // Copy fake data to the structure
        _ = withUnsafeMutablePointer(to: &unamePtr.pointee.sysname) { ptr in
            fakeInfo.sysname.withCString { cStr in
                strncpy(UnsafeMutableRawPointer(ptr).assumingMemoryBound(to: CChar.self), cStr, 255)
            }
        }
        
        _ = withUnsafeMutablePointer(to: &unamePtr.pointee.nodename) { ptr in
            fakeInfo.nodename.withCString { cStr in
                strncpy(UnsafeMutableRawPointer(ptr).assumingMemoryBound(to: CChar.self), cStr, 255)
            }
        }
        
        _ = withUnsafeMutablePointer(to: &unamePtr.pointee.release) { ptr in
            fakeInfo.release.withCString { cStr in
                strncpy(UnsafeMutableRawPointer(ptr).assumingMemoryBound(to: CChar.self), cStr, 255)
            }
        }
        
        _ = withUnsafeMutablePointer(to: &unamePtr.pointee.version) { ptr in
            fakeInfo.version.withCString { cStr in
                strncpy(UnsafeMutableRawPointer(ptr).assumingMemoryBound(to: CChar.self), cStr, 255)
            }
        }
        
        _ = withUnsafeMutablePointer(to: &unamePtr.pointee.machine) { ptr in
            fakeInfo.machine.withCString { cStr in
                strncpy(UnsafeMutableRawPointer(ptr).assumingMemoryBound(to: CChar.self), cStr, 255)
            }
        }
        
        return 0 // Success
    }
    
    private func mockGethostname(_ buffer: UnsafeMutablePointer<CChar>, size: Int32, fakeHostname: String) -> Int32 {
        logger.debug("Intercepted gethostname() call - returning fake hostname: \(fakeHostname)")
        
        let maxSize = min(Int(size), fakeHostname.count + 1)
        fakeHostname.withCString { cStr in
            strncpy(buffer, cStr, maxSize - 1)
            buffer[maxSize - 1] = 0 // Null terminate
        }
        
        return 0 // Success
    }
    
    private func mockGetuid(fakeUid: UInt32) -> uid_t {
        logger.debug("Intercepted getuid() call - returning fake UID: \(fakeUid)")
        
        return uid_t(fakeUid)
    }
    
    private func mockGetgid(fakeGid: UInt32) -> gid_t {
        logger.debug("Intercepted getgid() call - returning fake GID: \(fakeGid)")
        
        return gid_t(fakeGid)
    }
    
    // MARK: - Private Helpers
    
    private func ensureInitialized() throws {
        guard isInitialized else {
            throw HookError.systemNotInitialized
        }
    }
    
    private func throwIfError(_ result: PHResult) throws {
        guard result == PH_SUCCESS else {
            throw HookError.fromPHResult(result)
        }
    }
}

// MARK: - Error Conversion

private extension SyscallHookManager.HookError {
    static func fromPHResult(_ result: PHResult) -> SyscallHookManager.HookError {
        switch result {
        case PH_ERROR_INVALID_PARAM:
            return .invalidParameter
        case PH_ERROR_FUNCTION_NOT_FOUND:
            return .functionNotFound("unknown")
        case PH_ERROR_ALREADY_HOOKED:
            return .alreadyHooked("unknown")
        case PH_ERROR_NOT_HOOKED:
            return .notHooked("unknown")
        case PH_ERROR_MEMORY_ERROR:
            return .memoryError
        case PH_ERROR_PERMISSION_DENIED:
            return .permissionDenied
        case PH_ERROR_UNSUPPORTED_PLATFORM:
            return .unsupportedPlatform
        default:
            return .unknownError(result.rawValue)
        }
    }
}

// MARK: - DYLD Injection Support

/// DYLD Injection Manager Integration
/// Provides complete syscall hook functionality with DYLD injection
public class SyscallHookWithInjection {
    private let hookManager: SyscallHookManager
    private let dyldManager: DYLDInjectionManager
    private let logger = Logger(label: "SyscallHookWithInjection")
    
    public init(configuration: ConfigurationManager) {
        self.hookManager = SyscallHookManager.shared // Use singleton instance
        self.dyldManager = DYLDInjectionManager(configuration: configuration)
    }
    
    /// Launch application with syscall hooks injected via DYLD
    /// This is the main entry point for STORY-2025-002 AC001
    public func launchApplicationWithHooks(
        applicationPath: String,
        arguments: [String] = [],
        environment: [String: String] = [:]
    ) -> DYLDInjectionResult {
        
        logger.info("Launching application with syscall hooks: \(applicationPath)")
        
        // First initialize the hook system
        do {
            try hookManager.initialize()
            
            // Apply configured hooks based on current profile
            _ = try hookManager.installConfiguredHooks()
            
            logger.debug("Hook system initialized and configured")
            
        } catch {
            logger.error("Failed to initialize hook system: \(error)")
            return .injectionFailed
        }
        
        // Launch with DYLD injection
        let result = dyldManager.launchWithInjection(
            applicationPath: applicationPath,
            arguments: arguments,
            environment: environment
        )
        
        switch result {
        case .success:
            logger.info("Successfully launched \(applicationPath) with syscall hooks")
        case .sipEnabled:
            logger.warning("SIP enabled - hooks may not work with system applications")
        default:
            logger.error("DYLD injection failed: \(result.description)")
        }
        
        return result
    }
    
    /// Get injection command for manual testing (useful for AC001 validation)
    public func getInjectionCommand(
        applicationPath: String,
        arguments: [String] = []
    ) -> String {
        return dyldManager.generateInjectionCommand(
            applicationPath: applicationPath,
            arguments: arguments
        )
    }
    
    /// Check injection capabilities and system status
    public func getSystemStatus() -> [String: Any] {
        var status = dyldManager.getInjectionInfo()
        status["hook_manager_initialized"] = true // hookManager singleton is always available
        status["active_hooks"] = hookManager.activeHookCount
        return status
    }
}
