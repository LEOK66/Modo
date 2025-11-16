import Foundation
import FirebaseFunctions
import FirebaseAuth

/// Service for managing user account operations
final class AccountService {
    static let shared = AccountService()
    private let functions: Functions
    
    private init() {
        self.functions = Functions.functions()
    }
    
    // MARK: - Delete Account
    /// Deletes the current user's account and all associated data
    /// This calls the Cloud Function which handles:
    /// - Deleting all user data from Realtime Database
    /// - Deleting all user files from Storage
    /// - Deleting the user account from Firebase Auth
    ///
    /// - Parameter completion: Completion handler with result
    func deleteAccount(completion: @escaping (Result<Void, Error>) -> Void) {
        // Verify user is authenticated
        guard let user = Auth.auth().currentUser else {
            completion(.failure(NSError(
                domain: "AccountService",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "User must be authenticated to delete account"]
            )))
            return
        }
        
        print("🗑️ [AccountService] Requesting account deletion for user: \(user.uid)")
        
        // Call Cloud Function
        let callable = functions.httpsCallable("deleteAccount")
        
        // No data needed - Cloud Function uses request.auth to get userId
        callable.call(nil) { result, error in
            if let error = error {
                print("❌ [AccountService] Error deleting account: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            // Parse response
            guard let response = result?.data as? [String: Any],
                  let success = response["success"] as? Bool else {
                let error = NSError(
                    domain: "AccountService",
                    code: -2,
                    userInfo: [NSLocalizedDescriptionKey: "Invalid response from server"]
                )
                completion(.failure(error))
                return
            }
            
            if success {
                print("✅ [AccountService] Account deleted successfully")
                completion(.success(()))
            } else {
                let errorMessage = response["error"] as? String ?? "Unknown error occurred"
                let error = NSError(
                    domain: "AccountService",
                    code: -3,
                    userInfo: [NSLocalizedDescriptionKey: errorMessage]
                )
                print("❌ [AccountService] Account deletion failed: \(errorMessage)")
                completion(.failure(error))
            }
        }
    }
}

