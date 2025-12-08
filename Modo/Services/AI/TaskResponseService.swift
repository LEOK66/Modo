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
        good job! the task has been added to your schedule.
        you can view and manage this task on the home page.
        good luck with your training!💪
        """
    }
    
    /// Generate rejection message
    /// - Returns: Friendly rejection message
    func generateRejectionMessage() -> String {
        return """
        no problem! let me know what you'd like to adjust.
        would you prefer:
        - different exercises
        - more/less intensity
        - shorter/longer workout
        - just tell me what works better for you!
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

