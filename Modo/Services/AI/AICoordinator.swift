import Foundation
import FirebaseAuth

/// AI Coordinator - Unified entry point for all AI operations
///
/// This coordinator manages the complete AI conversation flow:
/// 1. Receives user messages
/// 2. Sends to AI with function definitions
/// 3. Handles AI responses (text or function calls)
/// 4. Coordinates with function handlers
/// 5. Sends function results back to AI
/// 6. Returns final AI response
///
/// Architecture:
/// ```
/// User → AICoordinator → FirebaseAIService → AI
///                ↓
///         FunctionCallCoordinator → Handlers → Services
///                ↓
///         AICoordinator → AI (with results)
///                ↓
///         User (final response)
/// ```
class AICoordinator {
    
    // MARK: - Dependencies
    
    private let firebaseAIService: FirebaseAIService
    private let functionCoordinator: AIFunctionCallCoordinator
    private let notificationManager: AINotificationManager
    
    // MARK: - State
    
    private var activeRequestId: String?
    private var pendingFunctionCall: PendingFunctionCall?
    
    // MARK: - Initialization
    
    init(
        firebaseAIService: FirebaseAIService = .shared,
        functionCoordinator: AIFunctionCallCoordinator = .shared,
        notificationManager: AINotificationManager = .shared
    ) {
        self.firebaseAIService = firebaseAIService
        self.functionCoordinator = functionCoordinator
        self.notificationManager = notificationManager
        
        setupNotificationObservers()
    }
    
    deinit {
        removeNotificationObservers()
    }
    
    // MARK: - Public Methods
    
