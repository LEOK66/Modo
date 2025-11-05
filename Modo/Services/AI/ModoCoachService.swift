import Foundation
import SwiftData
import Combine

class ModoCoachService: ObservableObject {
    
    @Published var messages: [FirebaseChatMessage] = []
    @Published var isProcessing: Bool = false
    
    private var modelContext: ModelContext?
    private var hasLoadedHistory = false
    private let firebaseAIService = FirebaseAIService.shared
    
    // ✅ Use AIPromptBuilder for unified prompt construction
    private let promptBuilder = AIPromptBuilder()
    
    init() {
        // Welcome message will be added after loading history
    }
    
    // MARK: - Load History from SwiftData
    func loadHistory(from context: ModelContext, userProfile: UserProfile? = nil) {
        guard !hasLoadedHistory else { return }
        
        self.modelContext = context
        
        let descriptor = FetchDescriptor<FirebaseChatMessage>(
            sortBy: [SortDescriptor(\.timestamp, order: .forward)]
        )
        
        do {
            let savedMessages = try context.fetch(descriptor)
            if savedMessages.isEmpty {
                // First time, check if we need to send user info
                if shouldSendUserInfo(userProfile: userProfile) {
                    sendInitialUserInfo(userProfile: userProfile)
                } else {
                    addWelcomeMessage()
                }
            } else {
                // Load existing messages
                messages = savedMessages
            }
            hasLoadedHistory = true
        } catch {
            print("Failed to load chat history: \(error)")
            addWelcomeMessage()
        }
    }
    
    // MARK: - Check if should send user info
    private func shouldSendUserInfo(userProfile: UserProfile?) -> Bool {
        // Check if user has completed profile setup
        guard let profile = userProfile else { return false }
        
        // Check if user has basic info
        let hasBasicInfo = profile.age != nil && 
                          profile.weightValue != nil && 
                          profile.heightValue != nil &&
                          profile.goal != nil
        
        return hasBasicInfo
    }
    
    // MARK: - Send Initial User Info to AI
    private func sendInitialUserInfo(userProfile: UserProfile?) {
        guard let profile = userProfile else {
            addWelcomeMessage()
            return
        }
        
        isProcessing = true
        
        // Build user info message
        var userInfoText = "Hi! I just signed up. Here's my confirmed profile information:\n\n"
        
        if let age = profile.age {
            userInfoText += "Age: \(age) years old\n"
        }
        
        if let gender = profile.gender {
            // Convert gender code to readable format
            let genderText: String
            switch gender.lowercased() {
            case "male", "m":
                genderText = "Male"
            case "female", "f":
                genderText = "Female"
            case "other", "non-binary", "nb":
                genderText = "Non-binary"
            default:
                genderText = gender.capitalized
            }
            userInfoText += "Gender: \(genderText)\n"
        }
        
        // Keep user's original units - don't convert
        if let weightValue = profile.weightValue, let weightUnit = profile.weightUnit {
            userInfoText += "Weight: \(weightValue) \(weightUnit)\n"
        }
        
        if let heightValue = profile.heightValue, let heightUnit = profile.heightUnit {
            userInfoText += "Height: \(heightValue) \(heightUnit)\n"
        }
        
        if let goal = profile.goal {
            userInfoText += "Goal: \(goal)\n"
        }
        
        if let lifestyle = profile.lifestyle {
            userInfoText += "Lifestyle: \(lifestyle)\n"
        }
        
        userInfoText += "\nI have basic gym equipment available (dumbbells, barbells, and machines). Please create personalized workout and nutrition plans based on this information. No need to ask me for these details again!"
        
        // Add user message
        let userMessage = FirebaseChatMessage(content: userInfoText, isFromUser: true)
        messages.append(userMessage)
        saveMessage(userMessage)
        
        // Get AI response
        Task {
            await processWithOpenAI(userInfoText, userProfile: profile)
        }
    }
    
