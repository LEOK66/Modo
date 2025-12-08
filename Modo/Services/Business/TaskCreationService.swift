import Foundation

/// Service for creating TaskItem from AIGeneratedTask
struct TaskCreationService {
    /// Create TaskItem from AI Generated Task
    static func createTaskFromAIGenerated(_ aiTask: AIGeneratedTask) -> TaskItem {
        let task: TaskItem
        
        switch aiTask.type {
        case .workout:
            // Create workout task
            let exerciseNames = aiTask.exercises.map { $0.name }
            let subtitle = exerciseNames.prefix(3).joined(separator: ", ") + (exerciseNames.count > 3 ? "..." : "")
            
            // Create more detailed description
            let description = """
            Total Duration: \(aiTask.totalDuration) min
            Exercises: \(aiTask.exercises.count)
            Estimated Calories: \(aiTask.totalCalories) cal
            
            Workout Details:
            """ + "\n" + aiTask.exercises.map { exercise in
                "• \(exercise.name): \(exercise.sets) sets × \(exercise.reps) reps, \(exercise.restSec)s rest (~\(exercise.calories) cal)"
            }.joined(separator: "\n")
            
            let fitnessEntries = aiTask.exercises.map { exercise in
                FitnessEntry(
                    exercise: nil,
                    customName: exercise.name,
                    minutesInt: exercise.durationMin,
                    caloriesText: String(exercise.calories),
                    sets: exercise.sets,
                    reps: exercise.reps,
                    restSec: exercise.restSec
                )
            }
            
            // Use random time for AI tasks (morning workout)
            let startTime = "09:00 AM"
            let calendar = Calendar.current
            let startDate = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: aiTask.date) ?? aiTask.date
            let endDate = calendar.date(byAdding: .minute, value: aiTask.totalDuration, to: startDate) ?? startDate
            let timeFormatter = DateFormatter()
            timeFormatter.dateFormat = "hh:mm a"
            let endTime = timeFormatter.string(from: endDate)
            
            task = TaskItem(
                title: aiTask.title,
                subtitle: subtitle,
                time: startTime,
                timeDate: startDate,
                endTime: endTime,
                meta: "\(aiTask.totalDuration) min • \(aiTask.exercises.count) exercises • -\(aiTask.totalCalories) cal",
                isDone: false,
                emphasisHex: "8B5CF6",
                category: .fitness,
                dietEntries: [],
                fitnessEntries: fitnessEntries,
                isAIGenerated: true
            )
            
            print("✅ Created AI workout task: \(task.title)")
            
        case .nutrition:
            // Create nutrition task for single meal
            let meal = aiTask.meals.first!
            let foodNames = meal.foodItems.map { $0.name }
            let subtitle = foodNames.prefix(3).joined(separator: ", ") + (foodNames.count > 3 ? "..." : "")
            
            // Create more detailed description
            let description = """
            Meal: \(meal.name)
            Total Calories: \(aiTask.totalCalories) kcal
            Items: \(meal.foodItems.count)
            
            Food Items:
            """ + "\n" + meal.foodItems.map { "• \($0.name) (~\($0.calories) cal)" }.joined(separator: "\n")
            
            let dietEntries = meal.foodItems.map { foodItem in
                // Create as custom food item
                DietEntry(
                    food: nil,
                    customName: foodItem.name,
                    caloriesText: String(foodItem.calories)
                )
            }
            
            // Use meal time
            let startTime = meal.time
            let calendar = Calendar.current
            let timeFormatter = DateFormatter()
            timeFormatter.dateFormat = "hh:mm a"
            let startDate = timeFormatter.date(from: startTime).flatMap { parsedTime in
                let components = calendar.dateComponents([.hour, .minute], from: parsedTime)
                return calendar.date(bySettingHour: components.hour ?? 8, minute: components.minute ?? 0, second: 0, of: aiTask.date)
            } ?? aiTask.date
            
            task = TaskItem(
                title: aiTask.title,
                subtitle: subtitle,
                time: startTime,
                timeDate: startDate,
                endTime: nil,
                meta: "\(aiTask.totalCalories)kcal",
                isDone: false,
                emphasisHex: "10B981",
                category: .diet,
                dietEntries: dietEntries,
                fitnessEntries: [],
                isAIGenerated: true
            )
            
            print("✅ Created AI nutrition task: \(task.title)")
        }
        
        return task
    }
}

