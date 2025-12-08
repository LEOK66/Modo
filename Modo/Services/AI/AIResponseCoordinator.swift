import Foundation

/// AI Response Coordinator
///
/// Manages AI response processing workflow:
/// - Routes between text responses and function calls
/// - Coordinates CRUD handlers via AIFunctionCallCoordinator
/// - Delegates legacy plan generation to LegacyPlanService
/// - Observes function call results and generates natural language responses
class AIResponseCoordinator {
    
    // MARK: - Dependencies
    
    private let firebaseAIService: FirebaseAIService
    private let functionCoordinator: AIFunctionCallCoordinator
    private let legacyPlanService: LegacyPlanService
    private let notificationManager: AINotificationManager
    
    // MARK: - State
    
    private var pendingFunctionCall: PendingFunctionInfo?
    private var functionResponseObservers: [NSObjectProtocol] = []
    
    // MARK: - Callbacks
    
    /// Called when a text response is received from AI
    var onTextResponse: ((String) -> Void)?
    
    /// Called when an error occurs
    var onError: ((String) -> Void)?
    
    /// Called when processing state changes
    var onProcessingStateChanged: ((Bool) -> Void)?
    
    /// Called when a legacy plan is generated
    var onLegacyPlanGenerated: ((PlanResult) -> Void)?
    
    // MARK: - Init
    
    init(
        firebaseAIService: FirebaseAIService = .shared,
        functionCoordinator: AIFunctionCallCoordinator = .shared,
        legacyPlanService: LegacyPlanService = LegacyPlanService(),
        notificationManager: AINotificationManager = .shared
    ) {
        self.firebaseAIService = firebaseAIService
        self.functionCoordinator = functionCoordinator
        self.legacyPlanService = legacyPlanService
        self.notificationManager = notificationManager
        
        setupFunctionResponseObservers()
    }
    
    deinit {
        // Cleanup observers
        functionResponseObservers.forEach { NotificationCenter.default.removeObserver($0) }
    }
    
    // MARK: - Setup Observers
    
    private func setupFunctionResponseObservers() {
        // Observe query_tasks responses
        let queryObserver = notificationManager.observeResponse(
            type: .taskQueryResponse
        ) { [weak self] (payload: AINotificationManager.TaskResponsePayload<[AITaskDTO]>) in
            self?.handleFunctionResponse(payload: payload)
        }
        functionResponseObservers.append(queryObserver)
        
        // Observe create_tasks responses
        let createObserver = notificationManager.observeResponse(
            type: .taskCreateResponse
        ) { [weak self] (payload: AINotificationManager.TaskResponsePayload<[AITaskDTO]>) in
            self?.handleFunctionResponse(payload: payload)
        }
        functionResponseObservers.append(createObserver)
        
        // Observe update_task responses
        let updateObserver = notificationManager.observeResponse(
            type: .taskUpdateResponse
        ) { [weak self] (payload: AINotificationManager.TaskResponsePayload<AITaskDTO>) in
            self?.handleFunctionResponse(payload: payload)
        }
        functionResponseObservers.append(updateObserver)
        
        // Observe delete_task responses
        let deleteObserver = notificationManager.observeResponse(
            type: .taskDeleteResponse
        ) { [weak self] (payload: AINotificationManager.TaskResponsePayload<Bool>) in
            self?.handleFunctionResponse(payload: payload)
        }
        functionResponseObservers.append(deleteObserver)
    }
    
    // MARK: - Process AI Response
    
    /// Process AI response and route to appropriate handler
    /// - Parameters:
    ///   - response: AI response from Firebase
    ///   - history: Conversation history for context
    ///   - userProfile: User profile for personalization
    func processResponse(
        _ response: ChatCompletionResponse,
        history: [ChatMessage],
        userProfile: UserProfile?
    ) {
        guard let choice = response.choices.first else {
            onProcessingStateChanged?(false)
            print("⚠️ AIResponseCoordinator: Empty AI response")
            return
        }
        
        // Check if AI wants to call a function
        if let functionCall = choice.message.effectiveFunctionCall {
            print("🔧 AIResponseCoordinator: AI requested function call - \(functionCall.name)")
            handleFunctionCallRequest(functionCall, history: history, userProfile: userProfile)
        } else if let content = choice.message.content, !content.isEmpty {
            // Direct text response from AI
            onProcessingStateChanged?(false)
            print("✅ AIResponseCoordinator: Got text response - \(content.prefix(100))...")
            onTextResponse?(content)
        } else {
            onProcessingStateChanged?(false)
            print("⚠️ AIResponseCoordinator: Empty content in AI response")
        }
    }
    
