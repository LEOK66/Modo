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
    
    // MARK: - Build Functions with Strict Mode
    /// Build function definitions with strict: true for guaranteed JSON format
    func buildFunctions() -> [FunctionDefinition] {
        return [
            // Generate Workout Plan Function
            FunctionDefinition(
                name: "generate_workout_plan",
                description: """
                Generate a personalized daily workout plan with specific exercises.
                MUST include at least 3-5 exercises with sets, reps, and rest periods.
                Call this function when user explicitly asks for a workout plan.
                """,
                parameters: [
                    "type": "object",
                    "properties": [
                        "date": [
                            "type": "string",
                            "description": "Target date in YYYY-MM-DD format"
                        ],
                        "goal": [
                            "type": "string",
                            "description": "Workout goal (e.g., muscle_gain, weight_loss, strength, endurance)"
                        ],
                        "exercises": [
                            "type": "array",
                            "description": "List of exercises in the workout",
                            "items": [
                                "type": "object",
                                "properties": [
                                    "name": [
                                        "type": "string",
                                        "description": "Exercise name"
                                    ],
                                    "sets": [
                                        "type": "integer",
                                        "description": "Number of sets"
                                    ],
                                    "reps": [
                                        "type": "string",
                                        "description": "Number of reps (e.g., '10', '8-12', '15')"
                                    ],
                                    "rest_sec": [
                                        "type": "integer",
                                        "description": "Rest period in seconds"
                                    ]
                                ],
                                "required": ["name", "sets", "reps", "rest_sec"],
                                "additionalProperties": false
                            ]
                        ],
                        "daily_kcal_target": [
                            "type": "integer",
                            "description": "Daily calorie target"
                        ],
                        "notes": [
                            "type": ["string", "null"],
                            "description": "Additional notes or tips"
                        ]
                    ],
                    "required": ["date", "goal", "exercises", "daily_kcal_target", "notes"],
                    "additionalProperties": false
                ],
                strict: true
            ),
            
            // Generate Nutrition Plan Function
            FunctionDefinition(
                name: "generate_nutrition_plan",
                description: """
                Generate a daily meal plan with specific foods and calorie information.
                IMPORTANT: Only generate main meals (breakfast, lunch, dinner). Do NOT include snacks.
                Call this function when user explicitly asks for a meal/nutrition plan.
                """,
                parameters: [
                    "type": "object",
                    "properties": [
                        "date": [
                            "type": "string",
                            "description": "Target date in YYYY-MM-DD format"
                        ],
                        "goal": [
                            "type": "string",
                            "description": "Nutrition goal (e.g., weight_loss, muscle_gain, maintenance)"
                        ],
                        "meals": [
                            "type": "array",
                            "description": "List of main meals for the day (breakfast, lunch, dinner only - no snacks)",
                            "items": [
                                "type": "object",
                                "properties": [
                                    "meal_type": [
                                        "type": "string",
                                        "description": "Type of meal (ONLY: breakfast, lunch, or dinner - NO snacks)",
                                        "enum": ["breakfast", "lunch", "dinner"]
                                    ],
                                    "time": [
                                        "type": "string",
                                        "description": "Meal time (e.g., '08:00 AM')"
                                    ],
                                    "foods": [
                                        "type": "array",
                                        "description": "List of foods in this meal",
                                        "items": [
                                            "type": "object",
                                            "properties": [
                                                "name": [
                                                    "type": "string",
                                                    "description": "Food name"
                                                ],
                                                "portion": [
                                                    "type": "string",
                                                    "description": "Portion size (e.g., '200g', '1 cup')"
                                                ],
                                                "calories": [
                                                    "type": "integer",
                                                    "description": "Calories in this portion"
                                                ],
                                                "protein": [
                                                    "type": "number",
                                                    "description": "Protein in grams"
                                                ],
                                                "carbs": [
                                                    "type": "number",
                                                    "description": "Carbs in grams"
                                                ],
                                                "fat": [
                                                    "type": "number",
                                                    "description": "Fat in grams"
                                                ]
                                            ],
                                            "required": ["name", "portion", "calories", "protein", "carbs", "fat"],
                                            "additionalProperties": false
                                        ]
                                    ]
                                ],
                                "required": ["meal_type", "time", "foods"],
                                "additionalProperties": false
                            ]
                        ],
                        "daily_totals": [
                            "type": "object",
                            "description": "Daily nutrition totals",
                            "properties": [
                                "calories": [
                                    "type": "integer",
                                    "description": "Total daily calories"
                                ],
                                "protein": [
                                    "type": "number",
                                    "description": "Total daily protein in grams"
                                ],
                                "carbs": [
                                    "type": "number",
                                    "description": "Total daily carbs in grams"
                                ],
                                "fat": [
                                    "type": "number",
                                    "description": "Total daily fat in grams"
                                ]
                            ],
                            "required": ["calories", "protein", "carbs", "fat"],
                            "additionalProperties": false
                        ]
                    ],
                    "required": ["date", "goal", "meals", "daily_totals"],
                    "additionalProperties": false
                ],
                strict: true
            ),
            
            // Generate Multi-Day Plan Function
            FunctionDefinition(
                name: "generate_multi_day_plan",
                description: """
                Generate a multi-day plan (2-7 days) for workout and/or nutrition.
                Use this when user asks for: "this week", "next 3 days", "7-day plan", etc.
                IMPORTANT: Maximum 7 days per plan. Each day should have varied content.
                """,
                parameters: [
                    "type": "object",
                    "properties": [
                        "start_date": [
                            "type": "string",
                            "description": "Start date in YYYY-MM-DD format"
                        ],
                        "end_date": [
                            "type": "string",
                            "description": "End date in YYYY-MM-DD format"
                        ],
                        "plan_type": [
                            "type": "string",
                            "description": "Type of plan",
                            "enum": ["workout", "nutrition", "both"]
                        ],
                        "days": [
                            "type": "array",
                            "description": "Array of daily plans (maximum 7 days)",
                            "items": [
                                "type": "object",
                                "properties": [
                                    "date": [
                                        "type": "string",
                                        "description": "Date in YYYY-MM-DD format"
                                    ],
                                    "day_name": [
                                        "type": "string",
                                        "description": "Day name (e.g., 'Monday', 'Day 1')"
                                    ],
                                    "workout": [
                                        "type": ["object", "null"],
                                        "description": "Workout plan for this day (null if rest day or nutrition-only)",
                                        "properties": [
                                            "goal": [
                                                "type": "string",
                                                "description": "Workout goal for this day"
                                            ],
                                            "exercises": [
                                                "type": "array",
                                                "description": "List of exercises",
                                                "items": [
                                                    "type": "object",
                                                    "properties": [
                                                        "name": ["type": "string"],
                                                        "sets": ["type": "integer"],
                                                        "reps": ["type": "string"],
                                                        "rest_sec": ["type": "integer"]
                                                    ],
                                                    "required": ["name", "sets", "reps", "rest_sec"],
                                                    "additionalProperties": false
                                                ]
                                            ],
                                            "daily_kcal_target": ["type": "integer"],
                                            "notes": ["type": ["string", "null"]]
                                        ],
                                        "required": ["goal", "exercises", "daily_kcal_target", "notes"],
                                        "additionalProperties": false
                                    ],
                                    "nutrition": [
                                        "type": ["object", "null"],
                                        "description": "Nutrition plan for this day (null if workout-only)",
                                        "properties": [
                                            "goal": ["type": "string"],
                                            "meals": [
                                                "type": "array",
                                                "items": [
                                                    "type": "object",
                                                    "properties": [
                                                        "meal_type": [
                                                            "type": "string",
                                                            "enum": ["breakfast", "lunch", "dinner"]
                                                        ],
                                                        "time": ["type": "string"],
                                                        "foods": [
                                                            "type": "array",
                                                            "items": [
                                                                "type": "object",
                                                                "properties": [
                                                                    "name": ["type": "string"],
                                                                    "portion": ["type": "string"],
                                                                    "calories": ["type": "integer"],
                                                                    "protein": ["type": "number"],
                                                                    "carbs": ["type": "number"],
                                                                    "fat": ["type": "number"]
                                                                ],
                                                                "required": ["name", "portion", "calories", "protein", "carbs", "fat"],
                                                                "additionalProperties": false
                                                            ]
                                                        ],
                                                        "calories": ["type": "integer"],
                                                        "protein": ["type": "number"],
                                                        "carbs": ["type": "number"],
                                                        "fat": ["type": "number"]
                                                    ],
                                                    "required": ["meal_type", "time", "foods", "calories", "protein", "carbs", "fat"],
                                                    "additionalProperties": false
                                                ]
                                            ],
                                            "daily_totals": [
                                                "type": "object",
                                                "properties": [
                                                    "calories": ["type": "integer"],
                                                    "protein": ["type": "number"],
                                                    "carbs": ["type": "number"],
                                                    "fat": ["type": "number"]
                                                ],
                                                "required": ["calories", "protein", "carbs", "fat"],
                                                "additionalProperties": false
                                            ]
                                        ],
                                        "required": ["goal", "meals", "daily_totals"],
                                        "additionalProperties": false
                                    ]
                                ],
                                "required": ["date", "day_name", "workout", "nutrition"],
                                "additionalProperties": false
                            ]
                        ],
                        "notes": [
                            "type": ["string", "null"],
                            "description": "Overall notes for the multi-day plan"
                        ]
                    ],
                    "required": ["start_date", "end_date", "plan_type", "days", "notes"],
                    "additionalProperties": false
                ],
                strict: true
            ),
            
            // Query Tasks Function
            FunctionDefinition(
                name: "query_tasks",
                description: """
                Query existing tasks from the user's schedule.
                Use this when user asks: "What tasks do I have?", "Show me today's workouts", "What's on my schedule?", etc.
                """,
                parameters: [
                    "type": "object",
                    "properties": [
                        "date": [
                            "type": "string",
                            "description": "Target date in YYYY-MM-DD format (default: today)"
                        ],
                        "date_range": [
                            "type": "integer",
                            "description": "Number of days to include (1 = single day, 7 = week)",
                            "minimum": 1,
                            "maximum": 30
                        ],
                        "category": [
                            "type": ["string", "null"],
                            "description": "Filter by category: fitness, diet, or null for all"
                        ],
                        "is_done": [
                            "type": ["boolean", "null"],
                            "description": "Filter by completion status: true (done), false (pending), null (all)"
                        ]
                    ],
                    "required": ["date", "date_range", "category", "is_done"],
                    "additionalProperties": false
                ],
                strict: true
            ),
            
            // Create Tasks Function
            FunctionDefinition(
                name: "create_tasks",
                description: """
                Create one or multiple new tasks in the user's schedule.
                Use this when user asks to: "Add a workout", "Create a meal plan", "Schedule this for tomorrow", etc.
                """,
                parameters: [
                    "type": "object",
                    "properties": [
                        "tasks": [
                            "type": "array",
                            "description": "Array of tasks to create",
                            "items": [
                                "type": "object",
                                "properties": [
                                    "type": [
                                        "type": "string",
                                        "description": "Task type",
                                        "enum": ["workout", "nutrition", "custom"]
                                    ],
                                    "title": [
                                        "type": "string",
                                        "description": "Task title"
                                    ],
                                    "subtitle": [
                                        "type": ["string", "null"],
                                        "description": "Task subtitle or description"
                                    ],
                                    "date": [
                                        "type": "string",
                                        "description": "Task date in YYYY-MM-DD format"
                                    ],
                                    "time": [
                                        "type": "string",
                                        "description": "Task time (e.g., '9:00 AM', '14:30')"
                                    ],
                                    "category": [
                                        "type": "string",
                                        "description": "Task category",
                                        "enum": ["fitness", "diet", "others"]
                                    ],
                                    "exercises": [
                                        "type": ["array", "null"],
                                        "description": "Exercise details (for fitness tasks)",
                                        "items": [
                                            "type": "object",
                                            "properties": [
                                                "name": ["type": "string"],
                                                "sets": ["type": "integer"],
                                                "reps": ["type": "string"],
                                                "rest_sec": ["type": "integer"],
                                                "duration_min": ["type": "integer"],
                                                "calories": ["type": "integer"]
                                            ],
                                            "required": ["name", "sets", "reps", "rest_sec", "duration_min", "calories"],
                                            "additionalProperties": false
                                        ]
                                    ],
                                    "meals": [
                                        "type": ["array", "null"],
                                        "description": "Meal details (for diet tasks)",
                                        "items": [
                                            "type": "object",
                                            "properties": [
                                                "name": ["type": "string"],
                                                "time": ["type": "string"],
                                                "foods": [
                                                    "type": "array",
                                                    "items": [
                                                        "type": "object",
                                                        "properties": [
                                                            "name": ["type": "string"],
                                                            "portion": ["type": "string"],
                                                            "calories": ["type": "integer"],
                                                            "macros": [
                                                                "type": ["object", "null"],
                                                                "properties": [
                                                                    "protein": ["type": "number"],
                                                                    "carbs": ["type": "number"],
                                                                    "fat": ["type": "number"]
                                                                ],
                                                                "required": ["protein", "carbs", "fat"],
                                                                "additionalProperties": false
                                                            ]
                                                        ],
                                                        "required": ["name", "portion", "calories", "macros"],
                                                        "additionalProperties": false
                                                    ]
                                                ],
                                                "total_calories": ["type": "integer"]
                                            ],
                                            "required": ["name", "time", "foods", "total_calories"],
                                            "additionalProperties": false
                                        ]
                                    ]
                                ],
                                "required": ["type", "title", "subtitle", "date", "time", "category", "exercises", "meals"],
                                "additionalProperties": false
                            ]
                        ]
                    ],
                    "required": ["tasks"],
                    "additionalProperties": false
                ],
                strict: true
            ),
            
            // Update Task Function
            FunctionDefinition(
                name: "update_task",
                description: """
                **THIS FUNCTION MUST BE CALLED IMMEDIATELY AFTER query_tasks WHEN USER ASKS TO MODIFY A TASK**
                
                This function ACTUALLY MODIFIES the task in the database. You CANNOT update tasks without calling this.
                
                WHEN TO USE (ALWAYS REQUIRED):
                - User says: "Change X to Y", "Update X", "Modify X", "Edit X", "Make X into Y"
                - Examples: "Change breakfast time to 9am", "Update workout to 5pm", "Edit meal portions"
                
                CRITICAL - YOU MUST FOLLOW THIS EXACT SEQUENCE:
                1. IF user asks to update → query_tasks (to get task_id)
                2. IMMEDIATELY call update_task in the SAME RESPONSE (not a separate message!)
                3. THEN say: "I've updated [task]: [changes]"
                
                YOU ARE FORBIDDEN FROM:
                ❌ Saying "I've updated..." without calling this function (that's lying!)
                ❌ Saying "One moment" or "Let me do that" (just call the function!)
                ❌ Only calling query_tasks and stopping (you MUST also call update_task!)
                ❌ Describing what you'll update without actually updating (ACTION REQUIRED!)
                
                CORRECT BEHAVIOR:
                User: "Change workout to 5pm"
                → Call query_tasks (find task)
                → Call update_task (with task_id and time="5:00 PM") **IN SAME RESPONSE**
                → Respond: "I've updated Morning Run to 5:00 PM"
                
                WRONG BEHAVIOR:
                User: "Change workout to 5pm"
                → Call query_tasks
                → Stop and say "I'll update that for you" ❌ NO! CALL update_task NOW!
                """,
                parameters: [
                    "type": "object",
                    "properties": [
                        "task_id": [
                            "type": "string",
                            "description": "UUID of the task to update (from query_tasks result)"
                        ],
                        "updates": [
                            "type": "object",
                            "description": "All fields to update. Copy the query_tasks result and modify only what user wants to change.",
                            "properties": [
                                "title": [
                                    "type": ["string", "null"],
                                    "description": "Task title. Use value from query_tasks if not changing."
                                ],
                                "time": [
                                    "type": ["string", "null"],
                                    "description": "Task time. Use value from query_tasks if not changing."
                                ],
                                "is_done": [
                                    "type": ["boolean", "null"],
                                    "description": "Completion status. Use value from query_tasks if not changing."
                                ],
                                "exercises": [
                                    "type": ["array", "null"],
                                    "description": "Complete exercises list. Copy from query_tasks and modify only the specific exercise/field user wants to change. Set to null if task has no exercises.",
                                    "items": [
                                        "type": "object",
                                        "properties": [
                                            "name": ["type": "string", "description": "Exercise name"],
                                            "sets": ["type": "integer", "description": "Number of sets"],
                                            "reps": ["type": "string", "description": "Reps per set (e.g., '10', '8-12')"],
                                            "rest_sec": ["type": "integer", "description": "Rest between sets in seconds"],
                                            "duration_min": ["type": "integer", "description": "Duration in minutes"],
                                            "calories": ["type": "integer", "description": "Estimated calories burned"]
                                        ],
                                        "required": ["name", "sets", "reps", "rest_sec", "duration_min", "calories"],
                                        "additionalProperties": false
                                    ]
                                ],
                                "foods": [
                                    "type": ["array", "null"],
                                    "description": "Complete foods list. Copy from query_tasks and modify only the specific food/field user wants to change. Set to null if task has no foods.",
                                    "items": [
                                        "type": "object",
                                        "properties": [
                                            "name": ["type": "string", "description": "Food name"],
                                            "portion": ["type": "string", "description": "Portion size (e.g., '100g', '1 cup')"],
                                            "calories": ["type": "integer", "description": "Calories"]
                                        ],
                                        "required": ["name", "portion", "calories"],
                                        "additionalProperties": false
                                    ]
                                ]
                            ],
                            "required": ["title", "time", "is_done", "exercises", "foods"],
                            "additionalProperties": false
                        ]
                    ],
                    "required": ["task_id", "updates"],
                    "additionalProperties": false
                ],
                strict: true
            ),
            
            // Delete Task Function
            FunctionDefinition(
                name: "delete_task",
                description: """
                **THIS FUNCTION MUST BE CALLED IMMEDIATELY AFTER query_tasks WHEN USER ASKS TO DELETE A TASK**
                
                This function ACTUALLY REMOVES the task from the database. You CANNOT delete tasks without calling this.
                
                WHEN TO USE (ALWAYS REQUIRED):
                - User says: "Delete X", "Remove X", "Cancel X", "Get rid of X"
                - Examples: "Delete this workout", "Remove breakfast", "Cancel today's task"
                
                CRITICAL - YOU MUST FOLLOW THIS EXACT SEQUENCE:
                1. IF user asks to delete → query_tasks (to get task_id)
                2. IMMEDIATELY call delete_task in the SAME RESPONSE (not a separate message!)
                3. THEN say: "I've deleted [task] from [date]"
                
                YOU ARE FORBIDDEN FROM:
                ❌ Saying "I've deleted..." without calling this function (that's lying!)
                ❌ Saying "One moment" or "Let me do that" (just call the function!)
                ❌ Only calling query_tasks and stopping (you MUST also call delete_task!)
                ❌ Asking for confirmation (just delete it if user asks!)
                
                CORRECT BEHAVIOR:
                User: "Delete today's workout"
                → Call query_tasks (find task)
                → Call delete_task (with task_id) **IN SAME RESPONSE**
                → Respond: "I've deleted Morning Run from November 20, 2025"
                
                WRONG BEHAVIOR:
                User: "Delete today's workout"
                → Call query_tasks
                → Stop and say "I'll delete that for you" ❌ NO! CALL delete_task NOW!
                """,
                parameters: [
                    "type": "object",
                    "properties": [
                        "task_id": [
                            "type": "string",
                            "description": "UUID of the task to delete (from query_tasks result)"
                        ],
                        "reason": [
                            "type": ["string", "null"],
                            "description": "Optional reason for deletion"
                        ]
                    ],
                    "required": ["task_id", "reason"],
                    "additionalProperties": false
                ],
                strict: true
            )
        ]
    }
    
    // MARK: - Send Chat Request
    /// Sends a chat completion request to Firebase Cloud Function
    func sendChatRequest(
        messages: [ChatMessage],
        functions functionDefs: [FunctionDefinition]? = nil,
        functionCall: String? = nil,
        parallelToolCalls: Bool? = nil,
        maxTokens: Int? = nil
    ) async throws -> ChatCompletionResponse {
        
        // Convert to dictionary format for Firebase
        let messagesDict = messages.map { $0.toDictionary() }
        
        // Prepare request data
        var data: [String: Any] = [
            "messages": messagesDict,
            "model": OpenAIConfig.model,
            "temperature": OpenAIConfig.temperature,
            "maxTokens": maxTokens ?? OpenAIConfig.maxTokens
        ]
        
        // Add tools (new format) if provided
        if let functionDefs = functionDefs {
            // Convert functions to tools format (required for strict mode)
            let toolsDict = functionDefs.map { funcDef -> [String: Any] in
                return [
                    "type": "function",
                    "function": funcDef.toDictionary()
                ]
            }
            data["tools"] = toolsDict
            
            // Use tool_choice instead of function_call
            if let functionCall = functionCall {
                if functionCall == "auto" || functionCall == "none" {
                    data["toolChoice"] = functionCall
                } else {
                    // Specific function
                    data["toolChoice"] = [
                        "type": "function",
                        "function": ["name": functionCall]
                    ]
                }
            }
            
            if let parallelToolCalls = parallelToolCalls {
                data["parallelToolCalls"] = parallelToolCalls
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
                throw ModoAIError.invalidResponse(reason: "Firebase returned data in the wrong format")
            }
            
            print("✅ [Firebase] Response received successfully")
            
            // Decode response data to ChatCompletionResponse
            do {
                return try self.decodeDictionary(responseData, to: ChatCompletionResponse.self)
            } catch {
                print("❌ [Firebase] Decoding error: \(error)")
                throw ModoAIError.decodingError(underlying: error)
            }
            
        } catch let error as ModoAIError {
            // Re-throw ModoAIError as-is
            throw error
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
                switch code {
                case .unauthenticated:
                    throw ModoAIError.authenticationFailed
                case .notFound:
                    throw ModoAIError.functionNotFound
                case .deadlineExceeded:
                    throw ModoAIError.timeoutError
                case .resourceExhausted:
                    throw ModoAIError.apiRateLimitExceeded
                default:
                    throw ModoAIError.firebaseError(underlying: error)
                }
            }
            
            // Handle network errors
            if error.domain == NSURLErrorDomain {
                switch error.code {
                case NSURLErrorNotConnectedToInternet:
                    throw ModoAIError.noInternetConnection
                case NSURLErrorTimedOut:
                    throw ModoAIError.timeoutError
                default:
                    throw ModoAIError.networkError(underlying: error)
                }
            }
            
            throw ModoAIError.firebaseError(underlying: error)
        }
    }
    
    // MARK: - Helper Methods
    
    /// Decode dictionary to Codable type
    /// - Parameters:
    ///   - dictionary: Source dictionary
    ///   - type: Target Codable type
    /// - Returns: Decoded object
    private func decodeDictionary<T: Decodable>(_ dictionary: [String: Any], to type: T.Type) throws -> T {
        let jsonData = try JSONSerialization.data(withJSONObject: dictionary)
        let decoder = JSONDecoder()
        return try decoder.decode(type, from: jsonData)
    }
}

// MARK: - Helper Models

/// Represents a chat message for OpenAI API via Firebase
struct ChatMessage {
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
    let strict: Bool?
    
    init(name: String, description: String, parameters: [String: Any], strict: Bool? = nil) {
        self.name = name
        self.description = description
        self.parameters = parameters
        self.strict = strict
    }
    
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "name": name,
            "description": description,
            "parameters": parameters
        ]
        if let strict = strict {
            dict["strict"] = strict
        }
        return dict
    }
}

// MARK: - Message Conversion Helper
extension ChatMessage {
    static func from(_ chatMessage: FirebaseChatMessage) -> ChatMessage {
        let role = chatMessage.isFromUser ? "user" : "assistant"
        return ChatMessage(
            role: role,
            content: chatMessage.content,
            name: nil,
            functionCall: nil
        )
    }
    
    static func fromArray(_ chatMessages: [FirebaseChatMessage]) -> [ChatMessage] {
        return chatMessages.map { from($0) }
    }
}

// MARK: - Legacy Error (Deprecated)
// Note: Use ModoAIError instead for new code
@available(*, deprecated, message: "Use ModoAIError instead")
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
