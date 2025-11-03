import Foundation

class OpenAIService {
    
    static let shared = OpenAIService()
    
    private init() {}
    
    // MARK: - Send Chat Request
    func sendChatRequest(
        messages: [ChatCompletionRequest.Message],
        functions: [ChatCompletionRequest.Function]? = nil,
        functionCall: String? = nil
    ) async throws -> ChatCompletionResponse {
        
        guard OpenAIConfig.apiKey != "YOUR_API_KEY_HERE" else {
            throw OpenAIError.missingAPIKey
        }
        
        let request = ChatCompletionRequest(
            model: OpenAIConfig.model,
            messages: messages,
            temperature: OpenAIConfig.temperature,
            maxTokens: OpenAIConfig.maxTokens,
            functions: functions,
            functionCall: functionCall
        )
        
        var urlRequest = URLRequest(url: URL(string: OpenAIConfig.apiURL)!)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(OpenAIConfig.apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let encoder = JSONEncoder()
        urlRequest.httpBody = try encoder.encode(request)
        
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenAIError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            if let errorMessage = String(data: data, encoding: .utf8) {
                print("OpenAI API Error: \(errorMessage)")
            }
            throw OpenAIError.httpError(statusCode: httpResponse.statusCode)
        }
        
        let decoder = JSONDecoder()
        return try decoder.decode(ChatCompletionResponse.self, from: data)
    }
    
    // MARK: - Build System Prompt
    func buildSystemPrompt(userProfile: UserProfile?) -> String {
        var prompt = """
        You are Modo Coach, an AI fitness assistant inside the Modo Fitness App.
        
        Your role:
        - Generate personalized workout plans based on user data
        - Provide nutrition guidance and calorie estimates
        - Analyze training progress and suggest improvements
        
        You ONLY handle fitness, nutrition, and training questions.
        If asked about unrelated topics, politely refuse and redirect to fitness.
        
        Response style:
        - Friendly and encouraging
        - Use emojis sparingly (💪, 🏋️, 🥗)
        - Keep responses concise but informative
        - NO MARKDOWN formatting (no **, __, ##, etc.)
        - Use plain text only, no bold or emphasis marks
        
        Workout plan format:
        - When creating a plan, include estimated duration (e.g., "45-minute workout")
        - Include brief description of focus (e.g., "Upper body strength training")
        - List exercises with sets x reps, rest periods, AND estimated calories burned
        - Format: "Exercise Name: X sets x Y reps, Z seconds rest, ~W calories"
        - Example: "Bench Press: 4 sets x 8-10 reps, 90 seconds rest, ~50 calories"
        - Calculate calories based on exercise intensity and duration
        - CRITICAL: After ANY workout plan, ALWAYS end with: "What do you think of this plan?"
        - This ending is REQUIRED for all workout plans, even if user rejected a previous one
        - DO NOT ask about warm-up routines
        - DO NOT ask if they want a nutrition plan
        
        Nutrition plan format:
        - Include meal times (e.g., "8:00 AM - Breakfast")
        - List specific foods with portions (e.g., "2 eggs, 2 slices whole wheat toast")
        - Include macros for each meal (calories, protein, carbs, fat)
        - Provide daily totals
        - CRITICAL: After ANY nutrition plan, ALWAYS end with: "What do you think of this plan?"
        - This ending is REQUIRED for all nutrition plans
        
        Multi-day plans:
        - If user asks for "this week", "next week", "7 days", etc., create a 7-day plan
        - If user asks for "these two days", "this weekend", etc., create a 2-day plan
        - If user asks for "this month", create a 30-day plan
        - Clearly label each day (e.g., "Day 1 - Monday", "Day 2 - Tuesday")
        - Vary exercises/meals across days for variety
        - Consider rest days for workout plans
        - CRITICAL: After ANY multi-day plan, ALWAYS end with: "What do you think of this plan?"
        - This ending is REQUIRED for all multi-day plans
        
        IMPORTANT: If user rejects a plan and asks for a new one, the new plan MUST also end with "What do you think of this plan?"
        
        Units and measurements:
        - ALWAYS use Imperial/US units by default:
          * Weight: lbs (pounds)
          * Height: feet and inches (e.g., 5'10")
          * Distance: miles, yards, feet
          * Temperature: Fahrenheit
          * Food portions: oz, cups, tablespoons
        - Convert metric to imperial automatically
        
        CRITICAL RULES for workout/diet plans:
        - When user asks to create a WORKOUT plan, FIRST ask: "What time would you like to do this workout?"
        - For NUTRITION plans, ask: "What time do you usually have breakfast/your first meal?"
        - For MULTI-DAY plans, ask about preferred workout times or meal times
        - Wait for their time response, THEN generate the plan
        - DO NOT ask for goal (you already have it in user profile)
        - DO NOT ask about experience level (infer from profile)
        - DO NOT ask about equipment (assume basic: dumbbells, barbells, or bodyweight)
        - DO NOT ask other clarifying questions unless absolutely necessary
        - Be proactive and generate the plan based on available information
        
        IMPORTANT for workout plans:
        - ALWAYS include 3-5 specific exercises with sets and reps
        - Use realistic rep ranges (e.g., "8-10", "12-15", "6-8")
        - Include rest periods (60-120 seconds for most exercises)
        - Mix compound and isolation exercises
        - Adapt difficulty based on user's goal and stats automatically
        """
        
        if let profile = userProfile {
            prompt += "\n\nUser Profile:"
            if let heightValue = profile.heightValue, let heightUnit = profile.heightUnit {
                // Convert to feet/inches if in cm
                if heightUnit.lowercased() == "cm" {
                    let totalInches = heightValue / 2.54
                    let feet = Int(totalInches / 12)
                    let inches = Int(totalInches.truncatingRemainder(dividingBy: 12))
                    prompt += "\n- Height: \(feet)'\(inches)\""
                } else {
                    prompt += "\n- Height: \(heightValue) \(heightUnit)"
                }
            }
            if let weightValue = profile.weightValue, let weightUnit = profile.weightUnit {
                // Convert to lbs if in kg
                if weightUnit.lowercased() == "kg" {
                    let lbs = Int(weightValue * 2.20462)
                    prompt += "\n- Weight: \(lbs)lbs"
                } else {
                    prompt += "\n- Weight: \(weightValue) \(weightUnit)"
                }
            }
            if let age = profile.age {
                prompt += "\n- Age: \(age) years"
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
                    genderText = gender
                }
                prompt += "\n- Gender: \(genderText)"
            }
            if let goal = profile.goal {
                prompt += "\n- Goal: \(goal)"
            }
            if let lifestyle = profile.lifestyle {
                prompt += "\n- Lifestyle: \(lifestyle)"
            }
        }
        
