import Foundation
import Combine
import FirebaseAuth
@testable import Modo

/// Mock implementation of AuthServiceProtocol for testing
/// This allows tests to run without actual Firebase authentication
final class MockAuthService: AuthServiceProtocol {
    // MARK: - Published Properties
    @Published var isAuthenticated: Bool = false
    @Published var currentUser: User?
    @Published var hasCompletedOnboarding: Bool = false
    
    // MARK: - Computed Properties
    var needsEmailVerification: Bool {
        guard let user = currentUser else { return false }
        let isThirdPartyAuth = user.providerData.contains { provider in
            provider.providerID == "apple.com" || provider.providerID == "google.com"
        }
        return !isThirdPartyAuth && !user.isEmailVerified
    }
    
    // MARK: - Test Configuration
    var shouldSucceedSignUp = true
    var shouldSucceedSignIn = true
    var shouldSucceedPasswordReset = true
    var shouldSucceedPasswordChange = true
    var shouldSucceedGoogleSignIn = true
    var shouldSucceedAppleSignIn = true
    var mockError: Error?
    var mockUser: User?
    
    // MARK: - Call Tracking
    var signUpCallCount = 0
    var signInCallCount = 0
    var signOutCallCount = 0
    var resetPasswordCallCount = 0
    var changePasswordCallCount = 0
    var lastSignUpEmail: String?
    var lastSignInEmail: String?
    
    // MARK: - Authentication Methods
    func signUp(email: String, password: String, completion: @escaping (Result<User, Error>) -> Void) {
        signUpCallCount += 1
        lastSignUpEmail = email
        
        if let error = mockError {
            completion(.failure(error))
            return
        }
        
        if shouldSucceedSignUp {
            // Note: In real tests, you should use Firebase Auth Emulator or set mockUser
            // For now, we'll use mockUser if provided, otherwise we can't create a real User
            if let user = mockUser {
                currentUser = user
                isAuthenticated = true
                completion(.success(user))
            } else {
                // Without Firebase Auth Emulator, we can't create a real User object
                // Tests should either set mockUser or use Firebase Auth Emulator
                completion(.failure(NSError(domain: "MockAuthService", code: -999, userInfo: [NSLocalizedDescriptionKey: "mockUser not set. Use Firebase Auth Emulator or set mockUser in test"])))
            }
        } else {
            completion(.failure(NSError(domain: "MockAuthService", code: 17007, userInfo: [NSLocalizedDescriptionKey: "Email already in use"])))
        }
    }
    
    func signIn(email: String, password: String, completion: @escaping (Result<User, Error>) -> Void) {
        signInCallCount += 1
        lastSignInEmail = email
        
        if let error = mockError {
            completion(.failure(error))
            return
        }
        
        if shouldSucceedSignIn {
            if let user = mockUser {
                currentUser = user
                isAuthenticated = true
                completion(.success(user))
            } else {
                completion(.failure(NSError(domain: "MockAuthService", code: -999, userInfo: [NSLocalizedDescriptionKey: "mockUser not set. Use Firebase Auth Emulator or set mockUser in test"])))
            }
        } else {
            completion(.failure(NSError(domain: "MockAuthService", code: 17011, userInfo: [NSLocalizedDescriptionKey: "Invalid email or password"])))
        }
    }
    
    func signOut() throws {
        signOutCallCount += 1
        currentUser = nil
        isAuthenticated = false
        hasCompletedOnboarding = false
    }
    
    func getCurrentUser() -> User? {
        return currentUser
    }
    
    func resetPassword(email: String, completion: @escaping (Result<Void, Error>) -> Void) {
        resetPasswordCallCount += 1
        
        if let error = mockError {
            completion(.failure(error))
            return
        }
        
        if shouldSucceedPasswordReset {
            completion(.success(()))
        } else {
            completion(.failure(NSError(domain: "MockAuthService", code: 17011, userInfo: [NSLocalizedDescriptionKey: "User not found"])))
        }
    }
    
    func changePassword(currentPassword: String, newPassword: String, completion: @escaping (Result<Void, Error>) -> Void) {
        changePasswordCallCount += 1
        
        if let error = mockError {
            completion(.failure(error))
            return
        }
        
        if shouldSucceedPasswordChange {
            completion(.success(()))
        } else {
            completion(.failure(NSError(domain: "MockAuthService", code: 17014, userInfo: [NSLocalizedDescriptionKey: "Invalid password"])))
        }
    }
    
    func checkEmailVerification(completion: @escaping (Bool) -> Void) {
        guard let user = currentUser else {
            completion(false)
            return
        }
        completion(user.isEmailVerified)
    }
    
    func startAppleSignInFlow(completion: @escaping (Result<User, Error>) -> Void) {
        if let error = mockError {
            completion(.failure(error))
            return
        }
        
        if shouldSucceedAppleSignIn {
            if let user = mockUser {
                currentUser = user
                isAuthenticated = true
                completion(.success(user))
            } else {
                completion(.failure(NSError(domain: "MockAuthService", code: -999, userInfo: [NSLocalizedDescriptionKey: "mockUser not set. Use Firebase Auth Emulator or set mockUser in test"])))
            }
        } else {
            completion(.failure(NSError(domain: "MockAuthService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Apple Sign-In failed"])))
        }
    }
    
    func startGoogleSignInFlow(completion: @escaping (Result<User, Error>) -> Void) {
        if let error = mockError {
            completion(.failure(error))
            return
        }
        
        if shouldSucceedGoogleSignIn {
            if let user = mockUser {
                currentUser = user
                isAuthenticated = true
                completion(.success(user))
            } else {
                completion(.failure(NSError(domain: "MockAuthService", code: -999, userInfo: [NSLocalizedDescriptionKey: "mockUser not set. Use Firebase Auth Emulator or set mockUser in test"])))
            }
        } else {
            completion(.failure(NSError(domain: "MockAuthService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Google Sign-In failed"])))
        }
    }
    
    func completeOnboarding() {
        hasCompletedOnboarding = true
    }
    
    // MARK: - Helper Methods
    // Note: Firebase User objects cannot be easily mocked without Firebase Auth Emulator
    // For unit tests, we recommend:
    // 1. Using Firebase Auth Emulator for integration tests
    // 2. Testing business logic separately from Firebase Auth
    // 3. Setting mockUser directly in tests when needed
    // For now, tests should set mockUser before calling methods that need it
    
    // MARK: - Test Helpers
    func reset() {
        isAuthenticated = false
        currentUser = nil
        hasCompletedOnboarding = false
        shouldSucceedSignUp = true
        shouldSucceedSignIn = true
        shouldSucceedPasswordReset = true
        shouldSucceedPasswordChange = true
        shouldSucceedGoogleSignIn = true
        shouldSucceedAppleSignIn = true
        mockError = nil
        mockUser = nil
        signUpCallCount = 0
        signInCallCount = 0
        signOutCallCount = 0
        resetPasswordCallCount = 0
        changePasswordCallCount = 0
        lastSignUpEmail = nil
        lastSignInEmail = nil
    }
}

