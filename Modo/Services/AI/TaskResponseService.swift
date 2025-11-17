import Foundation

/// Task Response Service
///
/// Handles user responses to AI-generated tasks (accept/reject)
class TaskResponseService {
    
    // MARK: - Task Response Handling
    
    /// Generate acceptance message
    /// - Returns: Friendly acceptance message
    func generateAcceptanceMessage() -> String {
        return """
        太好了！任务已添加到您的日程中。
        
        您可以在主页查看和管理这个任务。祝您训练顺利！💪
        """
    }
    
    /// Generate rejection message
    /// - Returns: Friendly rejection message
    func generateRejectionMessage() -> String {
        return """
        好的，已取消这个任务。
        
        如果您需要其他类型的任务或有特殊要求，随时告诉我！
        """
    }
    
    /// Post task acceptance notification
    /// - Parameter task: Task to accept
    func postTaskAcceptance(_ task: AIGeneratedTask) {
        NotificationCenter.default.post(
            name: NSNotification.Name("AcceptAITask"),
            object: task
        )
        print("✅ TaskResponseService: Posted task acceptance notification")
    }
    
    /// Post task rejection notification
    /// - Parameter taskId: ID of task to reject
    func postTaskRejection(taskId: UUID) {
        NotificationCenter.default.post(
            name: NSNotification.Name("RejectAITask"),
            object: taskId
        )
        print("❌ TaskResponseService: Posted task rejection notification")
    }
}

