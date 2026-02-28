import Foundation

/// JSON pretty printer for configuration files
public class JSONPrettyPrinter {
    
    /// Formatting options
    public struct FormatOptions {
        /// Indentation string (default: 2 spaces)
        public var indentation: String
        
        /// Sort keys alphabetically
        public var sortKeys: Bool
        
        /// Maximum line length before wrapping
        public var maxLineLength: Int
        
        /// Array element threshold for multi-line formatting
        public var arrayThreshold: Int
        
        /// Support JSON5 format with comments
        public var supportComments: Bool
        
        public init(
            indentation: String = "  ",
            sortKeys: Bool = true,
            maxLineLength: Int = 100,
            arrayThreshold: Int = 3,
            supportComments: Bool = false
        ) {
            self.indentation = indentation
            self.sortKeys = sortKeys
            self.maxLineLength = maxLineLength
            self.arrayThreshold = arrayThreshold
            self.supportComments = supportComments
        }
        
        /// Default formatting options
        public static let `default` = FormatOptions()
    }
    
    /// Format JSON data with pretty printing
    public static func format(_ data: Data, options: FormatOptions = .default) throws -> String {
        // First, validate JSON syntax
        guard let jsonObject = try? JSONSerialization.jsonObject(with: data, options: []) else {
            throw JSONPrettyPrinterError.invalidJSON("Invalid JSON syntax")
        }
        
        // Format the JSON object
        return try formatValue(jsonObject, level: 0, options: options)
    }
    
    /// Format JSON string with pretty printing
    public static func format(_ jsonString: String, options: FormatOptions = .default) throws -> String {
        guard let data = jsonString.data(using: .utf8) else {
            throw JSONPrettyPrinterError.invalidJSON("Invalid UTF-8 string")
        }
        return try format(data, options: options)
    }
    
    /// Format SystemExtensionConfiguration with pretty printing
    public static func format(_ config: SystemExtensionConfiguration, options: FormatOptions = .default) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = []
        encoder.dateEncodingStrategy = .iso8601
        