    // MARK: - Handle Function Call Request
    
    private func handleFunctionCallRequest(
        _ functionCall: ChatCompletionResponse.Choice.Message.FunctionCall,
        history: [ChatMessage],
        userProfile: UserProfile?
    ) {
        // Check if this is a new CRUD function that has a handler
        if functionCoordinator.hasHandler(for: functionCall.name) {
            // Use new handler architecture for CRUD operations
            handleCRUDFunctionCall(functionCall, history: history, userProfile: userProfile)
        } else {
            // Use legacy handler for workout/nutrition plan generation
            handleLegacyFunctionCall(functionCall, userProfile: userProfile)
        }
    }
    
    // MARK: - Handle CRUD Function Call
    
    private func handleCRUDFunctionCall(
        _ functionCall: ChatCompletionResponse.Choice.Message.FunctionCall,
        history: [ChatMessage],
        userProfile: UserProfile?
    ) {
        let requestId = UUID().uuidString
        
        // Create assistant message with function call to maintain history
        let assistantMessage = ChatMessage(
            role: "assistant",
            content: "", // Content is empty for function calls
            name: nil,
            functionCall: FunctionCallData(
                name: functionCall.name,
                arguments: functionCall.arguments
            )
        )
        
        // Append to history for the follow-up request
        var updatedHistory = history
        updatedHistory.append(assistantMessage)
        
        // Store pending function call info with updated history
        pendingFunctionCall = PendingFunctionInfo(
            functionName: functionCall.name,
            requestId: requestId,
            history: updatedHistory,
            userProfile: userProfile
        )
        
        // Execute function handler
        Task {
            do {
                try await functionCoordinator.handleFunctionCall(
                    name: functionCall.name,
                    arguments: functionCall.arguments,
                    requestId: requestId
                )
                // Response will be handled by observer
            } catch {
                await MainActor.run {
                    self.onProcessingStateChanged?(false)
                    self.pendingFunctionCall = nil
                    print("❌ AIResponseCoordinator: Function call failed - \(error.localizedDescription)")
                    self.onError?("Sorry, there was an error executing the operation.")
                }
            }
        }
    }
    
    // MARK: - Handle Legacy Function Call
    
    private func handleLegacyFunctionCall(
        _ functionCall: ChatCompletionResponse.Choice.Message.FunctionCall,
        userProfile: UserProfile?
    ) {
        guard let data = functionCall.arguments.data(using: .utf8) else {
            print("❌ AIResponseCoordinator: Failed to convert arguments to data")
            onProcessingStateChanged?(false)
            onError?("Failed to process plan generation request.")
            return
        }
        
        switch functionCall.name {
        case "generate_workout_plan":
            legacyPlanService.handleWorkoutPlan(data: data, userProfile: userProfile) { [weak self] result in
                self?.handleLegacyPlanResult(result)
            }
            
        case "generate_nutrition_plan":
            legacyPlanService.handleNutritionPlan(data: data, userProfile: userProfile) { [weak self] result in
                self?.handleLegacyPlanResult(result)
            }
            
        case "generate_multi_day_plan":
            legacyPlanService.handleMultiDayPlan(data: data, userProfile: userProfile) { [weak self] result in
                self?.handleLegacyPlanResult(result)
            }
            
        default:
            print("⚠️ AIResponseCoordinator: Unknown function - \(functionCall.name)")
            onProcessingStateChanged?(false)
            onError?("Unknown operation requested.")
        }
    }
    
    // MARK: - Handle Legacy Plan Result
    
