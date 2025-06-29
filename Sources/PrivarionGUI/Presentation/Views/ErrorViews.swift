import SwiftUI

/// Error presentation views for SwiftUI interface
/// Provides alerts, banners, and notifications for error display
/// Integrates with ErrorManager for centralized error handling

// MARK: - Error Alert View

/// SwiftUI wrapper for error alerts
struct ErrorAlertView: ViewModifier {
    @ObservedObject var errorManager: ErrorManager
    
    func body(content: Content) -> some View {
        content
            .alert(item: Binding<ErrorAlert?>(
                get: { errorManager.currentAlerts.first },
                set: { _ in }
            )) { alert in
                if let secondaryAction = alert.secondaryAction {
                    return Alert(
                        title: Text(alert.title),
                        message: Text(alert.message + (alert.recoveryMessage.map { "\n\n\($0)" } ?? "")),
                        primaryButton: convertToAlertButton(alert.primaryAction),
                        secondaryButton: convertToAlertButton(secondaryAction)
                    )
                } else {
                    return Alert(
                        title: Text(alert.title),
                        message: Text(alert.message + (alert.recoveryMessage.map { "\n\n\($0)" } ?? "")),
                        dismissButton: convertToAlertButton(alert.primaryAction)
                    )
                }
            }
    }
    
    private func convertToAlertButton(_ action: AlertAction) -> Alert.Button {
        switch action.style {
        case .default:
            return .default(Text(action.title), action: action.action)
        case .cancel:
            return .cancel(Text(action.title), action: action.action)
        case .destructive:
            return .destructive(Text(action.title), action: action.action)
        }
    }
}

// MARK: - Error Banner View

/// Error banner for non-critical notifications
struct ErrorBannerView: View {
    let banner: ErrorBanner
    let onDismiss: () -> Void
    let onRetry: (() -> Void)?
    
    @State private var isVisible = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Error icon
            Image(systemName: iconName)
                .foregroundColor(iconColor)
                .font(.headline)
            
