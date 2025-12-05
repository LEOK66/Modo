import Foundation
import FirebaseDatabase

/// Service for managing achievement unlock logic and progress tracking
class AchievementService: AchievementServiceProtocol {
    private let databaseService: DatabaseServiceProtocol
    private let database = Database.database().reference()
    
    init(databaseService: DatabaseServiceProtocol) {
        self.databaseService = databaseService
    }
    
    // MARK: - Check and Unlock Achievements
    
    func checkAndUnlockAchievements(
        userId: String,
        statistics: AchievementStatistics
    ) async throws -> [(Achievement, UserAchievement)] {
        // Get current user achievements
        var userAchievements = try await getUserAchievements(userId: userId)
        var newlyUnlocked: [(Achievement, UserAchievement)] = []
        
        // Check each achievement
        for achievement in Achievement.allAchievements {
            let achievementId = achievement.id
            var userAchievement = userAchievements[achievementId] ?? UserAchievement(
                id: achievementId,
                achievementId: achievementId,
                status: .locked,
                currentProgress: 0
            )
            
            // Skip if already unlocked
            if userAchievement.isUnlocked {
                continue
            }
            
            // Get current progress value for this achievement's condition type
            // Support conditions with parameters (macro, timeWindow)
            let currentValue = statistics.value(
                for: achievement.unlockCondition.type,
                macro: achievement.unlockCondition.macro,
                timeWindow: achievement.unlockCondition.timeWindow
            )
            
            // Update progress
            userAchievement.currentProgress = currentValue
            
            // Check if unlock condition is met
            if currentValue >= achievement.unlockCondition.targetValue {
                // Unlock the achievement
                userAchievement.status = .unlocked
                userAchievement.unlockedAt = Date()
                
                // Save to Firebase
                try await saveUserAchievement(userId: userId, userAchievement: userAchievement)
                
                newlyUnlocked.append((achievement, userAchievement))
            } else {
                // Just update progress
                try await saveUserAchievement(userId: userId, userAchievement: userAchievement)
            }
            
            // Update local cache
            userAchievements[achievementId] = userAchievement
        }
        
        return newlyUnlocked
    }
    
    // MARK: - Get User Achievements
    
    func getUserAchievements(userId: String) async throws -> [String: UserAchievement] {
        let path = "users/\(userId)/achievements"
        
        return try await withCheckedThrowingContinuation { continuation in
            database.child(path).observeSingleEvent(of: .value) { snapshot in
                guard snapshot.exists() else {
                    // No achievements yet, return empty dictionary
                    continuation.resume(returning: [:])
                    return
                }
                
                guard let data = snapshot.value as? [String: [String: Any]] else {
                    continuation.resume(returning: [:])
                    return
                }
                
                var userAchievements: [String: UserAchievement] = [:]
                
                for (achievementId, achievementData) in data {
                    if let userAchievement = self.decodeUserAchievement(
                        id: achievementId,
                        data: achievementData
                    ) {
                        userAchievements[achievementId] = userAchievement
                    }
                }
                
                continuation.resume(returning: userAchievements)
            }
        }
    }
    
    // MARK: - Update Progress
    
    func updateProgress(
        userId: String,
        achievementId: String,
        progress: Int
    ) async throws {
        let path = "users/\(userId)/achievements/\(achievementId)"
        
        var updates: [String: Any] = [
            "currentProgress": progress
        ]
        
        // Check if should unlock
        if let achievement = Achievement.achievement(byId: achievementId),
           progress >= achievement.unlockCondition.targetValue {
            updates["status"] = AchievementStatus.unlocked.rawValue
            updates["unlockedAt"] = ServerValue.timestamp()
        }
        
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            database.child(path).updateChildValues(updates) { error, _ in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }
    
    // MARK: - Get Statistics
    
    func getStatistics(userId: String) async throws -> AchievementStatistics {
        // This method should aggregate statistics from various sources
        // For now, return empty statistics - will be implemented based on your data structure
        // You'll need to query tasks, completions, etc. to build this
        return AchievementStatistics()
    }
    
    // MARK: - Private Helpers
    
    private func saveUserAchievement(
        userId: String,
        userAchievement: UserAchievement
    ) async throws {
        let path = "users/\(userId)/achievements/\(userAchievement.id)"
        let data = encodeUserAchievement(userAchievement)
        
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            database.child(path).setValue(data) { error, _ in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }
    
    private func encodeUserAchievement(_ userAchievement: UserAchievement) -> [String: Any] {
        var data: [String: Any] = [
            "id": userAchievement.id,
            "achievementId": userAchievement.achievementId,
            "status": userAchievement.status.rawValue,
            "currentProgress": userAchievement.currentProgress
        ]
        
        if let unlockedAt = userAchievement.unlockedAt {
            data["unlockedAt"] = unlockedAt.timeIntervalSince1970
        }
        
        return data
    }
    
    private func decodeUserAchievement(id: String, data: [String: Any]) -> UserAchievement? {
        guard let achievementId = data["achievementId"] as? String,
              let statusString = data["status"] as? String,
              let status = AchievementStatus(rawValue: statusString),
              let currentProgress = data["currentProgress"] as? Int else {
            return nil
        }
        
        var unlockedAt: Date?
        if let timestamp = data["unlockedAt"] as? TimeInterval {
            unlockedAt = Date(timeIntervalSince1970: timestamp)
        } else if let timestamp = data["unlockedAt"] as? Int {
            unlockedAt = Date(timeIntervalSince1970: TimeInterval(timestamp))
        }
        
        return UserAchievement(
            id: id,
            achievementId: achievementId,
            status: status,
            currentProgress: currentProgress,
            unlockedAt: unlockedAt
        )
    }
}

