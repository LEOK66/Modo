import Foundation
import SwiftUI
import Combine

/// AI Task Generator - Creates workout and nutrition tasks automatically
/// Now modular: uses specialized services for prompts, parsing, and data lookup
class AITaskGenerator: ObservableObject {
    @Published var isGenerating = false
    
    // Core services
    private let firebaseAIService = FirebaseAIService.shared
    
    // ✅ NEW: Modular services for better separation of concerns
    private let promptBuilder = AIPromptBuilder()
    private let responseParser = AIResponseParser()
    private let nutritionLookup = NutritionLookupService()
    private let exerciseData = ExerciseDataService()
    
    // MARK: - Generate Missing Tasks (Smart Generation - Sequential)
    
    /// Generate missing tasks one by one sequentially
    /// - Parameters:
    ///   - missing: Array of task types to generate (e.g., ["fitness", "breakfast", "lunch", "dinner"])
    ///   - date: Date for the tasks
    ///   - userProfile: User profile for personalization
    ///   - onEachTask: Called immediately when each task is generated
    ///   - onComplete: Called when all tasks are generated
    func generateMissingTasksSequentially(
        missing: [String],
        for date: Date,
        userProfile: UserProfile?,
        onEachTask: @escaping (AIGeneratedTask) -> Void,
        onComplete: @escaping () -> Void
    ) {
        print("🎯 AI Task Generator: Generating tasks sequentially: \(missing.joined(separator: ", "))")
        
        var tasksToGenerate = missing
        
        func generateNextTask() {
            guard !tasksToGenerate.isEmpty else {
                print("✅ All sequential generation completed")
                onComplete()
                return
            }
            
            let taskType = tasksToGenerate.removeFirst()
            print("🔄 Generating: \(taskType)")
            
            if taskType == "fitness" {
                // Generate fitness task
                generateWorkoutTask(for: date, userProfile: userProfile) { result in
                    switch result {
                    case .success(let task):
                        print("  ✅ Successfully generated fitness task")
                        onEachTask(task)
                    case .failure(let error):
                        print("  ❌ Failed to generate fitness task: \(error.localizedDescription)")
                    }
                    // Continue to next task
                    generateNextTask()
                }
            } else if ["breakfast", "lunch", "dinner", "snack"].contains(taskType) {
                // Generate nutrition task
                print("  🍽️ Requesting nutrition task for: \(taskType)")
                generateSpecificNutritionTasks([taskType], for: date, userProfile: userProfile) { result in
                    switch result {
                    case .success(let tasks):
                        print("  ✅ Successfully generated \(tasks.count) nutrition task(s) for \(taskType)")
                        for task in tasks {
                            onEachTask(task)
                        }
                    case .failure(let error):
                        print("  ❌ Failed to generate nutrition task for \(taskType): \(error.localizedDescription)")
                    }
                    // Continue to next task
                    generateNextTask()
                }
            } else {
                // Unknown task type, skip
                print("  ⚠️ Unknown task type: \(taskType), skipping")
                generateNextTask()
            }
        }
        
        // Start generating
        generateNextTask()
    }
    
    // MARK: - Generate Missing Tasks (Smart Generation - Parallel, Legacy)
    
    /// Generate only the missing tasks based on analysis (parallel generation)
    /// - Parameters:
    ///   - missing: Array of task types to generate (e.g., ["fitness", "breakfast", "lunch", "dinner"])
    ///   - date: Date for the tasks
    ///   - userProfile: User profile for personalization
    ///   - completion: Completion handler with generated tasks
    func generateMissingTasks(missing: [String], for date: Date, userProfile: UserProfile?, completion: @escaping ([AIGeneratedTask]) -> Void) {
        print("🎯 AI Task Generator: Generating missing tasks: \(missing.joined(separator: ", "))")
        
        var generatedTasks: [AIGeneratedTask] = []
        let dispatchGroup = DispatchGroup()
        
        // Generate fitness task if missing
        if missing.contains("fitness") {
            dispatchGroup.enter()
            generateWorkoutTask(for: date, userProfile: userProfile) { result in
                if case .success(let task) = result {
                    generatedTasks.append(task)
                }
                dispatchGroup.leave()
            }
        }
        
        // Generate specific meals if missing
        var mealsToGenerate: [String] = []
        if missing.contains("breakfast") {
            mealsToGenerate.append("breakfast")
        }
        if missing.contains("lunch") {
            mealsToGenerate.append("lunch")
        }
        if missing.contains("dinner") {
            mealsToGenerate.append("dinner")
        }
        if missing.contains("snack") {
            mealsToGenerate.append("snack")
        }
        
        // Generate nutrition tasks for missing meals
        if !mealsToGenerate.isEmpty {
            dispatchGroup.enter()
            generateSpecificNutritionTasks(mealsToGenerate, for: date, userProfile: userProfile) { result in
                if case .success(let tasks) = result {
                    generatedTasks.append(contentsOf: tasks)
                }
                dispatchGroup.leave()
            }
        }
        
        dispatchGroup.notify(queue: .main) {
            print("✅ Generated \(generatedTasks.count) missing tasks")
            completion(generatedTasks)
        }
    }
    
