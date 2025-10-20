import FirebaseAuth

final class AuthService {
    static let shared = AuthService()
    private init() {}

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
}
