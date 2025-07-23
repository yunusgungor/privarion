import Foundation
import PrivarionCore

/// Actor responsible for handling export and import of temporary permissions
/// Provides thread-safe operations for file I/O and data transformation
actor PermissionExportManager {
    
    // MARK: - Export Functionality
    
    /// Exports permissions to JSON format
    /// - Parameter permissions: Array of permissions to export
    /// - Returns: JSON data ready for file writing
    /// - Throws: Encoding errors
    func exportToJSON(permissions: [PrivarionCore.TemporaryPermissionManager.TemporaryPermissionGrant]) async throws -> Data {
        let exportData = PermissionExportData(
            exportedAt: Date(),
            version: "1.0",
            permissions: permissions.map { grant in
                ExportedPermission(
                    id: grant.id,
                    bundleIdentifier: grant.bundleIdentifier,
                    serviceName: grant.serviceName,
                    grantedAt: grant.grantedAt,
                    expiresAt: grant.expiresAt,
                    isExpired: grant.isExpired
                )
            }
        )
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        return try encoder.encode(exportData)
    }
    
    /// Exports permissions to CSV format
    /// - Parameter permissions: Array of permissions to export
    /// - Returns: CSV data ready for file writing
    /// - Throws: Encoding errors
    func exportToCSV(permissions: [PrivarionCore.TemporaryPermissionManager.TemporaryPermissionGrant]) async throws -> Data {
        var csvContent = "ID,Bundle Identifier,Service Name,Granted At,Expires At,Status\n"
        
        let dateFormatter = ISO8601DateFormatter()
        
        for permission in permissions {
            let grantedAtString = dateFormatter.string(from: permission.grantedAt)
            let expiresAtString = dateFormatter.string(from: permission.expiresAt)
            let status = permission.isExpired ? "Expired" : "Active"
            
            // Escape CSV fields that might contain commas
            let bundleId = escapeCSVField(permission.bundleIdentifier)
            let serviceName = escapeCSVField(permission.serviceName)
            
            csvContent += "\(permission.id),\(bundleId),\(serviceName),\(grantedAtString),\(expiresAtString),\(status)\n"
        }
        
        guard let data = csvContent.data(using: .utf8) else {
            throw ExportError.encodingFailed
        }
        
        return data
    }
    
    // MARK: - Import Functionality
    
    /// Imports permission templates from JSON data
    /// - Parameter data: JSON data to import
    /// - Returns: Array of permission templates ready for creation
    /// - Throws: Decoding or validation errors
    func importFromJSON(data: Data) async throws -> [PermissionTemplate] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        let importData = try decoder.decode(PermissionImportData.self, from: data)
        
        // Validate imported data
        try validateImportData(importData)
        
        return importData.templates.map { template in
            PermissionTemplate(
                bundleIdentifier: template.bundleIdentifier,
                serviceName: template.serviceName,
                durationMinutes: template.durationMinutes,
                description: template.description
            )
        }
    }
    
    // MARK: - Helper Methods
    
    private func escapeCSVField(_ field: String) -> String {
        if field.contains(",") || field.contains("\"") || field.contains("\n") {
            return "\"\(field.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return field
    }
    
    private func validateImportData(_ data: PermissionImportData) throws {
        guard !data.templates.isEmpty else {
            throw ImportError.emptyData
        }
        
        for template in data.templates {
            // Validate bundle identifier format
            guard isValidBundleIdentifier(template.bundleIdentifier) else {
                throw ImportError.invalidBundleIdentifier(template.bundleIdentifier)
            }
            
            // Validate service name
            guard isValidServiceName(template.serviceName) else {
                throw ImportError.invalidServiceName(template.serviceName)
            }
            
            // Validate duration
            guard template.durationMinutes >= 15 && template.durationMinutes <= 10080 else {
                throw ImportError.invalidDuration(template.durationMinutes)
            }
        }
    }
    
    private func isValidBundleIdentifier(_ identifier: String) -> Bool {
        let bundleIDPattern = #"^[a-zA-Z][a-zA-Z0-9]*(\.[a-zA-Z][a-zA-Z0-9]*)+$"#
        let regex = try? NSRegularExpression(pattern: bundleIDPattern)
        let range = NSRange(location: 0, length: identifier.utf16.count)
        return regex?.firstMatch(in: identifier, options: [], range: range) != nil
    }
    
    private func isValidServiceName(_ serviceName: String) -> Bool {
        let validServices = [
            "kTCCServiceCamera", "kTCCServiceMicrophone", "kTCCServiceContactsLimited",
            "kTCCServiceCalendar", "kTCCServiceReminders", "kTCCServicePhotos",
            "kTCCServiceContactsFull", "kTCCServiceAccessibility", "kTCCServicePostEvent",
            "kTCCServiceLocation", "kTCCServiceDeveloperTool", "kTCCServiceScreenCapture",
            "kTCCServiceSystemPolicyDesktopFolder", "kTCCServiceSystemPolicyDocumentsFolder",
            "kTCCServiceSystemPolicyDownloadsFolder", "kTCCServiceSystemPolicyNetworkVolumes"
        ]
        return validServices.contains(serviceName)
    }
}

// MARK: - Data Models

struct PermissionExportData: Codable {
    let exportedAt: Date
    let version: String
    let permissions: [ExportedPermission]
}

struct ExportedPermission: Codable {
    let id: String
    let bundleIdentifier: String
    let serviceName: String
    let grantedAt: Date
    let expiresAt: Date
    let isExpired: Bool
}

struct PermissionImportData: Codable {
    let version: String
    let templates: [ImportedTemplate]
}

struct ImportedTemplate: Codable {
    let bundleIdentifier: String
    let serviceName: String
    let durationMinutes: Int
    let description: String?
}

struct PermissionTemplate {
    let bundleIdentifier: String
    let serviceName: String
    let durationMinutes: Int
    let description: String?
}

// MARK: - Error Types

enum ExportError: LocalizedError {
    case encodingFailed
    case noPermissionsToExport
    
    var errorDescription: String? {
        switch self {
        case .encodingFailed:
            return "Failed to encode permission data"
        case .noPermissionsToExport:
            return "No permissions available for export"
        }
    }
}

enum ImportError: LocalizedError {
    case emptyData
    case invalidFormat
    case invalidBundleIdentifier(String)
    case invalidServiceName(String)
    case invalidDuration(Int)
    
    var errorDescription: String? {
        switch self {
        case .emptyData:
            return "Import file contains no permission templates"
        case .invalidFormat:
            return "Import file format is not supported"
        case .invalidBundleIdentifier(let id):
            return "Invalid bundle identifier: \(id)"
        case .invalidServiceName(let service):
            return "Invalid service name: \(service)"
        case .invalidDuration(let duration):
            return "Invalid duration: \(duration) minutes (must be 15-10080)"
        }
    }
}
