import Foundation
import SwiftData

/// Service for coordinating AI task generation in MainPageView.
///
/// This service analyzes existing tasks and generates missing tasks using AI.
/// It supports two modes: normal mode (generates only missing tasks) and replace mode
/// (replaces all existing AI tasks with new ones).
class MainPageAIService {
    private let aiTaskGenerator = AITaskGenerator()
    private let taskAnalysisService = TaskAnalysisService.self
    
    /// Generates AI tasks based on existing tasks and generation mode.
    ///
    /// In normal mode, analyzes existing tasks and generates only missing task types
    /// (fitness, breakfast, lunch, dinner). In replace mode, generates all 4 task types
    /// regardless of existing tasks.
    ///
    /// - Parameters:
    ///   - existingTasks: Current tasks for the date
    ///   - selectedDate: Date to generate tasks for
    ///   - userProfile: User profile for personalization
    ///   - replaceMode: Whether to replace existing AI tasks (true) or generate only missing ones (false)
    ///   - onEachTask: Callback called when each task is generated
    ///   - onComplete: Callback called when all tasks are generated
    /// - Returns: Set of task IDs being replaced (for animation purposes). Empty set if no replacement.
    func generateAITasks(
        existingTasks: [TaskItem],
        selectedDate: Date,
        userProfile: UserProfile?,
        replaceMode: Bool,
        onEachTask: @escaping (TaskItem) -> Void,
        onComplete: @escaping () -> Void
    ) -> Set<UUID> {
        print("🎲 MainPageAIService: Smart AI Task Generation for \(selectedDate)")
        
        // Check if there are already AI-generated tasks
        let existingAITasks = existingTasks.filter { $0.isAIGenerated }
        let hasAITasks = !existingAITasks.isEmpty
        
        if hasAITasks {
            // Replace mode: return IDs to be replaced
            print("🔄 MainPageAIService: Replacing existing AI tasks: \(existingAITasks.count) tasks")
            return Set(existingAITasks.map { $0.id })
        }
        
        // Determine what tasks to generate
        let tasksToGenerate: [String]
        if replaceMode {
            // Replace mode: always generate all 4 tasks
            tasksToGenerate = ["fitness", "breakfast", "lunch", "dinner"]
            print("🔄 MainPageAIService: Replace mode: generating all 4 tasks")
        } else {
            // Normal mode: analyze and generate only missing tasks
            let analysis = taskAnalysisService.analyzeExistingTasks(existingTasks)
            tasksToGenerate = analysis.missingTasks
            print("📊 MainPageAIService: Task Analysis:")
            print("   - Fitness: \(analysis.hasFitness ? "✅" : "❌")")
            print("   - Breakfast: \(analysis.hasBreakfast ? "✅" : "❌")")
            print("   - Lunch: \(analysis.hasLunch ? "✅" : "❌")")
            print("   - Dinner: \(analysis.hasDinner ? "✅" : "❌")")
            print("💡 Will generate: \(tasksToGenerate.joined(separator: ", "))")
        }
        
        // If no tasks to generate, just finish
        guard !tasksToGenerate.isEmpty else {
            print("ℹ️ MainPageAIService: No tasks to generate")
            onComplete()
            return []
        }
        
        // Generate tasks one by one
        aiTaskGenerator.generateMissingTasksSequentially(
            missing: tasksToGenerate,
            for: selectedDate,
            userProfile: userProfile,
            isReplacement: replaceMode,
            onEachTask: { aiTask in
                // Create task from AI generated task
                let task = TaskCreationService.createTaskFromAIGenerated(aiTask)
                print("✅ MainPageAIService: Generated and added: \(aiTask.title)")
                onEachTask(task)
            },
            onComplete: {
                print("✅ MainPageAIService: All AI tasks generation completed")
                onComplete()
            }
        )
        
        return []
    }
}

