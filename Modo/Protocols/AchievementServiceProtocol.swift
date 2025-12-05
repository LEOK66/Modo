import Foundation

/// Protocol for achievement unlock management
protocol AchievementServiceProtocol {
    /// Check and unlock achievements based on current statistics
    /// - Parameters:
    ///   - userId: User ID
    ///   - statistics: Current user statistics
    /// - Returns: Array of newly unlocked achievements (Achievement, UserAchievement)
    func checkAndUnlockAchievements(
        userId: String,
        statistics: AchievementStatistics
    ) async throws -> [(Achievement, UserAchievement)]
    
    /// Get user's achievement progress for all achievements
    /// - Parameter userId: User ID
    /// - Returns: Dictionary mapping achievement ID to UserAchievement
    func getUserAchievements(userId: String) async throws -> [String: UserAchievement]
    
    /// Update achievement progress without checking unlock
    /// - Parameters:
    ///   - userId: User ID
    ///   - achievementId: Achievement ID
    ///   - progress: New progress value
    func updateProgress(
        userId: String,
        achievementId: String,
        progress: Int
    ) async throws
    
    /// Get current statistics for a user
    /// - Parameter userId: User ID
    /// - Returns: Current statistics
    func getStatistics(userId: String) async throws -> AchievementStatistics
}

// MARK: - Achievement Statistics

/// Statistics used to check achievement unlock conditions
struct AchievementStatistics: Codable, Equatable {
    // MARK: - Basic Statistics (Priority 1)
    var streak: Int = 0
    var totalTasks: Int = 0
    var fitnessTasks: Int = 0
    var dietTasks: Int = 0
    var challenges: Int = 0
    var aiTasks: Int = 0
    
    // MARK: - Time-based Statistics (Priority 1)
    var dietTasksAfter11PM: Int = 0
    var timeOfDayTasksBefore7AM: Int = 0
    var timeOfDayTasksAfterMidnight: Int = 0
    var allTimePeriodsDays: Int = 0 // Days with tasks in all 4 time periods
    
    // MARK: - Diet & Macro Statistics (Priority 2)
    var calorieAccuracyStreak: Int = 0 // Consecutive days within ±50 calories
    var macroStreakProtein: Int = 0 // Consecutive days meeting protein target
    var macroStreakCarbs: Int = 0 // Consecutive days meeting carbs target
    var macroStreakFats: Int = 0 // Consecutive days meeting fats target
    var allMacrosStreak: Int = 0 // Consecutive days meeting all macro targets
    var dietTasksSkippedStreak: Int = 0 // Consecutive days over calorie target by 1000
    
    // MARK: - Daily Challenge Statistics (Priority 2)
    var dailyChallengeTotal: Int = 0
    var dailyTasksTotal: Int = 0
    var dailyChallengesStreak: Int = 0
    var aiGeneratedTasksAdded: Int = 0
    
    // MARK: - Streak History Statistics (Priority 3)
    var streakRestarts: Int = 0
    var streakComeback: Int = 0 // Current streak after a break
    
    // MARK: - Weekly Statistics (Priority 3)
    var weekendOnlyStreak: Int = 0 // Consecutive weeks
    var allCategoriesInWeekStreak: Int = 0 // Consecutive weeks
    
    // MARK: - Daily Completion Statistics (Priority 3)
    var consecutiveDaysSkipped: Int = 0
    var almostPerfectDays: Int = 0 // Days with 4/5 tasks completed
    
    // MARK: - AI Usage Statistics (Priority 4 - Placeholder, not implemented yet)
    var aiPlansGenerated: Int = 0
    var insightsPageVisits: Int = 0
    var aiGoalsCompleted: Int = 0
    var aiFeatureUsage: Int = 0
    var aiPlanRegenerations: Int = 0
    
    // MARK: - Other Statistics (Priority 4 - Placeholder, not implemented yet)
    var remindersSnoozed: Int = 0
    var taskRescheduled: Int = 0
    
    /// Get value for a specific condition type
    /// - Parameters:
    ///   - conditionType: The condition type to get value for
    ///   - macro: Optional macro parameter for macroStreak condition ("protein", "carbs", "fats")
    ///   - timeWindow: Optional time window parameter for timeOfDayTasks condition ("before_7am", "after_midnight")
    /// - Returns: The statistic value for the condition
    func value(
        for conditionType: UnlockCondition.ConditionType,
        macro: String? = nil,
        timeWindow: String? = nil
    ) -> Int {
        switch conditionType {
        // Basic conditions
        case .streak:
            return streak
        case .totalTasks:
            return totalTasks
        case .fitnessTasks:
            return fitnessTasks
        case .dietTasks:
            return dietTasks
        case .challenges:
            return challenges
        case .aiTasks:
            return aiTasks
            
        // Streak variations
        case .streakRestarts:
            return streakRestarts
        case .streakComeback:
            return streakComeback
            
        // Diet variations
        case .dietTasksSkipped:
            return dietTasksSkippedStreak
        case .dietTasksAfter11PM:
            return dietTasksAfter11PM
            
        // Macros
        case .macroStreak:
            guard let macro = macro else { return 0 }
            switch macro.lowercased() {
            case "protein":
                return macroStreakProtein
            case "carbs", "carbohydrates":
                return macroStreakCarbs
            case "fats", "fat":
                return macroStreakFats
            default:
                return 0
            }
        case .allMacrosStreak:
            return allMacrosStreak
        case .calorieAccuracy:
            return calorieAccuracyStreak
            
        // Time of day
        case .timeOfDayTasks:
            guard let timeWindow = timeWindow else { return 0 }
            switch timeWindow.lowercased() {
            case "before_7am":
                return timeOfDayTasksBefore7AM
            case "after_midnight":
                return timeOfDayTasksAfterMidnight
            default:
                return 0
            }
        case .allTimePeriods:
            return allTimePeriodsDays
            
        // Daily Challenge
        case .dailyChallengeTotal:
            return dailyChallengeTotal
        case .dailyTasksTotal:
            return dailyTasksTotal
        case .dailyChallengesStreak:
            return dailyChallengesStreak
        case .aiGeneratedTasksAdded:
            return aiGeneratedTasksAdded
            
        // AI Usage (Priority 4 - not implemented yet)
        case .aiPlansGenerated:
            return aiPlansGenerated
        case .insightsPageVisits:
            return insightsPageVisits
        case .aiGoalsCompleted:
            return aiGoalsCompleted
        case .aiFeatureUsage:
            return aiFeatureUsage
        case .aiPlanRegenerations:
            return aiPlanRegenerations
            
        // Humor
        case .consecutiveDaysSkipped:
            return consecutiveDaysSkipped
        case .remindersSnoozed:
            return remindersSnoozed
        case .almostPerfectDays:
            return almostPerfectDays
        case .weekendOnlyStreak:
            return weekendOnlyStreak
        case .taskRescheduled:
            return taskRescheduled
            
        // Special
        case .allCategoriesInWeek:
            return allCategoriesInWeekStreak
        }
    }
}

