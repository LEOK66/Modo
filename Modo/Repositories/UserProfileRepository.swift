import Foundation
import SwiftData

/// Repository for managing UserProfile data
/// Coordinates between SwiftData (local) and Firebase (cloud) data sources
final class UserProfileRepository: RepositoryProtocol {
    let modelContext: ModelContext
    let databaseService: DatabaseServiceProtocol
    
    /// Initialize UserProfileRepository
    /// - Parameters:
    ///   - modelContext: SwiftData model context for local operations
    ///   - databaseService: Database service for Firebase operations
    init(modelContext: ModelContext, databaseService: DatabaseServiceProtocol) {
        self.modelContext = modelContext
        self.databaseService = databaseService
    }
    
    // MARK: - Local Operations (SwiftData)
    
    /// Fetch user profile from SwiftData
    /// - Parameter userId: User ID to fetch profile for
    /// - Returns: UserProfile if found, nil otherwise
    func fetchLocalProfile(userId: String) -> UserProfile? {
        let descriptor = FetchDescriptor<UserProfile>(
            predicate: #Predicate { $0.userId == userId }
        )
        
        do {
            return try modelContext.fetch(descriptor).first
        } catch {
            print("❌ UserProfileRepository: Failed to fetch local profile - \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Save user profile to SwiftData
    /// - Parameter profile: UserProfile to save
    func saveLocalProfile(_ profile: UserProfile) {
        // Check if profile already exists
        if let existing = fetchLocalProfile(userId: profile.userId) {
            // Update existing profile
            updateLocalProfile(existing, with: profile)
        } else {
            // Insert new profile
            modelContext.insert(profile)
        }
        
        do {
            try modelContext.save()
            print("✅ UserProfileRepository: Profile saved to SwiftData - UserId: \(profile.userId)")
        } catch {
            print("❌ UserProfileRepository: Failed to save profile to SwiftData - \(error.localizedDescription)")
        }
    }
    
    /// Update existing profile with new data
    /// - Parameters:
    ///   - existing: Existing UserProfile in SwiftData
    ///   - new: New UserProfile data to update with
    private func updateLocalProfile(_ existing: UserProfile, with new: UserProfile) {
        existing.username = new.username
        existing.avatarName = new.avatarName
        existing.profileImageURL = new.profileImageURL
        existing.heightValue = new.heightValue
        existing.heightUnit = new.heightUnit
        existing.weightValue = new.weightValue
        existing.weightUnit = new.weightUnit
        existing.age = new.age
        existing.gender = new.gender
        existing.lifestyle = new.lifestyle
        existing.goal = new.goal
        existing.dailyCalories = new.dailyCalories
        existing.dailyProtein = new.dailyProtein
        existing.targetWeightLossValue = new.targetWeightLossValue
        existing.targetWeightLossUnit = new.targetWeightLossUnit
        existing.targetDays = new.targetDays
        existing.goalStartDate = new.goalStartDate
        existing.bufferDays = new.bufferDays
        existing.updatedAt = Date()
    }
    
    // MARK: - Cloud Operations (Firebase)
    
    /// Fetch user profile from Firebase
    /// - Parameters:
    ///   - userId: User ID to fetch profile for
    ///   - completion: Completion handler with UserProfile or error
    func fetchCloudProfile(userId: String, completion: @escaping (Result<UserProfile, Error>) -> Void) {
        databaseService.fetchUserProfile(userId: userId) { result in
            switch result {
            case .success(let profile):
                completion(.success(profile))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    /// Save user profile to Firebase
    /// - Parameters:
    ///   - profile: UserProfile to save
    ///   - completion: Completion handler with result
    func saveCloudProfile(_ profile: UserProfile, completion: ((Result<Void, Error>) -> Void)? = nil) {
        databaseService.saveUserProfile(profile, completion: completion)
    }
    
    /// Update username in Firebase
    /// - Parameters:
    ///   - userId: User ID
    ///   - username: New username
    ///   - completion: Completion handler with result
    func updateCloudUsername(userId: String, username: String, completion: ((Result<Void, Error>) -> Void)? = nil) {
        databaseService.updateUsername(userId: userId, username: username, completion: completion)
    }
    
    // MARK: - Synchronization
    
    /// Sync user profile from Firebase to SwiftData
    /// - Parameters:
    ///   - userId: User ID to sync profile for
    ///   - completion: Completion handler with result
    func syncFromCloud(userId: String, completion: @escaping (Result<UserProfile, Error>) -> Void) {
        fetchCloudProfile(userId: userId) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let cloudProfile):
                // Convert to SwiftData model
                let localProfile = self.fetchLocalProfile(userId: userId) ?? UserProfile(userId: userId)
                self.updateLocalProfile(localProfile, with: cloudProfile)
                self.saveLocalProfile(localProfile)
                completion(.success(localProfile))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    /// Sync user profile from SwiftData to Firebase
    /// - Parameters:
    ///   - userId: User ID to sync profile for
    ///   - completion: Completion handler with result
    func syncToCloud(userId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let localProfile = fetchLocalProfile(userId: userId) else {
            completion(.failure(NSError(domain: "UserProfileRepository", code: 1, userInfo: [NSLocalizedDescriptionKey: "Local profile not found"])))
            return
        }
        
        // Convert SwiftData model to Firebase model
        let cloudProfile = UserProfile(userId: localProfile.userId)
        cloudProfile.username = localProfile.username
        cloudProfile.avatarName = localProfile.avatarName
        cloudProfile.profileImageURL = localProfile.profileImageURL
        cloudProfile.heightValue = localProfile.heightValue
        cloudProfile.heightUnit = localProfile.heightUnit
        cloudProfile.weightValue = localProfile.weightValue
        cloudProfile.weightUnit = localProfile.weightUnit
        cloudProfile.age = localProfile.age
        cloudProfile.gender = localProfile.gender
        cloudProfile.lifestyle = localProfile.lifestyle
        cloudProfile.goal = localProfile.goal
        cloudProfile.dailyCalories = localProfile.dailyCalories
        cloudProfile.dailyProtein = localProfile.dailyProtein
        cloudProfile.targetWeightLossValue = localProfile.targetWeightLossValue
        cloudProfile.targetWeightLossUnit = localProfile.targetWeightLossUnit
        cloudProfile.targetDays = localProfile.targetDays
        cloudProfile.goalStartDate = localProfile.goalStartDate
        cloudProfile.bufferDays = localProfile.bufferDays
        cloudProfile.updatedAt = localProfile.updatedAt
        
        saveCloudProfile(cloudProfile, completion: completion)
    }
    
    /// Save user profile to both SwiftData and Firebase
    /// - Parameters:
    ///   - profile: UserProfile to save
    ///   - syncToCloud: Whether to sync to Firebase (default: true)
    ///   - completion: Completion handler with result
    func saveProfile(_ profile: UserProfile, syncToCloud: Bool = true, completion: ((Result<Void, Error>) -> Void)? = nil) {
        // Save to SwiftData first (offline-first)
        saveLocalProfile(profile)
        
        // Sync to Firebase in background if requested
        if syncToCloud {
            saveCloudProfile(profile) { result in
                switch result {
                case .success:
                    print("✅ UserProfileRepository: Profile synced to Firebase - UserId: \(profile.userId)")
                case .failure(let error):
                    print("⚠️ UserProfileRepository: Failed to sync profile to Firebase - \(error.localizedDescription)")
                }
                completion?(result)
            }
        } else {
            completion?(.success(()))
        }
    }
}








