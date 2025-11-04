import Foundation
import SwiftData
import Combine

class ModoCoachService: ObservableObject {
    
    @Published var messages: [ChatMessage] = []
    @Published var isProcessing: Bool = false
    
    private var modelContext: ModelContext?
    private var hasLoadedHistory = false
    
    // ✅ Use AIPromptBuilder for unified prompt construction
    private let promptBuilder = AIPromptBuilder()
    
    init() {
        // Welcome message will be added after loading history
    }
    
    // MARK: - Load History from SwiftData
    func loadHistory(from context: ModelContext, userProfile: UserProfile? = nil) {
        guard !hasLoadedHistory else { return }
        
        self.modelContext = context
        
        let descriptor = FetchDescriptor<ChatMessage>(
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
        
        if let weightValue = profile.weightValue, let weightUnit = profile.weightUnit {
            if weightUnit.lowercased() == "kg" {
                let lbs = Int(weightValue * 2.20462)
                userInfoText += "Weight: \(lbs)lbs\n"
            } else {
                userInfoText += "Weight: \(Int(weightValue))\(weightUnit)\n"
            }
        }
        
        if let heightValue = profile.heightValue, let heightUnit = profile.heightUnit {
            if heightUnit.lowercased() == "cm" {
                let totalInches = heightValue / 2.54
                let feet = Int(totalInches / 12)
                let inches = Int(totalInches.truncatingRemainder(dividingBy: 12))
                userInfoText += "Height: \(feet)'\(inches)\"\n"
            } else {
                userInfoText += "Height: \(heightValue) \(heightUnit)\n"
            }
        }
        
        if let goal = profile.goal {
            userInfoText += "Goal: \(goal)\n"
        }
        
        if let lifestyle = profile.lifestyle {
            userInfoText += "Lifestyle: \(lifestyle)\n"
        }
        
        userInfoText += "\nI have basic gym equipment available (dumbbells, barbells, and machines). Please create personalized workout and nutrition plans based on this information. No need to ask me for these details again!"
        
        // Add user message
        let userMessage = ChatMessage(content: userInfoText, isFromUser: true)
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
            let descriptor = FetchDescriptor<ChatMessage>()
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
        let welcomeMessage = ChatMessage(
            content: "Hi! I'm your MODO wellness assistant. I can help you with diet planning, fitness routines, and healthy lifestyle tips.\nWhat would you like to know?",
            isFromUser: false
        )
        messages.append(welcomeMessage)
        saveMessage(welcomeMessage)
    }
    
    // MARK: - Save Message to SwiftData
    private func saveMessage(_ message: ChatMessage) {
        guard let context = modelContext else { return }
        context.insert(message)
        try? context.save()
    }
    
    // MARK: - Accept Workout Plan
    func acceptWorkoutPlan(for message: ChatMessage, onTaskCreated: ((WorkoutPlanData) -> Void)? = nil, onTextPlanAccepted: (() -> Void)? = nil) {
        // Check if it's a structured workout plan
        if let plan = message.workoutPlan {
            // Call the callback to create task
            onTaskCreated?(plan)
            
            let confirmMessage = ChatMessage(
                content: "Great! I've added your workout plan to your tasks. Don't forget to log your progress after completing it! 💪",
                isFromUser: false
            )
            messages.append(confirmMessage)
            saveMessage(confirmMessage)
        } else {
            // Handle text-based workout plan
            onTextPlanAccepted?()
            
            let confirmMessage = ChatMessage(
                content: "Great! I've added this workout to your tasks. Don't forget to log your progress! 💪",
                isFromUser: false
            )
            messages.append(confirmMessage)
            saveMessage(confirmMessage)
        }
    }
    
    // MARK: - Reject Workout Plan
    func rejectWorkoutPlan(for message: ChatMessage) {
        let rejectMessage = ChatMessage(
            content: "No problem! Let me know what you'd like to adjust. Would you prefer:\n\n• Different exercises\n• More/less intensity\n• Shorter/longer workout\n\nJust tell me what works better for you!",
            isFromUser: false
        )
        messages.append(rejectMessage)
        saveMessage(rejectMessage)
    }
    
    // MARK: - Send Message
    func sendMessage(_ text: String, userProfile: UserProfile?) {
        // Add user message
        let userMessage = ChatMessage(content: text, isFromUser: true)
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
        let message = ChatMessage(content: text, isFromUser: false)
        messages.append(message)
        saveMessage(message)
    }
    
    // MARK: - Send User Message
    func sendUserMessage(_ text: String) {
        let message = ChatMessage(content: text, isFromUser: true)
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
            
            let messages: [[String: Any]] = [
                [
                    "role": "system",
                    "content": systemPrompt
                ],
                [
                    "role": "user",
                    "content": [
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
                ]
            ]
            
            let requestBody: [String: Any] = [
                "model": "gpt-4o",
                "messages": messages,
                "max_tokens": 300
            ]
            
            guard let jsonData = try? JSONSerialization.data(withJSONObject: requestBody) else {
                throw OpenAIError.invalidResponse
            }
            
            var urlRequest = URLRequest(url: URL(string: OpenAIConfig.apiURL)!)
            urlRequest.httpMethod = "POST"
            urlRequest.setValue("Bearer \(OpenAIConfig.apiKey)", forHTTPHeaderField: "Authorization")
            urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            urlRequest.httpBody = jsonData
            
            let (data, response) = try await URLSession.shared.data(for: urlRequest)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                throw OpenAIError.invalidResponse
            }
            
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let choices = json["choices"] as? [[String: Any]],
               let firstChoice = choices.first,
               let message = firstChoice["message"] as? [String: Any],
               let content = message["content"] as? String {
                
                await MainActor.run {
                    let nutritionMessage = ChatMessage(
                        content: "🍽️ Food Analysis:\n\n\(content)",
                        isFromUser: false
                    )
                    self.messages.append(nutritionMessage)
                    self.saveMessage(nutritionMessage)
                    self.isProcessing = false
                }
            } else {
                throw OpenAIError.decodingError
            }
            
        } catch {
            await MainActor.run {
                print("Vision API Error: \(error)")
                let errorMessage = ChatMessage(
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
            var apiMessages: [ChatCompletionRequest.Message] = []
            
            // ✅ Use AIPromptBuilder for unified prompt construction
            let systemPrompt = promptBuilder.buildChatSystemPrompt(userProfile: userProfile)
            apiMessages.append(ChatCompletionRequest.Message(
                role: "system",
                content: systemPrompt,
                name: nil,
                functionCall: nil
            ))
            
            // Add recent conversation history (last 10 messages)
            let recentMessages = messages.suffix(11) // 10 + current message
            for msg in recentMessages.dropLast() {
                apiMessages.append(ChatCompletionRequest.Message(
                    role: msg.isFromUser ? "user" : "assistant",
                    content: msg.content,
                    name: nil,
                    functionCall: nil
                ))
            }
            
            // Add current user message
            apiMessages.append(ChatCompletionRequest.Message(
                role: "user",
                content: text,
                name: nil,
                functionCall: nil
            ))
            
            // Call OpenAI API - Simple text chat without Function Calling
            let response = try await OpenAIService.shared.sendChatRequest(
                messages: apiMessages,
                functions: nil,  // Not using Function Calling for now
                functionCall: nil
            )
            
            await MainActor.run {
                // Handle text response only
                if let choice = response.choices.first,
                   let content = choice.message.content {
                    let aiMessage = ChatMessage(
                        content: content,
                        isFromUser: false
                    )
                    self.messages.append(aiMessage)
                    self.saveMessage(aiMessage)
                } else {
                    print("No content in response")
                }
                self.isProcessing = false
            }
            
        } catch {
            await MainActor.run {
                print("OpenAI API Error: \(error)")
                // Show error message
                let errorMessage = ChatMessage(
                    content: "Sorry, I encountered an issue. Please try again later.\n\nError: \(error.localizedDescription)",
                    isFromUser: false
                )
                self.messages.append(errorMessage)
                self.saveMessage(errorMessage)
                self.isProcessing = false
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
            let aiMessage = ChatMessage(
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
            
            let response = ChatMessage(
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
        let errorMessage = ChatMessage(
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
            
            let response = ChatMessage(
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
    private func processUserIntent(_ text: String, userProfile: UserProfile?) {
        let lowercased = text.lowercased()
        
        // Check if it's a workout request
        if lowercased.contains("workout") || lowercased.contains("train") || lowercased.contains("exercise") || lowercased.contains("plan") {
            generateWorkoutPlan(userProfile: userProfile)
        }
        // Check if it's a food/calorie request
        else if lowercased.contains("calorie") || lowercased.contains("food") || lowercased.contains("nutrition") || lowercased.contains("eat") {
            provideFoodInfo(query: text)
        }
        // Check if it's progress review
        else if lowercased.contains("progress") || lowercased.contains("review") || lowercased.contains("how am i doing") {
            provideProgressReview()
        }
        // Off-topic detection
        else if isOffTopic(text) {
            refuseOffTopic()
        }
        // Default helpful response
        else {
            provideGeneralHelp()
        }
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
        
        let response = ChatMessage(
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
        let response = ChatMessage(
            content: "I can help estimate calories! For example:\n• Chicken breast (150g): ~240 kcal, 45g protein\n• Brown rice (100g): ~110 kcal, 23g carbs\n• Avocado (100g): ~160 kcal, 15g fat\n\nWhat specific food would you like to know about?",
            isFromUser: false
        )
        messages.append(response)
        saveMessage(response)
    }
    
    // MARK: - Provide Progress Review
    private func provideProgressReview() {
        let response = ChatMessage(
            content: "Great question! To review your progress, I need to see your recent workout logs. Once you start logging workouts, I can analyze:\n\n• Volume trends\n• Strength gains\n• Consistency\n• Recovery patterns\n\nKeep logging and I'll help you optimize!",
            isFromUser: false
        )
        messages.append(response)
        saveMessage(response)
    }
    
    // MARK: - Refuse Off-Topic
    private func refuseOffTopic() {
        let response = ChatMessage(
            content: "That question isn't related to training or nutrition. I can help you with your fitness plan or calorie estimation instead. What would you like to know about your training?",
            isFromUser: false
        )
        messages.append(response)
        saveMessage(response)
    }
    
    // MARK: - Provide General Help
    private func provideGeneralHelp() {
        let response = ChatMessage(
            content: "I'm here to help with your fitness journey! I can assist with:\n\n💪 Workout Plans – Daily/weekly training schedules\n🍽️ Nutrition – Calorie and macro estimates\n📊 Progress – Review your training logs\n\nWhat would you like to focus on today?",
            isFromUser: false
        )
        messages.append(response)
        saveMessage(response)
    }
    
    // MARK: - Off-Topic Detection
    private func isOffTopic(_ text: String) -> Bool {
        let offTopicKeywords = ["politics", "election", "president", "movie", "music", "celebrity", "weather", "news", "stock", "crypto"]
        let lowercased = text.lowercased()
        
        return offTopicKeywords.contains { lowercased.contains($0) }
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

