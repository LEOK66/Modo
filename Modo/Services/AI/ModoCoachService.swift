import Foundation
import SwiftData
import Combine
import FirebaseAuth

class ModoCoachService: ObservableObject {
    
    @Published var messages: [FirebaseChatMessage] = []
    @Published var isProcessing: Bool = false
    
    private var modelContext: ModelContext?
    private var hasLoadedHistory = false
    private var lastLoadedUserId: String? = nil // ✅ Track which user's history was loaded
    private let firebaseAIService = FirebaseAIService.shared
    
    // ✅ Use AIPromptBuilder for unified prompt construction
    private let promptBuilder = AIPromptBuilder()
    
    // ✅ Use AIResponseCoordinator for handling AI responses and function calls
    private let responseCoordinator: AIResponseCoordinator
    
    // ✅ Use specialized services
    private let contentModerator: ContentModerationService
    private let imageAnalyzer: ImageAnalysisService
    private let taskResponder: TaskResponseService
    private let legacyPlanService: LegacyPlanService
    
    // ✅ Use AIFunctionCallCoordinator for CRUD operations
    private let functionCoordinator = AIFunctionCallCoordinator.shared
    
    // MARK: - Constants
    
    /// Maximum number of conversation history messages to include in API request
    /// Includes both user and assistant messages (10 pairs + current message = 21 total)
    private let maxHistoryMessages = 10
    
    /// Default workout exercise parameters for fallback generation
    private struct DefaultWorkoutParams {
        static let sets = 3
        static let restSecModerate = 60
        static let restSecHigh = 90
        static let rpeModerate = 7
        static let rpeHigh = 8
        static let rpeLow = 5
    }
    
    init() {
        // Initialize services
        self.responseCoordinator = AIResponseCoordinator()
        self.contentModerator = ContentModerationService()
        self.imageAnalyzer = ImageAnalysisService()
        self.taskResponder = TaskResponseService()
        self.legacyPlanService = LegacyPlanService()
        
        // Welcome message will be added after loading history
        
        // ✅ Register CRUD function handlers
        registerFunctionHandlers()
        
        // ✅ Setup responseCoordinator callbacks
        setupResponseCoordinatorCallbacks()
    }
    
    // MARK: - Register Function Handlers
    private func registerFunctionHandlers() {
        functionCoordinator.registerHandlers([
            QueryTasksHandler(),
            CreateTasksHandler(),
            UpdateTaskHandler(),
            DeleteTaskHandler()
        ])
        print("✅ Registered \(functionCoordinator.getRegisteredFunctions().count) CRUD handlers")
    }
    
    // MARK: - Setup Response Coordinator Callbacks
    private func setupResponseCoordinatorCallbacks() {
        // Handle text responses from AI
        responseCoordinator.onTextResponse = { [weak self] text in
            guard let self = self else { return }
            DispatchQueue.main.async {
                let aiMessage = FirebaseChatMessage(content: text, isFromUser: false)
                self.messages.append(aiMessage)
                self.saveMessage(aiMessage)
            }
        }
        
        // Handle errors
        responseCoordinator.onError = { [weak self] errorMessage in
            guard let self = self else { return }
            DispatchQueue.main.async {
                let errorMsg = FirebaseChatMessage(content: errorMessage, isFromUser: false)
                self.messages.append(errorMsg)
                self.saveMessage(errorMsg)
            }
        }
        
        // Handle processing state changes
        responseCoordinator.onProcessingStateChanged = { [weak self] isProcessing in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.isProcessing = isProcessing
            }
        }
        
