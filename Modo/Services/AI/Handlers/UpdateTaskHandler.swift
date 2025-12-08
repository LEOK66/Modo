import Foundation
import FirebaseAuth

/// Update Task Handler
///
/// Handles update_task function calls from AI
///
/// This handler:
/// 1. Parses task ID and updates from AI
/// 2. Finds the task in TaskCacheService
/// 3. Applies updates and saves via TaskManagerService
/// 4. Posts update response via AINotificationManager
class UpdateTaskHandler: AIFunctionCallHandler {
    var functionName: String { "update_task" }
    
    private let taskService: TaskServiceProtocol
    private let cacheService: TaskCacheService
    private let notificationManager: AINotificationManager
    
    init(
        taskService: TaskServiceProtocol = ServiceContainer.shared.taskService,
        cacheService: TaskCacheService = TaskCacheService.shared,
        notificationManager: AINotificationManager = .shared
    ) {
        self.taskService = taskService
        self.cacheService = cacheService
        self.notificationManager = notificationManager
    }
    
    func handle(arguments: String, requestId: String) async throws {
        // Get current user ID
        guard let userId = Auth.auth().currentUser?.uid else {
            throw AIFunctionCallError.executionFailed("User not authenticated")
        }
        
        // Parse arguments
        guard let (taskId, updates) = parseArguments(arguments) else {
            throw AIFunctionCallError.invalidArguments("Failed to parse update_task arguments")
        }
        
        print("📝 Updating task: \(taskId)")
        
        // Update task
        guard let updatedTask = await updateTask(taskId: taskId, updates: updates, userId: userId) else {
            throw AIFunctionCallError.executionFailed("Task not found: \(taskId)")
        }
        
        print("✅ Task updated successfully")
        print("   Updated task: \(updatedTask.title)")
        print("   Task ID: \(updatedTask.id)")
        print("   Time: \(updatedTask.time)")
        print("   Done: \(updatedTask.isDone)")
        
        // Post response with detailed info
        let dto = AITaskDTO.from(updatedTask)
        notificationManager.postResponse<AITaskDTO>(
            type: .taskUpdateResponse,
            requestId: requestId,
            success: true,
            data: dto,
            error: nil
        )
        
        print("📤 Posted update response for task: \(dto.title)")
    }
    
    // MARK: - Private Methods
    
    private func parseArguments(_ arguments: String) -> (UUID, TaskUpdateParams)? {
        guard let jsonData = arguments.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
              let taskIdString = json["task_id"] as? String,
              let taskId = UUID(uuidString: taskIdString),
              let updatesJson = json["updates"] as? [String: Any] else {
            return nil
        }
        
        // Parse updates
        let title = updatesJson["title"] as? String
        let time = updatesJson["time"] as? String
        let isDone = updatesJson["is_done"] as? Bool
        
        // Parse exercises
        var exercises: [AITaskDTO.Exercise]? = nil
        if let exercisesArray = updatesJson["exercises"] as? [[String: Any]] {
            exercises = exercisesArray.compactMap { exerciseJson -> AITaskDTO.Exercise? in
                guard let name = exerciseJson["name"] as? String,
                      let sets = exerciseJson["sets"] as? Int,
                      let reps = exerciseJson["reps"] as? String,
                      let restSec = exerciseJson["rest_sec"] as? Int,
                      let durationMin = exerciseJson["duration_min"] as? Int,
                      let calories = exerciseJson["calories"] as? Int else {
                    return nil
                }
                
                return AITaskDTO.Exercise(
                    name: name,
                    sets: sets,
                    reps: reps,
                    restSec: restSec,
                    durationMin: durationMin,
                    calories: calories
                )
            }
        }
        
        // Parse foods (as a meal)
        var meals: [AITaskDTO.Meal]? = nil
        if let foodsArray = updatesJson["foods"] as? [[String: Any]] {
            let foods = foodsArray.compactMap { foodJson -> AITaskDTO.Food? in
                guard let name = foodJson["name"] as? String,
                      let portion = foodJson["portion"] as? String,
                      let calories = foodJson["calories"] as? Int else {
                    return nil
                }
                return AITaskDTO.Food(name: name, portion: portion, calories: calories, macros: nil)
            }
            
            if !foods.isEmpty {
                let totalCalories = foods.reduce(0) { $0 + $1.calories }
                meals = [AITaskDTO.Meal(
                    name: title ?? "Meal",
                    time: time ?? "12:00 PM",
                    foods: foods,
                    totalCalories: totalCalories,
                    macros: nil
                )]
            }
        }
        
        let updates = TaskUpdateParams(
            title: title,
            time: time,
            date: nil,
            isDone: isDone,
            exercises: exercises,
            meals: meals
        )
        
        return (taskId, updates)
    }
    
