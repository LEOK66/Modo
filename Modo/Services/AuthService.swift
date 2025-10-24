import FirebaseAuth
import Combine

final class AuthService: ObservableObject {
    static let shared = AuthService()
    private var authStateListener: AuthStateDidChangeListenerHandle?
    private init() {
        setupAuthStateListener()
        loadOnboardingStatus()
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
