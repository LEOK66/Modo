import SwiftUI
import SwiftData
import FirebaseAuth
import Combine

/// Service to manage and share current user profile across the app
/// This eliminates the need to query UserProfile in every view
class UserProfileService: ObservableObject {
    @Published var currentProfile: UserProfile?
    
    /// Convenience properties for avatar access
    var avatarName: String? {
        currentProfile?.avatarName
    }
    
    var profileImageURL: String? {
        currentProfile?.profileImageURL
    }
    
    var username: String? {
        currentProfile?.username
    }
    
    /// Update the current profile from SwiftData query results
    /// Call this in the root view when profiles change
    func updateProfile(from profiles: [UserProfile]) {
        guard let userId = Auth.auth().currentUser?.uid else {
            currentProfile = nil
            return
        }
        
        currentProfile = profiles.first { $0.userId == userId }
    }
    
    /// Manually set profile (useful after updates)
    func setProfile(_ profile: UserProfile?) {
        // Force objectWillChange to trigger UI updates
        objectWillChange.send()
        currentProfile = profile
    }
}

