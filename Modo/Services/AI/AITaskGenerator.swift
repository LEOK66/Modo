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
    ///   - isReplacement: Whether this is replacing existing tasks (for variety)
    ///   - onEachTask: Called immediately when each task is generated
    ///   - onComplete: Called when all tasks are generated
    func generateMissingTasksSequentially(
        missing: [String],
        for date: Date,
        userProfile: UserProfile?,
        isReplacement: Bool = false,
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
                generateWorkoutTask(for: date, userProfile: userProfile, isReplacement: isReplacement) { result in
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
                generateSpecificNutritionTasks([taskType], for: date, userProfile: userProfile, isReplacement: isReplacement) { result in
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
    ///   - isReplacement: Whether this is replacing an existing workout (for variety)
    ///   - completion: Completion handler with generated task
    func generateWorkoutTask(for date: Date, userProfile: UserProfile?, isReplacement: Bool = false, completion: @escaping (Result<AIGeneratedTask, Error>) -> Void) {
        isGenerating = true
        print("🏋️ AITaskGenerator: Generating workout task... (replacement: \(isReplacement))")
        
        // ✅ Use AIPromptBuilder for prompt construction
        let systemPrompt = promptBuilder.buildSystemPrompt(userProfile: userProfile)
        let userPrompt = "Generate a workout plan for \(formatDate(date)). \(isReplacement ? "This replaces a previous workout, so create something DIFFERENT with varied exercises." : "")"
        
        Task {
            do {
                let messages = [
                    ChatMessage(role: "system", content: systemPrompt),
                    ChatMessage(role: "user", content: userPrompt)
                ]

                // ⭐ Use Function Calling instead of text parsing
                let response = try await firebaseAIService.sendChatRequest(
                    messages: messages,
                    functions: firebaseAIService.buildFunctions(),
                    functionCall: "auto",
                    parallelToolCalls: false
                )
                
                await MainActor.run {
                    self.isGenerating = false
                    
                    // Check if AI called the function
                    if let functionCall = response.choices.first?.message.effectiveFunctionCall,
                       functionCall.name == "generate_workout_plan",
                       let data = functionCall.arguments.data(using: .utf8) {
                        
                        do {
                            // Decode structured response (100% reliable with strict mode)
                            let workoutPlan = try JSONDecoder().decode(WorkoutPlanFunctionResponse.self, from: data)
                            
                            guard let exercises = workoutPlan.exercises, !exercises.isEmpty else {
                                completion(.failure(ModoAIError.missingRequiredData(field: "exercises")))
                                return
                            }
                            
                            // Convert to AIExercise - use AI-provided values or calculate if missing
                            let aiExercises = exercises.map { exercise -> AIExercise in
                                let duration = exercise.durationMin ?? self.exerciseData.calculateDuration(
                                    sets: exercise.sets,
                                    reps: exercise.reps,
                                    restSec: exercise.restSec ?? 60
                                )
                                
                                let calories = exercise.calories ?? self.exerciseData.calculateCalories(
                                    for: exercise.name,
                                    sets: exercise.sets,
                                    reps: exercise.reps,
                                    restSec: exercise.restSec ?? 60,
                                    userWeight: userProfile?.weightValue
                                )
                                
                                return AIExercise(
                                    name: exercise.name,
                                    sets: exercise.sets,
                                    reps: exercise.reps,
                                    restSec: exercise.restSec ?? 60,
                                    durationMin: duration,
                                    calories: calories
                                )
                            }
                            
                            let totalDuration = aiExercises.reduce(0) { $0 + $1.durationMin }
                            let totalCalories = aiExercises.reduce(0) { $0 + $1.calories }
                            
                            let task = AIGeneratedTask(
                                type: .workout,
                                date: date,
                                title: workoutPlan.goal.capitalized, // Use goal as title
                                exercises: aiExercises,
                                meals: [],
                                totalDuration: totalDuration,
                                totalCalories: totalCalories
                            )
                            
                            print("   ✅ Generated via Function Calling: \(task.title) - \(aiExercises.count) exercises")
                            completion(.success(task))
                            
                        } catch {
                            print("   ❌ Failed to decode function response: \(error)")
                            completion(.failure(ModoAIError.decodingError(underlying: error)))
                        }
                        
                    } else {
                        // Fallback: AI didn't call function (shouldn't happen with proper prompt)
                        print("   ⚠️ AI didn't call function, response: \(response.choices.first?.message.content ?? "empty")")
                        completion(.failure(ModoAIError.invalidResponse(reason: "AI didn't call the required function")))
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
    
    // MARK: - Helper
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
    
    // MARK: - Generate Nutrition Tasks (Refactored with modular services)
    
    /// Generate nutrition tasks for specific meals only
    /// - Parameters:
    ///   - meals: Array of meal types (e.g., ["breakfast", "lunch"])
    ///   - date: Date for the tasks
    ///   - userProfile: User profile for personalization
    ///   - isReplacement: Whether this is replacing existing meals (for variety)
    ///   - completion: Completion handler with generated tasks
    func generateSpecificNutritionTasks(_ meals: [String], for date: Date, userProfile: UserProfile?, isReplacement: Bool = false, completion: @escaping (Result<[AIGeneratedTask], Error>) -> Void) {
        isGenerating = true
        print("🍽️ AITaskGenerator: Generating nutrition tasks for \(meals.joined(separator: ", "))... (replacement: \(isReplacement))")
        
        // ✅ Use AIPromptBuilder for prompt construction
        let systemPrompt = promptBuilder.buildSystemPrompt(userProfile: userProfile)
        let userPrompt = """
        Generate a nutrition plan for \(formatDate(date)) with ONLY these specific meals: \(meals.joined(separator: ", ")).
        CRITICAL: DO NOT include any meals not in this list. Generate exactly \(meals.count) meal(s).
        \(isReplacement ? "This replaces previous meals, so create DIFFERENT dishes with varied ingredients." : "")
        """
        
        Task {
            do {
                let messages = [
                    ChatMessage(role: "system", content: systemPrompt),
                    ChatMessage(role: "user", content: userPrompt)
                ]

                // ⭐ Use Function Calling instead of text parsing
                let response = try await firebaseAIService.sendChatRequest(
                    messages: messages,
                    functions: firebaseAIService.buildFunctions(),
                    functionCall: "auto",
                    parallelToolCalls: false
                )
                
                await MainActor.run {
                    // Check if AI called the function
                    if let functionCall = response.choices.first?.message.effectiveFunctionCall,
                       functionCall.name == "generate_nutrition_plan",
                       let data = functionCall.arguments.data(using: .utf8) {
                        
                        do {
                            // Decode structured response (100% reliable with strict mode)
                            let nutritionPlan = try JSONDecoder().decode(NutritionPlanFunctionResponse.self, from: data)
                            
                            guard !nutritionPlan.meals.isEmpty else {
                                self.isGenerating = false
                                completion(.failure(ModoAIError.missingRequiredData(field: "meals")))
                                return
                            }
                            
                            // Convert to AIGeneratedTask array
                            var generatedTasks: [AIGeneratedTask] = []
                            
                            // Filter: Only process meals that were explicitly requested
                            let requestedMealTypes = Set(meals.map { $0.lowercased() })
                            
                            for meal in nutritionPlan.meals {
                                // Skip unrequested meals (prevents duplicates from AI over-generation)
                                guard requestedMealTypes.contains(meal.mealType.lowercased()) else {
                                    print("   ⚠️ AITaskGenerator: Skipping unrequested meal: \(meal.mealType)")
                                    continue
                                }
                                
                                let foodItems = meal.foods.map { food in
                                    AIFoodItem(name: food.name, calories: food.calories)
                                }
                                
                                let totalCalories = foodItems.reduce(0) { $0 + $1.calories }
                                
                                let aiMeal = AIMeal(
                                    name: meal.mealType.capitalized,
                                    foods: meal.foods.map { $0.name },
                                    time: meal.time ?? self.getMealTime(meal.mealType),
                                    foodItems: foodItems
                                )
                                
                                let task = AIGeneratedTask(
                                    type: .nutrition,
                                    date: date,
                                    title: meal.mealType.capitalized,
                                    exercises: [],
                                    meals: [aiMeal],
                                    totalDuration: 0,
                                    totalCalories: totalCalories
                                )
                                
                                generatedTasks.append(task)
                            }
                            
                            self.isGenerating = false
                            print("   ✅ Generated via Function Calling: \(generatedTasks.count) nutrition tasks")
                            completion(.success(generatedTasks))
                            
                        } catch {
                            self.isGenerating = false
                            print("   ❌ Failed to decode function response: \(error)")
                            completion(.failure(ModoAIError.decodingError(underlying: error)))
                        }
                        
                    } else {
                        // Fallback: AI didn't call function
                        self.isGenerating = false
                        print("   ⚠️ AI didn't call function, response: \(response.choices.first?.message.content ?? "empty")")
                        completion(.failure(ModoAIError.invalidResponse(reason: "AI didn't call the required function")))
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
                        // Priority: AI-provided calories > Cache > Default
                        // AI should have provided calories, but if not, use cache if available
                        let cached = results.first(where: { $0.name == food.name })
                        let defaultCalories = 250
                        let calories = food.calories > 0 ? food.calories : (cached?.calories ?? defaultCalories)
                        
                        if food.calories == 0 && cached == nil {
                            print("  ⚠️ No calories from AI or cache for '\(food.name)', using default \(defaultCalories)")
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
