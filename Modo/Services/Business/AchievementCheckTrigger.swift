import Foundation
import SwiftData
import FirebaseAuth

/// Helper class to trigger achievement checks at appropriate times
/// This class simplifies the process of checking achievements when events occur
class AchievementCheckTrigger {
    private let achievementService: AchievementServiceProtocol
    private let statisticsCollector: AchievementStatisticsCollector
    private let modelContext: ModelContext
    
    // Cache for previous streak to track restarts
    private var previousStreakCache: [String: Int] = [:]
    
    init(
        achievementService: AchievementServiceProtocol,
        statisticsCollector: AchievementStatisticsCollector,
        modelContext: ModelContext
    ) {
        self.achievementService = achievementService
        self.statisticsCollector = statisticsCollector
        self.modelContext = modelContext
    }
    
    /// Check achievements when a task is completed
    /// - Parameters:
    ///   - userId: User ID
    ///   - tasksByDate: Current tasks dictionary
    ///   - userProfile: User profile for nutrition calculations (optional)
    func checkOnTaskCompleted(
        userId: String,
        tasksByDate: [Date: [TaskItem]],
        userProfile: UserProfile? = nil
    ) {
        Task {
            do {
                // Get previous streak for tracking restarts
                let previousStreak = previousStreakCache[userId]
                
                // Collect current statistics (async version for complete stats including streak history)
                let statistics = try await statisticsCollector.collectStatisticsAsync(
                    userId: userId,
                    tasksByDate: tasksByDate,
                    userProfile: userProfile,
                    previousStreak: previousStreak
                )
                
                // Update streak cache
                previousStreakCache[userId] = statistics.streak
                
                // Check and unlock achievements
                let newlyUnlocked = try await achievementService.checkAndUnlockAchievements(
                    userId: userId,
                    statistics: statistics
                )
                
                // Queue unlock animations
                for (achievement, userAchievement) in newlyUnlocked {
                    AchievementUnlockManager.shared.queueUnlock(
                        achievement: achievement,
                        userAchievement: userAchievement
                    )
                }
            } catch {
                print("❌ Error checking achievements: \(error)")
            }
        }
    }
    
    /// Check achievements when streak changes
    /// - Parameters:
    ///   - userId: User ID
    ///   - tasksByDate: Current tasks dictionary
    ///   - userProfile: User profile for nutrition calculations (optional)
    func checkOnStreakChanged(
        userId: String,
        tasksByDate: [Date: [TaskItem]],
        userProfile: UserProfile? = nil
    ) {
        checkOnTaskCompleted(userId: userId, tasksByDate: tasksByDate, userProfile: userProfile)
    }
    
    /// Check achievements when app launches (to catch any missed unlocks)
    /// - Parameters:
    ///   - userId: User ID
    ///   - tasksByDate: Current tasks dictionary
    ///   - userProfile: User profile for nutrition calculations (optional)
    func checkOnAppLaunch(
        userId: String,
        tasksByDate: [Date: [TaskItem]],
        userProfile: UserProfile? = nil
    ) {
        checkOnTaskCompleted(userId: userId, tasksByDate: tasksByDate, userProfile: userProfile)
    }
    
    /// Check achievements when a challenge is completed
    /// - Parameters:
    ///   - userId: User ID
    ///   - tasksByDate: Current tasks dictionary
    ///   - userProfile: User profile for nutrition calculations (optional)
    func checkOnChallengeCompleted(
        userId: String,
        tasksByDate: [Date: [TaskItem]],
        userProfile: UserProfile? = nil
    ) {
        checkOnTaskCompleted(userId: userId, tasksByDate: tasksByDate, userProfile: userProfile)
    }
}

