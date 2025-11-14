import Foundation
import SwiftData

/// Service for AI-powered task generation in AddTaskView
/// Handles automatic task generation, title generation, and description generation
class AddTaskAIService {
    private let firebaseAIService = FirebaseAIService.shared
    private let promptBuilder = AIPromptBuilder()
    private let taskCacheService = TaskCacheService.shared
    
    // MARK: - Automatic Task Generation
    
    /// Automatically generate a task based on existing tasks for the day
    /// - Parameters:
    ///   - selectedDate: Date for the task
    ///   - modelContext: SwiftData model context for fetching user profile
    ///   - completion: Completion handler with generated content or error
    func generateTaskAutomatically(
        for selectedDate: Date,
        modelContext: ModelContext,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        print("🎬 Automatic AI Generation started...")
        
        // Get user profile
        let userProfile: UserProfile? = {
            let fetchDescriptor = FetchDescriptor<UserProfile>()
            return try? modelContext.fetch(fetchDescriptor).first
        }()
        
        // Analyze existing tasks for the selected date
        let existingTasks = getExistingTasksForDate(selectedDate)
        let taskAnalysis = analyzeExistingTasks(existingTasks)
        
        print("📊 Task analysis: \(taskAnalysis)")
        
        // Build AI prompt using AIPromptBuilder
        let systemPrompt = promptBuilder.buildSystemPrompt(userProfile: userProfile)
        let userMessage = buildSmartPrompt(based: taskAnalysis, userProfile: userProfile)
        
        print("📝 Auto-generated prompt: \(userMessage.prefix(200))...")
        
        // Call OpenAI
        Task {
            do {
                print("📡 Sending request to OpenAI...")
                let FirebaseChatMessages = [
                    FirebaseFirebaseChatMessage(role: "system", content: systemPrompt),
                    FirebaseFirebaseChatMessage(role: "user", content: userMessage)
                ]

                let response = try await firebaseAIService.sendChatRequest(
                    messages: FirebaseChatMessages
                )
                
                print("✅ Received response from OpenAI")
                
                // Extract content from response
                let content = response.choices.first?.message.content ?? ""
                print("📄 Response content: \(content.prefix(200))...")
                
                await MainActor.run {
                    completion(.success(content))
                }
            } catch {
                print("❌ AI generation error: \(error)")
                print("❌ Error details: \(error.localizedDescription)")
                await MainActor.run {
                    completion(.failure(error))
                }
            }
        }
    }
    
    /// Generate or refine task title based on user profile
    /// - Parameters:
    ///   - currentTitle: Current title text (empty for new, or existing for refinement)
    ///   - modelContext: SwiftData model context for fetching user profile
    ///   - completion: Completion handler with generated title or error
    func generateOrRefineTitle(
        currentTitle: String,
        modelContext: ModelContext,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        // Get user profile
        let userProfile: UserProfile? = {
            let fetchDescriptor = FetchDescriptor<UserProfile>()
            return try? modelContext.fetch(fetchDescriptor).first
        }()
        
        // Build system prompt
        let systemPrompt = promptBuilder.buildSystemPrompt(userProfile: userProfile)
        
        // Build user message based on whether title is empty or not
        let userMessage: String
        if currentTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            // Generate new title based on user profile
            userMessage = """
            Generate a concise, clear task title (2-4 words max) for a fitness or nutrition task based on the user's profile.
            The title should be relevant to their goals and lifestyle.
            Examples: "Morning Run", "Upper Body Strength", "Healthy Breakfast", "Evening Yoga"
            
            Respond with ONLY the title, no additional text or explanation.
            """
        } else {
            // Refine existing title (improve grammar, clarity)
            userMessage = """
            Improve and refine this task title for clarity and grammar: "\(currentTitle)"
            
            Keep it concise (2-4 words max), maintain the same meaning, but make it clearer and more professional.
            Respond with ONLY the improved title, no additional text or explanation.
            """
        }
        
