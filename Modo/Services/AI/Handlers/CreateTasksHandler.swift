import Foundation
import FirebaseAuth

/// Create Tasks Handler
///
/// Handles create_tasks function calls from AI
///
/// This handler:
/// 1. Parses task data from AI
/// 2. Converts to TaskItem
/// 3. Creates tasks via TaskManagerService
/// 4. Posts response via AINotificationManager
class CreateTasksHandler: AIFunctionCallHandler {
    var functionName: String { "create_tasks" }
    
    private let taskService: TaskServiceProtocol
    private let notificationManager: AINotificationManager
    
    init(
        taskService: TaskServiceProtocol = ServiceContainer.shared.taskService,
        notificationManager: AINotificationManager = .shared
    ) {
        self.taskService = taskService
        self.notificationManager = notificationManager
    }
    
    func handle(arguments: String, requestId: String) async throws {
        // Get current user ID
        guard let userId = Auth.auth().currentUser?.uid else {
            throw AIFunctionCallError.executionFailed("User not authenticated")
        }
        
        // Parse arguments
        guard let dtos = parseArguments(arguments) else {
            throw AIFunctionCallError.invalidArguments("Failed to parse create_tasks arguments")
        }
        
        print("➕ Creating \(dtos.count) tasks")
        
        // Create tasks using TaskManagerService
        let createdTasks = await createTasks(dtos, userId: userId)
        
        print("✅ Created \(createdTasks.count) tasks")
        
        // Post response
        notificationManager.postResponse(
            type: .taskCreateResponse,
            requestId: requestId,
            success: true,
            data: createdTasks.map { AITaskDTO.from($0) },
            error: nil
        )
    }
    
    // MARK: - Private Methods
    
    private func parseArguments(_ arguments: String) -> [AITaskDTO]? {
        guard let jsonData = arguments.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
              let tasksArray = json["tasks"] as? [[String: Any]] else {
            return nil
        }
        
        var dtos: [AITaskDTO] = []
        
        for taskJson in tasksArray {
            guard let dto = parseTaskFromJson(taskJson) else {
                continue
            }
            dtos.append(dto)
        }
        
        return dtos.isEmpty ? nil : dtos
    }
    
    private func parseTaskFromJson(_ json: [String: Any]) -> AITaskDTO? {
        // Parse required fields
        guard let typeString = json["type"] as? String,
              let type = AITaskDTO.TaskType(rawValue: typeString),
              let title = json["title"] as? String,
              let dateString = json["date"] as? String,
              let date = AIServiceUtils.parseDate(dateString),
              let time = json["time"] as? String,
              let categoryString = json["category"] as? String,
              let category = AITaskDTO.Category(rawValue: categoryString) else {
            return nil
        }
        
        // Parse optional fields
        let subtitle = json["subtitle"] as? String
        
        // Parse exercises
        let exercises = parseExercises(from: json["exercises"])
        
        // Parse meals
        let meals = parseMeals(from: json["meals"])
        
        // Calculate totals
        let totalDuration = exercises?.reduce(0, { $0 + $1.durationMin })
        let totalCalories = exercises?.reduce(0, { $0 + $1.calories }) ?? 
                           meals?.first?.totalCalories ?? 0
        
        return AITaskDTO(
            id: UUID(),
            type: type,
            title: title,
            subtitle: subtitle,
            date: date,
            time: time,
            category: category,
            exercises: exercises,
            totalDuration: totalDuration,
            meals: meals,
            totalCalories: totalCalories,
            isAIGenerated: true,
            isDone: false,
            source: "coach",
            createdAt: Date()
        )
    }
    
    private func parseExercises(from data: Any?) -> [AITaskDTO.Exercise]? {
        guard let exercisesArray = data as? [[String: Any]] else {
            return nil
        }
        
        let exercises = exercisesArray.compactMap { exerciseJson -> AITaskDTO.Exercise? in
            guard let name = exerciseJson["name"] as? String,
                  let sets = exerciseJson["sets"] as? Int,
                  let reps = exerciseJson["reps"] as? String,
                  let restSec = exerciseJson["rest_sec"] as? Int,
                  let durationMin = exerciseJson["duration_min"] as? Int,
                  let calories = exerciseJson["calories"] as? Int else {
                return nil
            }
            
            let targetRPE = exerciseJson["target_RPE"] as? Int
            let alternatives = exerciseJson["alternatives"] as? [String]
            
            return AITaskDTO.Exercise(
                name: name,
                sets: sets,
                reps: reps,
                restSec: restSec,
                durationMin: durationMin,
                calories: calories,
                targetRPE: targetRPE,
                alternatives: alternatives
            )
        }
        
        return exercises.isEmpty ? nil : exercises
    }
    
    private func parseMeals(from data: Any?) -> [AITaskDTO.Meal]? {
        guard let mealsArray = data as? [[String: Any]] else {
            return nil
        }
        
        let meals = mealsArray.compactMap { mealJson -> AITaskDTO.Meal? in
            guard let name = mealJson["name"] as? String,
                  let time = mealJson["time"] as? String,
                  let foodsArray = mealJson["foods"] as? [[String: Any]],
                  let totalCalories = mealJson["total_calories"] as? Int else {
                return nil
            }
            
            let foods = foodsArray.compactMap { foodJson -> AITaskDTO.Food? in
                guard let foodName = foodJson["name"] as? String,
                      let portion = foodJson["portion"] as? String,
                      let calories = foodJson["calories"] as? Int else {
                    return nil
                }
                
                // Parse optional macros
                var macros: AITaskDTO.Macros?
                if let macrosJson = foodJson["macros"] as? [String: Any],
                   let protein = macrosJson["protein"] as? Double,
                   let carbs = macrosJson["carbs"] as? Double,
                   let fat = macrosJson["fat"] as? Double {
                    macros = AITaskDTO.Macros(protein: protein, carbs: carbs, fat: fat)
                }
                
                return AITaskDTO.Food(
                    name: foodName,
                    portion: portion,
                    calories: calories,
                    macros: macros
                )
            }
            
            // Parse meal macros
            var macros: AITaskDTO.Macros?
            if let macrosJson = mealJson["macros"] as? [String: Any],
               let protein = macrosJson["protein"] as? Double,
               let carbs = macrosJson["carbs"] as? Double,
               let fat = macrosJson["fat"] as? Double {
                macros = AITaskDTO.Macros(protein: protein, carbs: carbs, fat: fat)
            }
            
            return AITaskDTO.Meal(
                name: name,
                time: time,
                foods: foods,
                totalCalories: totalCalories,
                macros: macros
            )
        }
        
        return meals.isEmpty ? nil : meals
    }
    
    private func createTasks(_ dtos: [AITaskDTO], userId: String) async -> [TaskItem] {
        var createdTasks: [TaskItem] = []
        
        for dto in dtos {
            let taskItem = dto.toTaskItem()
            
            // Add task using TaskManagerService
            await withCheckedContinuation { continuation in
                taskService.addTask(taskItem, userId: userId) { result in
                    switch result {
                    case .success:
                        createdTasks.append(taskItem)
                        print("✅ Created task: \(taskItem.title)")
                    case .failure(let error):
                        print("❌ Failed to create task: \(error.localizedDescription)")
                    }
                    continuation.resume()
                }
            }
        }
        
        return createdTasks
    }
}