    // MARK: - Clear Chat History
    func clearHistory() {
        guard let context = modelContext else { return }
        
        // Delete all messages from database
        do {
            let descriptor = FetchDescriptor<FirebaseChatMessage>()
            let allMessages = try context.fetch(descriptor)
            
            for message in allMessages {
                context.delete(message)
            }
            
            try context.save()
            
            // Clear in-memory messages
            messages.removeAll()
            
            // Add welcome message
            addWelcomeMessage()
            
        } catch {
            print("Failed to clear chat history: \(error)")
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
        if isInappropriate(text) {
            refuseInappropriate()
            return
        }
        
        // Add user message
        let userMessage = FirebaseChatMessage(content: text, isFromUser: true)
        messages.append(userMessage)
        saveMessage(userMessage)
        
        // Process with AI
        isProcessing = true
        
        // Call real OpenAI API
        Task {
            await processWithOpenAI(text, userProfile: userProfile)
        }
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
        
        do {
            // Build vision API request
            let systemPrompt = """
            You are a creative nutrition expert with diverse culinary knowledge. Analyze the food in the image and provide:
            1. Food identification (be specific: type of cuisine, preparation style)
            2. Estimated serving size (use oz, cups, or pieces)
            3. Nutritional information: Protein (g), Fat (g), Carbs (g), Calories (kcal)
            
            Format your response EXACTLY as (plain text, no markdown):
            Food: [name and style, e.g., "Grilled Chicken Breast (Mediterranean style)"]
            Serving: [size in oz, cups, or pieces]
            Protein: [X]g
            Fat: [X]g
            Carbs: [X]g
            Calories: [X]kcal
            
            Be specific and consider:
            - Cooking methods (grilled, fried, steamed, baked, raw)
            - Cuisine type (Asian, Mediterranean, American, Mexican, etc.)
            - Ingredient variations
            
            Use Imperial/US measurements:
            - Weight: oz (ounces) for food portions
            - Volume: cups, tablespoons, teaspoons
            - NO metric units
            
            If it's not food or you can't identify it, say "This doesn't appear to be food."
            """
            
            // Build multimodal message with image
            let userContent: [[String: Any]] = [
                [
                    "type": "text",
                    "text": "Analyze this food and provide nutritional information."
                ],
                [
                    "type": "image_url",
                    "image_url": [
                        "url": "data:image/jpeg;base64,\(base64Image)"
                    ]
                ]
            ]
            
            // Create messages using FirebaseAIService
            let messages: [FirebaseFirebaseChatMessage] = [
                FirebaseFirebaseChatMessage(role: "system", content: systemPrompt),
                FirebaseFirebaseChatMessage(role: "user", multimodalContent: userContent)
            ]
            
            // Call Firebase AI Service with reduced maxTokens for food analysis
            let response = try await firebaseAIService.sendChatRequest(
                messages: messages,
                functions: nil,
                functionCall: nil,
                maxTokens: 300
            )
            
            // Extract content from response
            if let content = response.choices.first?.message.content {
                await MainActor.run {
                    let nutritionMessage = FirebaseChatMessage(
                        content: "🍽️ Food Analysis:\n\n\(content)",
                        isFromUser: false
                    )
                    self.messages.append(nutritionMessage)
                    self.saveMessage(nutritionMessage)
                    self.isProcessing = false
                }
            } else {
                throw FirebaseAIError.decodingError
            }
            
        } catch {
            await MainActor.run {
                print("Vision API Error: \(error)")
                let errorMessage = FirebaseChatMessage(
                    content: "Sorry, I couldn't analyze the image. Please make sure it's a clear photo of food and try again.",
                    isFromUser: false
                )
                self.messages.append(errorMessage)
                self.saveMessage(errorMessage)
                self.isProcessing = false
            }
        }
    }
    
    // MARK: - Process with OpenAI API
    private func processWithOpenAI(_ text: String, userProfile: UserProfile?) async {
        do {
            // Build conversation history
            var apiMessages: [FirebaseFirebaseChatMessage] = []
            
            // ✅ Use AIPromptBuilder for unified prompt construction
            let systemPrompt = promptBuilder.buildChatSystemPrompt(userProfile: userProfile)
            apiMessages.append(FirebaseFirebaseChatMessage(
                role: "system",
                content: systemPrompt
            ))
            
            // Add recent conversation history (last 10 messages)
            let recentMessages = messages.suffix(11) // 10 + current message
            for msg in recentMessages.dropLast() {
                apiMessages.append(FirebaseFirebaseChatMessage(
                    role: msg.isFromUser ? "user" : "assistant",
                    content: msg.content
                ))
            }
            
            // Add current user message
            apiMessages.append(FirebaseFirebaseChatMessage(
                role: "user",
                content: text
            ))
            
            // Call Firebase AI Service
            let response = try await firebaseAIService.sendChatRequest(
                messages: apiMessages,
                functions: nil,
                functionCall: nil
            )
            
            await MainActor.run {
                self.isProcessing = false
                
                // Check if OpenAI wants to call a function
                if let functionCall = response.choices.first?.message.functionCall {
                    print("🔧 Function call detected: \(functionCall.name)")
                    
                    // Handle function calls
                    if functionCall.name == "generate_workout_plan" {
                        handleWorkoutPlanFunction(arguments: functionCall.arguments, userProfile: userProfile)
                    } else if functionCall.name == "lookup_food_calorie" {
                        handleFoodCalorieFunction(arguments: functionCall.arguments)
                    }
                }
                // Regular text response
                else if let content = response.choices.first?.message.content {
                    let responseMessage = FirebaseChatMessage(
                        content: content,
                        isFromUser: false
                    )
                    self.messages.append(responseMessage)
                    self.saveMessage(responseMessage)
                }
            }
            
        } catch {
            await MainActor.run {
                self.isProcessing = false
                print("❌ Error processing with OpenAI: \(error)")
                
                // Fallback response
                let errorMessage = FirebaseChatMessage(
                    content: "Sorry, I'm having trouble connecting right now. Please try again in a moment.",
                    isFromUser: false
                )
                self.messages.append(errorMessage)
                self.saveMessage(errorMessage)
            }
        }
    }
    
    // MARK: - Handle OpenAI Response
    private func handleOpenAIResponse(_ response: ChatCompletionResponse, userProfile: UserProfile?) {
        guard let choice = response.choices.first else { return }
        
        // Check if it's a function call
        if let functionCall = choice.message.functionCall {
            handleFunctionCall(functionCall, userProfile: userProfile)
        } else if let content = choice.message.content {
            // Regular text response
            let aiMessage = FirebaseChatMessage(
                content: content,
                isFromUser: false
            )
            messages.append(aiMessage)
            saveMessage(aiMessage)
        }
    }
    
    // MARK: - Handle Function Call
    private func handleFunctionCall(_ functionCall: ChatCompletionResponse.Choice.Message.FunctionCall, userProfile: UserProfile?) {
        switch functionCall.name {
        case "generate_workout_plan":
            handleWorkoutPlanFunction(arguments: functionCall.arguments, userProfile: userProfile)
            
        case "lookup_food_calorie":
            handleFoodCalorieFunction(arguments: functionCall.arguments)
            
        default:
            print("Unknown function: \(functionCall.name)")
        }
    }
    
    // MARK: - Handle Workout Plan Function
    private func handleWorkoutPlanFunction(arguments: String, userProfile: UserProfile?) {
        guard let jsonData = arguments.data(using: .utf8) else { return }
        
        do {
            let decoder = JSONDecoder()
            let functionResponse = try decoder.decode(WorkoutPlanFunctionResponse.self, from: jsonData)
            
            // Validate exercises
            guard let exercises = functionResponse.exercises, !exercises.isEmpty else {
                print("Warning: No exercises in workout plan")
                sendErrorMessage("AI returned incomplete workout plan. Let me generate a default one for you.")
                // Fallback to local generation
                generateWorkoutPlan(userProfile: userProfile)
                return
            }
            
            // Convert to WorkoutPlanData
            let convertedExercises = exercises.map { exercise in
                WorkoutPlanData.Exercise(
                    name: exercise.name,
                    sets: exercise.sets,
                    reps: exercise.reps,
                    restSec: exercise.restSec,
                    targetRPE: exercise.targetRPE,
                    alternatives: exercise.alternatives
                )
            }
            
            // Use local calculation if AI didn't return calorie target
            let kcalTarget = functionResponse.dailyKcalTarget ?? calculateDailyCalories(userProfile: userProfile)
            
            let plan = WorkoutPlanData(
                date: functionResponse.date,
                goal: functionResponse.goal,
                dailyKcalTarget: kcalTarget,
                exercises: convertedExercises,
                notes: functionResponse.notes
            )
            
            let response = FirebaseChatMessage(
                content: "Here's your personalized workout plan 💪:\n\(formatDate(plan.date)) – \(plan.goal)",
                isFromUser: false,
                messageType: "workout_plan",
                workoutPlan: plan
            )
            
            messages.append(response)
            saveMessage(response)
            
        } catch {
            print("Failed to decode workout plan: \(error)")
            // Print raw JSON for debugging
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                print("Raw JSON: \(jsonString)")
            }
            
            // Fallback to local generation
            sendErrorMessage("Had trouble generating that plan. Let me create one for you using our standard template.")
            generateWorkoutPlan(userProfile: userProfile)
        }
    }
    
