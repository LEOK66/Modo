import Foundation

/// Protocol defining the task management service interface
/// This protocol allows for dependency injection and testing
protocol TaskServiceProtocol {
    /// Adds a task to local cache and Firebase database
    /// - Parameters:
    ///   - task: The task item to add
    ///   - userId: The user ID for Firebase path
    ///   - onComplete: Completion handler called with result of Firebase operation
    func addTask(_ task: TaskItem, userId: String, onComplete: @escaping (Result<Void, Error>) -> Void)
    
    /// Removes a task from local cache and Firebase database
    /// - Parameters:
    ///   - task: The task item to remove
    ///   - userId: The user ID for Firebase path
    ///   - onComplete: Completion handler called with result of Firebase operation
    func removeTask(_ task: TaskItem, userId: String, onComplete: @escaping (Result<Void, Error>) -> Void)
    
    /// Updates a task in local cache and Firebase database
    /// - Parameters:
    ///   - newTask: The updated task item
    ///   - oldTask: The original task item (for date comparison)
    ///   - userId: The user ID for Firebase path
    ///   - onComplete: Completion handler called with result of Firebase operation
    func updateTask(_ newTask: TaskItem, oldTask: TaskItem, userId: String, onComplete: @escaping (Result<Void, Error>) -> Void)
    
    /// Loads tasks for a specific date from cache or Firebase
    /// - Parameters:
    ///   - date: The date to load tasks for
    ///   - userId: The user ID for Firebase path
    ///   - completion: Completion handler called with result containing tasks or error
    func loadTasks(for date: Date, userId: String, completion: @escaping (Result<[TaskItem], Error>) -> Void)
}

