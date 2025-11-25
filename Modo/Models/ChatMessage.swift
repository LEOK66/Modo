import Foundation
import SwiftData
import FirebaseAuth

// MARK: - Chat Message Model
@Model
final class FirebaseChatMessage {
    var id: UUID
    var content: String
    var isFromUser: Bool
    var timestamp: Date
    var messageType: String // "text", "workout_plan", "nutrition_plan", "multi_day_plan", "food_info"
    var workoutPlan: WorkoutPlanData?
    var nutritionPlan: NutritionPlanData?
    var multiDayPlan: MultiDayPlanData?
    var actionTaken: Bool // Track if user has clicked Accept/Reject
    var userId: String = "" // Add userId to isolate messages by user
    
    init(content: String, isFromUser: Bool, messageType: String = "text", workoutPlan: WorkoutPlanData? = nil, nutritionPlan: NutritionPlanData? = nil, multiDayPlan: MultiDayPlanData? = nil, userId: String? = nil) {
        self.id = UUID()
        self.content = content
        self.isFromUser = isFromUser
        self.timestamp = Date()
        self.messageType = messageType
        self.workoutPlan = workoutPlan
        self.nutritionPlan = nutritionPlan
        self.multiDayPlan = multiDayPlan
        self.actionTaken = false
        // ✅ Get userId from Auth if not provided, or use empty string as fallback
        if let userId = userId {
            self.userId = userId
        } else if let currentUserId = Auth.auth().currentUser?.uid {
            self.userId = currentUserId
        } else {
            self.userId = "" // Fallback for old messages or preview
        }
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
        var durationMin: Int?
        var calories: Int?
    }
}

// MARK: - Nutrition Plan Data
struct NutritionPlanData: Codable {
    var date: String
    var goal: String
    var dailyKcalTarget: Int
    var meals: [Meal]
    var notes: String?
    
    struct Meal: Codable, Identifiable {
        var id = UUID()
        var name: String // e.g., "Breakfast", "Lunch", "Dinner", "Snack"
        var time: String // e.g., "8:00 AM"
        var foods: [Food] // List of food items with details
        var calories: Int
        var protein: Double
        var carbs: Double
        var fat: Double
        
        // Custom decoding for backward compatibility
        enum CodingKeys: String, CodingKey {
            case id, name, time, foods, calories, protein, carbs, fat
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            // Decode standard fields
            self.id = (try? container.decode(UUID.self, forKey: .id)) ?? UUID()
            self.name = try container.decode(String.self, forKey: .name)
            self.time = try container.decode(String.self, forKey: .time)
            self.calories = try container.decode(Int.self, forKey: .calories)
            self.protein = try container.decode(Double.self, forKey: .protein)
            self.carbs = try container.decode(Double.self, forKey: .carbs)
            self.fat = try container.decode(Double.self, forKey: .fat)
            
            // Handle backward compatibility for foods field
            // Try new format first ([Food]), fallback to old format ([String])
            if let newFoods = try? container.decode([Food].self, forKey: .foods) {
                // New format: already Food objects
                self.foods = newFoods
            } else if let oldFoods = try? container.decode([String].self, forKey: .foods) {
                // Old format: convert String array to Food objects
                // Estimate calories by dividing total calories evenly
                let caloriesPerFood = oldFoods.isEmpty ? 0 : calories / oldFoods.count
                self.foods = oldFoods.map { foodName in
                    Food(name: foodName, portion: "1 serving", calories: caloriesPerFood)
                }
            } else {
                // Fallback: empty array if both fail
                self.foods = []
            }
        }
        
        // Standard initializer for creating new objects
        init(id: UUID = UUID(), name: String, time: String, foods: [Food], calories: Int, protein: Double, carbs: Double, fat: Double) {
            self.id = id
            self.name = name
            self.time = time
            self.foods = foods
            self.calories = calories
            self.protein = protein
            self.carbs = carbs
            self.fat = fat
        }
    }
    
    struct Food: Codable, Identifiable {
        var id = UUID()
        var name: String
        var portion: String
        var calories: Int
    }
}

// MARK: - Multi-Day Plan Data
struct MultiDayPlanData: Codable {
    var startDate: String
    var endDate: String
    var planType: String // "workout" or "nutrition" or "both"
    var days: [DayPlan]
    var notes: String?
    
    struct DayPlan: Codable, Identifiable {
        var id = UUID()
        var date: String
        var dayName: String // e.g., "Day 1", "Monday"
        var workout: WorkoutPlanData?
        var nutrition: NutritionPlanData?
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

