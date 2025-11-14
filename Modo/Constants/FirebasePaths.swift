import Foundation

/// Firebase database path constants
/// Centralized paths to avoid hardcoding strings throughout the codebase
enum FirebasePaths {
    static func users(_ userId: String) -> String {
        return "users/\(userId)"
    }
    
    static func userTasks(_ userId: String) -> String {
        return "users/\(userId)/tasks"
    }
    
    static func userTasksForDate(_ userId: String, dateKey: String) -> String {
        return "users/\(userId)/tasks/\(dateKey)"
    }
    
    static func userProfile(_ userId: String) -> String {
        return "users/\(userId)/profile"
    }
    
    static func userChallenges(_ userId: String) -> String {
        return "users/\(userId)/challenges"
    }
}

