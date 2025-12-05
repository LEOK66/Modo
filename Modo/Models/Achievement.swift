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
    var macro: String? // For macroStreak: "protein", "carbs", "fats"
    var timeWindow: String? // For timeOfDayTasks: "before_7am", "after_midnight"
    
    init(type: ConditionType, targetValue: Int, macro: String? = nil, timeWindow: String? = nil) {
        self.type = type
        self.targetValue = targetValue
        self.macro = macro
        self.timeWindow = timeWindow
    }
    
    enum ConditionType: String, Codable {
        // Basic conditions
        case streak = "streak"              // Consecutive days completed
        case totalTasks = "total_tasks"     // Total tasks completed
        case fitnessTasks = "fitness_tasks" // Fitness tasks completed
        case dietTasks = "diet_tasks"       // Diet tasks completed
        case challenges = "challenges"      // Daily challenges completed
        case aiTasks = "ai_tasks"           // AI-generated tasks used
        
        // Streak variations
        case streakRestarts = "streak_restarts" // Number of times streak restarted
        case streakComeback = "streak_comeback" // Return to streak after breaking
        
        // Diet variations
        case dietTasksSkipped = "diet_tasks_skipped" // Consecutive days over calorie target by 1000
        case dietTasksAfter11PM = "diet_tasks_after_11pm" // Diet tasks completed after 11 PM
        
        // Macros
        case macroStreak = "macro_streak" // Single macro streak (protein/carbs/fats)
        case allMacrosStreak = "all_macros_streak" // All macros streak
        case calorieAccuracy = "calorie_accuracy" // Days within ±50 calories of target
        
        // Time of day
        case timeOfDayTasks = "time_of_day_tasks" // Tasks in specific time window
        case allTimePeriods = "all_time_periods" // Tasks in all 4 time periods
        
        // Daily Challenge
        case dailyChallengeTotal = "daily_challenge_total" // Total daily challenges completed
        case dailyTasksTotal = "daily_tasks_total" // Total daily tasks completed
        case dailyChallengesStreak = "daily_challenges_streak" // Consecutive daily challenges
        case aiGeneratedTasksAdded = "ai_generated_tasks_added" // AI-generated daily tasks added
        
        // AI Usage
        case aiPlansGenerated = "ai_plans_generated" // AI meal plans generated
        case insightsPageVisits = "insights_page_visits" // Insights page visits
        case aiGoalsCompleted = "ai_goals_completed" // AI-generated goals completed
        case aiFeatureUsage = "ai_feature_usage" // AI features used (meal scan, insights, etc.)
        case aiPlanRegenerations = "ai_plan_regenerations" // AI plan regenerations
        
        // Humor
        case consecutiveDaysSkipped = "consecutive_days_skipped" // Consecutive days with all tasks skipped
        case remindersSnoozed = "reminders_snoozed" // Reminder snoozes
        case almostPerfectDays = "almost_perfect_days" // Days with 4/5 tasks completed
        case weekendOnlyStreak = "weekend_only_streak" // Consecutive weeks only completing on weekends
        case taskRescheduled = "task_rescheduled" // Task reschedules
        
        // Special
        case allCategoriesInWeek = "all_categories_in_week" // All categories completed in consecutive weeks
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
        // MARK: - Total Task Achievements
        Achievement(
            id: "first_step",
            title: "First Step",
            description: "Every journey begins with a single step",
            iconName: "achievement_first_step",
            iconColor: "#FF6B6B",
            category: .task,
            unlockCondition: UnlockCondition(type: .totalTasks, targetValue: 1),
            order: 1
        ),
        Achievement(
            id: "century_club",
            title: "Century Club",
            description: "10000 tasks conquered, champion mindset unlocked",
            iconName: "achievement_century_club",
            iconColor: "#E74C3C",
            category: .task,
            unlockCondition: UnlockCondition(type: .totalTasks, targetValue: 10000),
            order: 22
        ),
        Achievement(
            id: "modo_master",
            title: "Modo Master",
            description: "You've mastered the art of consistency",
            iconName: "system:graduationcap.fill",
            iconColor: "#2C3E50",
            category: .task,
            unlockCondition: UnlockCondition(type: .totalTasks, targetValue: 5000),
            order: 3
        ),
        
        // MARK: - Daily Task Achievements
        Achievement(
            id: "task_starter",
            title: "Task Starter",
            description: "Getting the hang of the daily grind",
            iconName: "system:pin.fill",
            iconColor: "#E74C3C",
            category: .challenge,
            unlockCondition: UnlockCondition(type: .dailyChallengeTotal, targetValue: 1000),
            order: 4
        ),
        Achievement(
            id: "daily_driver",
            title: "Daily Driver",
            description: "You keep showing up, and it shows",
            iconName: "system:calendar.badge.checkmark",
            iconColor: "#E67E22",
            category: .challenge,
            unlockCondition: UnlockCondition(type: .dailyTasksTotal, targetValue: 500),
            order: 5
        ),
        Achievement(
            id: "momentum_builder",
            title: "Momentum Builder",
            description: "Seven days, seven wins",
            iconName: "system:arrow.up.right.circle.fill",
            iconColor: "#E74C3C",
            category: .challenge,
            unlockCondition: UnlockCondition(type: .dailyChallengesStreak, targetValue: 7),
            order: 6
        ),
        Achievement(
            id: "mission_acceptor",
            title: "Mission Acceptor",
            description: "Picking up challenges like a pro",
            iconName: "system:puzzlepiece.fill",
            iconColor: "#27AE60",
            category: .challenge,
            unlockCondition: UnlockCondition(type: .aiGeneratedTasksAdded, targetValue: 100),
            order: 7
        ),
        
        // MARK: - AI Usage Achievements
        Achievement(
            id: "first_in_command",
            title: "First in Command",
            description: "Your AI sidekick gets to work",
            iconName: "system:wand.and.stars",
            iconColor: "#95A5A6",
            category: .ai,
            unlockCondition: UnlockCondition(type: .aiTasks, targetValue: 1),
            order: 8
        ),
        Achievement(
            id: "plan_generator",
            title: "Plan Generator",
            description: "Your plans practically write themselves",
            iconName: "system:slider.horizontal.3",
            iconColor: "#7F8C8D",
            category: .ai,
            unlockCondition: UnlockCondition(type: .aiPlansGenerated, targetValue: 100),
            order: 9
        ),
        Achievement(
            id: "insight_explorer",
            title: "Insight Explorer",
            description: "Digging for the truth behind your habits",
            iconName: "system:brain.head.profile",
            iconColor: "#E91E63",
            category: .ai,
            unlockCondition: UnlockCondition(type: .insightsPageVisits, targetValue: 100),
            order: 10
        ),
        
        // MARK: - Fitness Achievements
        Achievement(
            id: "fitness_fanatic",
            title: "Fitness Fanatic",
            description: "Your body is your temple, and you're the architect",
            iconName: "achievement_fitness_fanatic",
            iconColor: "#00D2D3",
            category: .fitness,
            unlockCondition: UnlockCondition(type: .fitnessTasks, targetValue: 100),
            order: 21
        ),
        
        // MARK: - Nutrition Achievements
        Achievement(
            id: "nutrition_ninja",
            title: "Nutrition Ninja",
            description: "You are what you eat, and you're eating right",
            iconName: "system:carrot.fill",
            iconColor: "#FF9800",
            category: .diet,
            unlockCondition: UnlockCondition(type: .dietTasks, targetValue: 100),
            order: 12
        ),
        Achievement(
            id: "cheat_day_champion",
            title: "Cheat Day Champion",
            description: "Balance is important... right?",
            iconName: "system:fork.knife",
            iconColor: "#FFC107",
            category: .diet,
            unlockCondition: UnlockCondition(type: .dietTasksSkipped, targetValue: 3),
            order: 13
        ),
        Achievement(
            id: "midnight_snacker",
            title: "Midnight Snacker",
            description: "Calories don't count after midnight... do they?",
            iconName: "system:moon.fill",
            iconColor: "#FFB74D",
            category: .diet,
            unlockCondition: UnlockCondition(type: .dietTasksAfter11PM, targetValue: 10),
            order: 14
        ),
        
        // MARK: - Streak Achievements
        Achievement(
            id: "ten_day_streak",
            title: "10-Day Streak",
            description: "Consistency is the key to greatness",
            iconName: "achievement_ten_day_streak",
            iconColor: "#FFEB3B",
            category: .streak,
            unlockCondition: UnlockCondition(type: .streak, targetValue: 10),
            order: 15
        ),
        Achievement(
            id: "365_day_diamond",
            title: "365-Day Diamond",
            description: "You've built a habit that lasts",
            iconName: "achievement_thirty_day_diamond",
            iconColor: "#00BCD4",
            category: .streak,
            unlockCondition: UnlockCondition(type: .streak, targetValue: 365),
            order: 20
        ),
        Achievement(
            id: "week_warrior",
            title: "Week Warrior",
            description: "10 full week of dedication—you're unstoppable",
            iconName: "achievement_week_warrior",
            iconColor: "#9C27B0",
            category: .streak,
            unlockCondition: UnlockCondition(type: .streak, targetValue: 10),
            order: 17
        ),
        Achievement(
            id: "iron_will",
            title: "Iron Will",
            description: "Your willpower is forged in steel",
            iconName: "system:flame.fill",
            iconColor: "#F44336",
            category: .streak,
            unlockCondition: UnlockCondition(type: .streak, targetValue: 500),
            order: 18
        ),
        Achievement(
            id: "restart_royalty",
            title: "Restart Royalty",
            description: "Every day is a fresh start, especially Mondays",
            iconName: "system:arrow.clockwise.circle.fill",
            iconColor: "#03A9F4",
            category: .streak,
            unlockCondition: UnlockCondition(type: .streakRestarts, targetValue: 5),
            order: 19
        ),
        Achievement(
            id: "comeback_kid",
            title: "The Comeback Kid",
            description: "Fall down seven times, stand up eight",
            iconName: "system:sparkles",
            iconColor: "#FF5722",
            category: .streak,
            unlockCondition: UnlockCondition(type: .streakComeback, targetValue: 7),
            order: 20
        ),
        
        // MARK: - Goal Achievements
        Achievement(
            id: "goal_finisher",
            title: "Goal Finisher",
            description: "You asked, AI delivered, you conquered",
            iconName: "system:trophy.fill",
            iconColor: "#FFC107",
            category: .ai,
            unlockCondition: UnlockCondition(type: .aiGoalsCompleted, targetValue: 100),
            order: 21
        ),
        Achievement(
            id: "ai_apprentice",
            title: "AI Apprentice",
            description: "You're getting the hang of this AI stuff",
            iconName: "system:figure.wave",
            iconColor: "#9E9E9E",
            category: .ai,
            unlockCondition: UnlockCondition(type: .aiFeatureUsage, targetValue: 50),
            order: 22
        ),
        Achievement(
            id: "regenerated",
            title: "Regenerated",
            description: "You like your plans extra fine-tuned",
            iconName: "system:arrow.triangle.2.circlepath",
            iconColor: "#FF9800",
            category: .ai,
            unlockCondition: UnlockCondition(type: .aiPlanRegenerations, targetValue: 100),
            order: 23
        ),
        
        // MARK: - Humor Achievements
        Achievement(
            id: "professional_procrastinator",
            title: "Professional Procrastinator",
            description: "Tomorrow is always the busiest day of the week",
            iconName: "system:zzz",
            iconColor: "#607D8B",
            category: .milestone,
            unlockCondition: UnlockCondition(type: .consecutiveDaysSkipped, targetValue: 3),
            order: 24
        ),
        Achievement(
            id: "snooze_master",
            title: "Snooze Master",
            description: "Just 5 more minutes... (x15)",
            iconName: "system:alarm.fill",
            iconColor: "#FF5722",
            category: .milestone,
            unlockCondition: UnlockCondition(type: .remindersSnoozed, targetValue: 15),
            order: 25
        ),
        Achievement(
            id: "almost_there",
            title: "Almost There",
            description: "Close enough counts in horseshoes and hand grenades",
            iconName: "system:scope",
            iconColor: "#E91E63",
            category: .milestone,
            unlockCondition: UnlockCondition(type: .almostPerfectDays, targetValue: 10),
            order: 26
        ),
        Achievement(
            id: "weekend_warrior",
            title: "Weekend Warrior",
            description: "Weekdays are for resting, weekends are for crushing",
            iconName: "system:calendar.badge.exclamationmark",
            iconColor: "#FF9800",
            category: .milestone,
            unlockCondition: UnlockCondition(type: .weekendOnlyStreak, targetValue: 4),
            order: 27
        ),
        Achievement(
            id: "task_juggler",
            title: "Task Juggler",
            description: "Timing is everything... eventually",
            iconName: "system:circle.grid.cross.fill",
            iconColor: "#9C27B0",
            category: .milestone,
            unlockCondition: UnlockCondition(type: .taskRescheduled, targetValue: 2),
            order: 28
        ),
        
        // MARK: - Special Achievements
        Achievement(
            id: "rainbow_warrior",
            title: "Rainbow Warrior",
            description: "Balance across all areas of health—you're doing it all",
            iconName: "system:rainbow",
            iconColor: "#E91E63",
            category: .milestone,
            unlockCondition: UnlockCondition(type: .allCategoriesInWeek, targetValue: 10),
            order: 29
        ),
        
        // MARK: - Macros Achievements
        Achievement(
            id: "protein_pro",
            title: "Protein Pro",
            description: "You're basically made of whey at this point",
            iconName: "system:drop.fill",
            iconColor: "#795548",
            category: .diet,
            unlockCondition: UnlockCondition(type: .macroStreak, targetValue: 30, macro: "protein"),
            order: 30
        ),
        Achievement(
            id: "carb_commander",
            title: "Carb Commander",
            description: "Carbs in check, chaos controlled",
            iconName: "system:leaf.fill",
            iconColor: "#FFC107",
            category: .diet,
            unlockCondition: UnlockCondition(type: .macroStreak, targetValue: 30, macro: "carbs"),
            order: 31
        ),
        Achievement(
            id: "fat_balance_master",
            title: "Fat Balance Master",
            description: "Healthy fats, healthier choices",
            iconName: "system:heart.fill",
            iconColor: "#4CAF50",
            category: .diet,
            unlockCondition: UnlockCondition(type: .macroStreak, targetValue: 30, macro: "fats"),
            order: 32
        ),
        Achievement(
            id: "clean_plate_captain",
            title: "Clean Plate Captain",
            description: "Perfect macros, perfect discipline",
            iconName: "system:circle.grid.3x3.fill",
            iconColor: "#00BCD4",
            category: .diet,
            unlockCondition: UnlockCondition(type: .allMacrosStreak, targetValue: 60),
            order: 33
        ),
        Achievement(
            id: "calorie_consistent",
            title: "Calorie Consistent",
            description: "Dialed in to the exact calorie",
            iconName: "system:flame.fill",
            iconColor: "#FF5722",
            category: .diet,
            unlockCondition: UnlockCondition(type: .calorieAccuracy, targetValue: 100),
            order: 34
        ),
        
        // MARK: - Time-of-Day Achievements
        Achievement(
            id: "early_bird",
            title: "Early Bird",
            description: "The early bird catches the worm",
            iconName: "achievement_early_bird",
            iconColor: "#FF9800",
            category: .challenge,
            unlockCondition: UnlockCondition(type: .timeOfDayTasks, targetValue: 30, timeWindow: "before_7am"),
            order: 35
        ),
        Achievement(
            id: "night_owl",
            title: "Night Owl",
            description: "Sleep is for the weak... or is it?",
            iconName: "achievement_night_owl",
            iconColor: "#5F27CD",
            category: .challenge,
            unlockCondition: UnlockCondition(type: .timeOfDayTasks, targetValue: 30, timeWindow: "after_midnight"),
            order: 36
        ),
        Achievement(
            id: "around_the_clock",
            title: "Around the Clock",
            description: "You work out around the clock, literally",
            iconName: "system:clock.fill",
            iconColor: "#03A9F4",
            category: .challenge,
            unlockCondition: UnlockCondition(type: .allTimePeriods, targetValue: 5),
            order: 37
        ),
    ]
    
    /// Get achievement by ID
    static func achievement(byId id: String) -> Achievement? {
        return allAchievements.first { $0.id == id }
    }
}

