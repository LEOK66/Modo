import Foundation
import FirebaseDatabase

/// Protocol defining the database service interface
/// This protocol allows for dependency injection and testing
protocol DatabaseServiceProtocol {
    // MARK: - User Profile Methods
    
    /// Save user profile to Firebase
    /// - Parameters:
    ///   - profile: UserProfile to save
    ///   - completion: Completion handler with result
    func saveUserProfile(_ profile: UserProfile, completion: ((Result<Void, Error>) -> Void)?)
    
    /// Update username for a user
    /// - Parameters:
    ///   - userId: User ID
    ///   - username: New username
    ///   - completion: Completion handler with result
    func updateUsername(userId: String, username: String, completion: ((Result<Void, Error>) -> Void)?)
    
    /// Fetch username for a user
    /// - Parameters:
    ///   - userId: User ID
    ///   - completion: Completion handler with username or error
    func fetchUsername(userId: String, completion: @escaping (Result<String?, Error>) -> Void)
    
    /// Fetch user profile from Firebase
    /// - Parameters:
    ///   - userId: User ID
    ///   - completion: Completion handler with UserProfile or error
    func fetchUserProfile(userId: String, completion: @escaping (Result<UserProfile, Error>) -> Void)
    
    // MARK: - Task Methods
    
    /// Save a task to Firebase
    /// - Parameters:
    ///   - userId: User ID
    ///   - task: Task to save
    ///   - date: Date the task belongs to
    ///   - completion: Completion handler with result
    func saveTask(userId: String, task: TaskItem, date: Date, completion: ((Result<Void, Error>) -> Void)?)
    
    /// Delete a task from Firebase
    /// - Parameters:
    ///   - userId: User ID
    ///   - taskId: Task ID to delete
    ///   - date: Date the task belongs to
    ///   - completion: Completion handler with result
    func deleteTask(userId: String, taskId: UUID, date: Date, completion: ((Result<Void, Error>) -> Void)?)
    
    /// Fetch tasks for a specific date
    /// - Parameters:
    ///   - userId: User ID
    ///   - date: Date to fetch tasks for
    ///   - completion: Completion handler with tasks or error
    func fetchTasksForDate(userId: String, date: Date, completion: @escaping (Result<[TaskItem], Error>) -> Void)
    
    /// Listen to real-time changes for tasks on a specific date
    /// - Parameters:
    ///   - userId: User ID
    ///   - date: Date to listen to
    ///   - callback: Callback with updated tasks
    /// - Returns: Listener handle (store this to stop listening later)
    func listenToTasks(userId: String, date: Date, callback: @escaping ([TaskItem]) -> Void) -> DatabaseHandle?
    
    /// Stop a real-time listener
    /// - Parameter handle: Handle returned from listenToTasks
    func stopListening(handle: DatabaseHandle)
    
    /// Delete all tasks for a user
    /// - Parameters:
    ///   - userId: User ID
    ///   - completion: Completion handler with result
    func deleteAllTasks(userId: String, completion: ((Result<Void, Error>) -> Void)?)
    
    // MARK: - Daily Completion Methods
    
    /// Save daily completion status to Firebase
    /// - Parameters:
    ///   - userId: User ID
    ///   - date: Date to save completion for
    ///   - isCompleted: Whether the day is completed
    ///   - completion: Completion handler with result
    func saveDailyCompletion(userId: String, date: Date, isCompleted: Bool, completion: ((Result<Void, Error>) -> Void)?)
    
    /// Fetch daily completion status from Firebase
    /// - Parameters:
    ///   - userId: User ID
    ///   - date: Date to fetch completion for
    ///   - completion: Completion handler with isCompleted Bool or error
    func fetchDailyCompletion(userId: String, date: Date, completion: @escaping (Result<Bool, Error>) -> Void)
    
    /// Fetch daily completions for a date range from Firebase
    /// - Parameters:
    ///   - userId: User ID
    ///   - startDate: Start date (inclusive)
    ///   - endDate: End date (inclusive)
    ///   - completion: Completion handler with dictionary [Date: Bool] or error
    func fetchDailyCompletions(userId: String, startDate: Date, endDate: Date, completion: @escaping (Result<[Date: Bool], Error>) -> Void)
    
    // MARK: - Daily Challenge Methods
    
    /// Save daily challenge to Firebase
    /// - Parameters:
    ///   - userId: User ID
    ///   - challenge: DailyChallenge to save
    ///   - date: Date the challenge belongs to
    ///   - isCompleted: Whether the challenge is completed
    ///   - isLocked: Whether the challenge is locked
    ///   - completedAt: When the challenge was completed (optional)
    ///   - taskId: Task ID associated with challenge (optional)
    ///   - completion: Completion handler with result
    func saveDailyChallenge(userId: String, challenge: DailyChallenge, date: Date, isCompleted: Bool, isLocked: Bool, completedAt: Date?, taskId: UUID?, completion: ((Result<Void, Error>) -> Void)?)
    
    /// Fetch daily challenge from Firebase
    /// - Parameters:
    ///   - userId: User ID
    ///   - date: Date to fetch challenge for
    ///   - completion: Completion handler with challenge data dictionary or error
    func fetchDailyChallenge(userId: String, date: Date, completion: @escaping (Result<[String: Any]?, Error>) -> Void)
    
    /// Update daily challenge completion status
    /// - Parameters:
    ///   - userId: User ID
    ///   - date: Date of the challenge
    ///   - isCompleted: Whether the challenge is completed
    ///   - isLocked: Whether the challenge is locked
    ///   - completedAt: When the challenge was completed (optional)
    ///   - completion: Completion handler with result
    func updateDailyChallengeCompletion(userId: String, date: Date, isCompleted: Bool, isLocked: Bool, completedAt: Date?, completion: ((Result<Void, Error>) -> Void)?)
    
    /// Update daily challenge task ID
    /// - Parameters:
    ///   - userId: User ID
    ///   - date: Date of the challenge
    ///   - taskId: Task ID to associate with challenge (nil to remove)
    ///   - completion: Completion handler with result
    func updateDailyChallengeTaskId(userId: String, date: Date, taskId: UUID?, completion: ((Result<Void, Error>) -> Void)?)
    
    /// Listen to daily challenge changes in real-time
    /// - Parameters:
    ///   - userId: User ID
    ///   - date: Date to listen to
    ///   - callback: Callback with updated challenge data dictionary
    /// - Returns: Listener handle (store this to stop listening later)
    func listenToDailyChallenge(userId: String, date: Date, callback: @escaping ([String: Any]?) -> Void) -> DatabaseHandle?
}

