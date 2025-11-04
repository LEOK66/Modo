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
    
    // MARK: - Deprecated - Use AIPromptBuilder instead
    // buildSystemPrompt() has been removed - use AIPromptBuilder.buildChatSystemPrompt() instead
    
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