    private func updateTask(taskId: UUID, updates: TaskUpdateParams, userId: String) async -> TaskItem? {
        // Find the task in cache
        let taskDate = Date() // We'll search recent dates
        var foundTask: TaskItem?
        
        print("🔍 Searching for task \(taskId) in cache...")
        
        // Search last 30 days and next 30 days (total 61 days)
        for dayOffset in -30...30 {
            guard let searchDate = Calendar.current.date(byAdding: .day, value: dayOffset, to: taskDate) else {
                continue
            }
            let tasks = cacheService.getTasks(for: searchDate, userId: userId)
            
            if !tasks.isEmpty && dayOffset % 10 == 0 {
                print("   - Checked \(searchDate): \(tasks.count) tasks")
            }
            
            if let task = tasks.first(where: { $0.id == taskId }) {
                foundTask = task
                print("✅ Found task on \(searchDate): \(task.title)")
                break
            }
        }
        
        guard let oldTask = foundTask else {
            print("❌ Task not found in cache: \(taskId)")
            print("   Try checking if task is loaded in TaskListViewModel")
            return nil
        }
        
        print("📋 Found task: \(oldTask.title)")
        
        // Create new task with updates (TaskItem properties are immutable)
        let newTitle = updates.title ?? oldTask.title
        let newTime = updates.time ?? oldTask.time
        let newIsDone = updates.isDone ?? oldTask.isDone
        
        // Convert exercises to fitness entries if provided
        var newFitnessEntries = oldTask.fitnessEntries
        if let exercises = updates.exercises {
            newFitnessEntries = exercises.map { exercise in
                FitnessEntry(
                    customName: exercise.name,
                    minutesInt: exercise.durationMin,
                    caloriesText: String(exercise.calories),
                    sets: exercise.sets,
                    reps: exercise.reps,
                    restSec: exercise.restSec
                )
            }
            print("  - Exercises updated: \(exercises.count) exercises")
        }
        
        // Convert meals to diet entries if provided
        var newDietEntries = oldTask.dietEntries
        if let meals = updates.meals {
            newDietEntries = meals.flatMap { meal in
                meal.foods.map { food in
                    DietEntry(
                        customName: food.name,
                        quantityText: food.portion,
                        unit: "serving",
                        caloriesText: String(food.calories)
                    )
                }
            }
            print("  - Foods updated: \(newDietEntries.count) food items")
        }
        
        // Log updates
        if updates.title != nil {
            print("  - Title updated: \(newTitle)")
        }
        if updates.time != nil {
            print("  - Time updated: \(newTime)")
        }
        if updates.isDone != nil {
            print("  - Done status updated: \(newIsDone)")
        }
        
        // Create updated task
        let updatedTask = TaskItem(
            id: oldTask.id,
            title: newTitle,
            subtitle: oldTask.subtitle,
            time: newTime,
            timeDate: oldTask.timeDate,
            endTime: oldTask.endTime,
            meta: oldTask.meta,
            isDone: newIsDone,
            emphasisHex: oldTask.emphasisHex,
            category: oldTask.category,
            dietEntries: newDietEntries,
            fitnessEntries: newFitnessEntries,
            createdAt: oldTask.createdAt,
            updatedAt: Date(),
            isAIGenerated: oldTask.isAIGenerated,
            isDailyChallenge: oldTask.isDailyChallenge
        )
        
        // Save the updated task
        return await withCheckedContinuation { continuation in
            taskService.updateTask(updatedTask, oldTask: oldTask, userId: userId) { result in
                switch result {
                case .success:
                    print("✅ Task updated in Firebase successfully")
                    
                    // Force cache update on main thread
                    Task { @MainActor in
                        self.cacheService.updateTask(
                            updatedTask,
                            oldDate: Calendar.current.startOfDay(for: oldTask.timeDate),
                            userId: userId
                        )
                        print("✅ Task cache updated")
                    }
                    
                    continuation.resume(returning: updatedTask)
                case .failure(let error):
                    print("❌ Failed to update task: \(error.localizedDescription)")
                    continuation.resume(returning: nil)
                }
            }
        }
    }
}
