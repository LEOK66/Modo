import Foundation
import SwiftUI
import Combine

/// AI Task Generator - Creates workout and nutrition tasks automatically
class AITaskGenerator: ObservableObject {
    @Published var isGenerating = false
    
    private let openAIService = OpenAIService.shared
    
    // MARK: - Generate Both Tasks
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
        
        // Generate nutrition tasks (3 meals)
        dispatchGroup.enter()
        generateNutritionTasks(for: date, userProfile: userProfile) { result in
            if case .success(let tasks) = result {
                generatedTasks.append(contentsOf: tasks)
            }
            dispatchGroup.leave()
        }
        
        dispatchGroup.notify(queue: .main) {
            completion(generatedTasks)
        }
    }
    
    // MARK: - Generate Workout Task
    private func generateWorkoutTask(for date: Date, userProfile: UserProfile?, completion: @escaping (Result<AIGeneratedTask, Error>) -> Void) {
        isGenerating = true
        
        // Build prompt for quick workout generation
        var prompt = "Generate a quick workout plan for today. "
        
        if let profile = userProfile {
            if let goal = profile.goal {
                prompt += "Goal: \(goal). "
            }
            if let lifestyle = profile.lifestyle {
                prompt += "Lifestyle: \(lifestyle). "
            }
        }
        
        prompt += "Include 3-4 exercises with sets, reps, rest periods, and estimated calories. Format each as: 'Exercise Name: X sets x Y reps, Z seconds rest, ~W calories'. End with total estimated time."
        
        Task {
            do {
                let messages = [
                    ChatCompletionRequest.Message(role: "system", content: buildSystemPrompt(userProfile: userProfile), name: nil, functionCall: nil),
                    ChatCompletionRequest.Message(role: "user", content: prompt, name: nil, functionCall: nil)
                ]
                
                let response = try await openAIService.sendChatRequest(
                    messages: messages
                )
                
                await MainActor.run {
                    self.isGenerating = false
                    
                    if let content = response.choices.first?.message.content {
                        let task = self.parseWorkoutResponse(content, date: date)
                        completion(.success(task))
                    } else {
                        completion(.failure(NSError(domain: "AITaskGenerator", code: 1, userInfo: [NSLocalizedDescriptionKey: "No response content"])))
                    }
                }
            } catch {
                await MainActor.run {
                    self.isGenerating = false
                    completion(.failure(error))
                }
            }
        }
    }
    
    // MARK: - Generate Nutrition Tasks (3 meals)
    private func generateNutritionTasks(for date: Date, userProfile: UserProfile?, completion: @escaping (Result<[AIGeneratedTask], Error>) -> Void) {
        isGenerating = true
        
        // Build prompt for nutrition plan
        var prompt = "Generate a simple daily meal plan for today with 3 meals (breakfast, lunch, dinner). "
        
        if let profile = userProfile {
            if let goal = profile.goal {
                prompt += "Goal: \(goal). "
            }
            if let lifestyle = profile.lifestyle {
                prompt += "Lifestyle: \(lifestyle). "
            }
        }
        
        prompt += "For each meal, list 2-3 specific food items. I will look up the exact calories using a food database."
        
        Task {
            do {
                let messages = [
                    ChatCompletionRequest.Message(role: "system", content: buildSystemPrompt(userProfile: userProfile), name: nil, functionCall: nil),
                    ChatCompletionRequest.Message(role: "user", content: prompt, name: nil, functionCall: nil)
                ]
                
                let response = try await openAIService.sendChatRequest(
                    messages: messages
                )
                
                await MainActor.run {
                    if let content = response.choices.first?.message.content {
                        // Parse meal plan and fetch calories from OffClient
                        self.parseNutritionResponse(content, date: date, completion: completion)
                    } else {
                        self.isGenerating = false
                        completion(.failure(NSError(domain: "AITaskGenerator", code: 2, userInfo: [NSLocalizedDescriptionKey: "No response content"])))
                    }
                }
            } catch {
                await MainActor.run {
                    self.isGenerating = false
                    completion(.failure(error))
                }
            }
        }
    }
    
    // MARK: - Parse Workout Response
    private func parseWorkoutResponse(_ content: String, date: Date) -> AIGeneratedTask {
        let lines = content.components(separatedBy: .newlines)
        var exercises: [AIExercise] = []
        var theme = "Workout"
        
        // Extract theme
        for line in lines {
            let lowercaseLine = line.lowercased()
            if (lowercaseLine.contains("workout") || lowercaseLine.contains("training")) 
                && !lowercaseLine.contains("what do you think")
                && theme == "Workout" {
                theme = line.trimmingCharacters(in: .whitespacesAndNewlines)
                    .replacingOccurrences(of: ":", with: "")
                break
            }
        }
        
        // Parse exercises
        for line in lines {
            if line.contains("x") || line.contains("×") {
                let exercise = parseExerciseLine(line)
                exercises.append(exercise)
            }
        }
        
        // Calculate totals
        let pureWorkoutTime = exercises.reduce(0) { $0 + $1.durationMin }
        let totalDuration = Int(Double(pureWorkoutTime) * 1.9)
        let totalCalories = exercises.reduce(0) { $0 + $1.calories }
        
        // Adjust exercise durations proportionally
        let adjustedExercises = exercises.map { exercise -> AIExercise in
            var adjusted = exercise
            adjusted.durationMin = Int(Double(exercise.durationMin) * 1.9)
            return adjusted
        }
        
        return AIGeneratedTask(
            type: .workout,
            date: date,
            title: cleanTheme(theme),
            exercises: adjustedExercises,
            meals: [],
            totalDuration: totalDuration,
            totalCalories: totalCalories
        )
    }
    
    // MARK: - Parse Nutrition Response (Returns 3 separate tasks)
    private func parseNutritionResponse(_ content: String, date: Date, completion: @escaping (Result<[AIGeneratedTask], Error>) -> Void) {
        let lines = content.components(separatedBy: .newlines)
        var meals: [AIMeal] = []
        var currentMeal: String?
        var currentFoods: [String] = []
        
        // Parse meal structure
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            
            let lowercased = trimmed.lowercased()
            
            // Check if it's a meal header
            if lowercased.contains("breakfast") {
                if let meal = currentMeal, !currentFoods.isEmpty {
                    meals.append(AIMeal(name: meal, foods: currentFoods, time: getMealTime(meal)))
                }
                currentMeal = "Breakfast"
                currentFoods = []
            } else if lowercased.contains("lunch") {
                if let meal = currentMeal, !currentFoods.isEmpty {
                    meals.append(AIMeal(name: meal, foods: currentFoods, time: getMealTime(meal)))
                }
                currentMeal = "Lunch"
                currentFoods = []
            } else if lowercased.contains("dinner") {
                if let meal = currentMeal, !currentFoods.isEmpty {
                    meals.append(AIMeal(name: meal, foods: currentFoods, time: getMealTime(meal)))
                }
                currentMeal = "Dinner"
                currentFoods = []
            } else if currentMeal != nil {
                // It's a food item
                let cleaned = trimmed
                    .replacingOccurrences(of: "^[•\\-\\d\\.]+\\s*", with: "", options: .regularExpression)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if !cleaned.isEmpty && cleaned.count > 2 {
                    currentFoods.append(cleaned)
                }
            }
        }
        
        // Add last meal
        if let meal = currentMeal, !currentFoods.isEmpty {
            meals.append(AIMeal(name: meal, foods: currentFoods, time: getMealTime(meal)))
        }
        
        // Fetch calories for all foods using OffClient
        fetchCaloriesForMeals(meals) { updatedMeals in
            // Create 3 separate tasks, one for each meal
            var tasks: [AIGeneratedTask] = []
            
            for meal in updatedMeals {
                let task = AIGeneratedTask(
                    type: .nutrition,
                    date: date,
                    title: meal.name, // "Breakfast", "Lunch", "Dinner"
                    exercises: [],
                    meals: [meal],
                    totalDuration: 0,
                    totalCalories: meal.totalCalories
                )
                tasks.append(task)
            }
            
            self.isGenerating = false
            completion(.success(tasks))
        }
    }
    
    // MARK: - Fetch Calories for Meals
    private func fetchCaloriesForMeals(_ meals: [AIMeal], completion: @escaping ([AIMeal]) -> Void) {
        var updatedMeals = meals
        let dispatchGroup = DispatchGroup()
        
        for (mealIndex, meal) in meals.enumerated() {
            var updatedFoodItems: [AIFoodItem] = []
            
            for food in meal.foods {
                dispatchGroup.enter()
                
                // Use OffClient to search for food
                OffClient.searchFoodsCached(query: food, limit: 1) { foodItems in
                    if let firstItem = foodItems.first, let calories = firstItem.calories {
                        updatedFoodItems.append(AIFoodItem(name: food, calories: calories))
                    } else {
                        // Fallback: estimate based on food type
                        let estimatedCalories = self.estimateCalories(for: food)
                        updatedFoodItems.append(AIFoodItem(name: food, calories: estimatedCalories))
                    }
                    dispatchGroup.leave()
                }
            }
            
            dispatchGroup.notify(queue: .main) {
                updatedMeals[mealIndex].foodItems = updatedFoodItems
            }
        }
        
        dispatchGroup.notify(queue: .main) {
            completion(updatedMeals)
        }
    }
    
    // MARK: - Helper Functions
    private func parseExerciseLine(_ line: String) -> AIExercise {
        var exerciseName = ""
        var sets = 3
        var reps = "10"
        var restSec = 60
        var calories = 0
        
        // Extract exercise name
        if line.contains(":") {
            let parts = line.components(separatedBy: ":")
            if let firstPart = parts.first {
                var cleanName = firstPart
                cleanName = cleanName.replacingOccurrences(of: "•", with: "")
                cleanName = cleanName.replacingOccurrences(of: "-", with: "")
                cleanName = cleanName.replacingOccurrences(of: ".", with: "")
                cleanName = cleanName.replacingOccurrences(of: "\\d+\\.", with: "", options: .regularExpression)
                cleanName = cleanName.trimmingCharacters(in: .whitespaces)
                if !cleanName.isEmpty && cleanName.count > 2 {
                    exerciseName = cleanName
                }
            }
        }
        
        if exerciseName.isEmpty {
            exerciseName = line.trimmingCharacters(in: .whitespaces)
        }
        
        // Extract sets
        if let setsRegex = try? NSRegularExpression(pattern: #"(\d+)\s*(?:sets?|x|×)"#, options: .caseInsensitive) {
            let nsString = line as NSString
            if let match = setsRegex.firstMatch(in: line, range: NSRange(location: 0, length: nsString.length)) {
                if let setsRange = Range(match.range(at: 1), in: line) {
                    sets = Int(line[setsRange]) ?? 3
                }
            }
        }
        
        // Extract reps
        if let repsRegex = try? NSRegularExpression(pattern: #"x\s*(\d+(?:-\d+)?)|(\d+(?:-\d+)?)\s*reps?"#, options: .caseInsensitive) {
            let nsString = line as NSString
            if let match = repsRegex.firstMatch(in: line, range: NSRange(location: 0, length: nsString.length)) {
                for i in 1..<match.numberOfRanges {
                    if let repsRange = Range(match.range(at: i), in: line), match.range(at: i).length > 0 {
                        reps = String(line[repsRange])
                        break
                    }
                }
            }
        }
        
        // Extract rest time
        if let restRegex = try? NSRegularExpression(pattern: #"(\d+)\s*(?:seconds?|secs?|s)\s*rest"#, options: .caseInsensitive) {
            let nsString = line as NSString
            if let match = restRegex.firstMatch(in: line, range: NSRange(location: 0, length: nsString.length)) {
                if let restRange = Range(match.range(at: 1), in: line) {
                    restSec = Int(line[restRange]) ?? 60
                }
            }
        }
        
        // Extract calories
        if let caloriesRegex = try? NSRegularExpression(pattern: #"[~]?(\d+)\s*(?:calories|cal)\b"#, options: .caseInsensitive) {
            let nsString = line as NSString
            if let match = caloriesRegex.firstMatch(in: line, range: NSRange(location: 0, length: nsString.length)) {
                if let caloriesRange = Range(match.range(at: 1), in: line) {
                    calories = Int(line[caloriesRange]) ?? 0
                }
            }
        }
        
        // Calculate duration
        let avgReps = extractAvgReps(from: reps)
        let workTimePerSet = avgReps * 4
        let totalDurationSec = sets > 1 ? (workTimePerSet + restSec) * (sets - 1) + workTimePerSet : workTimePerSet
        let durationMin = max(1, totalDurationSec / 60)
        
        // Fallback calories if not provided
        if calories == 0 {
            calories = durationMin * 7
        }
        
        return AIExercise(
            name: exerciseName,
            sets: sets,
            reps: reps,
            restSec: restSec,
            durationMin: durationMin,
            calories: calories
        )
    }
    
    private func extractAvgReps(from repsString: String) -> Int {
        let numbers = repsString.components(separatedBy: CharacterSet.decimalDigits.inverted)
            .compactMap { Int($0) }
        
        if numbers.count >= 2 {
            return (numbers[0] + numbers[1]) / 2
        } else if let first = numbers.first {
            return first
        }
        return 10
    }
    
    private func cleanTheme(_ theme: String) -> String {
        var cleaned = theme
            .replacingOccurrences(of: " Workout", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: " Training", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: " Session", with: "", options: .caseInsensitive)
            .trimmingCharacters(in: .whitespaces)
        
        if cleaned.isEmpty || cleaned.lowercased() == "workout" {
            cleaned = "Fitness"
        } else if cleaned.count > 30 {
            cleaned = String(cleaned.prefix(30))
        }
        
        return cleaned
    }
    
    private func getMealTime(_ mealName: String) -> String {
        switch mealName.lowercased() {
        case "breakfast": return "08:00 AM"
        case "lunch": return "12:00 PM"
        case "dinner": return "06:00 PM"
        default: return "12:00 PM"
        }
    }
    
    private func estimateCalories(for food: String) -> Int {
        let lowercased = food.lowercased()
        
        // Simple estimation based on food type
        if lowercased.contains("salad") || lowercased.contains("vegetable") {
            return 150
        } else if lowercased.contains("chicken") || lowercased.contains("fish") {
            return 250
        } else if lowercased.contains("rice") || lowercased.contains("pasta") {
            return 200
        } else if lowercased.contains("egg") {
            return 80
        } else if lowercased.contains("fruit") || lowercased.contains("apple") || lowercased.contains("banana") {
            return 100
        } else {
            return 200 // Default
        }
    }
    
    private func buildSystemPrompt(userProfile: UserProfile?) -> String {
        var prompt = """
        You are Modo, a fitness and nutrition AI assistant. Generate concise workout and meal plans.
        
        For workouts:
        - Include 3-4 exercises with sets, reps, rest, and calories
        - Format: "Exercise Name: X sets x Y reps, Z seconds rest, ~W calories"
        - Be specific and practical
        
        For meals:
        - List 2-3 specific food items per meal
        - Keep it simple and realistic
        - No need to include calories (I'll look them up)
        
        Use US customary units (lbs, feet/inches).
        """
        
        if let profile = userProfile {
            prompt += "\n\nUser Profile:"
            if let age = profile.age {
                prompt += "\n- Age: \(age) years"
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
}

// MARK: - Data Models

enum TaskType: String {
    case workout = "workout"
    case nutrition = "nutrition"
}

struct AIGeneratedTask {
    let type: TaskType
    let date: Date
    let title: String
    var exercises: [AIExercise]
    var meals: [AIMeal]
    let totalDuration: Int
    let totalCalories: Int
}

struct AIExercise {
    let name: String
    let sets: Int
    let reps: String
    let restSec: Int
    var durationMin: Int
    let calories: Int
}

struct AIMeal {
    let name: String
    let foods: [String]
    let time: String
    var foodItems: [AIFoodItem] = []
    
    var totalCalories: Int {
        foodItems.reduce(0) { $0 + $1.calories }
    }
}

struct AIFoodItem {
    let name: String
    let calories: Int
}

