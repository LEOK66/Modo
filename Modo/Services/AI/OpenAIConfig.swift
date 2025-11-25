import Foundation

// MARK: - OpenAI Configuration
struct OpenAIConfig {
    // Model settings
    static let model = "gpt-4o-mini"  // Using mini version for higher TPM and lower cost
    static let temperature: Double = 0.9
    
    // Token limits
    static let maxTokens = 3000  // Unified limit (sufficient for single-day and multi-day plans)
    static let maxTokensForVision = 300  // Reduced for image analysis
    static let maxTokensForChallenge = 300  // Reduced for daily challenge
    
    // Note: All API calls now go through Firebase Cloud Functions (FirebaseAIService)
    // No direct OpenAI API calls are made from the client anymore
}

// MARK: - API Response Models
struct ChatCompletionResponse: Codable {
    let id: String
    let object: String
    let created: Int
    let model: String
    let choices: [Choice]
    let usage: Usage?
    
    struct Choice: Codable {
        let index: Int
        let message: Message
        let finishReason: String?
        
        enum CodingKeys: String, CodingKey {
            case index, message
            case finishReason = "finish_reason"
        }
        
        struct Message: Codable {
            let role: String
            let content: String?
            let functionCall: FunctionCall?
            let toolCalls: [ToolCall]?
            
            enum CodingKeys: String, CodingKey {
                case role, content
                case functionCall = "function_call"
                case toolCalls = "tool_calls"
            }
            
            struct FunctionCall: Codable {
                let name: String
                let arguments: String
            }
            
            struct ToolCall: Codable {
                let id: String
                let type: String
                let function: FunctionCall
            }
        }
    }
    
    struct Usage: Codable {
        let promptTokens: Int
        let completionTokens: Int
        let totalTokens: Int
        
        enum CodingKeys: String, CodingKey {
            case promptTokens = "prompt_tokens"
            case completionTokens = "completion_tokens"
            case totalTokens = "total_tokens"
        }
    }
}

// Keep Function Response Models
struct WorkoutPlanFunctionResponse: Codable {
    let date: String
    let goal: String
    let dailyKcalTarget: Int?
    let exercises: [Exercise]?
    let notes: String?
    
    enum CodingKeys: String, CodingKey {
        case date, goal
        case dailyKcalTarget = "daily_kcal_target"
        case exercises, notes
    }
    
    struct Exercise: Codable {
        let name: String
        let sets: Int
        let reps: String
        let restSec: Int?
        let durationMin: Int?
        let calories: Int?
        
        enum CodingKeys: String, CodingKey {
            case name, sets, reps
            case restSec = "rest_sec"
            case durationMin = "duration_min"
            case calories
        }
    }
}

struct FoodCalorieFunctionResponse: Codable {
    let foodName: String
    let servingSize: String
    let calories: Int
    let protein: Double
    let carbs: Double
    let fat: Double
    let confidence: Double
    
    enum CodingKeys: String, CodingKey {
        case foodName = "food_name"
        case servingSize = "serving_size"
        case calories, protein, carbs, fat, confidence
    }
}

struct NutritionPlanFunctionResponse: Codable {
    let date: String
    let goal: String
    let meals: [Meal]
    let dailyTotals: DailyTotals?
    
    enum CodingKeys: String, CodingKey {
        case date, goal, meals
        case dailyTotals = "daily_totals"
    }
    
    struct Meal: Codable {
        let mealType: String
        let time: String?
        let foods: [Food]
        
        enum CodingKeys: String, CodingKey {
            case mealType = "meal_type"
            case time, foods
        }
    }
    
    struct Food: Codable {
        let name: String
        let portion: String
        let calories: Int
        let protein: Double?
        let carbs: Double?
        let fat: Double?
    }
    
    struct DailyTotals: Codable {
        let calories: Int
        let protein: Double?
        let carbs: Double?
        let fat: Double?
    }
}

// MARK: - Multi-Day Plan Function Response
struct MultiDayPlanFunctionResponse: Codable {
    let startDate: String
    let endDate: String
    let planType: String
    let days: [Day]
    let notes: String?
    
    enum CodingKeys: String, CodingKey {
        case startDate = "start_date"
        case endDate = "end_date"
        case planType = "plan_type"
        case days, notes
    }
    
    struct Day: Codable {
        let date: String
        let dayName: String
        let workout: Workout?
        let nutrition: Nutrition?
        
        enum CodingKeys: String, CodingKey {
            case date
            case dayName = "day_name"
            case workout, nutrition
        }
    }
    
    struct Workout: Codable {
        let goal: String
        let exercises: [Exercise]
        let dailyKcalTarget: Int
        let notes: String?
        
        enum CodingKeys: String, CodingKey {
            case goal, exercises
            case dailyKcalTarget = "daily_kcal_target"
            case notes
        }
        
        struct Exercise: Codable {
            let name: String
            let sets: Int
            let reps: String
            let restSec: Int?
            let durationMin: Int?
            let calories: Int?
            
            enum CodingKeys: String, CodingKey {
                case name, sets, reps
                case restSec = "rest_sec"
                case durationMin = "duration_min"
                case calories
            }
        }
    }
    
    struct Nutrition: Codable {
        let goal: String
        let meals: [Meal]
        let dailyTotals: DailyTotals?
        
        enum CodingKeys: String, CodingKey {
            case goal, meals
            case dailyTotals = "daily_totals"
        }
        
        struct Meal: Codable {
            let mealType: String
            let time: String
            let foods: [Food]
            let calories: Int
            let protein: Double
            let carbs: Double
            let fat: Double
            
            enum CodingKeys: String, CodingKey {
                case mealType = "meal_type"
                case time, foods, calories, protein, carbs, fat
            }
        }
        
        struct Food: Codable {
            let name: String
            let portion: String
            let calories: Int
            let protein: Double
            let carbs: Double
            let fat: Double
        }
        
        struct DailyTotals: Codable {
            let calories: Int
            let protein: Double
            let carbs: Double
            let fat: Double
        }
    }
}

// MARK: - Helper Extensions
extension ChatCompletionResponse.Choice.Message {
    /// Get function call from either old format (function_call) or new format (tool_calls)
    var effectiveFunctionCall: ChatCompletionResponse.Choice.Message.FunctionCall? {
        // Try new format first (tool_calls)
        if let toolCalls = toolCalls, let firstTool = toolCalls.first {
            return firstTool.function
        }
        // Fallback to old format (function_call)
        return functionCall
    }
}
