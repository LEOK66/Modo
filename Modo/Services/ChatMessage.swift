import Foundation
import SwiftData

// MARK: - Chat Message Model
@Model
final class ChatMessage {
    var id: UUID
    var content: String
    var isFromUser: Bool
    var timestamp: Date
    var messageType: String // "text", "workout_plan", "food_info"
    var workoutPlan: WorkoutPlanData?
    
    init(content: String, isFromUser: Bool, messageType: String = "text", workoutPlan: WorkoutPlanData? = nil) {
        self.id = UUID()
        self.content = content
        self.isFromUser = isFromUser
        self.timestamp = Date()
        self.messageType = messageType
        self.workoutPlan = workoutPlan
    }
}

// MARK: - Workout Plan Data
struct WorkoutPlanData: Codable {
    var date: String
    var goal: String
    var dailyKcalTarget: Int?
    var exercises: [Exercise]
    var notes: String?
    
    struct Exercise: Codable, Identifiable {
        var id = UUID()
        var name: String
        var sets: Int
        var reps: String
        var restSec: Int?
        var targetRPE: Int?
        var alternatives: [String]?
    }
}

// MARK: - Food Info Data
struct FoodInfoData: Codable {
    var foodName: String
    var servingSize: String
    var calories: Int
    var protein: Double
    var carbs: Double
    var fat: Double
    var confidence: Double
}

