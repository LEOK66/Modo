import Foundation
import FirebaseAuth

/// Delete Task Handler
///
/// Handles delete_task function calls from AI
///
/// This handler:
/// 1. Parses task ID from AI
/// 2. Finds the task in TaskCacheService
/// 3. Deletes the task using TaskManagerService
/// 4. Posts delete response via AINotificationManager
class DeleteTaskHandler: AIFunctionCallHandler {
    var functionName: String { "delete_task" }
    
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
        guard let (taskId, reason) = parseArguments(arguments) else {
            throw AIFunctionCallError.invalidArguments("Failed to parse delete_task arguments")
        }
        
        print("🗑️  Deleting task: \(taskId)")
        if let reason = reason {
            print("  Reason: \(reason)")
        }
        
        // Delete task
        let success = await deleteTask(taskId: taskId, userId: userId)
        
        guard success else {
            throw AIFunctionCallError.executionFailed("Task not found or deletion failed: \(taskId)")
        }
        
        print("✅ Task deleted successfully")
        
        // Post response with Bool indicating success
        notificationManager.postResponse(
            type: .taskDeleteResponse,
            requestId: requestId,
            success: true,
            data: true,
            error: nil
        )
    }
    
    // MARK: - Private Methods
    
    private func parseArguments(_ arguments: String) -> (UUID, String?)? {
        guard let jsonData = arguments.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
              let taskIdString = json["task_id"] as? String,
              let taskId = UUID(uuidString: taskIdString) else {
            return nil
        }
        
        let reason = json["reason"] as? String
        
        return (taskId, reason)
    }
    
    private func deleteTask(taskId: UUID, userId: String) async -> Bool {
        // Find the task in cache
        let taskDate = Date()
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
        
        guard let task = foundTask else {
            print("❌ Task not found: \(taskId)")
            return false
        }
        
        print("📋 Found task: \(task.title)")
        
        // Delete the task
        return await withCheckedContinuation { continuation in
            taskService.removeTask(task, userId: userId) { result in
                switch result {
                case .success:
                    print("✅ Task deleted successfully")
                    continuation.resume(returning: true)
                case .failure(let error):
                    print("❌ Failed to delete task: \(error.localizedDescription)")
                    continuation.resume(returning: false)
                }
            }
        }
    }
}

