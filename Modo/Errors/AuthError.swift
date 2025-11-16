import Foundation
import FirebaseAuth

/// Authentication-related errors
enum AuthError: Error, LocalizedError, Equatable {
    /// Email already in use
    case emailAlreadyInUse
    
    /// Invalid email format
    case invalidEmail
    
    /// Wrong password
    case wrongPassword
    
    /// User not found
    case userNotFound
    
    /// Weak password
    case weakPassword
    
    /// Too many requests
    case tooManyRequests
    
    /// Network error during authentication
    case networkError
    
    /// User cancelled the authentication flow
    case userCancelled
    
    /// Email not verified
    case emailNotVerified
    
    /// Invalid credentials
    case invalidCredentials
    
    /// Account disabled
    case accountDisabled
    
    /// Operation not allowed
    case operationNotAllowed
    
    /// Unknown authentication error
    case unknown(message: String, code: Int?)
    
    // MARK: - Error Context
    
    /// Context for error messages (sign in, sign up, etc.)
    enum Context {
        case signIn
        case signUp
        case passwordReset
        case passwordChange
        case emailVerification
        
        var defaultMessage: String {
            switch self {
            case .signIn:
                return "Invalid email or password"
            case .signUp:
                return "Failed to create account. Please try again."
            case .passwordReset:
                return "Failed to send reset link. Please try again."
            case .passwordChange:
                return "Failed to change password. Please try again."
            case .emailVerification:
                return "Failed to send verification email. Please try again."
            }
        }
    }
    
    // MARK: - LocalizedError Conformance
    
    var errorDescription: String? {
        switch self {
        case .emailAlreadyInUse:
            return "Email already in use"
        case .invalidEmail:
            return "Invalid email address"
        case .wrongPassword:
            return "Wrong password"
        case .userNotFound:
            return "User not found"
        case .weakPassword:
            return "Password is too weak"
        case .tooManyRequests:
            return "Too many requests"
        case .networkError:
            return "Network error"
        case .userCancelled:
            return "User cancelled"
        case .emailNotVerified:
            return "Email not verified"
        case .invalidCredentials:
            return "Invalid credentials"
        case .accountDisabled:
            return "Account disabled"
        case .operationNotAllowed:
            return "Operation not allowed"
        case .unknown(let message, _):
            return message
        }
    }
    
    var failureReason: String? {
        switch self {
        case .emailAlreadyInUse:
            return "This email is already registered"
        case .invalidEmail:
            return "The email address format is invalid"
        case .wrongPassword:
            return "The password is incorrect"
        case .userNotFound:
            return "No account found with this email"
        case .weakPassword:
            return "The password does not meet security requirements"
        case .tooManyRequests:
            return "Too many attempts. Please try again later"
        case .networkError:
            return "Network connection failed"
        case .userCancelled:
            return "The authentication was cancelled"
        case .emailNotVerified:
            return "The email address has not been verified"
        case .invalidCredentials:
            return "The provided credentials are invalid"
        case .accountDisabled:
            return "This account has been disabled"
        case .operationNotAllowed:
            return "This operation is not allowed"
        case .unknown:
            return nil
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .emailAlreadyInUse:
            return "Please use a different email or try logging in."
        case .invalidEmail:
            return "Please check the email address and try again."
        case .wrongPassword:
            return "Please check your password and try again."
        case .userNotFound:
            return "Please check your email or sign up."
        case .weakPassword:
            return "Please use at least 8 characters with letters and numbers."
        case .tooManyRequests:
            return "Please wait a few minutes before trying again."
        case .networkError:
            return "Please check your internet connection and try again."
        case .userCancelled:
            return nil // User cancellation doesn't need a recovery suggestion
        case .emailNotVerified:
            return "Please verify your email address."
        case .invalidCredentials:
            return "Please check your credentials and try again."
        case .accountDisabled:
            return "Please contact support for assistance."
        case .operationNotAllowed:
            return "Please contact support for assistance."
        case .unknown:
            return "Please try again later."
        }
    }
    
    // MARK: - User-Friendly Message
    
    /// Returns a user-friendly error message based on the context
    func userMessage(context: Context = .signIn) -> String {
        switch self {
        case .emailAlreadyInUse:
            switch context {
            case .signIn:
                return "This email is already registered. Please try logging in."
            case .signUp:
                return "This email is already registered. Please use a different email or try logging in."
            default:
                return "This email is already registered."
            }
        case .invalidEmail:
            return "Invalid email address. Please check and try again."
        case .wrongPassword:
            switch context {
            case .passwordChange:
                return "Current password is incorrect. Please try again."
            default:
                return "Invalid email or password"
            }
        case .userNotFound:
            switch context {
            case .passwordReset:
                return "No account found with this email address. Please check your email or sign up."
            case .signIn:
                return "This email is not registered. Please sign up first."
            default:
                return "User not found."
            }
        case .weakPassword:
            return "Password is too weak. Please use at least 8 characters with letters and numbers."
        case .tooManyRequests:
            return "Too many attempts. Please try again later."
        case .networkError:
            return "Network not available. Please check your connection and try again."
        case .userCancelled:
            return "" // User cancellation - don't show message
        case .emailNotVerified:
            return "Email not verified. Please verify your email address."
        case .invalidCredentials:
            switch context {
            case .signIn:
                return "Authentication failed. Please try signing in again."
            case .passwordChange:
                return "Current password is incorrect. Please try again."
            default:
                return "Invalid credentials. Please try again."
            }
        case .accountDisabled:
            return "This account has been disabled. Please contact support."
        case .operationNotAllowed:
            return "This operation is not allowed. Please contact support."
        case .unknown(let message, _):
            return message.isEmpty ? context.defaultMessage : message
        }
    }
    