        // Handle legacy plan generation
        responseCoordinator.onLegacyPlanGenerated = { [weak self] planResult in
            guard let self = self else { return }
            print("📥 ModoCoachService: Received legacy plan result")
            DispatchQueue.main.async {
                let message = FirebaseChatMessage(
                    content: planResult.content,
                    isFromUser: false,
                    messageType: planResult.messageType,
                    workoutPlan: planResult.workoutPlan,
                    nutritionPlan: planResult.nutritionPlan,
                    multiDayPlan: planResult.multiDayPlan
                )
                self.messages.append(message)
                self.saveMessage(message)
                print("✅ ModoCoachService: Legacy plan message added to UI")
            }
        }
    }
    
    // ✅ Reset state when user changes
    func resetForNewUser() {
        hasLoadedHistory = false
        lastLoadedUserId = nil
        messages.removeAll()
        modelContext = nil
    }
    
    // MARK: - Load History from SwiftData
    func loadHistory(from context: ModelContext, userProfile: UserProfile? = nil) {
        // ✅ Get current user ID
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            print("⚠️ No current user, cannot load chat history")
            messages.removeAll()
            return
        }
        
        // ✅ Check if this is a different user - if so, reset the flag
        if lastLoadedUserId != currentUserId {
            hasLoadedHistory = false
            messages.removeAll()
        }
        
        guard !hasLoadedHistory else { return }
        
        self.modelContext = context
        self.lastLoadedUserId = currentUserId
        
        // ✅ Filter messages by current user ID
        let predicate = #Predicate<FirebaseChatMessage> { message in
            message.userId == currentUserId
        }
        let descriptor = FetchDescriptor<FirebaseChatMessage>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.timestamp, order: .forward)]
        )
        
        do {
            let savedMessages = try context.fetch(descriptor)
            
            // ⚠️ REMOVED: Force loading properties can cause crashes with schema changes
            // SwiftData will lazy-load properties when actually accessed (safer approach)
            // The UI already has safe access patterns (e.g., safeMultiDayPlan in ChatBubble)
            
            if savedMessages.isEmpty {
                // First time - show welcome message
                // User info is already in system prompt, no need to send as user message
                addWelcomeMessage()
            } else {
                // Load existing messages
                messages = savedMessages
            }
            hasLoadedHistory = true
            
            print("✅ Loaded \(messages.count) chat messages for user \(currentUserId)")
        } catch {
            print("Failed to load chat history: \(error)")
            addWelcomeMessage()
            hasLoadedHistory = true
        }
    }
    
    // MARK: - Clear Chat History
    func clearHistory(with context: ModelContext? = nil) {
        // Use provided context or fallback to stored modelContext
        let contextToUse = context ?? modelContext
        
        guard let contextToUse = contextToUse,
              let currentUserId = Auth.auth().currentUser?.uid else {
            print("⚠️ No current user or context, cannot clear chat history")
            return
        }
        
        // ✅ Clear in-memory messages FIRST to avoid UI trying to access deleted objects
        messages.removeAll()
        
        // ✅ Only delete messages belonging to current user
        do {
            let predicate = #Predicate<FirebaseChatMessage> { message in
                message.userId == currentUserId
            }
            let descriptor = FetchDescriptor<FirebaseChatMessage>(predicate: predicate)
            
            // ⚠️ CRITICAL: Fetching old messages may fail if schema has changed
            let userMessages = try contextToUse.fetch(descriptor)
            
            // ✅ Force load all properties before deletion to avoid fault errors
            for message in userMessages {
                // Access properties to ensure they're loaded before deletion
                _ = message.workoutPlan
                _ = message.nutritionPlan
                _ = message.multiDayPlan
                contextToUse.delete(message)
            }
            
            try contextToUse.save()
            
            // Add welcome message after successful deletion
            addWelcomeMessage()
            
            print("✅ Chat history cleared successfully")
            
        } catch {
            print("❌ Failed to clear chat history: \(error)")
            print("🔄 This is likely due to schema migration issues")
            print("💡 Recommendation: Delete and reinstall the app to clear old database")
            
            // Try to at least clear in-memory messages
            messages.removeAll()
            addWelcomeMessage()
            
            // Show error to user
            DispatchQueue.main.async {
                // You could post a notification here to show an alert to user
                NotificationCenter.default.post(
                    name: NSNotification.Name("DatabaseMigrationError"),
                    object: nil,
                    userInfo: ["error": error.localizedDescription]
                )
            }
        }
    }
    
    // MARK: - Add Welcome Message
    private func addWelcomeMessage() {
        let welcomeMessage = FirebaseChatMessage(
            content: "Hi! I'm your MODO wellness assistant. I can help you with diet planning, fitness routines, and healthy lifestyle tips.\nWhat would you like to know?",
            isFromUser: false
        )
        messages.append(welcomeMessage)
        saveMessage(welcomeMessage)
    }
    
    // MARK: - Save Message to SwiftData
    func saveMessage(_ message: FirebaseChatMessage) {
        guard let context = modelContext else { return }
        context.insert(message)
        try? context.save()
    }
    
    // MARK: - Accept Workout Plan
    func acceptWorkoutPlan(for message: FirebaseChatMessage, onTaskCreated: ((WorkoutPlanData) -> Void)? = nil, onTextPlanAccepted: (() -> Void)? = nil) {
        // Check if it's a structured workout plan
        if let plan = message.workoutPlan {
            // Call the callback to create task
            onTaskCreated?(plan)
            
            let confirmMessage = FirebaseChatMessage(
                content: "Great! I've added your workout plan to your tasks. Don't forget to log your progress after completing it! 💪",
                isFromUser: false
            )
            messages.append(confirmMessage)
            saveMessage(confirmMessage)
        } else {
            // Handle text-based workout plan
            onTextPlanAccepted?()
            
            let confirmMessage = FirebaseChatMessage(
                content: "Great! I've added this workout to your tasks. Don't forget to log your progress! 💪",
                isFromUser: false
            )
            messages.append(confirmMessage)
            saveMessage(confirmMessage)
        }
    }
    
    // MARK: - Reject Workout Plan
    func rejectWorkoutPlan(for message: FirebaseChatMessage) {
        let rejectMessage = FirebaseChatMessage(
            content: "No problem! Let me know what you'd like to adjust. Would you prefer:\n\n• Different exercises\n• More/less intensity\n• Shorter/longer workout\n\nJust tell me what works better for you!",
            isFromUser: false
        )
        messages.append(rejectMessage)
        saveMessage(rejectMessage)
    }
    
    // MARK: - Send Message
    func sendMessage(_ text: String, userProfile: UserProfile?) {
        // Check for inappropriate content before sending
        if contentModerator.isInappropriate(text) {
            let refusalMessage = contentModerator.generateRefusalMessage()
            let message = FirebaseChatMessage(content: refusalMessage, isFromUser: false)
            messages.append(message)
            saveMessage(message)
            return
        }
        
        // ✅ Add user message IMMEDIATELY before AI processing
        let userMessage = FirebaseChatMessage(content: text, isFromUser: true)
        messages.append(userMessage)
        saveMessage(userMessage)
        
        // Process with AI
        isProcessing = true
        
        // Convert messages to ChatMessage format (include system prompt with user profile)
        let history = convertToChatMessages(includeSystemPrompt: true, userProfile: userProfile)
        
        // Create new message list with user's input
        var messagesToSend = history
        messagesToSend.append(ChatMessage(role: "user", content: text))
        
        // Call Firebase AI Service directly for smart routing
        Task {
            await processWithAI(messages: messagesToSend, userProfile: userProfile)
        }
    }
    
    // MARK: - Process with AI (Smart Routing)
    private func processWithAI(messages: [ChatMessage], userProfile: UserProfile?) async {
        do {
            let response = try await firebaseAIService.sendChatRequest(
                messages: messages,
                functions: firebaseAIService.buildFunctions(),
                functionCall: "auto",
                parallelToolCalls: false
            )
            
            // ✅ Delegate to AIResponseCoordinator for unified response handling
            responseCoordinator.processResponse(response, history: messages, userProfile: userProfile)
            
        } catch {
            print("❌ AI request failed: \(error.localizedDescription)")
            await MainActor.run {
                self.isProcessing = false
                
                // Convert to ModoAIError for better error messages
                let modoError = ModoAIError.from(error)
                
                // Build user-friendly error message
                var errorText = modoError.errorDescription ?? "sorry, something went wrong"
                
                // Add recovery suggestion for better UX
                if let suggestion = modoError.recoverySuggestion {
                    errorText += "\n\n💡 \(suggestion)"
                }
                
                let errorMessage = FirebaseChatMessage(
                    content: errorText,
                    isFromUser: false
                )
                self.messages.append(errorMessage)
                self.saveMessage(errorMessage)
            }
        }
    }
    
    // MARK: - Convert Messages
    private func convertToChatMessages(includeSystemPrompt: Bool = false, userProfile: UserProfile? = nil) -> [ChatMessage] {
        var chatMessages: [ChatMessage] = []
        
        // Add system prompt if requested
        if includeSystemPrompt {
            let systemPrompt = promptBuilder.buildSystemPrompt(userProfile: userProfile)
            chatMessages.append(ChatMessage(role: "system", content: systemPrompt))
        }
        
        // Get recent message history (limit to maxHistoryMessages pairs)
        let recentMessages = Array(messages.suffix(maxHistoryMessages * 2))
        
        let historyMessages = recentMessages.map { message in
            ChatMessage(
                role: message.isFromUser ? "user" : "assistant",
                content: message.content
            )
        }
        
        chatMessages.append(contentsOf: historyMessages)
        return chatMessages
    }
    
    // MARK: - Send Text Message (without AI processing)
    func sendTextMessage(_ text: String) {
        let message = FirebaseChatMessage(content: text, isFromUser: false)
        messages.append(message)
        saveMessage(message)
    }
    
    // MARK: - Send User Message
    func sendUserMessage(_ text: String) {
        let message = FirebaseChatMessage(content: text, isFromUser: true)
        messages.append(message)
        saveMessage(message)
    }
    
    // MARK: - Analyze Food Image
    func analyzeFoodImage(base64Image: String, userProfile: UserProfile?) async {
        isProcessing = true
        
        // ✅ Delegate to ImageAnalysisService
        do {
            let content = try await imageAnalyzer.analyzeFoodImage(base64Image)
            
                await MainActor.run {
                self.isProcessing = false
                    let nutritionMessage = FirebaseChatMessage(
                        content: "🍽️ Food Analysis:\n\n\(content)",
                        isFromUser: false
                    )
                    self.messages.append(nutritionMessage)
                    self.saveMessage(nutritionMessage)
                }
        } catch {
            await MainActor.run {
                self.isProcessing = false
                
                // Convert to ModoAIError for friendly message
                let modoError = ModoAIError.from(error)
                
                // Build user-friendly error message
                var errorText = "Sorry, I couldn't analyze this image."
                if let description = modoError.errorDescription {
                    errorText += "\n\n\(description)"
                }
                if let suggestion = modoError.recoverySuggestion {
                    errorText += "\n\n💡 \(suggestion)"
                }
                
                let errorMessage = FirebaseChatMessage(
                    content: errorText,
                    isFromUser: false
                )
                self.messages.append(errorMessage)
                self.saveMessage(errorMessage)
            }
        }
    }
    
    // MARK: - Process with OpenAI API
    private func processWithOpenAI(_ text: String, userProfile: UserProfile?) async {
        do {
            // Build conversation history
            var apiMessages: [ChatMessage] = []
            
            // ✅ Use AIPromptBuilder for unified prompt construction
            let systemPrompt = promptBuilder.buildChatSystemPrompt(userProfile: userProfile)
            apiMessages.append(ChatMessage(
                role: "system",
                content: systemPrompt
            ))
            
            // Add recent conversation history
            let recentMessages = messages.suffix(maxHistoryMessages * 2 + 1) // pairs + current
            for msg in recentMessages.dropLast() {
                apiMessages.append(ChatMessage(
                    role: msg.isFromUser ? "user" : "assistant",
                    content: msg.content
                ))
            }
            
            // Add current user message
            apiMessages.append(ChatMessage(
                role: "user",
                content: text
            ))
            
            // Enable Function Calling with strict: true
            // Use unified maxTokens (sufficient for both single-day and multi-day plans)
            let response = try await firebaseAIService.sendChatRequest(
                messages: apiMessages,
                functions: firebaseAIService.buildFunctions(),
                functionCall: "auto",
                parallelToolCalls: false
            )
            
            await MainActor.run {
                self.isProcessing = false
                
                // Always show text response first (user visible)
                if let textContent = response.choices.first?.message.content, !textContent.isEmpty {
                    let responseMessage = FirebaseChatMessage(
                        content: textContent,
                        isFromUser: false
                    )
                    self.messages.append(responseMessage)
                    self.saveMessage(responseMessage)
                }
                
                // If there is a Function Call, create task (background)
                if let functionCall = response.choices.first?.message.effectiveFunctionCall {
                    print("🔧 Function called: \(functionCall.name)")
                    self.handleFunctionCall(functionCall, userProfile: userProfile)
                }
            }
            
        } catch {
            await MainActor.run {
                self.isProcessing = false
                print("❌ Error processing with OpenAI: \(error)")
                
                // Convert to ModoAIError for friendly message
                let modoError = ModoAIError.from(error)
                
                // Build user-friendly error message
                var errorText = modoError.errorDescription ?? "Sorry, there was an error processing your request. Please try again."
                if let suggestion = modoError.recoverySuggestion {
                    errorText += "\n\n💡 \(suggestion)"
                }
                
                let errorMessage = FirebaseChatMessage(
                    content: errorText,
                    isFromUser: false
                )
                self.messages.append(errorMessage)
                self.saveMessage(errorMessage)
            }
        }
    }
    
    // MARK: - Handle Function Call
    private func handleFunctionCall(_ functionCall: ChatCompletionResponse.Choice.Message.FunctionCall, userProfile: UserProfile?) {
        guard let data = functionCall.arguments.data(using: .utf8) else {
            print("❌ Failed to convert arguments to data")
            return
        }
        
        // ✅ Check if new CRUD handler exists
        if functionCoordinator.hasHandler(for: functionCall.name) {
            Task {
                do {
                    try await functionCoordinator.handleFunctionCall(
                        name: functionCall.name,
                        arguments: functionCall.arguments
                    )
        } catch {
                    print("❌ CRUD function call failed: \(error.localizedDescription)")
                    await MainActor.run {
                        let errorMessage = FirebaseChatMessage(
                            content: "Failed to process your request. Please try again.",
                            isFromUser: false
                        )
                        self.messages.append(errorMessage)
                        self.saveMessage(errorMessage)
                    }
                }
            }
                    return
        }
        
        // ✅ Delegate to LegacyPlanService for plan generation functions
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
            print("⚠️ Unknown function: \(functionCall.name)")
        }
    }
    
    // MARK: - Handle Legacy Plan Result
    private func handleLegacyPlanResult(_ result: Result<PlanResult, Error>) {
        switch result {
        case .success(let planResult):
            let message = FirebaseChatMessage(
                content: planResult.content,
                isFromUser: false,
                messageType: planResult.messageType,
                workoutPlan: planResult.workoutPlan,
                nutritionPlan: planResult.nutritionPlan,
                multiDayPlan: planResult.multiDayPlan
            )
            messages.append(message)
            saveMessage(message)
            
        case .failure(let error):
            print("❌ LegacyPlanService error: \(error.localizedDescription)")
        let errorMessage = FirebaseChatMessage(
                content: "Had trouble generating that plan. Please try again.",
            isFromUser: false
        )
        messages.append(errorMessage)
        saveMessage(errorMessage)
    }
    }
    
    
    
    // MARK: - Inappropriate Content Detection
    private func isInappropriate(_ text: String) -> Bool {
        // Only block clearly inappropriate or harmful content
        // Be careful: some words might appear in legitimate health contexts
        let lowercased = text.lowercased()
        
        // Check for explicit sexual content (not health-related)
        let explicitSexual = ["porn", "pornography", "xxx", "nsfw"]
        let hasExplicitSexual = explicitSexual.contains { lowercased.contains($0) }
        
        // Check for violence (not exercise-related)
        let violenceKeywords = ["kill", "murder", "weapon", "gun", "bomb", "attack"]
        let hasViolence = violenceKeywords.contains { lowercased.contains($0) }
        
        // Check for illegal activities (not supplement-related)
        // Note: "drug" could be in "drug testing" or "drug store", so we need context
        let illegalKeywords = ["illegal", "steal", "rob", "fraud"]
        let hasIllegal = illegalKeywords.contains { lowercased.contains($0) }
        
        // Only block if it's clearly inappropriate AND not health/fitness related
        if hasExplicitSexual || hasViolence || hasIllegal {
            // Double-check: don't block if it's in a health/fitness context
            let healthContext = ["health", "fitness", "exercise", "workout", "training", "nutrition", "supplement", "medical", "recovery", "therapy"]
            let hasHealthContext = healthContext.contains { lowercased.contains($0) }
            
            // If it's in a health context, let it through (AI will handle it appropriately)
            if hasHealthContext {
                return false
            }
            
            return true
        }
        
        return false
    }
    
}