    // MARK: - Generate Both Tasks (Legacy - for compatibility)
    func generateBothTasks(for date: Date, userProfile: UserProfile?, completion: @escaping ([AIGeneratedTask]) -> Void) {
        print("🎲 AI Task Generator: Generating workout and nutrition tasks for \(date)")
        
        var generatedTasks: [AIGeneratedTask] = []
        let dispatchGroup = DispatchGroup()
        
        // Generate workout task
        dispatchGroup.enter()
        generateWorkoutTask(for: date, userProfile: userProfile) { result in
            if case .success(let task) = result {
                generatedTasks.append(task)
            }
            dispatchGroup.leave()
        }
        
        // Generate nutrition tasks (3 meals) using refactored method
        dispatchGroup.enter()
        generateSpecificNutritionTasks(["breakfast", "lunch", "dinner"], for: date, userProfile: userProfile) { result in
            if case .success(let tasks) = result {
                generatedTasks.append(contentsOf: tasks)
            }
            dispatchGroup.leave()
        }
        
        dispatchGroup.notify(queue: .main) {
            completion(generatedTasks)
        }
    }
    
    // MARK: - Generate Workout Task (Refactored with modular services)
    /// Generate a single workout task for a specific date
    /// - Parameters:
    ///   - date: Target date for the workout
    ///   - userProfile: User profile for personalization
    ///   - completion: Completion handler with generated task
    func generateWorkoutTask(for date: Date, userProfile: UserProfile?, completion: @escaping (Result<AIGeneratedTask, Error>) -> Void) {
        isGenerating = true
        print("🏋️ AITaskGenerator: Generating workout task...")
        
        // ✅ Use AIPromptBuilder for prompt construction
        let systemPrompt = promptBuilder.buildSystemPrompt(userProfile: userProfile)
        let userPrompt = promptBuilder.buildWorkoutPrompt(userProfile: userProfile)
        
        Task {
            do {
                let messages = [
                    FirebaseFirebaseChatMessage(role: "system", content: systemPrompt),
                    FirebaseFirebaseChatMessage(role: "user", content: userPrompt)
                ]

                let response = try await firebaseAIService.sendChatRequest(messages: messages)
                
                await MainActor.run {
                    self.isGenerating = false
                    
                    if let content = response.choices.first?.message.content {
                        // ✅ Use AIResponseParser for parsing
                        let (title, parsedExercises) = self.responseParser.parseWorkoutResponse(content)
                        
                        // ✅ Use ExerciseDataService to calculate duration and calories
                        let exercises = parsedExercises.map { parsed -> AIExercise in
                            let duration = self.exerciseData.calculateDuration(
                                sets: parsed.sets,
                                reps: parsed.reps,
                                restSec: parsed.restSec
                            )
                            
                            // Use AI-provided calories if available, otherwise calculate
                            let calories = parsed.calories > 0 ? parsed.calories : 
                                          self.exerciseData.calculateCalories(
                                            for: parsed.name,
                                            sets: parsed.sets,
                                            reps: parsed.reps,
                                            restSec: parsed.restSec,
                                            userWeight: userProfile?.weightValue
                                          )
                            
                            return AIExercise(
                                name: parsed.name,
                                sets: parsed.sets,
                                reps: parsed.reps,
                                restSec: parsed.restSec,
                                durationMin: duration,
                                calories: calories
                            )
                        }
                        
                        let totalDuration = exercises.reduce(0) { $0 + $1.durationMin }
                        let totalCalories = exercises.reduce(0) { $0 + $1.calories }
                        
                        let task = AIGeneratedTask(
                            type: .workout,
                            date: date,
                            title: title,
                            exercises: exercises,
                            meals: [],
                            totalDuration: totalDuration,
                            totalCalories: totalCalories
                        )
                        
                        print("   ✅ Generated: \(title) - \(exercises.count) exercises, \(totalDuration)min, \(totalCalories)cal")
                        completion(.success(task))
                    } else {
                        completion(.failure(NSError(domain: "AITaskGenerator", code: 1, userInfo: [NSLocalizedDescriptionKey: "No response content"])))
                    }
                }
            } catch {
                await MainActor.run {
                    self.isGenerating = false
                    print("   ❌ Error: \(error.localizedDescription)")
                    completion(.failure(error))
                }
            }
        }
    }
    