        return prompt
    }
    
    // MARK: - Build Function Definitions
    func buildFunctions() -> [ChatCompletionRequest.Function] {
        return [
            // Generate Workout Plan Function
            ChatCompletionRequest.Function(
                name: "generate_workout_plan",
                description: """
                Generate a personalized daily workout plan with specific exercises.
                MUST include at least 3-5 exercises with sets, reps, and rest periods.
                Example exercises: Squats, Push-ups, Deadlift, Bench Press, Pull-ups, Rows, Lunges, Plank.
                """,
                parameters: ChatCompletionRequest.Function.Parameters(
                    type: "object",
                    properties: [
                        "date": ChatCompletionRequest.Function.Parameters.Property(
                            type: "string",
                            description: "Date for the workout in YYYY-MM-DD format (e.g., 2025-10-31)",
                            items: nil
                        ),
                        "goal": ChatCompletionRequest.Function.Parameters.Property(
                            type: "string",
                            description: "Training goal: muscle_gain, fat_loss, strength, endurance, or general_fitness",
                            items: nil
                        ),
                        "exercises": ChatCompletionRequest.Function.Parameters.Property(
                            type: "array",
                            description: """
                            Array of exercise objects. Each exercise MUST have: name, sets, reps.
                            Example: [{"name": "Squats", "sets": 3, "reps": "10-12", "rest_sec": 90, "target_RPE": 7}]
                            Include 3-5 exercises minimum.
                            """,
                            items: ChatCompletionRequest.Function.Parameters.Property.Items(type: "object")
                        ),
                        "daily_kcal_target": ChatCompletionRequest.Function.Parameters.Property(
                            type: "number",
                            description: "Optional: Daily calorie target (e.g., 2500)",
                            items: nil
                        ),
                        "notes": ChatCompletionRequest.Function.Parameters.Property(
                            type: "string",
                            description: "Optional: Additional tips or notes about the workout",
                            items: nil
                        )
                    ],
                    required: ["date", "goal", "exercises"]
                )
            ),
            
            // Food Calorie Lookup Function
            ChatCompletionRequest.Function(
                name: "lookup_food_calorie",
                description: "Estimate calories and macronutrients for a specific food and serving size",
                parameters: ChatCompletionRequest.Function.Parameters(
                    type: "object",
                    properties: [
                        "food_name": ChatCompletionRequest.Function.Parameters.Property(
                            type: "string",
                            description: "Name of the food item",
                            items: nil
                        ),
                        "serving_size": ChatCompletionRequest.Function.Parameters.Property(
                            type: "string",
                            description: "Serving size (e.g., '150g', '1 cup', '1 medium')",
                            items: nil
                        ),
                        "calories": ChatCompletionRequest.Function.Parameters.Property(
                            type: "number",
                            description: "Estimated calories",
                            items: nil
                        ),
                        "protein": ChatCompletionRequest.Function.Parameters.Property(
                            type: "number",
                            description: "Protein in grams",
                            items: nil
                        ),
                        "carbs": ChatCompletionRequest.Function.Parameters.Property(
                            type: "number",
                            description: "Carbohydrates in grams",
                            items: nil
                        ),
                        "fat": ChatCompletionRequest.Function.Parameters.Property(
                            type: "number",
                            description: "Fat in grams",
                            items: nil
                        ),
                        "confidence": ChatCompletionRequest.Function.Parameters.Property(
                            type: "number",
                            description: "Confidence level (0.0 to 1.0)",
                            items: nil
                        )
                    ],
                    required: ["food_name", "calories", "protein", "carbs", "fat"]
                )
            )
        ]
    }
}

// MARK: - OpenAI Errors
enum OpenAIError: LocalizedError {
    case missingAPIKey
    case invalidResponse
    case httpError(statusCode: Int)
    case decodingError
    case networkError(Error)
    
    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "OpenAI API key is missing. Please add it to your configuration."
        case .invalidResponse:
            return "Received invalid response from OpenAI API."
        case .httpError(let code):
            return "HTTP error: \(code)"
        case .decodingError:
            return "Failed to decode API response."
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}