            // Error message
            VStack(alignment: .leading, spacing: 4) {
                Text(banner.message)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .lineLimit(3)
                
                Text(banner.category.displayName)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Action buttons
            HStack(spacing: 8) {
                if banner.isRetryable, let onRetry = onRetry {
                    Button("Retry") {
                        onRetry()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                
                Button("Dismiss") {
                    onDismiss()
                }
                .buttonStyle(.borderless)
                .controlSize(.small)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(backgroundColor)
        .overlay(
            Rectangle()
                .frame(width: 4)
                .foregroundColor(accentColor),
            alignment: .leading
        )
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        .scaleEffect(isVisible ? 1.0 : 0.9)
        .opacity(isVisible ? 1.0 : 0.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isVisible)
        .onAppear {
            isVisible = true
        }
    }
    
    private var iconName: String {
        switch banner.severity {
        case .critical:
            return "exclamationmark.triangle.fill"
        case .high:
            return "exclamationmark.circle.fill"
        case .medium:
            return "exclamationmark.circle"
        case .low:
            return "info.circle"
        }
    }
    
    private var iconColor: Color {
        switch banner.severity {
        case .critical:
            return .red
        case .high:
            return .orange
        case .medium:
            return .yellow
        case .low:
            return .blue
        }
    }
    
    private var backgroundColor: Color {
        switch banner.severity {
        case .critical:
            return Color.red.opacity(0.1)
        case .high:
            return Color.orange.opacity(0.1)
        case .medium:
            return Color.yellow.opacity(0.1)
        case .low:
            return Color.blue.opacity(0.1)
        }
    }
    
    private var accentColor: Color {
        switch banner.severity {
        case .critical:
            return .red
        case .high:
            return .orange
        case .medium:
            return .yellow
        case .low:
            return .blue
        }
    }
}

// MARK: - Error Banner Container

/// Container for displaying multiple error banners
struct ErrorBannerContainer: View {
    @ObservedObject var errorManager: ErrorManager
    
    var body: some View {
        VStack(spacing: 8) {
            ForEach(errorManager.errorBanners, id: \.id) { banner in
                ErrorBannerView(
                    banner: banner,
                    onDismiss: {
                        errorManager.dismissError(banner.id)
                    },
                    onRetry: banner.isRetryable ? {
                        // Retry action - this would be connected to specific operations
                        // For now, just dismiss the banner
                        errorManager.dismissError(banner.id)
                    } : nil
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal: .move(edge: .top).combined(with: .opacity)
                ))
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: errorManager.errorBanners.count)
    }
}

// MARK: - Error Statistics View

/// Debug view for error statistics (development/admin use)
struct ErrorStatisticsView: View {
    @ObservedObject var errorManager: ErrorManager
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: {
                isExpanded.toggle()
            }) {
                HStack {
                    Text("Error Statistics")
                        .font(.headline)
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                }
            }
            .buttonStyle(.plain)
            
            if isExpanded {
                let stats = errorManager.getErrorStatistics()
                
                VStack(alignment: .leading, spacing: 4) {
                    statisticRow("Total Errors", "\\(stats.totalErrors)")
                    statisticRow("Critical", "\\(stats.criticalErrors)")
                    statisticRow("High Severity", "\\(stats.highSeverityErrors)")
                    statisticRow("Medium Severity", "\\(stats.mediumSeverityErrors)")
                    statisticRow("Low Severity", "\\(stats.lowSeverityErrors)")
                    statisticRow("Successful Retries", "\\(stats.successfulRetries)")
                    
                    if let lastError = stats.lastErrorTimestamp {
                        statisticRow("Last Error", DateFormatter.localizedString(
                            from: lastError,
                            dateStyle: .short,
                            timeStyle: .medium
                        ))
                    }
                    
                    if !stats.errorsByCategory.isEmpty {
                        Text("By Category:")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .padding(.top, 8)
                        
                        ForEach(Array(stats.errorsByCategory.keys).sorted(by: { $0.rawValue < $1.rawValue }), id: \.rawValue) { category in
                            statisticRow(category.displayName, "\\(stats.errorsByCategory[category] ?? 0)")
                        }
                    }
                }
                .padding(.leading, 16)
                .transition(.opacity.combined(with: .slide))
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
        .animation(.easeInOut, value: isExpanded)
    }
    
    private func statisticRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
        }
    }
}

// MARK: - Recovery Progress View

/// Shows recovery progress for ongoing error recovery operations
struct RecoveryProgressView: View {
    @ObservedObject var errorManager: ErrorManager
    
    var body: some View {
        if errorManager.isRecovering {
            HStack(spacing: 12) {
                ProgressView()
                    .scaleEffect(0.8)
                    .controlSize(.small)
                
                Text("Attempting recovery...")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.blue.opacity(0.1))
            .cornerRadius(20)
            .transition(.opacity.combined(with: .scale))
        }
    }
}

// MARK: - View Extensions

extension View {
    /// Apply error alert handling to any view
    func errorAlerts(errorManager: ErrorManager) -> some View {
        self.modifier(ErrorAlertView(errorManager: errorManager))
    }
    
    /// Add error banner overlay to any view
    func errorBanners(errorManager: ErrorManager) -> some View {
        self.overlay(
            VStack {
                ErrorBannerContainer(errorManager: errorManager)
                    .padding(.horizontal)
                    .padding(.top)
                
                Spacer()
            },
            alignment: .top
        )
    }
    
    /// Add recovery progress indicator
    func recoveryProgress(errorManager: ErrorManager) -> some View {
        self.overlay(
            VStack {
                Spacer()
                
                RecoveryProgressView(errorManager: errorManager)
                    .padding(.bottom)
            },
            alignment: .bottom
        )
    }
    
    /// Apply complete error handling UI
    func withErrorHandling(errorManager: ErrorManager) -> some View {
        self
            .errorAlerts(errorManager: errorManager)
            .errorBanners(errorManager: errorManager)
            .recoveryProgress(errorManager: errorManager)
    }
}
