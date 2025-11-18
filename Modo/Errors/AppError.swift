import Foundation

/// Unified error type for the Modo application
/// This is the main error type that all services should use
enum AppError: Error, LocalizedError {
    // MARK: - Error Categories
    
    /// Network-related errors
    case network(NetworkError)
    
    /// Data-related errors (database, parsing, etc.)
    case data(DataError)
    
    /// Authentication-related errors
    case auth(AuthError)
    
    /// AI service errors
    case ai(AIError)
    
    /// Validation errors
    case validation(message: String)
    
    /// Unknown or unexpected errors
    case unknown(message: String, underlyingError: Error?)
    
    // MARK: - LocalizedError Conformance
    
    var errorDescription: String? {
        switch self {
        case .network(let error):
            return error.errorDescription
        case .data(let error):
            return error.errorDescription
        case .auth(let error):
            return error.errorDescription
        case .ai(let error):
            return error.errorDescription
        case .validation(let message):
            return message
        case .unknown(let message, _):
            return message
        }
    }
    
    var failureReason: String? {
        switch self {
        case .network(let error):
            return error.failureReason
        case .data(let error):
            return error.failureReason
        case .auth(let error):
            return error.failureReason
        case .ai(let error):
            return error.failureReason
        case .validation:
            return nil
        case .unknown(_, let underlyingError):
            return underlyingError?.localizedDescription
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .network(let error):
            return error.recoverySuggestion
        case .data(let error):
            return error.recoverySuggestion
        case .auth(let error):
            return error.recoverySuggestion
        case .ai(let error):
            return error.recoverySuggestion
        case .validation:
            return nil
        case .unknown:
            return "Please try again later. If the problem persists, contact support."
        }
    }
    
    // MARK: - User-Friendly Message
    
    /// Returns a user-friendly error message that can be displayed to the user
    var userMessage: String {
        return userMessage(context: nil)
    }
    
    /// Returns a user-friendly error message with optional context (for authentication errors)
    /// - Parameter context: Optional authentication context (signIn, signUp, etc.)
    /// - Returns: User-friendly error message
    func userMessage(context: AuthError.Context?) -> String {
        switch self {
        case .network(let error):
            return error.userMessage
        case .data(let error):
            return error.userMessage
        case .auth(let error):
            // Use provided context if available, otherwise use default
            return error.userMessage(context: context ?? .signIn)
        case .ai(let error):
            return error.userMessage
        case .validation(let message):
            return message
        case .unknown(let message, _):
            return message.isEmpty ? "An unexpected error occurred. Please try again." : message
        }
    }
    
    // MARK: - Conversion from Error
    
    /// Converts any Error to AppError
    /// This is useful when working with third-party libraries that return generic Error types
    static func from(_ error: Error) -> AppError {
        // If it's already an AppError, return it
        if let appError = error as? AppError {
            return appError
        }
        
        // Try to convert from known error types
        if let networkError = NetworkError.from(error) {
            return .network(networkError)
        }
        
        if let dataError = DataError.from(error) {
            return .data(dataError)
        }
        
        if let authError = AuthError.from(error) {
            return .auth(authError)
        }
        
        if let aiError = AIError.from(error) {
            return .ai(aiError)
        }
        
        // Convert NSError to appropriate AppError
        let nsError = error as NSError
        
        // Check for validation errors (common in form validation)
        if nsError.domain.contains("validation") || nsError.domain.contains("Validation") {
            return .validation(message: error.localizedDescription)
        }
        
        // Default to unknown error
        return .unknown(
            message: error.localizedDescription.isEmpty ? "An unexpected error occurred" : error.localizedDescription,
            underlyingError: error
        )
    }
    
    // MARK: - User Cancellation Check
    
    /// Determines if this error represents a user cancellation (should not be shown to user)
    var isUserCancellation: Bool {
        switch self {
        case .auth(let error):
            return error.isUserCancellation
        case .network(let error):
            return error.isCancellation
        default:
            return false
        }
    }
    
    // MARK: - Network Error Check
    
    /// Determines if this error is network-related
    var isNetworkError: Bool {
        if case .network = self {
            return true
        }
        return false
    }
}

// MARK: - Equatable Conformance

extension AppError: Equatable {
    static func == (lhs: AppError, rhs: AppError) -> Bool {
        switch (lhs, rhs) {
        case (.network(let lhsError), .network(let rhsError)):
            return lhsError == rhsError
        case (.data(let lhsError), .data(let rhsError)):
            return lhsError == rhsError
        case (.auth(let lhsError), .auth(let rhsError)):
            return lhsError == rhsError
        case (.ai(let lhsError), .ai(let rhsError)):
            return lhsError == rhsError
        case (.validation(let lhsMessage), .validation(let rhsMessage)):
            return lhsMessage == rhsMessage
        case (.unknown(let lhsMessage, _), .unknown(let rhsMessage, _)):
            return lhsMessage == rhsMessage
        default:
            return false
        }
    }
}

