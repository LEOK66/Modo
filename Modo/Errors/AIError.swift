import Foundation

/// AI service-related errors
enum AIError: Error, LocalizedError, Equatable {
    /// No response from AI service
    case noResponse
    
    /// Invalid response format
    case invalidResponse(message: String)
    
    /// Failed to parse AI response
    case parseFailed(message: String)
    
    /// AI service unavailable
    case serviceUnavailable
    
    /// Rate limit exceeded
    case rateLimitExceeded
    
    /// Invalid API key or configuration
    case invalidConfiguration(message: String)
    
    /// Request timeout
    case timeout
    
    /// Unknown AI error
    case unknown(message: String)
    
    // MARK: - LocalizedError Conformance
    
    var errorDescription: String? {
        switch self {
        case .noResponse:
            return "No response from AI service"
        case .invalidResponse(let message):
            return "Invalid response: \(message)"
        case .parseFailed(let message):
            return "Failed to parse response: \(message)"
        case .serviceUnavailable:
            return "AI service unavailable"
        case .rateLimitExceeded:
            return "Rate limit exceeded"
        case .invalidConfiguration(let message):
            return "Invalid configuration: \(message)"
        case .timeout:
            return "Request timeout"
        case .unknown(let message):
            return message
        }
    }
    
    var failureReason: String? {
        switch self {
        case .noResponse:
            return "The AI service did not return a response"
        case .invalidResponse:
            return "The AI service returned an invalid response"
        case .parseFailed:
            return "Failed to parse the AI service response"
        case .serviceUnavailable:
            return "The AI service is currently unavailable"
        case .rateLimitExceeded:
            return "Too many requests to the AI service"
        case .invalidConfiguration:
            return "The AI service configuration is invalid"
        case .timeout:
            return "The request to the AI service timed out"
        case .unknown:
            return nil
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .noResponse, .invalidResponse, .parseFailed:
            return "Please try again. If the problem persists, contact support."
        case .serviceUnavailable:
            return "Please try again later. The AI service may be experiencing issues."
        case .rateLimitExceeded:
            return "Please wait a few minutes before trying again."
        case .invalidConfiguration:
            return "Please contact support. The AI service configuration may need to be updated."
        case .timeout:
            return "Please check your internet connection and try again."
        case .unknown:
            return "Please try again later."
        }
    }
    
    // MARK: - User-Friendly Message
    
    var userMessage: String {
        switch self {
        case .noResponse:
            return "AI service did not respond. Please try again."
        case .invalidResponse:
            return "AI service returned an invalid response. Please try again."
        case .parseFailed:
            return "Failed to process AI response. Please try again."
        case .serviceUnavailable:
            return "AI service is currently unavailable. Please try again later."
        case .rateLimitExceeded:
            return "Too many requests. Please wait a few minutes and try again."
        case .invalidConfiguration:
            return "AI service configuration error. Please contact support."
        case .timeout:
            return "Request timed out. Please try again."
        case .unknown(let message):
            return message.isEmpty ? "AI service error. Please try again." : message
        }
    }
    
    // MARK: - Conversion from Error
    
    /// Converts any Error to AIError if it's AI service-related
    static func from(_ error: Error) -> AIError? {
        let nsError = error as NSError
        let errorDescription = nsError.localizedDescription.lowercased()
        let errorDomain = nsError.domain
        
        // Check for AI service domain errors
        if errorDomain.contains("AITaskGenerator") || errorDomain.contains("AddTaskAIService") || errorDomain.contains("FirebaseAIService") {
            if errorDescription.contains("no response") || errorDescription.contains("no response content") {
                return .noResponse
            }
            if errorDescription.contains("parse") || errorDescription.contains("failed to parse") {
                return .parseFailed(message: nsError.localizedDescription)
            }
            if errorDescription.contains("timeout") {
                return .timeout
            }
            if errorDescription.contains("rate limit") || errorDescription.contains("too many requests") {
                return .rateLimitExceeded
            }
            if errorDescription.contains("invalid") || errorDescription.contains("configuration") {
                return .invalidConfiguration(message: nsError.localizedDescription)
            }
            return .unknown(message: nsError.localizedDescription)
        }
        
        // Check error codes for common AI service errors
        if nsError.code == 1 && errorDescription.contains("response") {
            return .noResponse
        }
        if nsError.code == 2 && errorDescription.contains("parse") {
            return .parseFailed(message: nsError.localizedDescription)
        }
        
        // Check for timeout errors
        if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorTimedOut {
            return .timeout
        }
        
        return nil
    }
}

