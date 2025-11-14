import Foundation

/// Data-related errors (database, parsing, encoding, etc.)
enum DataError: Error, LocalizedError, Equatable {
    /// Data not found
    case notFound(resource: String)
    
    /// Failed to encode data
    case encodingFailed(message: String)
    
    /// Failed to decode/parse data
    case decodingFailed(message: String)
    
    /// Invalid data format
    case invalidFormat(message: String)
    
    /// Database operation failed
    case databaseError(message: String)
    
    /// Data already exists (conflict)
    case alreadyExists(resource: String)
    
    /// Operation not allowed (permissions, constraints, etc.)
    case notAllowed(message: String)
    
    /// Data synchronization failed
    case syncFailed(message: String)
    
    /// Unknown data error
    case unknown(message: String)
    
    // MARK: - LocalizedError Conformance
    
    var errorDescription: String? {
        switch self {
        case .notFound(let resource):
            return "\(resource) not found"
        case .encodingFailed(let message):
            return "Encoding failed: \(message)"
        case .decodingFailed(let message):
            return "Decoding failed: \(message)"
        case .invalidFormat(let message):
            return "Invalid format: \(message)"
        case .databaseError(let message):
            return "Database error: \(message)"
        case .alreadyExists(let resource):
            return "\(resource) already exists"
        case .notAllowed(let message):
            return "Operation not allowed: \(message)"
        case .syncFailed(let message):
            return "Sync failed: \(message)"
        case .unknown(let message):
            return message
        }
    }
    
    var failureReason: String? {
        switch self {
        case .notFound:
            return "The requested resource was not found"
        case .encodingFailed:
            return "Failed to encode data for storage"
        case .decodingFailed:
            return "Failed to decode data from storage"
        case .invalidFormat:
            return "The data format is invalid"
        case .databaseError:
            return "A database operation failed"
        case .alreadyExists:
            return "The resource already exists"
        case .notAllowed:
            return "The operation is not allowed"
        case .syncFailed:
            return "Data synchronization failed"
        case .unknown:
            return nil
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .notFound:
            return "Please check if the resource exists and try again."
        case .encodingFailed, .decodingFailed, .invalidFormat:
            return "Please check the data format and try again. If the problem persists, contact support."
        case .databaseError:
            return "Please try again. If the problem persists, contact support."
        case .alreadyExists:
            return "The resource already exists. Please use a different identifier."
        case .notAllowed:
            return "You don't have permission to perform this operation."
        case .syncFailed:
            return "Please check your internet connection and try again."
        case .unknown:
            return "Please try again later."
        }
    }
    
    // MARK: - User-Friendly Message
    
    var userMessage: String {
        switch self {
        case .notFound:
            return "Data not found. Please try again."
        case .encodingFailed, .decodingFailed:
            return "Failed to process data. Please try again."
        case .invalidFormat:
            return "Invalid data format. Please try again."
        case .databaseError:
            return "Database error. Please try again."
        case .alreadyExists:
            return "This item already exists."
        case .notAllowed:
            return "Operation not allowed."
        case .syncFailed:
            return "Failed to sync data. Please check your connection and try again."
        case .unknown(let message):
            return message.isEmpty ? "Data error. Please try again." : message
        }
    }
    
    // MARK: - Conversion from Error
    
    /// Converts any Error to DataError if it's data-related
    static func from(_ error: Error) -> DataError? {
        let nsError = error as NSError
        let errorDescription = nsError.localizedDescription.lowercased()
        
        // Check for encoding/decoding errors
        if nsError.domain == NSCocoaErrorDomain {
            switch nsError.code {
            case NSCoderReadCorruptError, NSCoderValueNotFoundError:
                return .decodingFailed(message: nsError.localizedDescription)
            case NSCoderInvalidValueError:
                return .invalidFormat(message: nsError.localizedDescription)
            default:
                break
            }
        }
        
        // Check for JSON encoding/decoding errors
        if nsError.domain == "NSCocoaErrorDomain" {
            if errorDescription.contains("encode") || errorDescription.contains("encoding") {
                return .encodingFailed(message: nsError.localizedDescription)
            }
            if errorDescription.contains("decode") || errorDescription.contains("decoding") || errorDescription.contains("parse") {
                return .decodingFailed(message: nsError.localizedDescription)
            }
        }
        
        // Check for Firebase database errors
        if nsError.domain.contains("Firebase") || nsError.domain.contains("FIRDatabase") {
            if errorDescription.contains("permission") || errorDescription.contains("not allowed") {
                return .notAllowed(message: nsError.localizedDescription)
            }
            if errorDescription.contains("not found") {
                return .notFound(resource: "Data")
            }
            return .databaseError(message: nsError.localizedDescription)
        }
        
        // Check error description for data-related keywords
        if errorDescription.contains("encode") || errorDescription.contains("encoding") {
            return .encodingFailed(message: nsError.localizedDescription)
        }
        if errorDescription.contains("decode") || errorDescription.contains("decoding") || errorDescription.contains("parse") {
            return .decodingFailed(message: nsError.localizedDescription)
        }
        if errorDescription.contains("not found") {
            return .notFound(resource: "Data")
        }
        if errorDescription.contains("already exists") || errorDescription.contains("duplicate") {
            return .alreadyExists(resource: "Data")
        }
        if errorDescription.contains("invalid") || errorDescription.contains("format") {
            return .invalidFormat(message: nsError.localizedDescription)
        }
        
        return nil
    }
}