    /// Returns a user-friendly error message (default context: signIn)
    var userMessage: String {
        return userMessage(context: .signIn)
    }
    
    // MARK: - Properties
    
    /// Whether this error represents a user cancellation
    var isUserCancellation: Bool {
        if case .userCancelled = self {
            return true
        }
        return false
    }
    
    // MARK: - Conversion from Error
    
    /// Converts any Error to AuthError if it's authentication-related
    static func from(_ error: Error) -> AuthError? {
        let nsError = error as NSError
        let errorDomain = nsError.domain
        let errorCode = nsError.code
        let errorDescription = nsError.localizedDescription.lowercased()
        
        // Check for Firebase Auth errors
        if errorDomain == "FIRAuthErrorDomain" {
            switch errorCode {
            case 17007: // Email already in use
                return .emailAlreadyInUse
            case 17008: // Invalid email
                return .invalidEmail
            case 17009: // Wrong password
                return .wrongPassword
            case 17011: // User not found
                return .userNotFound
            case 17004: // Invalid credential (ERROR_INVALID_CREDENTIAL)
                // For email/password login, 17004 with "malformed" or "expired" message
                // often indicates user not found (unregistered email)
                // This is a common Firebase behavior for unregistered emails
                if errorDescription.contains("malformed") || errorDescription.contains("expired") {
                    // For email/password authentication, this likely means user not found
                    return .userNotFound
                }
                // For other cases (e.g., third-party auth token issues), return invalidCredentials
                return .invalidCredentials
            case 17025: // Invalid credential (malformed or expired)
                return .invalidCredentials
            case 17026: // Weak password
                return .weakPassword
            case 17010: // Too many requests
                return .tooManyRequests
            case 17020: // Network error
                return .networkError
            case 17005: // User disabled
                return .accountDisabled
            case 17006: // Operation not allowed
                return .operationNotAllowed
            default:
                return .unknown(message: nsError.localizedDescription, code: errorCode)
            }
        }
        
        // Check for Google Sign-In cancellation
        if errorDomain == "com.google.GIDSignIn" && errorCode == -5 {
            return .userCancelled
        }
        
        // Check for Apple Sign-In cancellation
        if errorDomain == "com.apple.AuthenticationServices.AuthorizationError" && errorCode == 1001 {
            return .userCancelled
        }
        
        // Check for other Apple Sign-In error domains
        if errorDomain.contains("AuthenticationServices") || errorDomain.contains("ASAuthorization") {
            if errorCode == 1001 || errorCode == -1001 {
                return .userCancelled
            }
        }
        
        // Check for cancellation in error description
        if errorDescription.contains("cancel") || errorDescription.contains("cancelled") || errorDescription.contains("user canceled") {
            return .userCancelled
        }
        
        // Check for URL cancellation errors
        if errorDomain == NSURLErrorDomain && errorCode == NSURLErrorCancelled {
            return .userCancelled
        }
        
        // Check for network errors
        if errorDomain == NSURLErrorDomain {
            switch errorCode {
            case NSURLErrorNotConnectedToInternet,
                 NSURLErrorNetworkConnectionLost,
                 NSURLErrorTimedOut,
                 NSURLErrorCannotConnectToHost,
                 NSURLErrorCannotFindHost,
                 NSURLErrorDNSLookupFailed:
                return .networkError
            default:
                break
            }
        }
        
        // Check error description for auth-related keywords
        if errorDescription.contains("user not found") {
            return .userNotFound
        }
        if errorDescription.contains("email already") || errorDescription.contains("already in use") {
            return .emailAlreadyInUse
        }
        if errorDescription.contains("invalid email") {
            return .invalidEmail
        }
        if errorDescription.contains("wrong password") || errorDescription.contains("invalid password") {
            return .wrongPassword
        }
        if errorDescription.contains("weak password") {
            return .weakPassword
        }
        if errorDescription.contains("too many") {
            return .tooManyRequests
        }
        if errorDescription.contains("network") || errorDescription.contains("internet") || errorDescription.contains("connection") {
            return .networkError
        }
        
        return nil
    }
    
    // MARK: - Firebase Auth Error Code Mapping
    
    /// Maps Firebase Auth error codes to AuthError
    static func fromFirebaseAuthError(_ error: NSError) -> AuthError {
        if error.domain == "FIRAuthErrorDomain" {
            switch error.code {
            case 17007:
                return .emailAlreadyInUse
            case 17008:
                return .invalidEmail
            case 17009:
                return .wrongPassword
            case 17011:
                return .userNotFound
            case 17004: // ERROR_INVALID_CREDENTIAL
                return .invalidCredentials
            case 17025:
                return .invalidCredentials
            case 17026:
                return .weakPassword
            case 17010:
                return .tooManyRequests
            case 17020:
                return .networkError
            case 17005:
                return .accountDisabled
            case 17006:
                return .operationNotAllowed
            default:
                return .unknown(message: error.localizedDescription, code: error.code)
            }
        }
        return .unknown(message: error.localizedDescription, code: error.code)
    }
}

