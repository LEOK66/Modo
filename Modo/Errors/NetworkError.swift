import Foundation

/// Network-related errors
enum NetworkError: Error, LocalizedError, Equatable {
    /// No internet connection
    case notConnected
    
    /// Connection timeout
    case timeout
    
    /// Connection lost during operation
    case connectionLost
    
    /// Cannot connect to host
    case cannotConnectToHost
    
    /// Cannot find host (DNS failure)
    case cannotFindHost
    
    /// DNS lookup failed
    case dnsLookupFailed
    
    /// Request was cancelled
    case cancelled
    
    /// Server error (5xx)
    case serverError(statusCode: Int, message: String?)
    
    /// Client error (4xx)
    case clientError(statusCode: Int, message: String?)
    
    /// Unknown network error
    case unknown(message: String)
    
    // MARK: - LocalizedError Conformance
    
    var errorDescription: String? {
        switch self {
        case .notConnected:
            return "No internet connection"
        case .timeout:
            return "Connection timeout"
        case .connectionLost:
            return "Connection lost"
        case .cannotConnectToHost:
            return "Cannot connect to host"
        case .cannotFindHost:
            return "Cannot find host"
        case .dnsLookupFailed:
            return "DNS lookup failed"
        case .cancelled:
            return "Request cancelled"
        case .serverError(let statusCode, let message):
            return message ?? "Server error (\(statusCode))"
        case .clientError(let statusCode, let message):
            return message ?? "Client error (\(statusCode))"
        case .unknown(let message):
            return message
        }
    }
    
    var failureReason: String? {
        switch self {
        case .notConnected:
            return "Please check your internet connection"
        case .timeout:
            return "The request took too long to complete"
        case .connectionLost:
            return "The connection was lost during the operation"
        case .cannotConnectToHost:
            return "Unable to establish a connection to the server"
        case .cannotFindHost:
            return "The server address could not be resolved"
        case .dnsLookupFailed:
            return "DNS lookup failed"
        case .cancelled:
            return "The request was cancelled"
        case .serverError:
            return "The server encountered an error"
        case .clientError:
            return "The request was invalid"
        case .unknown:
            return nil
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .notConnected, .connectionLost, .cannotConnectToHost, .cannotFindHost, .dnsLookupFailed:
            return "Please check your internet connection and try again"
        case .timeout:
            return "Please check your internet connection and try again. If the problem persists, the server may be experiencing high load."
        case .cancelled:
            return nil // User cancellation doesn't need a recovery suggestion
        case .serverError:
            return "Please try again later. If the problem persists, contact support."
        case .clientError:
            return "Please check your request and try again."
        case .unknown:
            return "Please try again later."
        }
    }
    
    // MARK: - User-Friendly Message
    
    var userMessage: String {
        switch self {
        case .notConnected, .connectionLost, .cannotConnectToHost, .cannotFindHost, .dnsLookupFailed:
            return "Network not available. Please check your connection and try again."
        case .timeout:
            return "Request timed out. Please check your connection and try again."
        case .cancelled:
            return "" // User cancellation - don't show message
        case .serverError:
            return "Server error. Please try again later."
        case .clientError:
            return "Request error. Please try again."
        case .unknown(let message):
            return message.isEmpty ? "Network error. Please try again." : message
        }
    }
    
    // MARK: - Properties
    
    /// Whether this is a cancellation error
    var isCancellation: Bool {
        if case .cancelled = self {
            return true
        }
        return false
    }
    
    // MARK: - Conversion from Error
    
    /// Converts any Error to NetworkError if it's network-related
    static func from(_ error: Error) -> NetworkError? {
        let nsError = error as NSError
        
        // Check for URL errors
        if nsError.domain == NSURLErrorDomain {
            switch nsError.code {
            case NSURLErrorNotConnectedToInternet:
                return .notConnected
            case NSURLErrorTimedOut:
                return .timeout
            case NSURLErrorNetworkConnectionLost:
                return .connectionLost
            case NSURLErrorCannotConnectToHost:
                return .cannotConnectToHost
            case NSURLErrorCannotFindHost:
                return .cannotFindHost
            case NSURLErrorDNSLookupFailed:
                return .dnsLookupFailed
            case NSURLErrorCancelled:
                return .cancelled
            default:
                return .unknown(message: nsError.localizedDescription)
            }
        }
        
        // Check for Firebase network errors
        if nsError.domain == "FIRAuthErrorDomain" {
            // Firebase Auth error code 17020 is network error
            if nsError.code == 17020 {
                return .notConnected
            }
        }
        
        // Check error description for network-related keywords
        let errorDescription = nsError.localizedDescription.lowercased()
        let networkKeywords = ["network", "internet", "connection", "offline", "unreachable", "timeout"]
        if networkKeywords.contains(where: { errorDescription.contains($0) }) {
            if errorDescription.contains("timeout") {
                return .timeout
            } else if errorDescription.contains("offline") || errorDescription.contains("not connected") {
                return .notConnected
            } else if errorDescription.contains("connection lost") {
                return .connectionLost
            } else {
                return .unknown(message: nsError.localizedDescription)
            }
        }
        
        return nil
    }
}

