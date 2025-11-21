import Foundation

/// AI Task Data Transfer Object
///
/// Unified data format for all AI services (ModoCoachService, AITaskGenerator, AddTaskAIService)
///
/// Naming conventions:
/// - Boolean properties use `is` prefix
/// - Methods start with verbs
/// - Nested types use clear names
struct AITaskDTO: Codable, Identifiable {
    // MARK: - Properties
    
    let id: UUID
    let type: TaskType
    let title: String
    let subtitle: String?
    let date: Date
    let time: String
    let category: Category
    
    // Fitness specific
    var exercises: [Exercise]?
    var totalDuration: Int? // minutes
    
    // Nutrition specific
    var meals: [Meal]?
    var totalCalories: Int?
    
    // Metadata
    var isAIGenerated: Bool
    var isDone: Bool
    var source: String? // "coach", "main_page", "add_task"
    var createdAt: Date
    
    // MARK: - Nested Types
    
    enum TaskType: String, Codable {
        case workout
        case nutrition
        case custom
    }
    
    enum Category: String, Codable {
        case fitness
        case diet
        case others
    }
    
    struct Exercise: Codable {
        let name: String
        let sets: Int
        let reps: String
        let restSec: Int
        let durationMin: Int
        let calories: Int
    }
    
    struct Meal: Codable {
        let name: String
        let time: String
        let foods: [Food]
        let totalCalories: Int
        let macros: Macros?
    }
    
    struct Food: Codable {
        let name: String
        let portion: String
        let calories: Int
        let macros: Macros?
    }
    
    struct Macros: Codable {
        let protein: Double
        let carbs: Double
        let fat: Double
    }
}

// MARK: - Conversion Extensions

extension AITaskDTO {
    /// Create DTO from TaskItem
    /// - Parameter taskItem: Source TaskItem
    /// - Returns: AITaskDTO instance
    static func from(_ taskItem: TaskItem) -> AITaskDTO {
        let type: TaskType = taskItem.category == .fitness ? .workout : 
                             taskItem.category == .diet ? .nutrition : .custom
        
        // Convert fitness entries to exercises
        let exercises: [Exercise]? = taskItem.fitnessEntries.isEmpty ? nil : taskItem.fitnessEntries.compactMap { entry in
            // Only include entries that have at least sets and reps defined
            guard let sets = entry.sets, let reps = entry.reps else {
                return nil
            }
            
            return Exercise(
                name: entry.customName.isEmpty ? (entry.exercise?.name ?? "Exercise") : entry.customName,
                sets: sets,
                reps: reps,
                restSec: entry.restSec ?? 60, // Rest has a reasonable default
                durationMin: entry.minutesInt,
                calories: Int(entry.caloriesText) ?? 0
            )
        }
        
        // Convert diet entries to meals
        let meals: [Meal]? = taskItem.dietEntries.isEmpty ? nil : [
            Meal(
                name: taskItem.title,
                time: taskItem.time,
                foods: taskItem.dietEntries.map { entry in
                    let foodName = entry.customName.isEmpty ? (entry.food?.name ?? "Food") : entry.customName
                    let portion = entry.quantityText.isEmpty ? "1 \(entry.unit)" : "\(entry.quantityText) \(entry.unit)"
                    return Food(
                        name: foodName,
                        portion: portion,
                        calories: Int(entry.caloriesText) ?? 0,
                        macros: nil
                    )
                },
                totalCalories: taskItem.dietEntries.reduce(0) { $0 + (Int($1.caloriesText) ?? 0) },
                macros: nil
            )
        ]
        
        // Map TaskCategory to AITaskDTO.Category
        let dtoCategory: Category
        switch taskItem.category {
        case .fitness:
            dtoCategory = .fitness
        case .diet:
            dtoCategory = .diet
        case .others:
            dtoCategory = .others
        }
        
        return AITaskDTO(
            id: taskItem.id,
            type: type,
            title: taskItem.title,
            subtitle: taskItem.subtitle.isEmpty ? nil : taskItem.subtitle,
            date: taskItem.timeDate,
            time: taskItem.time,
            category: dtoCategory,
            exercises: exercises,
            totalDuration: exercises?.reduce(0, { $0 + $1.durationMin }),
            meals: meals,
            totalCalories: meals?.first?.totalCalories,
            isAIGenerated: taskItem.isAIGenerated,
            isDone: taskItem.isDone,
            source: nil,
            createdAt: taskItem.createdAt
        )
    }
    
