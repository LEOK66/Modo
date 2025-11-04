import Foundation
import FirebaseFunctions

class FirebaseAIService {
    
    static let shared = FirebaseAIService()
    private let functions: Functions
    
    private init() {
        self.functions = Functions.functions()
        // If your Firebase project is in a different region, modify here:
        // self.functions = Functions.functions(region: "asia-east1")
    }
    
    // MARK: - Send Chat Request
    /// Sends a chat completion request to Firebase Cloud Function
    func sendChatRequest(
        messages: [FirebaseFirebaseChatMessage],
        functions functionDefs: [FunctionDefinition]? = nil,
        functionCall: String? = nil,
        maxTokens: Int? = nil
    ) async throws -> ChatCompletionResponse {
        
        // Convert to dictionary format for Firebase
        let messagesDict = messages.map { $0.toDictionary() }
        let functionsDict = functionDefs?.map { $0.toDictionary() }
        
        // Prepare request data
        var data: [String: Any] = [
            "messages": messagesDict,
            "model": OpenAIConfig.model,
            "temperature": OpenAIConfig.temperature,
            "maxTokens": maxTokens ?? OpenAIConfig.maxTokens
        ]
        
        // Add functions if provided
        if let functionsDict = functionsDict {
            data["functions"] = functionsDict
            if let functionCall = functionCall {
                data["functionCall"] = functionCall
            }
        }
        
        // Call Cloud Function
        let callable = self.functions.httpsCallable("chatWithAI")
        
        do {
            print("🔍 [Firebase] Sending request to Cloud Function...")
            let result = try await callable.call(data)
            
            // Parse response
            guard let response = result.data as? [String: Any],
                  let success = response["success"] as? Bool,
                  success,
                  let responseData = response["data"] as? [String: Any] else {
                print("❌ [Firebase] Invalid response: \(result.data)")
                throw FirebaseAIError.invalidResponse
            }
            
            print("✅ [Firebase] Response received successfully")
            
            // Convert dictionary to ChatCompletionResponse
            let jsonData = try JSONSerialization.data(withJSONObject: responseData)
            let decoder = JSONDecoder()
            return try decoder.decode(ChatCompletionResponse.self, from: jsonData)
            
        } catch let error as NSError {
            print("❌ [Firebase] Error occurred: \(error)")
            
            // Handle Firebase Functions specific errors
            if error.domain == FunctionsErrorDomain {
                let code = FunctionsErrorCode(rawValue: error.code)
                let message = error.localizedDescription
                let details = error.userInfo[FunctionsErrorDetailsKey]
                
                print("❌ [Firebase] Error code: \(String(describing: code))")
                print("❌ [Firebase] Message: \(message)")
                print("❌ [Firebase] Details: \(String(describing: details))")
                
                // Handle specific error cases
                if code == .unauthenticated {
                    throw FirebaseAIError.unauthenticated
                }
            }
            
            throw FirebaseAIError.functionError(error)
        }
    }
}

// MARK: - Helper Models

/// Represents a chat message for OpenAI API via Firebase
struct FirebaseFirebaseChatMessage {
    let role: String
    let content: Any // Can be String or [[String: Any]] for multimodal content
    let name: String?
    let functionCall: FunctionCallData?
    
    init(role: String, content: String, name: String? = nil, functionCall: FunctionCallData? = nil) {
        self.role = role
        self.content = content
        self.name = name
        self.functionCall = functionCall
    }
    
    // Initialize with multimodal content (for images)
    init(role: String, multimodalContent: [[String: Any]], name: String? = nil) {
        self.role = role
        self.content = multimodalContent
        self.name = name
        self.functionCall = nil
    }
    
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "role": role,
            "content": content
        ]
        if let name = name {
            dict["name"] = name
        }
        if let functionCall = functionCall {
            dict["function_call"] = [
                "name": functionCall.name,
                "arguments": functionCall.arguments
            ]
        }
        return dict
    }
}

struct FunctionCallData {
    let name: String
    let arguments: String
}

struct FunctionDefinition {
    let name: String
    let description: String
    let parameters: [String: Any]
    
    func toDictionary() -> [String: Any] {
        return [
            "name": name,
            "description": description,
            "parameters": parameters
        ]
    }
}

// MARK: - Message Conversion Helper
extension FirebaseFirebaseChatMessage {
    static func from(_ chatMessage: FirebaseChatMessage) -> FirebaseFirebaseChatMessage {
        let role = chatMessage.isFromUser ? "user" : "assistant"
        return FirebaseFirebaseChatMessage(
            role: role,
            content: chatMessage.content,
            name: nil,
            functionCall: nil
        )
    }
    
    static func fromArray(_ chatMessages: [FirebaseChatMessage]) -> [FirebaseFirebaseChatMessage] {
        return chatMessages.map { from($0) }
    }
}

// MARK: - Errors
enum FirebaseAIError: LocalizedError {
    case invalidResponse
    case functionError(Error)
    case unauthenticated
    case decodingError
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from Firebase"
        case .functionError(let error):
            return "Firebase error: \(error.localizedDescription)"
        case .unauthenticated:
            return "Authentication required"
        case .decodingError:
            return "Failed to decode API response"
        }
    }
}