    // MARK: - Send Error Message
    private func sendErrorMessage(_ text: String) {
        let errorMessage = FirebaseChatMessage(
            content: text,
            isFromUser: false
        )
        messages.append(errorMessage)
        saveMessage(errorMessage)
    }
    
    // MARK: - Handle Food Calorie Function
    private func handleFoodCalorieFunction(arguments: String) {
        guard let jsonData = arguments.data(using: .utf8) else { return }
        
        do {
            let decoder = JSONDecoder()
            let foodInfo = try decoder.decode(FoodCalorieFunctionResponse.self, from: jsonData)
            
            let content = """
            📊 Nutrition Info for \(foodInfo.foodName) (\(foodInfo.servingSize)):
            
            • Calories: \(foodInfo.calories) kcal
            • Protein: \(String(format: "%.1f", foodInfo.protein))g
            • Carbs: \(String(format: "%.1f", foodInfo.carbs))g
            • Fat: \(String(format: "%.1f", foodInfo.fat))g
            
            Confidence: \(Int(foodInfo.confidence * 100))%
            """
            
            let response = FirebaseChatMessage(
                content: content,
                isFromUser: false
            )
            
            messages.append(response)
            saveMessage(response)
            
        } catch {
            print("Failed to decode food info: \(error)")
        }
    }
    
