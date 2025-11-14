import Foundation

/// Unified error types for Modo AI services
enum ModoAIError: LocalizedError {
    // Network related
    case networkError(underlying: Error)
    case timeoutError
    case noInternetConnection
    
    // API related
    case apiError(message: String)
    case apiRateLimitExceeded
    case authenticationFailed
    case invalidAPIKey
    
    // Response related
    case invalidResponse(reason: String)
    case emptyResponse
    case decodingError(underlying: Error)
    
    // Parsing related
    case parsingError(reason: String)
    case missingRequiredData(field: String)
    
    // Firebase related
    case firebaseError(underlying: Error)
    case functionNotFound
    case functionExecutionFailed
    
    // Content related
    case inappropriateContent
    case contentFilterBlocked
    
    // General
    case unknown(underlying: Error)
    
    // MARK: - LocalizedError Implementation
    
    var errorDescription: String? {
        switch self {
        // Network
        case .networkError:
            return "network connection error, please check your network settings"
        case .timeoutError:
            return "request timeout, please try again"
        case .noInternetConnection:
            return "cannot connect to the network, please check your network connection"
            
        // API
        case .apiError(let message):
            return "service error: \(message)"
        case .apiRateLimitExceeded:
            return "request too frequent, please try again later"
        case .authenticationFailed:
            return "authentication failed, please login again"
        case .invalidAPIKey:
            return "service configuration error, please contact technical support"
            
        // Response
        case .invalidResponse(let reason):
            return "server returned an invalid response: \(reason)"
        case .emptyResponse:
            return "server returned an empty response, please try again"
        case .decodingError:
            return "data parsing failed, please try again"
            
        // Parsing
        case .parsingError(let reason):
            return "data parsing failed: \(reason)"
        case .missingRequiredData(let field):
            return "missing required data field: \(field)"
            
        // Firebase
        case .firebaseError:
            return "service connection failed, please try again"
        case .functionNotFound:
            return "service unavailable, please try again later"
        case .functionExecutionFailed:
            return "service execution failed, please try again"
            
        // Content
        case .inappropriateContent:
            return "content is inappropriate"
        case .contentFilterBlocked:
            return "content is blocked by the security filter"
            
        // General
        case .unknown:
            return "an unknown error occurred, please try again"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .networkError, .noInternetConnection:
            return "please check your network connection and try again"
        case .timeoutError:
            return "network is slow, please try again later"
        case .apiRateLimitExceeded:
            return "please try again later"
        case .authenticationFailed:
            return "please login again"
        case .invalidResponse, .emptyResponse, .decodingError:
            return "if the problem persists, please contact customer service"
        case .parsingError, .missingRequiredData:
            return "please try again"
        case .firebaseError, .functionNotFound, .functionExecutionFailed:
            return "please check your network connection or try again later"
        case .inappropriateContent, .contentFilterBlocked:
            return "please modify your content and try again"
        case .invalidAPIKey:
            return "please contact technical support"
        default:
            return "if the problem persists, please contact customer service"
        }
    }
    
    var failureReason: String? {
        switch self {
        case .networkError(let error), .unknown(let error):
            return error.localizedDescription
        case .decodingError(let error):
            return "JSON parsing failed: \(error.localizedDescription)"
        case .firebaseError(let error):
            return "Firebase error: \(error.localizedDescription)"
        case .apiError(let message):
            return message
        case .invalidResponse(let reason):
            return reason
        case .parsingError(let reason):
            return reason
        case .missingRequiredData(let field):
            return "field '\(field)' is missing"
        default:
            return nil
        }
    }
    
    // MARK: - Helper Methods
    
    /// Check if error is recoverable (user can retry)
    var isRecoverable: Bool {
        switch self {
        case .networkError, .timeoutError, .noInternetConnection,
             .apiRateLimitExceeded, .emptyResponse, .firebaseError,
             .functionExecutionFailed:
            return true
        case .authenticationFailed, .invalidAPIKey, .functionNotFound:
            return false
        default:
            return true
        }
    }
    
    /// Check if error requires user action
    var requiresUserAction: Bool {
        switch self {
        case .authenticationFailed, .inappropriateContent, .contentFilterBlocked:
            return true
        default:
            return false
        }
    }
}

// MARK: - Error Conversion Helpers

extension ModoAIError {
    /// Convert NSError to ModoAIError
    static func from(_ error: Error) -> ModoAIError {
        if let modoError = error as? ModoAIError {
            return modoError
        }
        
        let nsError = error as NSError
        
        // Check for network errors
        if nsError.domain == NSURLErrorDomain {
            switch nsError.code {
            case NSURLErrorNotConnectedToInternet:
                return .noInternetConnection
            case NSURLErrorTimedOut:
                return .timeoutError
            default:
                return .networkError(underlying: error)
            }
        }
        
        // Check for decoding errors
        if error is DecodingError {
            return .decodingError(underlying: error)
        }
        
        return .unknown(underlying: error)
    }
}