        Task {
            do {
                let messages = [
                    FirebaseFirebaseChatMessage(role: "system", content: systemPrompt),
                    FirebaseFirebaseChatMessage(role: "user", content: userMessage)
                ]
                
                let response = try await firebaseAIService.sendChatRequest(messages: messages)
                
                await MainActor.run {
                    if let content = response.choices.first?.message.content {
                        // Clean up the response - remove quotes, extra whitespace, etc.
                        let cleanedTitle = content
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                            .replacingOccurrences(of: "\"", with: "")
                            .replacingOccurrences(of: "'", with: "")
                        
                        // Limit to 40 characters (same as TextField limit)
                        let finalTitle = String(cleanedTitle.prefix(40))
                        completion(.success(finalTitle))
                    } else {
                        completion(.failure(NSError(domain: "AddTaskAIService", code: 1, userInfo: [NSLocalizedDescriptionKey: "No response content"])))
                    }
                }
            } catch {
                await MainActor.run {
                    print("❌ Title generation error: \(error)")
                    completion(.failure(error))
                }
            }
        }
    }
    
    /// Generate description based on existing title, or generate both title and description if title is empty
    /// - Parameters:
    ///   - currentTitle: Current title text (empty for new, or existing for description only)
    ///   - modelContext: SwiftData model context for fetching user profile
    ///   - completion: Completion handler with (title, description) or error
    func generateDescription(
        currentTitle: String,
        modelContext: ModelContext,
        completion: @escaping (Result<(title: String, description: String), Error>) -> Void
    ) {
        // Get user profile
        let userProfile: UserProfile? = {
            let fetchDescriptor = FetchDescriptor<UserProfile>()
            return try? modelContext.fetch(fetchDescriptor).first
        }()
        
        // Build system prompt
        let systemPrompt = promptBuilder.buildSystemPrompt(userProfile: userProfile)
        
        // Build user message based on whether title exists
        let userMessage: String
        if currentTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            // Generate a task suggestion (both title and description) that the user should do
            userMessage = """
            Suggest a fitness or nutrition task that would be beneficial for the user based on their profile, goals, and lifestyle.
            This should be something they would want to do or should do.
            
            Provide:
            1. A concise task title (2-4 words max) - something they should do
            2. A brief, helpful description (1-2 sentences) explaining what the task involves
            
            Format your response EXACTLY as:
            TITLE: [title here]
            DESCRIPTION: [description here]
            
            Make it relevant, actionable, and aligned with their fitness goals.
            Examples:
            - TITLE: Morning Run
              DESCRIPTION: 5km jog in the park to start the day with energy and boost metabolism
            - TITLE: Healthy Breakfast
              DESCRIPTION: Balanced meal with protein, carbs, and healthy fats to fuel your day
            - TITLE: Upper Body Strength
              DESCRIPTION: 30-minute workout focusing on chest, back, and arms to build muscle
            """
        } else {
            // Generate description based on existing title
            userMessage = """
            Generate a brief, helpful description (1-2 sentences) that fits well with this task title: "\(currentTitle)"
            
            The description should explain what the task involves, provide context, and make it clear what the user needs to do.
            Keep it concise, actionable, and relevant to the title.
            
            Respond with ONLY the description text, no additional labels or formatting.
            """
        }
        
        Task {
            do {
                let messages = [
                    FirebaseFirebaseChatMessage(role: "system", content: systemPrompt),
                    FirebaseFirebaseChatMessage(role: "user", content: userMessage)
                ]
                
                let response = try await firebaseAIService.sendChatRequest(messages: messages)
                
                await MainActor.run {
                    if let content = response.choices.first?.message.content {
                        if currentTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            // Parse both title and description
                            var finalTitle = ""
                            var finalDescription = ""
                            
                            let lines = content.components(separatedBy: .newlines)
                            for line in lines {
                                let trimmed = line.trimmingCharacters(in: .whitespaces)
                                if trimmed.hasPrefix("TITLE:") {
                                    let title = trimmed.replacingOccurrences(of: "TITLE:", with: "")
                                        .trimmingCharacters(in: .whitespaces)
                                        .replacingOccurrences(of: "\"", with: "")
                                        .replacingOccurrences(of: "'", with: "")
                                    finalTitle = String(title.prefix(40))
                                } else if trimmed.hasPrefix("DESCRIPTION:") {
                                    finalDescription = trimmed.replacingOccurrences(of: "DESCRIPTION:", with: "")
                                        .trimmingCharacters(in: .whitespaces)
                                }
                            }
                            
                            completion(.success((title: finalTitle, description: finalDescription)))
                        } else {
                            // Just set description
                            let cleanedDesc = content
                                .trimmingCharacters(in: .whitespacesAndNewlines)
                                .replacingOccurrences(of: "DESCRIPTION:", with: "")
                                .trimmingCharacters(in: .whitespaces)
                            
                            completion(.success((title: currentTitle, description: cleanedDesc)))
                        }
                    } else {
                        completion(.failure(NSError(domain: "AddTaskAIService", code: 2, userInfo: [NSLocalizedDescriptionKey: "No response content"])))
                    }
                }
            } catch {
                await MainActor.run {
                    print("❌ Description generation error: \(error)")
                    completion(.failure(error))
                }
            }
        }
    }
    
    // MARK: - Task Analysis (Private Helpers)
    
    /// Get existing tasks for the selected date from cache
    private func getExistingTasksForDate(_ date: Date) -> [TaskInfo] {
        // Get tasks from cache service
        let tasks = taskCacheService.getTasks(for: date)
        
        print("📊 Found \(tasks.count) existing tasks for \(date)")
        
        // Convert TaskItem to TaskInfo
        return tasks.map { task in
            let categoryString: String
            switch task.category {
            case .fitness:
                categoryString = "fitness"
            case .diet:
                categoryString = "diet"
            case .others:
                categoryString = "others"
            }
            
            return TaskInfo(
                category: categoryString,
                time: task.time,
                title: task.title
            )
        }
    }
    
    struct TaskInfo {
        let category: String // "fitness", "diet", "others"
        let time: String
        let title: String
    }
    
    struct TaskAnalysis {
        let hasFitness: Bool
        let hasBreakfast: Bool
        let hasLunch: Bool
        let hasDinner: Bool
        let totalTasks: Int
        let suggestion: String // What to generate
    }
    
    /// Analyze existing tasks to determine what's missing
    private func analyzeExistingTasks(_ tasks: [TaskInfo]) -> TaskAnalysis {
        print("🔍 Analyzing \(tasks.count) existing tasks:")
        for (index, task) in tasks.enumerated() {
            print("   \(index + 1). [\(task.category)] \(task.title) at \(task.time)")
        }
        
        let hasFitness = tasks.contains { $0.category == "fitness" }
        
        // Check for meals by time or keywords
        let hasBreakfast = tasks.contains { task in
            task.category == "diet" && (
                task.time.contains("AM") && !task.time.contains("12:") ||
                task.title.lowercased().contains("breakfast")
            )
        }
        
        let hasLunch = tasks.contains { task in
            task.category == "diet" && (
                (task.time.contains("12:") || task.time.contains("01:") || task.time.contains("02:")) ||
                task.title.lowercased().contains("lunch")
            )
        }
        
        let hasDinner = tasks.contains { task in
            task.category == "diet" && (
                task.time.contains("PM") && !task.time.contains("12:") && !task.time.contains("01:") && !task.time.contains("02:") ||
                task.title.lowercased().contains("dinner")
            )
        }
        
        print("📋 Task coverage:")
        print("   - Fitness: \(hasFitness ? "✅" : "❌")")
        print("   - Breakfast: \(hasBreakfast ? "✅" : "❌")")
        print("   - Lunch: \(hasLunch ? "✅" : "❌")")
        print("   - Dinner: \(hasDinner ? "✅" : "❌")")
        
        // Determine what to suggest
        var suggestion = ""
        if !hasFitness {
            suggestion = "fitness"
        } else if !hasBreakfast {
            suggestion = "breakfast"
        } else if !hasLunch {
            suggestion = "lunch"
        } else if !hasDinner {
            suggestion = "dinner"
        } else {
            // All basic tasks covered, generate a random healthy snack or workout
            suggestion = Bool.random() ? "fitness" : "snack"
        }
        
        print("💡 Suggestion: Generate \(suggestion)")
        
        return TaskAnalysis(
            hasFitness: hasFitness,
            hasBreakfast: hasBreakfast,
            hasLunch: hasLunch,
            hasDinner: hasDinner,
            totalTasks: tasks.count,
            suggestion: suggestion
        )
    }
    
    /// Build smart prompt based on task analysis
    private func buildSmartPrompt(based analysis: TaskAnalysis, userProfile: UserProfile?) -> String {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: Date())
        let timeOfDay = hour < 12 ? "morning" : hour < 17 ? "afternoon" : "evening"
        
        var prompt = "It's \(timeOfDay). "
        
        switch analysis.suggestion {
        case "fitness":
            prompt += """
            Create a workout task with a SHORT, CONCISE title (2-4 words max, like 'Upper Body Strength' or 'Full Body HIIT').
            Consider the user's current fitness level and goals. Suggest an appropriate workout for \(timeOfDay).
            """
            
        case "breakfast":
            prompt += """
            Create a healthy breakfast task for ONE PERSON. The user hasn't logged breakfast yet.
            Provide nutritious breakfast options with specific portion sizes (e.g., '2 eggs', '1 cup oatmeal', '6oz yogurt').
            Use single servings appropriate for one person.
            """
            
        case "lunch":
            prompt += """
            Create a healthy lunch task for ONE PERSON. The user hasn't logged lunch yet.
            Provide balanced lunch options with specific portion sizes (e.g., '6oz chicken', '1 cup rice', '1 cup vegetables').
            Use single servings appropriate for one person.
            """
            
        case "dinner":
            prompt += """
            Create a healthy dinner task for ONE PERSON. The user hasn't logged dinner yet.
            Provide nutritious dinner options with specific portion sizes (e.g., '8oz salmon', '1.5 cups quinoa', '2 cups salad').
            Use single servings appropriate for one person.
            """
            
        case "snack":
            prompt += """
            Create a healthy snack task for ONE PERSON. Suggest a nutritious snack between meals.
            Keep it light and balanced with specific portions (e.g., '1 apple', '1oz almonds', '1 protein bar').
            Use single servings appropriate for one person.
            """
            
        default:
            prompt += "Create a helpful fitness or nutrition task for today."
        }
        
        prompt += """
        
        
        Please provide:
        1. A clear, concise task title (max 50 characters)
        2. A detailed description
        3. Task category (fitness or diet)
        4. If fitness: List specific exercises with sets, reps, rest periods, duration (minutes), and calories
        5. If diet: List specific foods/meals with portion sizes and calories
        6. Suggested time of day (format: "HH:MM AM/PM")
        
        Format your response as:
        TITLE: [title here]
        DESCRIPTION: [description here]
        CATEGORY: [fitness or diet]
        TIME: [time here]
        
        For fitness tasks:
        EXERCISES:
        - [Exercise name]: [sets] sets x [reps] reps, [rest]s rest, [duration]min, [calories]cal
        
        For diet tasks:
        FOODS:
        - [Food name]: [quantity] [unit], [calories]cal
        
        Examples of valid units: serving, oz, g, kg, lbs, cups, tbsp, etc.
        Example: "Chicken Breast: 6 oz, 280cal"
        Example: "Oatmeal: 1 serving, 150cal"
        Example: "Banana: 100 g, 89cal"
        """
        
        return prompt
    }
    
    // MARK: - Manual Task Generation (from user prompt)
    
    /// Generate task content using AI based on user's custom prompt
    /// - Parameters:
    ///   - userPrompt: User's custom prompt/description
    ///   - modelContext: SwiftData model context for fetching user profile
    ///   - completion: Completion handler with generated content or error
    func generateTaskFromPrompt(
        userPrompt: String,
        modelContext: ModelContext,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        print("🎬 AI Generation from user prompt started...")
        print("📝 Prompt: \(userPrompt)")
        
        guard !userPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            completion(.failure(NSError(domain: "AddTaskAIService", code: 3, userInfo: [NSLocalizedDescriptionKey: "Please describe what task you'd like to create"])))
            return
        }
        
        // Get user profile
        let userProfile: UserProfile? = {
            let fetchDescriptor = FetchDescriptor<UserProfile>()
            return try? modelContext.fetch(fetchDescriptor).first
        }()
        
        // Build system prompt using AIPromptBuilder
        let systemPrompt = promptBuilder.buildSystemPrompt(userProfile: userProfile)
        
        // User's request
        let userMessage = """
        Create a task based on this description: "\(userPrompt)"
        
        Please provide:
        1. A clear, concise task title (max 50 characters)
        2. A detailed description
        3. Task category (fitness or diet)
        4. If fitness: List specific exercises with sets, reps, rest periods, duration (minutes), and calories
        5. If diet: List specific foods/meals with portion sizes and calories
        6. Suggested time of day (format: "HH:MM AM/PM")
        
        Format your response as:
        TITLE: [title here]
        DESCRIPTION: [description here]
        CATEGORY: [fitness or diet]
        TIME: [time here]
        
        For fitness tasks:
        EXERCISES:
        - [Exercise name]: [sets] sets x [reps] reps, [rest]s rest, [duration]min, [calories]cal
        
        For diet tasks:
        FOODS:
        - [Food name]: [quantity] [unit], [calories]cal
        
        Examples of valid units: serving, oz, g, kg, lbs, cups, tbsp, etc.
        Example: "Chicken Breast: 6 oz, 280cal"
        Example: "Oatmeal: 1 serving, 150cal"
        Example: "Banana: 100 g, 89cal"
        """
        
        // Call OpenAI
        Task {
            do {
                print("📡 Sending request to OpenAI...")
                let FirebaseChatMessages = [
                    FirebaseFirebaseChatMessage(role: "system", content: systemPrompt),
                    FirebaseFirebaseChatMessage(role: "user", content: userMessage)
                ]

                let response = try await firebaseAIService.sendChatRequest(
                    messages: FirebaseChatMessages
                )
                print("✅ Received response from OpenAI")
                
                // Extract content from response
                let content = response.choices.first?.message.content ?? ""
                print("📄 Response content: \(content.prefix(200))...")
                
                await MainActor.run {
                    completion(.success(content))
                }
            } catch {
                print("❌ AI generation error: \(error)")
                print("❌ Error details: \(error.localizedDescription)")
                await MainActor.run {
                    completion(.failure(error))
                }
            }
        }
    }
}