    // MARK: - Process User Intent
    // NOTE: This function is kept for potential future use, but currently
    // all messages go through processWithOpenAI which handles them via AI
    private func processUserIntent(_ text: String, userProfile: UserProfile?) {
        // This function is not currently used in the main flow
        // All messages are sent directly to AI via processWithOpenAI
        // Keeping it here for potential future quick responses or shortcuts
    }
    
    // MARK: - Generate Workout Plan
    private func generateWorkoutPlan(userProfile: UserProfile?) {
        let exercises = [
            WorkoutPlanData.Exercise(name: "Squats", sets: 3, reps: "10", restSec: 90, targetRPE: 7),
            WorkoutPlanData.Exercise(name: "Push-ups", sets: 3, reps: "8", restSec: 60, targetRPE: 8),
            WorkoutPlanData.Exercise(name: "Dumbbell Rows", sets: 3, reps: "12", restSec: 90, targetRPE: 7),
            WorkoutPlanData.Exercise(name: "15 min brisk walk or light jog", sets: 1, reps: "15 min", restSec: nil, targetRPE: 5)
        ]
        
        let plan = WorkoutPlanData(
            date: formatTomorrow(),
            goal: userProfile?.goal ?? "muscle_gain",
            dailyKcalTarget: calculateDailyCalories(userProfile: userProfile),
            exercises: exercises,
            notes: "Sounds good?"
        )
        
        let response = FirebaseChatMessage(
            content: "Here's your workout plan for tomorrow 💪:\n\(formatDate(plan.date)) – Full Body Strength",
            isFromUser: false,
            messageType: "workout_plan",
            workoutPlan: plan
        )
        
        messages.append(response)
        saveMessage(response)
    }
    
    // MARK: - Provide Food Info
    private func provideFoodInfo(query: String) {
        let response = FirebaseChatMessage(
            content: "I can help estimate calories! For example:\n• Chicken breast (150g): ~240 kcal, 45g protein\n• Brown rice (100g): ~110 kcal, 23g carbs\n• Avocado (100g): ~160 kcal, 15g fat\n\nWhat specific food would you like to know about?",
            isFromUser: false
        )
        messages.append(response)
        saveMessage(response)
    }
    
    // MARK: - Provide Progress Review
    private func provideProgressReview() {
        let response = FirebaseChatMessage(
            content: "Great question! To review your progress, I need to see your recent workout logs. Once you start logging workouts, I can analyze:\n\n• Volume trends\n• Strength gains\n• Consistency\n• Recovery patterns\n\nKeep logging and I'll help you optimize!",
            isFromUser: false
        )
        messages.append(response)
        saveMessage(response)
    }
    
    // MARK: - Refuse Inappropriate Content
    private func refuseInappropriate() {
        let response = FirebaseChatMessage(
            content: "I'm here to help with your fitness and health journey. Let's keep our conversation focused on that. How can I help you reach your fitness goals today?",
            isFromUser: false
        )
        messages.append(response)
        saveMessage(response)
    }
    
    // MARK: - Provide General Help
    private func provideGeneralHelp() {
        let response = FirebaseChatMessage(
            content: "I'm here to help with your fitness journey! I can assist with:\n\n💪 Workout Plans – Daily/weekly training schedules\n🍽️ Nutrition – Calorie and macro estimates\n📊 Progress – Review your training logs\n\nWhat would you like to focus on today?",
            isFromUser: false
        )
        messages.append(response)
        saveMessage(response)
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
    
    // MARK: - Helper Functions
    private func formatTomorrow() -> String {
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: tomorrow)
    }
    
    private func formatDate(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        if let date = formatter.date(from: dateString) {
            formatter.dateFormat = "EEEE"
            return formatter.string(from: date)
        }
        return "Tomorrow"
    }
    
    private func calculateDailyCalories(userProfile: UserProfile?) -> Int {
        guard let profile = userProfile,
              let weight = profile.weightValue,
              let height = profile.heightValue,
              let age = profile.age else {
            return 2500 // Default
        }
        
        // Simple BMR calculation (Mifflin-St Jeor for male, adjust as needed)
        let bmr = 10 * weight + 6.25 * height - 5 * Double(age) + 5
        
        // Activity multiplier (moderate activity)
        let tdee = bmr * 1.55
        
        // Adjust based on goal
        if profile.goal?.lowercased().contains("loss") == true {
            return Int(tdee * 0.85) // 15% deficit
        } else if profile.goal?.lowercased().contains("gain") == true {
            return Int(tdee * 1.15) // 15% surplus
        }
        
        return Int(tdee)
    }
}