    // MARK: - Generate Nutrition Tasks (Refactored with modular services)
    
    /// Generate nutrition tasks for specific meals only
    /// - Parameters:
    ///   - meals: Array of meal types (e.g., ["breakfast", "lunch"])
    ///   - date: Date for the tasks
    ///   - userProfile: User profile for personalization
    ///   - completion: Completion handler with generated tasks
    func generateSpecificNutritionTasks(_ meals: [String], for date: Date, userProfile: UserProfile?, completion: @escaping (Result<[AIGeneratedTask], Error>) -> Void) {
        isGenerating = true
        print("🍽️ AITaskGenerator: Generating nutrition tasks for \(meals.joined(separator: ", "))...")
        
        // ✅ Use AIPromptBuilder for prompt construction
        let systemPrompt = promptBuilder.buildSystemPrompt(userProfile: userProfile)
        let userPrompt = promptBuilder.buildNutritionPrompt(meals: meals, userProfile: userProfile)
        
        Task {
            do {
                let messages = [
                    FirebaseFirebaseChatMessage(role: "system", content: systemPrompt),
                    FirebaseFirebaseChatMessage(role: "user", content: userPrompt)
                ]

                let response = try await firebaseAIService.sendChatRequest(messages: messages)
                
                await MainActor.run {
                    if let content = response.choices.first?.message.content {
                        print("📝 AI Response received, parsing...")
                        
                        // ✅ Use AIResponseParser for parsing
                        let parsedMeals = self.responseParser.parseNutritionResponse(content)
                        
                        guard !parsedMeals.isEmpty else {
                            self.isGenerating = false
                            print("  ❌ No meals parsed from AI response")
                            completion(.failure(NSError(domain: "AITaskGenerator", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to parse any meals"])))
                            return
                        }
                        
                        // ✅ Use NutritionLookupService to fetch calories (API priority)
                        self.fetchCaloriesForMeals(parsedMeals, date: date, completion: completion)
                    } else {
                        self.isGenerating = false
                        print("  ❌ No response content from AI")
                        completion(.failure(NSError(domain: "AITaskGenerator", code: 2, userInfo: [NSLocalizedDescriptionKey: "No response content"])))
                    }
                }
            } catch {
                await MainActor.run {
                    self.isGenerating = false
                    print("  ❌ Error: \(error.localizedDescription)")
                    completion(.failure(error))
                }
            }
        }
    }
    
    // MARK: - Fetch Calories for Meals (Refactored)
    
    /// Process parsed meals and create tasks (using AI-provided calories or cache lookup)
    /// - Parameters:
    ///   - parsedMeals: Dictionary of meal names to food items with calories [mealName: [(name, calories)]]
    ///   - date: Date for the tasks
    ///   - completion: Completion handler with AIGeneratedTask array
    private func fetchCaloriesForMeals(_ parsedMeals: [String: [(name: String, calories: Int)]], date: Date, completion: @escaping (Result<[AIGeneratedTask], Error>) -> Void) {
        print("🔍 Processing \(parsedMeals.count) meals (using AI-provided calories or cache)...")
        
        let dispatchGroup = DispatchGroup()
        var generatedTasks: [AIGeneratedTask] = []
        let tasksQueue = DispatchQueue(label: "com.modo.aitaskgenerator.tasks")
        
        for (mealName, foods) in parsedMeals {
            dispatchGroup.enter()
            
            // Check if AI provided calories for all foods
            let allHaveCalories = foods.allSatisfy { $0.calories > 0 }
            
            if allHaveCalories {
                // Use AI-provided calories directly
                let foodItems = foods.map { AIFoodItem(name: $0.name, calories: $0.calories) }
                let totalCalories = foodItems.reduce(0) { $0 + $1.calories }
                
                let meal = AIMeal(
                    name: mealName,
                    foods: foods.map { $0.name },
                    time: self.getMealTime(mealName),
                    foodItems: foodItems
                )
                
                let task = AIGeneratedTask(
                    type: .nutrition,
                    date: date,
                    title: mealName,
                    exercises: [],
                    meals: [meal],
                    totalDuration: 0,
                    totalCalories: totalCalories
                )
                
                tasksQueue.async {
                    generatedTasks.append(task)
                    print("  ✅ Generated \(mealName) using AI calories: \(foodItems.count) items, \(totalCalories) cal")
                    dispatchGroup.leave()
                }
            } else {
                // Some foods missing calories - use cache lookup (cache-only, no network)
                // Note: AI should provide calories, but we fallback to cache for robustness
                let foodNames = foods.map { $0.name }
                nutritionLookup.lookupCaloriesBatch(foodNames, allowNetwork: false) { results in
                    // Merge AI-provided calories with cache results
                    let foodItems = foods.map { food in
                        // Priority: AI-provided calories > Cache > Default (250)
                        // AI should have provided calories, but if not, use cache if available
                        let cached = results.first(where: { $0.name == food.name })
                        let calories = food.calories > 0 ? food.calories : (cached?.calories ?? 250)
                        
                        if food.calories == 0 && cached == nil {
                            print("  ⚠️ No calories from AI or cache for '\(food.name)', using default 250")
                        }
                        
                        return AIFoodItem(name: food.name, calories: calories)
                    }
                    let totalCalories = foodItems.reduce(0) { $0 + $1.calories }
                    
                    let meal = AIMeal(
                        name: mealName,
                        foods: foodNames,
                        time: self.getMealTime(mealName),
                        foodItems: foodItems
                    )
                    
                    let task = AIGeneratedTask(
                        type: .nutrition,
                        date: date,
                        title: mealName,
                        exercises: [],
                        meals: [meal],
                        totalDuration: 0,
                        totalCalories: totalCalories
                    )
                    
                    tasksQueue.async {
                        generatedTasks.append(task)
                        print("  ✅ Generated \(mealName) using cache: \(foodItems.count) items, \(totalCalories) cal")
                        dispatchGroup.leave()
                    }
                }
            }
        }
        
        dispatchGroup.notify(queue: .main) {
            self.isGenerating = false
            print("  ✅ All nutrition tasks generated: \(generatedTasks.count)")
            completion(.success(generatedTasks))
        }
    }
    
    // MARK: - Helper: Get Meal Time
    private func getMealTime(_ mealName: String) -> String {
        switch mealName.lowercased() {
        case "breakfast": return "08:00 AM"
        case "lunch": return "12:00 PM"
        case "dinner": return "06:00 PM"
        case "snack": return "03:00 PM"
        default: return "12:00 PM"
        }
    }
}

// MARK: - Data Models

/// Generated task containing workout or nutrition data
struct AIGeneratedTask {
    let type: TaskType
    let date: Date
    let title: String
    let exercises: [AIExercise]
    let meals: [AIMeal]
    let totalDuration: Int  // minutes
    let totalCalories: Int
    
    enum TaskType {
        case workout
        case nutrition
    }
}

/// Exercise information
struct AIExercise {
    let name: String
    let sets: Int
    let reps: String  // Can be "10" or "8-12"
    let restSec: Int
    let durationMin: Int
    let calories: Int
}

/// Meal information
struct AIMeal {
    let name: String  // "Breakfast", "Lunch", "Dinner"
    var foods: [String]  // Raw food names from AI
    let time: String  // "08:00 AM"
    var foodItems: [AIFoodItem] = []  // Populated after calorie lookup
    
    var totalCalories: Int {
        return foodItems.reduce(0) { $0 + $1.calories }
    }
}

/// Food item with calories
struct AIFoodItem {
    let name: String
    let calories: Int
}
