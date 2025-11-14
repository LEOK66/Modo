import Foundation

/// Service for analyzing existing tasks to determine what's missing
struct TaskAnalysisService {
    /// Analysis result
    struct TaskAnalysis {
        let hasFitness: Bool
        let hasBreakfast: Bool
        let hasLunch: Bool
        let hasDinner: Bool
        let missingTasks: [String] // ["fitness", "breakfast", "lunch", "dinner"]
    }
    
    /// Analyze existing tasks to determine what's missing
    static func analyzeExistingTasks(_ tasks: [TaskItem]) -> TaskAnalysis {
        print("🔍 Analyzing \(tasks.count) existing tasks:")
        for (index, task) in tasks.enumerated() {
            let categoryStr = task.category == .fitness ? "fitness" : task.category == .diet ? "diet" : "others"
            print("   \(index + 1). [\(categoryStr)] \(task.title) at \(task.time)")
        }
        
        let hasFitness = tasks.contains { $0.category == .fitness }
        
        // Check for meals by time or keywords
        let hasBreakfast = tasks.contains { task in
            task.category == .diet && (
                (task.time.contains("AM") && !task.time.contains("12:")) ||
                task.title.lowercased().contains("breakfast")
            )
        }
        
        let hasLunch = tasks.contains { task in
            task.category == .diet && (
                (task.time.contains("12:") || task.time.contains("01:") || task.time.contains("02:")) ||
                task.title.lowercased().contains("lunch")
            )
        }
        
        let hasDinner = tasks.contains { task in
            task.category == .diet && (
                (task.time.contains("PM") && !task.time.contains("12:") && !task.time.contains("01:") && !task.time.contains("02:")) ||
                task.title.lowercased().contains("dinner")
            )
        }
        
        // Build list of missing tasks
        var missingTasks: [String] = []
        if !hasFitness {
            missingTasks.append("fitness")
        }
        if !hasBreakfast {
            missingTasks.append("breakfast")
        }
        if !hasLunch {
            missingTasks.append("lunch")
        }
        if !hasDinner {
            missingTasks.append("dinner")
        }
        
        // If all tasks are present, add a snack as bonus
        if missingTasks.isEmpty {
            missingTasks.append("snack")
        }
        
        return TaskAnalysis(
            hasFitness: hasFitness,
            hasBreakfast: hasBreakfast,
            hasLunch: hasLunch,
            hasDinner: hasDinner,
            missingTasks: missingTasks
        )
    }
}

