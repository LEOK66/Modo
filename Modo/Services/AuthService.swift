import FirebaseAuth
import Combine
import UIKit
import FirebaseCore
import GoogleSignIn
import GoogleSignInSwift


final class AuthService: ObservableObject {
    static let shared = AuthService()
    private var authStateListener: AuthStateDidChangeListenerHandle?
    private init() {
        setupAuthStateListener()
    }   
    @Published var isAuthenticated = false
    @Published var currentUser: User?

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
        
        user.reload { error in
            if let error = error {
                print("Error reloading user: \(error)")
                completion(false)
            } else {
                completion(user.isEmailVerified)
            }
        }
    }
    
    // MARK: - Google Sign-In
    func signInWithGoogle(presentingViewController: UIViewController,
                          completion: @escaping (Result<User, Error>) -> Void) {
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
}
