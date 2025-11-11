import Foundation
import FirebaseAuth

/// Unified error handling for authentication operations
enum AuthErrorHandler {
    
    // MARK: - Error Context
    enum AuthContext {
        case signIn
        case signUp
        case passwordReset
        case emailVerification
        
        var defaultMessage: String {
            switch self {
            case .signIn:
                return "Invalid email or password"
            case .signUp:
                return "Failed to create account. Please try again."
            case .passwordReset:
                return "Failed to send reset link. Please try again."
            case .emailVerification:
                return "Failed to send verification email. Please try again."
            }
        }
    }
    
    // MARK: - User Cancellation Check
    /// Determines if an error is due to user cancellation (should not be shown to user)
    static func isUserCancellation(_ error: Error) -> Bool {
        let nsError = error as NSError
        let errorDomain = nsError.domain
        let errorCode = nsError.code
        let errorDescription = nsError.localizedDescription.lowercased()
        
        // Check for Google Sign-In cancellation
        if errorDomain == "com.google.GIDSignIn" && errorCode == -5 {
            return true
        }
        
        // Check for Apple Sign-In cancellation
        if errorDomain == "com.apple.AuthenticationServices.AuthorizationError" && errorCode == 1001 {
            return true
        }
        
        // Check for other Apple Sign-In error domains
        if errorDomain.contains("AuthenticationServices") || errorDomain.contains("ASAuthorization") {
            if errorCode == 1001 || errorCode == -1001 {
                return true
            }
        }
        
        // Check for cancellation in error description
        if errorDescription.contains("cancel") || errorDescription.contains("cancelled") || errorDescription.contains("user canceled") {
            return true
        }
        
        // Check for URL cancellation errors
        if errorDomain == NSURLErrorDomain && errorCode == NSURLErrorCancelled {
            return true
        }
        
        return false
    }
    
    // MARK: - Network Error Check
    /// Determines if an error is network-related
    static func isNetworkError(_ error: Error) -> Bool {
        let nsError = error as NSError
        
        // Check for network-related error codes
        let networkErrorCodes: [Int] = [
            NSURLErrorNotConnectedToInternet,
            NSURLErrorNetworkConnectionLost,
            NSURLErrorTimedOut,
            NSURLErrorCannotConnectToHost,
            NSURLErrorCannotFindHost,
            NSURLErrorDNSLookupFailed
        ]
        
        if nsError.domain == NSURLErrorDomain && networkErrorCodes.contains(nsError.code) {
            return true
        }
        
        // Check error description for network-related keywords
        let errorDescription = nsError.localizedDescription.lowercased()
        let networkKeywords = ["network", "internet", "connection", "offline", "unreachable", "timeout"]
        if networkKeywords.contains(where: { errorDescription.contains($0) }) {
            return true
        }
        
        return false
    }
    
    // MARK: - Error Message Generation
    /// Returns a user-friendly error message based on the error and context
    static func getMessage(for error: Error, context: AuthContext = .signIn) -> String {
        let nsError = error as NSError
        
        // Check for network errors first
        if isNetworkError(nsError) {
            return "Network not available. Please check your connection and try again."
        }
        
        // Check for Firebase Auth errors
        if nsError.domain == "FIRAuthErrorDomain" {
            return getFirebaseAuthMessage(for: nsError, context: context)
        }
        
        // Check for Bundle ID mismatch (Apple Sign-In specific)
        let errorDescription = nsError.localizedDescription.lowercased()
        if errorDescription.contains("audience") && errorDescription.contains("does not match") {
            return "Bundle ID configuration mismatch. Please check Firebase Console settings."
        }
        
        // Default error message based on context
        return context.defaultMessage
    }
    
    // MARK: - Firebase Auth Error Messages
    private static func getFirebaseAuthMessage(for error: NSError, context: AuthContext) -> String {
        switch error.code {
        case 17020: // Network error
            return "Network not available. Please check your connection and try again."
            
        case 17007: // Email already in use
            switch context {
            case .signIn:
                return "This email is already registered. Please try logging in."
            case .signUp:
                return "This email is already registered. Please use a different email or try logging in."
            default:
                return "This email is already registered."
            }
            
        case 17008: // Invalid email
            return "Invalid email address. Please check and try again."
            
        case 17009: // Wrong password
            return "Invalid email or password"
            
        case 17010: // Too many requests
            return "Too many attempts. Please try again later."
            
        case 17011: // User not found
            switch context {
            case .passwordReset:
                return "No account found with this email address. Please check your email or sign up."
            case .signIn:
                return "Invalid email or password"
            default:
                return "User not found."
            }
            
        case 17026: // Weak password
            return "Password is too weak. Please use at least 8 characters with letters and numbers."
            
        default:
            // Check if it's a network-related error by checking the underlying error
            if isNetworkError(error) {
                return "Network not available. Please check your connection and try again."
            }
            return context.defaultMessage
        }
    }
}

