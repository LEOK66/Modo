import Foundation

/// Firebase database path constants
/// Centralized paths to avoid hardcoding strings throughout the codebase
enum FirebasePaths {
    /// Base path for user data
    static func users(_ userId: String) -> String {
        return "users/\(userId)"
    }
    
    /// Path for user tasks
    static func userTasks(_ userId: String) -> String {
        return "users/\(userId)/tasks"
    }
    
    /// Path for tasks on a specific date
    static func userTasksForDate(_ userId: String, dateKey: String) -> String {
        return "users/\(userId)/tasks/\(dateKey)"
    }
    
    /// Path for user profile
    static func userProfile(_ userId: String) -> String {
        return "users/\(userId)/profile"
    }
    
    /// Path for daily challenges
    static func userChallenges(_ userId: String) -> String {
        return "users/\(userId)/challenges"
    }
}

