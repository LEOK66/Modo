import Foundation

// MARK: - OpenAI Configuration
struct OpenAIConfig {
    
    static var apiKey: String {
        // Priority 1: Read from environment variable (production)
        if let key = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] {
            return key
        }
        
        // Priority 2: Read from Info.plist
        if let key = Bundle.main.object(forInfoDictionaryKey: "OPENAI_API_KEY") as? String {
            return key
        }
        
        // Priority 3: Read from APIKeys.swift (development)
        // This file is in .gitignore and will NOT be committed
        return APIKeys.openAI
    }
    
    static let apiURL = "https://api.openai.com/v1/chat/completions"
    static let model = "gpt-4o" 
    static let temperature: Double = 0.9  // Higher for more creative and diverse outputs
    static let maxTokens = 1000
}

// MARK: - API Request/Response Models
struct ChatCompletionRequest: Codable {
    let model: String
    let messages: [Message]
    let temperature: Double
    let maxTokens: Int?
    let functions: [Function]?
    let functionCall: String?
    
    enum CodingKeys: String, CodingKey {
        case model, messages, temperature
        case maxTokens = "max_tokens"
        case functions
        case functionCall = "function_call"
    }
    
    struct Message: Codable {
        let role: String
        let content: String
        let name: String?
        let functionCall: FunctionCall?
        
        enum CodingKeys: String, CodingKey {
            case role, content, name
            case functionCall = "function_call"
        }
        
        // Convenience initializer for simple messages
        init(role: String, content: String, name: String? = nil, functionCall: FunctionCall? = nil) {
            self.role = role
            self.content = content
            self.name = name
            self.functionCall = functionCall
        }
    }
    
    struct Function: Codable {
        let name: String
        let description: String
        let parameters: Parameters
        
        struct Parameters: Codable {
            let type: String
            let properties: [String: Property]
            let required: [String]
            
            struct Property: Codable {
                let type: String
                let description: String
                let items: Items?
                
                struct Items: Codable {
                    let type: String
                }
            }
        }
    }
    
    struct FunctionCall: Codable {
        let name: String
        let arguments: String
    }
}

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

// MARK: - Function Call Response Models
struct WorkoutPlanFunctionResponse: Codable {
    let date: String
    let goal: String
    let dailyKcalTarget: Int?  // Optional
    let exercises: [Exercise]?  // Optional, AI may not return
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

