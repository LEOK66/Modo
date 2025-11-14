import Foundation
import NotificationCenter

/// Service for setting up notification observers in MainPageView.
///
/// This service manages NotificationCenter observers for task creation notifications.
/// It handles daily challenge tasks and workout/nutrition tasks created from AI.
/// Observers are automatically removed to prevent duplicates and memory leaks.
class NotificationSetupService {
    private var dailyChallengeObserver: NSObjectProtocol?
    private var workoutTaskObserver: NSObjectProtocol?
    
    /// Sets up notification observer for daily challenge task creation.
    ///
    /// Listens for "AddDailyChallengeTask" notifications and creates a task when received.
    /// Removes any existing observer first to prevent duplicates.
    ///
    /// - Parameter onTaskCreated: Callback called when a task is created from notification (on main queue)
    func setupDailyChallengeNotification(onTaskCreated: @escaping (TaskItem) -> Void) {
        print("🔔 NotificationSetupService: Setting up daily challenge notification observer")
        
        // Remove existing observer first to prevent duplicates
        if let existingObserver = dailyChallengeObserver {
            print("   🗑️ Removing existing daily challenge observer")
            NotificationCenter.default.removeObserver(existingObserver)
            dailyChallengeObserver = nil
        }
        
        dailyChallengeObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("AddDailyChallengeTask"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            print("📬 NotificationSetupService: Received daily challenge notification")
            
            guard let userInfo = notification.userInfo,
                  let taskIdString = userInfo["taskId"] as? String,
                  let taskId = UUID(uuidString: taskIdString) else {
                print("⚠️ NotificationSetupService: Invalid daily challenge notification data")
                return
            }
            
            // Use NotificationTaskService to create task
            if let task = NotificationTaskService.createTaskFromDailyChallengeNotification(
                userInfo: userInfo,
                taskId: taskId
            ) {
                print("✅ NotificationSetupService: Daily challenge task created - \(task.title) (\(task.meta))")
                onTaskCreated(task)
            }
        }
    }
    
    /// Sets up notification observer for workout/nutrition task creation from AI.
    ///
    /// Listens for "CreateWorkoutTask" notifications and creates a task when received.
    /// Removes any existing observer first to prevent duplicates.
    ///
    /// - Parameter onTaskCreated: Callback called when a task is created from notification (on main queue)
    func setupWorkoutTaskNotification(onTaskCreated: @escaping (TaskItem) -> Void) {
        print("🔔 NotificationSetupService: Setting up workout task notification observer")
        
        // Remove existing observer first to prevent duplicates
        if let existingObserver = workoutTaskObserver {
            print("   🗑️ Removing existing observer")
            NotificationCenter.default.removeObserver(existingObserver)
            workoutTaskObserver = nil
        }
        
        // Add new observer and store the token
        workoutTaskObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("CreateWorkoutTask"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            print("📬 NotificationSetupService: Received workout/nutrition notification")
            
            guard let userInfo = notification.userInfo,
                  let dateString = userInfo["date"] as? String else {
                print("⚠️ NotificationSetupService: Missing required userInfo data")
                return
            }
            
            // Use NotificationTaskService to create task
            if let task = NotificationTaskService.createTaskFromWorkoutNotification(
                userInfo: userInfo,
                dateString: dateString
            ) {
                let taskType = task.category == .diet ? "Nutrition" : "Workout"
                print("✅ NotificationSetupService: \(taskType) task created - \(task.title) at \(task.time)")
                onTaskCreated(task)
            }
        }
    }
    
    /// Removes all notification observers.
    ///
    /// Should be called when the view disappears to prevent memory leaks.
    /// This method removes both daily challenge and workout task observers.
    func removeAllObservers() {
        if let observer = dailyChallengeObserver {
            print("🔕 NotificationSetupService: Removing daily challenge notification observer")
            NotificationCenter.default.removeObserver(observer)
            dailyChallengeObserver = nil
        }
        
        if let observer = workoutTaskObserver {
            print("🔕 NotificationSetupService: Removing workout task notification observer")
            NotificationCenter.default.removeObserver(observer)
            workoutTaskObserver = nil
        }
    }
}

