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
        // Welcome message will be added after loading history
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
            hasLoadedHistory = true
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
        guard let context = modelContext,
              let currentUserId = Auth.auth().currentUser?.uid else {
            print("⚠️ No current user or context, cannot clear chat history")
            return
        }
        
        // ✅ Only delete messages belonging to current user
        do {
            let predicate = #Predicate<FirebaseChatMessage> { message in
                message.userId == currentUserId
            }
            let descriptor = FetchDescriptor<FirebaseChatMessage>(predicate: predicate)
            let userMessages = try context.fetch(descriptor)
            
            for message in userMessages {
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
            let messages: [ChatMessage] = [
                ChatMessage(role: "system", content: systemPrompt),
                ChatMessage(role: "user", multimodalContent: userContent)
            ]
            
            // Call Firebase AI Service with reduced maxTokens for food analysis
            let response = try await firebaseAIService.sendChatRequest(
                messages: messages,
                functions: nil,
                functionCall: nil,
                maxTokens: OpenAIConfig.maxTokensForVision
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
                
                // Convert to ModoAIError for friendly message
                let modoError = ModoAIError.from(error)
                
                var errorText = "抱歉，无法分析这张图片。"
                if let description = modoError.errorDescription {
                    errorText = description
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
                self.isProcessing = false
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
            // ✅ Detect if user is asking for a plan to use "required" mode
            let userMessage = text.lowercased()
            let isPlanRequest = userMessage.contains("plan") ||
                               userMessage.contains("workout") ||
                               userMessage.contains("exercise") ||
                               userMessage.contains("meal") ||
                               userMessage.contains("breakfast") ||
                               userMessage.contains("lunch") ||
                               userMessage.contains("dinner") ||
                               userMessage.contains("diet") ||
                               userMessage.contains("nutrition")
            
            let functionCallMode: String
            if isPlanRequest && !userMessage.contains("?") {
                // User is requesting a plan (not asking about it) → encourage function call
                functionCallMode = "auto" // Still "auto" but prompt will enforce it
            } else {
                // General question → let AI decide freely
                functionCallMode = "auto"
            }
            
            let response = try await firebaseAIService.sendChatRequest(
                messages: apiMessages,
                functions: firebaseAIService.buildFunctions(), // Add function definitions (including strict: true)
                functionCall: functionCallMode,
                parallelToolCalls: false // Must be set to false (strict mode requires)
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
                var errorText = modoError.errorDescription ?? "抱歉，出现了一些问题"
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
        
        switch functionCall.name {
        case "generate_workout_plan":
            handleWorkoutPlanFunction(data: data, userProfile: userProfile)
            
        case "generate_nutrition_plan":
            handleNutritionPlanFunction(data: data, userProfile: userProfile)
            
        case "generate_multi_day_plan":
            handleMultiDayPlanFunction(data: data, userProfile: userProfile)
            
        default:
            print("⚠️ Unknown function: \(functionCall.name)")
        }
    }
    
    // MARK: - Handle Workout Plan Function
    private func handleWorkoutPlanFunction(data: Data, userProfile: UserProfile?) {
        do {
            let decoder = JSONDecoder()
            let functionResponse = try decoder.decode(WorkoutPlanFunctionResponse.self, from: data)
            
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
            if let jsonString = String(data: data, encoding: .utf8) {
                print("Raw JSON: \(jsonString)")
            }
            
            // Fallback to local generation
            sendErrorMessage("Had trouble generating that plan. Let me create one for you using our standard template.")
            generateWorkoutPlan(userProfile: userProfile)
        }
    }
    
    // MARK: - Handle Nutrition Plan Function
    private func handleNutritionPlanFunction(data: Data, userProfile: UserProfile?) {
        do {
            let decoder = JSONDecoder()
            let functionResponse = try decoder.decode(NutritionPlanFunctionResponse.self, from: data)
            
            print("✅ Successfully decoded nutrition plan with \(functionResponse.meals.count) meals")
            print("   Date: \(functionResponse.date)")
            print("   Goal: \(functionResponse.goal)")
            
            // Convert to NutritionPlanData
            let convertedMeals = functionResponse.meals.map { meal in
                let totalCalories = meal.foods.reduce(0) { $0 + $1.calories }
                let totalProtein = meal.foods.reduce(0.0) { $0 + ($1.protein ?? 0) }
                let totalCarbs = meal.foods.reduce(0.0) { $0 + ($1.carbs ?? 0) }
                let totalFat = meal.foods.reduce(0.0) { $0 + ($1.fat ?? 0) }
                
                print("   Meal: \(meal.mealType) - \(totalCalories)kcal")
                
                return NutritionPlanData.Meal(
                    name: meal.mealType.capitalized,
                    time: meal.time ?? getDefaultMealTime(for: meal.mealType),
                    foods: meal.foods.map { "\($0.name) (\($0.portion))" },
                    calories: totalCalories,
                    protein: totalProtein,
                    carbs: totalCarbs,
                    fat: totalFat
                )
            }
            
            // Calculate daily totals
            let dailyCalories = functionResponse.dailyTotals?.calories ?? convertedMeals.reduce(0) { $0 + $1.calories }
            
            let plan = NutritionPlanData(
                date: functionResponse.date,
                goal: functionResponse.goal,
                dailyKcalTarget: dailyCalories,
                meals: convertedMeals,
                notes: nil
            )
            
            print("   Created NutritionPlanData with \(plan.meals.count) meals")
            
            let response = FirebaseChatMessage(
                content: "Here's your personalized nutrition plan 🍽️:\n\(formatDate(plan.date)) – \(plan.goal)",
                isFromUser: false,
                messageType: "nutrition_plan",
                nutritionPlan: plan
            )
            
            print("   Created message with type: \(response.messageType)")
            print("   Message has nutritionPlan: \(response.nutritionPlan != nil)")
            
            messages.append(response)
            saveMessage(response)
            
            print("   ✅ Nutrition plan message saved successfully")
            
        } catch {
            print("❌ Failed to decode nutrition plan: \(error)")
            if let jsonString = String(data: data, encoding: .utf8) {
                print("Raw JSON: \(jsonString)")
            }
            
            sendErrorMessage("Had trouble generating that nutrition plan. Please try again.")
        }
    }
    
    // MARK: - Handle Multi-Day Plan Function
    private func handleMultiDayPlanFunction(data: Data, userProfile: UserProfile?) {
        do {
            let decoder = JSONDecoder()
            let functionResponse = try decoder.decode(MultiDayPlanFunctionResponse.self, from: data)
            
            print("✅ Successfully decoded multi-day plan with \(functionResponse.days.count) days")
            print("   Type: \(functionResponse.planType)")
            print("   Date range: \(functionResponse.startDate) to \(functionResponse.endDate)")
            
            // Convert to MultiDayPlanData
            let convertedDays = functionResponse.days.map { day in
                var workoutPlan: WorkoutPlanData? = nil
                var nutritionPlan: NutritionPlanData? = nil
                
                // Convert workout if present
                if let workout = day.workout {
                    let convertedExercises = workout.exercises.map { exercise in
                        WorkoutPlanData.Exercise(
                            name: exercise.name,
                            sets: exercise.sets,
                            reps: exercise.reps,
                            restSec: exercise.restSec,
                            targetRPE: exercise.targetRPE,
                            alternatives: exercise.alternatives
                        )
                    }
                    
                    workoutPlan = WorkoutPlanData(
                        date: day.date,
                        goal: workout.goal,
                        dailyKcalTarget: workout.dailyKcalTarget,
                        exercises: convertedExercises,
                        notes: workout.notes
                    )
                }
                
                // Convert nutrition if present
                if let nutrition = day.nutrition {
                    let convertedMeals = nutrition.meals.map { meal in
                        let foodNames = meal.foods.map { "\($0.name) (\($0.portion))" }
                        return NutritionPlanData.Meal(
                            name: meal.mealType.capitalized,
                            time: meal.time,
                            foods: foodNames,
                            calories: meal.calories,
                            protein: meal.protein,
                            carbs: meal.carbs,
                            fat: meal.fat
                        )
                    }
                    
                    let dailyCalories = nutrition.dailyTotals?.calories ?? convertedMeals.reduce(0) { $0 + $1.calories }
                    
                    nutritionPlan = NutritionPlanData(
                        date: day.date,
                        goal: nutrition.goal,
                        dailyKcalTarget: dailyCalories,
                        meals: convertedMeals,
                        notes: nil
                    )
                }
                
                return MultiDayPlanData.DayPlan(
                    date: day.date,
                    dayName: day.dayName,
                    workout: workoutPlan,
                    nutrition: nutritionPlan
                )
            }
            
            let plan = MultiDayPlanData(
                startDate: functionResponse.startDate,
                endDate: functionResponse.endDate,
                planType: functionResponse.planType,
                days: convertedDays,
                notes: functionResponse.notes
            )
            
            print("   Created MultiDayPlanData with \(plan.days.count) days")
            
            let planTypeText = functionResponse.planType == "both" ? "workout & nutrition" : functionResponse.planType
            let response = FirebaseChatMessage(
                content: "Here's your \(plan.days.count)-day \(planTypeText) plan 📅",
                isFromUser: false,
                messageType: "multi_day_plan",
                multiDayPlan: plan
            )
            
            print("   Created message with type: \(response.messageType)")
            print("   Message has multiDayPlan: \(response.multiDayPlan != nil)")
            
            messages.append(response)
            saveMessage(response)
            
            print("   ✅ Multi-day plan message saved successfully")
            
        } catch {
            print("❌ Failed to decode multi-day plan: \(error)")
            if let jsonString = String(data: data, encoding: .utf8) {
                print("Raw JSON: \(jsonString)")
            }
            
            sendErrorMessage("Had trouble generating that multi-day plan. Please try again.")
        }
    }
    
    // MARK: - Create Nutrition Tasks from Function
    private func createNutritionTasksFromFunction(_ nutritionPlan: NutritionPlanFunctionResponse) {
        for meal in nutritionPlan.meals {
            let mealTime = meal.time ?? getDefaultMealTime(for: meal.mealType)
            
            // Convert foods to dictionary
            let foodsData = meal.foods.map { food -> [String: Any] in
                var foodDict: [String: Any] = [
                    "name": food.name,
                    "portion": food.portion,
                    "calories": food.calories
                ]
                if let protein = food.protein {
                    foodDict["protein"] = protein
                }
                if let carbs = food.carbs {
                    foodDict["carbs"] = carbs
                }
                if let fat = food.fat {
                    foodDict["fat"] = fat
                }
                return foodDict
            }
            
            // Calculate total calories for the meal
            let totalCalories = meal.foods.reduce(0) { $0 + $1.calories }
            
            let userInfo: [String: Any] = [
                "date": nutritionPlan.date,
                "time": mealTime,
                "theme": "Nutrition",
                "mealType": meal.mealType.capitalized,
                "foods": foodsData,
                "totalCalories": totalCalories,
                "isNutrition": true,
                "isAIGenerated": true
            ]
            
            NotificationCenter.default.post(
                name: NSNotification.Name("CreateNutritionTask"),
                object: nil,
                userInfo: userInfo
            )
        }
    }
    
    // MARK: - Get Default Meal Time
    private func getDefaultMealTime(for mealType: String) -> String {
        switch mealType.lowercased() {
        case "breakfast":
            return "08:00 AM"
        case "lunch":
            return "12:00 PM"
        case "dinner":
            return "06:00 PM"
        case "snack":
            return "03:00 PM"
        default:
            return "12:00 PM"
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
    
    // MARK: - Generate Workout Plan
    private func generateWorkoutPlan(userProfile: UserProfile?) {
        let exercises = [
            WorkoutPlanData.Exercise(
                name: "Squats", 
                sets: DefaultWorkoutParams.sets, 
                reps: "10", 
                restSec: DefaultWorkoutParams.restSecHigh, 
                targetRPE: DefaultWorkoutParams.rpeModerate
            ),
            WorkoutPlanData.Exercise(
                name: "Push-ups", 
                sets: DefaultWorkoutParams.sets, 
                reps: "8", 
                restSec: DefaultWorkoutParams.restSecModerate, 
                targetRPE: DefaultWorkoutParams.rpeHigh
            ),
            WorkoutPlanData.Exercise(
                name: "Dumbbell Rows", 
                sets: DefaultWorkoutParams.sets, 
                reps: "12", 
                restSec: DefaultWorkoutParams.restSecHigh, 
                targetRPE: DefaultWorkoutParams.rpeModerate
            ),
            WorkoutPlanData.Exercise(
                name: "15 min brisk walk or light jog", 
                sets: 1, 
                reps: "15 min", 
                restSec: nil, 
                targetRPE: DefaultWorkoutParams.rpeLow
            )
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

