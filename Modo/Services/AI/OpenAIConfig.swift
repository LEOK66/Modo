import Foundation

// MARK: - OpenAI Configuration
struct OpenAIConfig {
    static let model = "gpt-4o"
    static let temperature: Double = 0.9
    static let maxTokens = 1000
    
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
            
            enum CodingKeys: String, CodingKey {
                case role, content
                case functionCall = "function_call"
            }
            
            struct FunctionCall: Codable {
                let name: String
                let arguments: String
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

// 保留 Function Response Models
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
        let targetRPE: Int?
        let alternatives: [String]?
        
        enum CodingKeys: String, CodingKey {
            case name, sets, reps
            case restSec = "rest_sec"
            case targetRPE = "target_RPE"
            case alternatives
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