    private func handleLegacyPlanResult(_ result: Result<PlanResult, Error>) {
        switch result {
        case .success(let planResult):
            print("✅ AIResponseCoordinator: Legacy plan generated successfully")
            onProcessingStateChanged?(false)
            // ✅ Use callback to notify ModoCoachService
            onLegacyPlanGenerated?(planResult)
            
        case .failure(let error):
            print("❌ AIResponseCoordinator: Legacy plan error - \(error.localizedDescription)")
            onProcessingStateChanged?(false)
            onError?("Had trouble generating that plan. Please try again.")
        }
    }
    
    // MARK: - Handle Function Response
    
    private func handleFunctionResponse<T: Codable>(payload: AINotificationManager.TaskResponsePayload<T>) {
        guard let pendingCall = pendingFunctionCall,
              payload.requestId == pendingCall.requestId else {
            print("⚠️ AIResponseCoordinator: Response requestId mismatch or no pending call")
            return
        }
        
        print("✅ AIResponseCoordinator: Received function response for \(pendingCall.functionName)")
        
        // Convert response to JSON string
        let resultString = formatFunctionResult(payload)
        
        // Send result back to AI to generate natural language response
        sendFunctionResultToAI(
            functionName: pendingCall.functionName,
            result: resultString,
            history: pendingCall.history,
            userProfile: pendingCall.userProfile
        )
        
        // Clear pending call
        pendingFunctionCall = nil
    }
    
    // MARK: - Format Function Result
    
    private func formatFunctionResult<T: Codable>(_ payload: AINotificationManager.TaskResponsePayload<T>) -> String {
        if payload.success {
            if let data = payload.data {
                // Try to encode data to JSON
                if let jsonData = try? JSONEncoder().encode(data),
                   let jsonString = String(data: jsonData, encoding: .utf8) {
                    return jsonString
                }
                return "\(data)"
            }
            return "{\"success\": true}"
        } else {
            return "{\"success\": false, \"error\": \"\(payload.error ?? "Unknown error")\"}"
        }
    }
    
    // MARK: - Send Function Result to AI
    
    private func sendFunctionResultToAI(
        functionName: String,
        result: String,
        history: [ChatMessage],
        userProfile: UserProfile?
    ) {
        print("🔄 AIResponseCoordinator: Sending function result back to AI")
        
        Task {
            do {
                // Build messages with function response
                var messages = history
                messages.append(ChatMessage(
                    role: "function",
                    content: result,
                    name: functionName
                ))
                
                // Send back to AI - keep functions available for chained calls
                // (e.g., query_tasks → delete_task)
                let response = try await firebaseAIService.sendChatRequest(
                    messages: messages,
                    functions: firebaseAIService.buildFunctions(),  // ✅ Keep functions available!
                    functionCall: "auto",
                    parallelToolCalls: false,  // Serial execution for chained calls
                    maxTokens: 1000
                )
                
                // ✅ Check if AI wants to call another function (chained call, e.g., delete_task after query_tasks)
                if let nextFunctionCall = response.choices.first?.message.effectiveFunctionCall {
                    print("🔗 AIResponseCoordinator: AI wants to chain another function call - \(nextFunctionCall.name)")
                    // Recursively handle the next function call
                    await MainActor.run {
                        self.processResponse(response, history: messages, userProfile: userProfile)
                    }
                } else if let content = response.choices.first?.message.content {
                    // Final text response
                    print("✅ AIResponseCoordinator: Got final AI response")
                    await MainActor.run {
                        self.onProcessingStateChanged?(false)
                        self.onTextResponse?(content)
                    }
                } else {
                    print("⚠️ AIResponseCoordinator: Empty AI response after function call")
                    await MainActor.run {
                        self.onProcessingStateChanged?(false)
                        self.onTextResponse?("Operation completed.")
                    }
                }
                
            } catch {
                await MainActor.run {
                    self.onProcessingStateChanged?(false)
                    print("❌ AIResponseCoordinator: Failed to get AI response - \(error.localizedDescription)")
                    self.onError?("Sorry, I couldn't generate a response.")
                }
            }
        }
    }
}

// MARK: - Supporting Types

/// Stores information about a pending function call waiting for response
private struct PendingFunctionInfo {
    let functionName: String
    let requestId: String
    let history: [ChatMessage]
    let userProfile: UserProfile?
}

