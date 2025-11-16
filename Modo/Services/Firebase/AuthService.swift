import FirebaseAuth
import Combine
import UIKit
import FirebaseCore
import GoogleSignIn
import GoogleSignInSwift
import AuthenticationServices
import CryptoKit


final class AuthService: ObservableObject, AuthServiceProtocol {
    // Optional dependency for challenge service (injected via dependency injection)
    // This allows AuthService to reset challenge state on sign out without direct dependency
    weak var challengeService: ChallengeServiceProtocol?
    
    private var authStateListener: AuthStateDidChangeListenerHandle?
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var hasCompletedOnboarding = false
    private var appleSignInDelegate: AppleSignInDelegate?
    private var appleSignInPresentationProvider: AppleSignInPresentationContextProvider?
    
    /// Initialize with optional challenge service dependency
    /// This allows for dependency injection while maintaining backward compatibility
    /// - Parameter challengeService: Optional challenge service for dependency injection
    init(challengeService: ChallengeServiceProtocol? = nil) {
        self.challengeService = challengeService
        setupAuthStateListener()
        if let user = Auth.auth().currentUser {
            self.currentUser = user
            self.isAuthenticated = true
            loadOnboardingStatus()
        }
    }
    
    /// Shared singleton instance (for backward compatibility)
    /// Note: Uses ServiceContainer for dependency injection even in fallback case
    static let shared: AuthService = {
        // Use ServiceContainer to get challenge service (ensures proper dependency injection)
        // This maintains backward compatibility while using the new architecture
        let challengeService = ServiceContainer.shared.challengeService
        return AuthService(challengeService: challengeService)
    }()
    
    // MARK: - Email Verification Status
    /// Determines if the current user needs email verification
    /// Apple/Google users are automatically considered verified
    var needsEmailVerification: Bool {
        guard let user = currentUser ?? Auth.auth().currentUser else {
            return false
        }
        
        // Apple/Google users don't need email verification
        let isThirdPartyAuth = user.providerData.contains { provider in
            provider.providerID == "apple.com" || provider.providerID == "google.com"
        }
        
        return !isThirdPartyAuth && !user.isEmailVerified
    }

    // MARK: - Create Account
    func signUp(email: String, password: String, completion: @escaping (Result<User, Error>) -> Void) {
        Auth.auth().createUser(withEmail: email, password: password) { result, error in
            if let error = error {
                completion(.failure(error))
            } else if let user = result?.user {
                user.sendEmailVerification { error in
                    if let error = error {
                        print("Error sending verification: \(error)")
                    }
                }
                completion(.success(user))
            }
        }
    }

    // MARK: - Sign In
    func signIn(email: String, password: String, completion: @escaping (Result<User, Error>) -> Void) {
        Auth.auth().signIn(withEmail: email, password: password) { result, error in
            if let error = error {
                completion(.failure(error))
            } else if let user = result?.user {
                completion(.success(user))
            }
        }
    }

    // MARK: - Sign Out
    func signOut() throws {
        // Reset challenge state if challenge service is available
        // Note: challengeService should always be injected via ServiceContainer
        challengeService?.resetState()
        
        try Auth.auth().signOut()
    }

    // MARK: - Check Auth State
    func getCurrentUser() -> User? {
        return Auth.auth().currentUser
    }

