// PrivarionSystemExtension - SystemExtensionLifecycle
// Protocol for observing system extension lifecycle events
// Requirements: 1.8, 17.1

import Foundation

/// Protocol for observing system extension lifecycle events
/// Allows observers to be notified of extension state changes
/// All lifecycle events are logged with timestamps and details
public protocol SystemExtensionLifecycle {
    /// Called before the extension begins activation
    /// Use this to prepare resources or validate prerequisites
    func willActivate() async
    
    /// Called after the extension has successfully activated
    /// Use this to initialize services or start monitoring
    func didActivate() async
    
    /// Called before the extension begins deactivation
    /// Use this to prepare for shutdown or save state
    func willDeactivate() async
    
    /// Called after the extension has successfully deactivated
    /// Use this to cleanup resources or stop services
    func didDeactivate() async
    
    /// Called when the extension encounters an error during lifecycle operations
    /// - Parameter error: The error that occurred
    func didFailWithError(_ error: Error) async
}
