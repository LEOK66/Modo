import Foundation
import SwiftUI

// MARK: - Achievement Model

/// Represents an achievement that users can unlock
struct Achievement: Identifiable, Codable, Equatable {
    let id: String
    let title: String
    let description: String
    let iconName: String // SF Symbol or asset name
    let iconColor: String // Hex color for the icon
    let category: AchievementCategory
    let unlockCondition: UnlockCondition
    let order: Int // Display order in the list
    
    init(
        id: String,
        title: String,
        description: String,
        iconName: String,
        iconColor: String,
        category: AchievementCategory,
        unlockCondition: UnlockCondition,
        order: Int = 0
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.iconName = iconName
        self.iconColor = iconColor
        self.category = category
        self.unlockCondition = unlockCondition
        self.order = order
    }
}

// MARK: - Achievement Category

enum AchievementCategory: String, Codable {
    case streak = "streak"
    case task = "task"
    case challenge = "challenge"
    case fitness = "fitness"
    case diet = "diet"
    case ai = "ai"
    case milestone = "milestone"
}

// MARK: - Unlock Condition

struct UnlockCondition: Codable, Equatable {
    let type: ConditionType
    let targetValue: Int
    
    enum ConditionType: String, Codable {
        case streak = "streak"              // Consecutive days completed
        case totalTasks = "total_tasks"     // Total tasks completed
        case fitnessTasks = "fitness_tasks" // Fitness tasks completed
        case dietTasks = "diet_tasks"       // Diet tasks completed
        case challenges = "challenges"      // Daily challenges completed
        case aiTasks = "ai_tasks"           // AI-generated tasks used
    }
}

// MARK: - User Achievement Progress

/// Represents a user's progress towards an achievement
struct UserAchievement: Identifiable, Codable, Equatable {
    let id: String // Same as achievement ID
    let achievementId: String
    var status: AchievementStatus
    var currentProgress: Int
    var unlockedAt: Date?
    
    init(
        id: String,
        achievementId: String,
        status: AchievementStatus = .locked,
        currentProgress: Int = 0,
        unlockedAt: Date? = nil
    ) {
        self.id = id
        self.achievementId = achievementId
        self.status = status
        self.currentProgress = currentProgress
        self.unlockedAt = unlockedAt
    }
    
    /// Check if achievement is unlocked
    var isUnlocked: Bool {
        return status == .unlocked
    }
}

// MARK: - Achievement Status

enum AchievementStatus: String, Codable {
    case locked = "locked"
    case unlocked = "unlocked"
}

// MARK: - Predefined Achievements

extension Achievement {
    /// All available achievements in the app
    static let allAchievements: [Achievement] = [
        // Streak Achievements
        Achievement(
            id: "first_step",
            title: "First Step",
            description: "Complete your first day",
            iconName: "achievement_first_step",
            iconColor: "#FF6B6B",
            category: .streak,
            unlockCondition: UnlockCondition(type: .streak, targetValue: 1),
            order: 1
        ),
        Achievement(
            id: "week_warrior",
            title: "Week Warrior",
            description: "Complete 7 consecutive days",
            iconName: "achievement_week_warrior",
            iconColor: "#9B59B6",
            category: .streak,
            unlockCondition: UnlockCondition(type: .streak, targetValue: 7),
            order: 2
        ),
        Achievement(
            id: "ten_day_streak",
            title: "10-Day Streak",
            description: "Complete 10 consecutive days",
            iconName: "achievement_ten_day_streak",
            iconColor: "#F1C40F",
            category: .streak,
            unlockCondition: UnlockCondition(type: .streak, targetValue: 10),
            order: 4
        ),
        Achievement(
            id: "thirty_day_diamond",
            title: "30-Day Diamond",
            description: "Complete 30 consecutive days",
            iconName: "achievement_thirty_day_diamond",
            iconColor: "#3498DB",
            category: .streak,
            unlockCondition: UnlockCondition(type: .streak, targetValue: 30),
            order: 7
        ),
        Achievement(
            id: "century_club",
            title: "Century Club",
            description: "Complete 100 consecutive days",
            iconName: "achievement_century_club",
            iconColor: "#E67E22",
            category: .streak,
            unlockCondition: UnlockCondition(type: .streak, targetValue: 100),
            order: 8
        ),
        
        // Task Achievements
        Achievement(
            id: "overachiever",
            title: "Overachiever",
            description: "Complete 50 total tasks",
            iconName: "achievement_overachiever",
            iconColor: "#F39C12",
            category: .task,
            unlockCondition: UnlockCondition(type: .totalTasks, targetValue: 50),
            order: 5
        ),
        
        // Challenge Achievements
        Achievement(
            id: "early_bird",
            title: "Early Bird",
            description: "Complete 5 daily challenges",
            iconName: "achievement_early_bird",
            iconColor: "#FF9F43",
            category: .challenge,
            unlockCondition: UnlockCondition(type: .challenges, targetValue: 5),
            order: 3
        ),
        Achievement(
            id: "night_owl",
            title: "Night Owl",
            description: "Complete 10 daily challenges",
            iconName: "achievement_night_owl",
            iconColor: "#5F27CD",
            category: .challenge,
            unlockCondition: UnlockCondition(type: .challenges, targetValue: 10),
            order: 6
        ),
        
        // Fitness Achievements
        Achievement(
            id: "fitness_fanatic",
            title: "Fitness Fanatic",
            description: "Complete 25 fitness tasks",
            iconName: "achievement_fitness_fanatic",
            iconColor: "#00D2D3",
            category: .fitness,
            unlockCondition: UnlockCondition(type: .fitnessTasks, targetValue: 25),
            order: 9
        ),
    ]
    
    /// Get achievement by ID
    static func achievement(byId id: String) -> Achievement? {
        return allAchievements.first { $0.id == id }
    }
}

