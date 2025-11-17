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
        
        // Post response
        notificationManager.postResponse(
            type: .taskUpdateResponse,
            requestId: requestId,
            success: true,
            data: AITaskDTO.from(updatedTask),
            error: nil
        )
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
        
        let updates = TaskUpdateParams(
            title: title,
            time: time,
            date: nil,
            isDone: isDone,
            exercises: nil,
            meals: nil
        )
        
        return (taskId, updates)
    }
    
    private func updateTask(taskId: UUID, updates: TaskUpdateParams, userId: String) async -> TaskItem? {
        // Find the task in cache
        let taskDate = Date() // We'll search recent dates
        var foundTask: TaskItem?
        
        // Search last 30 days
        for dayOffset in -30...30 {
            guard let searchDate = Calendar.current.date(byAdding: .day, value: dayOffset, to: taskDate) else {
                continue
            }
            let tasks = cacheService.getTasks(for: searchDate, userId: userId)
            if let task = tasks.first(where: { $0.id == taskId }) {
                foundTask = task
                break
            }
        }
        
        guard let oldTask = foundTask else {
            print("❌ Task not found: \(taskId)")
            return nil
        }
        
        print("📋 Found task: \(oldTask.title)")
        
        // Create new task with updates (TaskItem properties are immutable)
        let newTitle = updates.title ?? oldTask.title
        let newTime = updates.time ?? oldTask.time
        let newIsDone = updates.isDone ?? oldTask.isDone
        
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
            dietEntries: oldTask.dietEntries,
            fitnessEntries: oldTask.fitnessEntries,
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
                    print("✅ Task updated successfully")
                    continuation.resume(returning: updatedTask)
                case .failure(let error):
                    print("❌ Failed to update task: \(error.localizedDescription)")
                    continuation.resume(returning: nil)
                }
            }
        }
    }
}