    /// Convert to TaskItem
    /// - Returns: TaskItem instance
    func toTaskItem() -> TaskItem {
        let taskCategory: TaskCategory
        switch category {
        case .fitness:
            taskCategory = .fitness
        case .diet:
            taskCategory = .diet
        case .others:
            taskCategory = .others
        }
        
        // Convert meals to diet entries
        let dietEntries: [DietEntry] = meals?.flatMap { meal in
            meal.foods.map { food in
                DietEntry(
                    customName: food.name,
                    quantityText: food.portion,
                    unit: "serving",
                    caloriesText: String(food.calories)
                )
            }
        } ?? []
        
        // Convert exercises to fitness entries
        let fitnessEntries: [FitnessEntry] = exercises?.map { exercise in
            FitnessEntry(
                customName: exercise.name,
                minutesInt: exercise.durationMin,
                caloriesText: String(exercise.calories),
                sets: exercise.sets, // ✅ Preserve training parameters
                reps: exercise.reps,
                restSec: exercise.restSec
            )
        } ?? []
        
        let emphasisColor = AIServiceUtils.getCategoryColor(for: category.rawValue)
        
        return TaskItem(
            id: id,
            title: title,
            subtitle: subtitle ?? "",
            time: time,
            timeDate: date,
            endTime: nil,
            meta: "",
            isDone: isDone,
            emphasisHex: emphasisColor,
            category: taskCategory,
            dietEntries: dietEntries,
            fitnessEntries: fitnessEntries,
            createdAt: createdAt,
            updatedAt: Date(),
            isAIGenerated: isAIGenerated,
            isDailyChallenge: false
        )
    }
    
    /// Create DTO from AIGeneratedTask
    /// - Parameters:
    ///   - aiTask: Source AIGeneratedTask (from AITaskGenerator)
    ///   - source: Source identifier
    /// - Returns: AITaskDTO instance
    static func fromAIGeneratedTask(_ aiTask: AIGeneratedTask, source: String = "main_page") -> AITaskDTO {
        let exercises: [Exercise]? = aiTask.exercises.isEmpty ? nil : aiTask.exercises.map { ex in
            Exercise(
                name: ex.name,
                sets: ex.sets,
                reps: ex.reps,
                restSec: ex.restSec,
                durationMin: ex.durationMin,
                calories: ex.calories
            )
        }
        
        let meals: [Meal]? = aiTask.meals.isEmpty ? nil : aiTask.meals.map { meal in
            Meal(
                name: meal.name,
                time: meal.time,
                foods: meal.foodItems.map { food in
                    Food(
                        name: food.name,
                        portion: "1 serving",
                        calories: food.calories,
                        macros: nil
                    )
                },
                totalCalories: meal.totalCalories,
                macros: nil
            )
        }
        
        let category: Category = aiTask.type == .workout ? .fitness : .diet
        
        return AITaskDTO(
            id: UUID(),
            type: aiTask.type == .workout ? .workout : .nutrition,
            title: aiTask.title,
            subtitle: nil,
            date: aiTask.date,
            time: meals?.first?.time ?? "9:00 AM",
            category: category,
            exercises: exercises,
            totalDuration: aiTask.totalDuration,
            meals: meals,
            totalCalories: aiTask.totalCalories,
            isAIGenerated: true,
            isDone: false,
            source: source,
            createdAt: Date()
        )
    }
}

// MARK: - Query & Update Parameters

/// Task query parameters
struct TaskQueryParams: Codable {
    let date: Date
    let dateRange: Int? // Number of days to query (1-7)
    let category: AITaskDTO.Category?
    let isDone: Bool?
}

/// Task update parameters
struct TaskUpdateParams: Codable {
    var title: String?
    var time: String?
    var date: Date?
    var isDone: Bool?
    var exercises: [AITaskDTO.Exercise]?
    var meals: [AITaskDTO.Meal]?
}

/// Batch operation
struct TaskBatchOperation: Codable {
    enum OperationType: String, Codable {
        case create
        case update
        case delete
    }
    
    let type: OperationType
    let taskId: UUID?
    let taskData: AITaskDTO?
    let updateParams: TaskUpdateParams?
}