    /// Process a user message and get AI response
    /// - Parameters:
    ///   - message: User's message
    ///   - history: Conversation history
    ///   - completion: Called with AI's response or error
    func processMessage(
        _ message: String,
        history: [ChatMessage],
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        let requestId = UUID().uuidString
        activeRequestId = requestId
        
        print("🤖 AICoordinator: Processing message (requestId: \(requestId))")
        
        Task {
            do {
                // Build messages array
                var messages = history
                messages.append(ChatMessage(role: "user", content: message))
                
                // Get function definitions
                let functions = firebaseAIService.buildFunctions()
                
                // Send to AI
                let response = try await firebaseAIService.sendChatRequest(
                    messages: messages,
                    functions: functions,
                    functionCall: "auto",
                    maxTokens: 2000
                )
                
                self.handleAIResponse(response, requestId: requestId, history: messages, completion: completion)
                
            } catch {
                print("❌ AICoordinator: AI request failed - \(error.localizedDescription)")
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func handleAIResponse(
        _ response: ChatCompletionResponse,
        requestId: String,
        history: [ChatMessage],
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        guard let choice = response.choices.first else {
            completion(.failure(AICoordinatorError.noResponse))
            return
        }
        
        // Check if AI wants to call a function
        if let functionCall = choice.message.effectiveFunctionCall {
            print("🔧 AICoordinator: AI requested function call - \(functionCall.name)")
            handleFunctionCall(functionCall, requestId: requestId, history: history, completion: completion)
        } else if let content = choice.message.content, !content.isEmpty {
            // Direct text response
            print("✅ AICoordinator: Got text response")
            completion(.success(content))
        } else {
            print("⚠️ AICoordinator: Empty response")
            completion(.failure(AICoordinatorError.emptyResponse))
        }
    }
    
    private func handleFunctionCall(
        _ functionCall: ChatCompletionResponse.Choice.Message.FunctionCall,
        requestId: String,
        history: [ChatMessage],
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        // Store pending function call
        pendingFunctionCall = PendingFunctionCall(
            functionCall: functionCall,
            requestId: requestId,
            history: history,
            completion: completion
        )
        
        // Execute function via coordinator
        Task {
            do {
                try await functionCoordinator.handleFunctionCall(
                    name: functionCall.name,
                    arguments: functionCall.arguments,
                    requestId: requestId
                )
            } catch {
                print("❌ AICoordinator: Function call failed - \(error.localizedDescription)")
                await MainActor.run {
                    completion(.failure(error))
                }
            }
        }
    }
    
    // MARK: - Notification Observers
    
    private var observers: [NSObjectProtocol] = []
    
    private func setupNotificationObservers() {
        // Observe all response types
        let responseObserver = notificationManager.observeResponse(
            type: .taskQueryResponse
        ) { [weak self] (payload: AINotificationManager.TaskResponsePayload<[AITaskDTO]>) in
            self?.handleFunctionResponse(payload)
        }
        observers.append(responseObserver)
        
        let createObserver = notificationManager.observeResponse(
            type: .taskCreateResponse
        ) { [weak self] (payload: AINotificationManager.TaskResponsePayload<[AITaskDTO]>) in
            self?.handleFunctionResponse(payload)
        }
        observers.append(createObserver)
        
        let updateObserver = notificationManager.observeResponse(
            type: .taskUpdateResponse
        ) { [weak self] (payload: AINotificationManager.TaskResponsePayload<AITaskDTO>) in
            self?.handleFunctionResponse(payload)
        }
        observers.append(updateObserver)
        
        let deleteObserver = notificationManager.observeResponse(
            type: .taskDeleteResponse
        ) { [weak self] (payload: AINotificationManager.TaskResponsePayload<[String: String]>) in
            self?.handleFunctionResponse(payload)
        }
        observers.append(deleteObserver)
    }
    
    private func removeNotificationObservers() {
        observers.forEach { notificationManager.removeObserver($0) }
        observers.removeAll()
    }
    
    private func handleFunctionResponse<T: Codable>(_ payload: AINotificationManager.TaskResponsePayload<T>) {
        guard let pending = pendingFunctionCall,
              payload.requestId == pending.requestId else {
            print("⚠️ AICoordinator: Response requestId mismatch")
            return
        }
        
        print("📥 AICoordinator: Got function response - success: \(payload.success)")
        
        // Convert response to JSON string
        let responseContent: String
        if payload.success, let data = payload.data {
            responseContent = formatFunctionResult(data)
        } else {
            responseContent = "Error: \(payload.error ?? "Unknown error")"
        }
        
        // Send function result back to AI
        sendFunctionResultToAI(
            functionName: pending.functionCall.name,
            result: responseContent,
            history: pending.history,
            completion: pending.completion
        )
        
        // Clear pending call
        pendingFunctionCall = nil
    }
    
    private func formatFunctionResult<T: Codable>(_ data: T) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        
        if let jsonData = try? encoder.encode(data),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            return jsonString
        }
        
        return "\(data)"
    }
    
    private func sendFunctionResultToAI(
        functionName: String,
        result: String,
        history: [ChatMessage],
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        print("🔄 AICoordinator: Sending function result back to AI")
        
        Task {
            do {
                // Build messages with function response
                var messages = history
                messages.append(ChatMessage(
                    role: "function",
                    content: result,
                    name: functionName
                ))
                
                // Send back to AI
                let response = try await firebaseAIService.sendChatRequest(
                    messages: messages,
                    functions: nil,  // No functions for follow-up
                    functionCall: nil,
                    maxTokens: 1000
                )
                
                if let content = response.choices.first?.message.content {
                    print("✅ AICoordinator: Got final AI response")
                    completion(.success(content))
                } else {
                    completion(.failure(AICoordinatorError.emptyResponse))
                }
                
            } catch {
                print("❌ AICoordinator: Follow-up request failed - \(error.localizedDescription)")
                completion(.failure(error))
            }
        }
    }
}

// MARK: - Supporting Types

extension AICoordinator {
    struct PendingFunctionCall {
        let functionCall: ChatCompletionResponse.Choice.Message.FunctionCall
        let requestId: String
        let history: [ChatMessage]
        let completion: (Result<String, Error>) -> Void
    }
}

enum AICoordinatorError: Error, LocalizedError {
    case noResponse
    case emptyResponse
    case invalidFunctionResponse
    
    var errorDescription: String? {
        switch self {
        case .noResponse:
            return "No response from AI"
        case .emptyResponse:
            return "AI returned empty response"
        case .invalidFunctionResponse:
            return "Invalid function response format"
        }
    }
}

