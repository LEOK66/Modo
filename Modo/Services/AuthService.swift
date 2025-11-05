import FirebaseAuth
import Combine
import UIKit
import FirebaseCore
import GoogleSignIn
import GoogleSignInSwift
import AuthenticationServices
import CryptoKit


final class AuthService: ObservableObject {
    static let shared = AuthService()
    private var authStateListener: AuthStateDidChangeListenerHandle?
    private init() {
        // Immediately check current user state synchronously
        let currentUser = Auth.auth().currentUser
        self.currentUser = currentUser
        self.isAuthenticated = currentUser != nil
        if currentUser != nil {
            loadOnboardingStatus()
        }
        setupAuthStateListener()
    }   
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var hasCompletedOnboarding = false

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
        // Reset DailyChallengeService state before signing out
        DailyChallengeService.shared.resetState()
        
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
        
        // Store cached verification status before reload
        let cachedVerificationStatus = user.isEmailVerified
        
        user.reload { error in
            DispatchQueue.main.async {
                if let error = error {
                    // If reload fails (e.g., no network), use cached verification status
                    // This prevents showing email verification page for already-verified users when offline
                    print("Error reloading user: \(error.localizedDescription)")
                    print("Using cached verification status: \(cachedVerificationStatus)")
                    completion(cachedVerificationStatus)
                } else {
                    // Reload successful, use the latest verification status
                    completion(user.isEmailVerified)
                }
            }
        }
    }
    
    // MARK: - Google Sign-In
    func signInWithGoogle(presentingViewController: UIViewController,
                          completion: @escaping (Result<User, Error>) -> Void) {
        print("🔵 AuthService: Starting Google Sign In")
        
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            print("❌ AuthService: Missing client ID")
            completion(.failure(NSError(domain: "AuthService", code: -1,
                                        userInfo: [NSLocalizedDescriptionKey: "Missing client ID"])))
            return
        }
        
        print("✅ AuthService: Client ID found: \(clientID)")
        
        // Configure Google Sign-In
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config
        
        print("🔵 AuthService: Starting Google Sign In flow")
        
        // Start the sign-in flow
        GIDSignIn.sharedInstance.signIn(withPresenting: presentingViewController) { result, error in
            if let error = error {
                print("❌ AuthService: Google Sign In error: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            print("✅ AuthService: Google Sign In successful, processing tokens")
            
            guard
                let idToken = result?.user.idToken?.tokenString,
                let accessToken = result?.user.accessToken.tokenString
            else {
                print("❌ AuthService: Missing tokens")
                completion(.failure(NSError(domain: "AuthService", code: -2,
                                            userInfo: [NSLocalizedDescriptionKey: "Missing tokens"])))
                return
            }
            
            print("✅ AuthService: Tokens received, signing in to Firebase")
            
            let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: accessToken)
            
            // Sign in to Firebase
            Auth.auth().signIn(with: credential) { authResult, error in
                if let error = error {
                    print("❌ AuthService: Firebase sign in error: \(error.localizedDescription)")
                    completion(.failure(error))
                } else if let user = authResult?.user {
                    print("✅ AuthService: Firebase sign in successful for user: \(user.uid)")
                    completion(.success(user))
                }
            }
        }
    }
    
    // MARK: - Apple Sign-In
    func signInWithApple(authorization: ASAuthorization, 
                        nonce: String,
                        completion: @escaping (Result<User, Error>) -> Void) {
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
    
    // MARK: - Onboarding Status
    func completeOnboarding() {
        hasCompletedOnboarding = true
        saveOnboardingStatus()
    }
    
    private func loadOnboardingStatus() {
        // Load from UserDefaults or Firebase
        // For now, using UserDefaults
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