    // MARK: - Auth State Management
    private func setupAuthStateListener() {
        authStateListener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            DispatchQueue.main.async {
                self?.currentUser = user
                self?.isAuthenticated = user != nil
                if user != nil {
                    self?.loadOnboardingStatus()
                } else {
                    self?.hasCompletedOnboarding = false
                }
            }
        }
    }

    // MARK: - Password Reset
    func resetPassword(email: String, completion: @escaping (Result<Void, Error>) -> Void) {
        Auth.auth().sendPasswordReset(withEmail: email) { error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }
    }

    func checkEmailVerification(completion: @escaping (Bool) -> Void) {
        guard let user = Auth.auth().currentUser else {
            completion(false)
            return
        }
        
        let cachedVerificationStatus = user.isEmailVerified
        
        user.reload { [weak self] error in
            DispatchQueue.main.async {
                if let error = error {
                    print("Error reloading user: \(error.localizedDescription)")
                    print("Using cached verification status: \(cachedVerificationStatus)")
                    completion(cachedVerificationStatus)
                } else {
                    // Update currentUser to trigger UI refresh
                    // This ensures needsEmailVerification will reflect the updated state
                    if let updatedUser = Auth.auth().currentUser {
                        self?.currentUser = updatedUser
                    }
                    completion(user.isEmailVerified)
                }
            }
        }
    }
    
    // MARK: - Google Sign-In (Internal - use startGoogleSignInFlow instead)
    // Note: Changed from private to internal to allow testing with @testable import
    func signInWithGoogle(presentingViewController: UIViewController,
                          completion: @escaping (Result<User, Error>) -> Void) {
        print("🔵 AuthService: Starting Google Sign In")
        
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            completion(.failure(NSError(domain: "AuthService", code: -1,
                                        userInfo: [NSLocalizedDescriptionKey: "Missing client ID"])))
            return
        }
        
        // Configure Google Sign-In
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config
        
        // Start the sign-in flow
        GIDSignIn.sharedInstance.signIn(withPresenting: presentingViewController) { result, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard
                let idToken = result?.user.idToken?.tokenString,
                let accessToken = result?.user.accessToken.tokenString
            else {
                completion(.failure(NSError(domain: "AuthService", code: -2,
                                            userInfo: [NSLocalizedDescriptionKey: "Missing tokens"])))
                return
            }
            
            let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: accessToken)
            
            // Sign in to Firebase
            Auth.auth().signIn(with: credential) { authResult, error in
                if let error = error {
                    completion(.failure(error))
                } else if let user = authResult?.user {
                    completion(.success(user))
                }
            }
        }
    }
    
    // MARK: - Apple Sign-In (Internal - use startAppleSignInFlow instead)
    private func signInWithApple(authorization: ASAuthorization, 
                                  nonce: String,
                                  completion: @escaping (Result<User, Error>) -> Void) {
        print("🔵 AuthService: Starting Apple Sign In")
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            completion(.failure(NSError(domain: "AuthService", code: -3,
                                        userInfo: [NSLocalizedDescriptionKey: "Invalid Apple ID credential"])))
            return
        }
        
        guard let identityToken = appleIDCredential.identityToken,
              let idTokenString = String(data: identityToken, encoding: .utf8) else {
            completion(.failure(NSError(domain: "AuthService", code: -4,
                                        userInfo: [NSLocalizedDescriptionKey: "Missing identity token"])))
            return
        }

        // Create Firebase credential for Apple Sign-In
        let credential = OAuthProvider.appleCredential(withIDToken: idTokenString,
                                                        rawNonce: nonce,
                                                        fullName: appleIDCredential.fullName)
        
        // Sign in to Firebase
        Auth.auth().signIn(with: credential) { [weak self] authResult, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(.failure(error))
                } else if let user = authResult?.user {
                    // Force update auth state immediately for Apple Sign-In
                    self?.currentUser = user
                    self?.isAuthenticated = true
                    self?.loadOnboardingStatus()
                    completion(.success(user))
                } else {
                    completion(.failure(NSError(domain: "AuthService", code: -6,
                                                userInfo: [NSLocalizedDescriptionKey: "No user returned from sign in"])))
                }
            }
        }
    }
    
    // MARK: - Helper: Generate Nonce for Apple Sign-In
    static func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: [Character] =
        Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length
        
        while remainingLength > 0 {
            let randoms: [UInt8] = (0..<16).map { _ in
                var random: UInt8 = 0
                let errorCode = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
                if errorCode != errSecSuccess {
                    fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
                }
                return random
            }
            
            randoms.forEach { random in
                if remainingLength == 0 {
                    return
                }
                
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }
        
        return result
    }
    
    // MARK: - Helper: SHA256 Hash for Apple Sign-In
    static func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap {
            String(format: "%02x", $0)
        }.joined()
        
        return hashString
    }
    
    // MARK: - High-Level Social Auth Methods
    /// Starts the Apple Sign-In flow, handling all UI setup internally
    /// This method encapsulates nonce generation, ASAuthorizationController creation, and delegate management
    func startAppleSignInFlow(completion: @escaping (Result<User, Error>) -> Void) {
        let nonce = AuthService.randomNonceString()
        let hashedNonce = AuthService.sha256(nonce)
        
        let appleIDProvider = ASAuthorizationAppleIDProvider()
        let request = appleIDProvider.createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = hashedNonce
        
        // Create delegate and presentation provider - keep strong references
        appleSignInDelegate = AppleSignInDelegate(
            authService: self,
            nonce: nonce,
            onSuccess: { user in
                completion(.success(user))
            },
            onError: { error in
                completion(.failure(error))
            }
        )
        
        appleSignInPresentationProvider = AppleSignInPresentationContextProvider()
        
        guard let delegate = appleSignInDelegate, let provider = appleSignInPresentationProvider else {
            completion(.failure(NSError(domain: "AuthService", code: -7,
                                        userInfo: [NSLocalizedDescriptionKey: "Failed to create Apple Sign-In components"])))
            return
        }
        
        let authorizationController = ASAuthorizationController(authorizationRequests: [request])
        authorizationController.delegate = delegate
        authorizationController.presentationContextProvider = provider
        authorizationController.performRequests()
    }
    
    // MARK: - Apple Sign-In Delegate (Private)
    private class AppleSignInDelegate: NSObject, ASAuthorizationControllerDelegate {
        weak var authService: AuthService?
        let nonce: String
        let onSuccess: (User) -> Void
        let onError: (Error) -> Void
        
        init(authService: AuthService, nonce: String, onSuccess: @escaping (User) -> Void, onError: @escaping (Error) -> Void) {
            self.authService = authService
            self.nonce = nonce
            self.onSuccess = onSuccess
            self.onError = onError
        }
        
        func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
            guard let authService = authService else {
                onError(NSError(domain: "AuthService", code: -9, userInfo: [NSLocalizedDescriptionKey: "AuthService deallocated"]))
                return
            }
            
            authService.signInWithApple(authorization: authorization, nonce: nonce) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let user):
                        self.onSuccess(user)
                    case .failure(let error):
                        self.onError(error)
                    }
                }
            }
        }
        
        func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
            onError(error)
        }
    }

    // MARK: - Apple Sign-In Presentation Context Provider (Private)
    private class AppleSignInPresentationContextProvider: NSObject, ASAuthorizationControllerPresentationContextProviding {
        func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let window = windowScene.windows.first else {
                fatalError("No window found")
            }
            return window
        }
    }
    
    /// Starts the Google Sign-In flow, automatically finding the presenting view controller
    /// This method encapsulates the view controller lookup logic
    func startGoogleSignInFlow(completion: @escaping (Result<User, Error>) -> Void) {
        guard let topViewController = findTopViewController() else {
            completion(.failure(NSError(domain: "AuthService", code: -8,
                                        userInfo: [NSLocalizedDescriptionKey: "Unable to start Google Sign In. Please try again."])))
            return
        }
        
        signInWithGoogle(presentingViewController: topViewController, completion: completion)
    }
    
    // MARK: - Helper: Find Top View Controller
    private func findTopViewController() -> UIViewController? {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            return nil
        }
        
        var topController = window.rootViewController
        while let presentedController = topController?.presentedViewController {
            topController = presentedController
        }
        
        return topController
    }
    
    // MARK: - Onboarding Status
    func completeOnboarding() {
        hasCompletedOnboarding = true
        saveOnboardingStatus()
    }
    
    private func loadOnboardingStatus() {
        if let userId = Auth.auth().currentUser?.uid {
            hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding_\(userId)")
        }
    }
    
    private func saveOnboardingStatus() {
        if let userId = Auth.auth().currentUser?.uid {
            UserDefaults.standard.set(hasCompletedOnboarding, forKey: "hasCompletedOnboarding_\(userId)")
        }
    }
}
