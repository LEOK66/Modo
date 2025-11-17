import Foundation
import FirebaseAuth
import Combine

/// Protocol defining the authentication service interface
/// This protocol allows for dependency injection and testing
protocol AuthServiceProtocol: ObservableObject {
    // MARK: - Published Properties
    
    /// Whether the user is currently authenticated
    var isAuthenticated: Bool { get }
    
    /// The current authenticated user, if any
    var currentUser: User? { get }
    
    /// Whether the user has completed onboarding
    var hasCompletedOnboarding: Bool { get }
    
    // MARK: - Computed Properties
    
    /// Whether the current user needs email verification
    var needsEmailVerification: Bool { get }
    
    // MARK: - Authentication Methods
    
    /// Sign up a new user with email and password
    /// - Parameters:
    ///   - email: User's email address
    ///   - password: User's password
    ///   - completion: Completion handler with result
    func signUp(email: String, password: String, completion: @escaping (Result<User, Error>) -> Void)
    
    /// Sign in an existing user with email and password
    /// - Parameters:
    ///   - email: User's email address
    ///   - password: User's password
    ///   - completion: Completion handler with result
    func signIn(email: String, password: String, completion: @escaping (Result<User, Error>) -> Void)
    
    /// Sign out the current user
    /// - Throws: Error if sign out fails
    func signOut() throws
    
    /// Get the current authenticated user
    /// - Returns: The current user, or nil if not authenticated
    func getCurrentUser() -> User?
    
    /// Reset password for a user
    /// - Parameters:
    ///   - email: User's email address
    ///   - completion: Completion handler with result
    func resetPassword(email: String, completion: @escaping (Result<Void, Error>) -> Void)
    
    /// Change password for the current user
    /// - Parameters:
    ///   - currentPassword: User's current password
    ///   - newPassword: User's new password
    ///   - completion: Completion handler with result
    func changePassword(currentPassword: String, newPassword: String, completion: @escaping (Result<Void, Error>) -> Void)
    
    /// Check if the current user's email is verified
    /// - Parameter completion: Completion handler with verification status
    func checkEmailVerification(completion: @escaping (Bool) -> Void)
    
    // MARK: - Social Authentication
    
    /// Start Apple Sign-In flow
    /// - Parameter completion: Completion handler with result
    func startAppleSignInFlow(completion: @escaping (Result<User, Error>) -> Void)
    
    /// Start Google Sign-In flow
    /// - Parameter completion: Completion handler with result
    func startGoogleSignInFlow(completion: @escaping (Result<User, Error>) -> Void)
    
    // MARK: - Onboarding
    
    /// Mark onboarding as completed for the current user
    func completeOnboarding()
}