        let data = try encoder.encode(config)
        return try format(data, options: options)
    }
    
    // MARK: - Private Methods
    
    /// Format any JSON value
    internal static func formatValue(_ value: Any, level: Int, options: FormatOptions) throws -> String {
        if let dict = value as? [String: Any] {
            return try formatObject(dict, level: level, options: options)
        } else if let array = value as? [Any] {
            return try formatArray(array, level: level, options: options)
        } else if let string = value as? String {
            return formatString(string)
        } else if let number = value as? NSNumber {
            return formatNumber(number)
        } else if value is NSNull {
            return "null"
        } else {
            throw JSONPrettyPrinterError.unsupportedType("Unsupported JSON type")
        }
    }
    
    /// Format JSON object (dictionary)
    private static func formatObject(_ dict: [String: Any], level: Int, options: FormatOptions) throws -> String {
        if dict.isEmpty {
            return "{}"
        }
        
        let indent = String(repeating: options.indentation, count: level)
        let nextIndent = String(repeating: options.indentation, count: level + 1)
        
        var lines: [String] = ["{"]
        
        // Sort keys if requested
        let keys = options.sortKeys ? dict.keys.sorted() : Array(dict.keys)
        
        for (index, key) in keys.enumerated() {
            guard let value = dict[key] else { continue }
            
            let formattedValue = try formatValue(value, level: level + 1, options: options)
            let line = "\(nextIndent)\"\(key)\": \(formattedValue)"
            
            // Add comma if not last element
            if index < keys.count - 1 {
                lines.append(line + ",")
            } else {
                lines.append(line)
            }
        }
        
        lines.append("\(indent)}")
        
        return lines.joined(separator: "\n")
    }
    
    /// Format JSON array
    private static func formatArray(_ array: [Any], level: Int, options: FormatOptions) throws -> String {
        if array.isEmpty {
            return "[]"
        }
        
        // Check if array should be formatted inline or multi-line
        let shouldFormatMultiLine = array.count > options.arrayThreshold || containsComplexTypes(array)
        
        if shouldFormatMultiLine {
            return try formatArrayMultiLine(array, level: level, options: options)
        } else {
            return try formatArrayInline(array, level: level, options: options)
        }
    }
    
    /// Format array inline (single line)
    private static func formatArrayInline(_ array: [Any], level: Int, options: FormatOptions) throws -> String {
        let elements = try array.map { try formatValue($0, level: level, options: options) }
        let inline = "[\(elements.joined(separator: ", "))]"
        
        // Check if line is too long
        let currentIndent = String(repeating: options.indentation, count: level)
        if (currentIndent.count + inline.count) > options.maxLineLength {
            return try formatArrayMultiLine(array, level: level, options: options)
        }
        
        return inline
    }
    
    /// Format array multi-line (one element per line)
    private static func formatArrayMultiLine(_ array: [Any], level: Int, options: FormatOptions) throws -> String {
        let indent = String(repeating: options.indentation, count: level)
        let nextIndent = String(repeating: options.indentation, count: level + 1)
        
        var lines: [String] = ["["]
        
        for (index, element) in array.enumerated() {
            let formattedValue = try formatValue(element, level: level + 1, options: options)
            
            // For objects and arrays, format on same line as bracket
            if element is [String: Any] || element is [Any] {
                let line = "\(nextIndent)\(formattedValue)"
                if index < array.count - 1 {
                    lines.append(line + ",")
                } else {
                    lines.append(line)
                }
            } else {
                let line = "\(nextIndent)\(formattedValue)"
                if index < array.count - 1 {
                    lines.append(line + ",")
                } else {
                    lines.append(line)
                }
            }
        }
        
        lines.append("\(indent)]")
        
        return lines.joined(separator: "\n")
    }
    
    /// Format string value
    private static func formatString(_ string: String) -> String {
        // Escape special characters
        let escaped = string
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
            .replacingOccurrences(of: "\t", with: "\\t")
        
        return "\"\(escaped)\""
    }
    
    /// Format number value
    private static func formatNumber(_ number: NSNumber) -> String {
        // Check if it's a boolean
        if number === kCFBooleanTrue as NSNumber {
            return "true"
        } else if number === kCFBooleanFalse as NSNumber {
            return "false"
        }
        
        // Check if it's an integer
        if number.doubleValue == floor(number.doubleValue) {
            return "\(number.intValue)"
        }
        
        // Format as decimal
        return "\(number.doubleValue)"
    }
    
    /// Check if array contains complex types (objects or arrays)
    private static func containsComplexTypes(_ array: [Any]) -> Bool {
        return array.contains { $0 is [String: Any] || $0 is [Any] }
    }
}

// MARK: - JSON Pretty Printer Errors

/// JSON pretty printer errors
public enum JSONPrettyPrinterError: Error, LocalizedError {
    case invalidJSON(String)
    case unsupportedType(String)
    case formatError(String)
    
    public var errorDescription: String? {
        switch self {
        case .invalidJSON(let message):
            return "Invalid JSON: \(message)"
        case .unsupportedType(let message):
            return "Unsupported type: \(message)"
        case .formatError(let message):
            return "Format error: \(message)"
        }
    }
}

// MARK: - JSON5 Support (Future Enhancement)

/// JSON5 formatter with comment support
public class JSON5Formatter {
    
    /// Format JSON with comments (JSON5 format)
    public static func formatWithComments(_ data: Data, comments: [String: String] = [:]) throws -> String {
        // Parse JSON
        guard let jsonObject = try? JSONSerialization.jsonObject(with: data, options: []) else {
            throw JSONPrettyPrinterError.invalidJSON("Invalid JSON syntax")
        }
        
        // Format with standard pretty printer
        let formatted = try JSONPrettyPrinter.formatValue(jsonObject, level: 0, options: .default)
        
        // Add comments if provided
        if comments.isEmpty {
            return formatted
        }
        
        var lines = formatted.components(separatedBy: "\n")
        
        // Insert comments before matching keys
        for (key, comment) in comments {
            if let index = lines.firstIndex(where: { $0.contains("\"\(key)\":") }) {
                let indent = String(lines[index].prefix(while: { $0 == " " }))
                lines.insert("\(indent)// \(comment)", at: index)
            }
        }
        
        return lines.joined(separator: "\n")
    }
}
