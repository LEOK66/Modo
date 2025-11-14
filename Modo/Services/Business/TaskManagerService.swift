import Foundation
import FirebaseAuth

/// Service for managing tasks (add, update, delete) with cache and Firebase sync.
///
/// This service coordinates task operations between local cache and Firebase database.
/// It ensures data consistency by updating cache immediately and syncing to Firebase in the background.
class TaskManagerService: TaskServiceProtocol {
    private let cacheService: TaskCacheService
    private let databaseService: DatabaseServiceProtocol
    
    /// Initialize TaskManagerService with dependencies
    /// - Parameters:
    ///   - cacheService: Cache service for local storage (defaults to shared instance)
    ///   - databaseService: Database service for Firebase operations (required)
    init(cacheService: TaskCacheService = TaskCacheService.shared, databaseService: DatabaseServiceProtocol) {
        self.cacheService = cacheService
        self.databaseService = databaseService
    }
    
    /// Adds a task to local cache and Firebase database.
    ///
    /// The task is saved to cache immediately for UI responsiveness, then synced to Firebase
    /// in the background. The completion handler is called when Firebase sync completes.
    ///
    /// - Parameters:
    ///   - task: The task item to add
    ///   - userId: The user ID for Firebase path
    ///   - onComplete: Completion handler called with result of Firebase operation
    func addTask(_ task: TaskItem, userId: String, onComplete: @escaping (Result<Void, Error>) -> Void) {
        print("📝 TaskManagerService: Creating task - Title: \"\(task.title)\", Date: \(task.timeDate), Category: \(task.category), ID: \(task.id)")
        
        // Update cache immediately on the main actor
        Task { @MainActor in
            self.cacheService.saveTask(task, date: task.timeDate, userId: userId)
            print("✅ TaskManagerService: Task saved to local cache")
        }
        
        // Save to Firebase (background sync)
        databaseService.saveTask(userId: userId, task: task, date: task.timeDate) { result in
            switch result {
            case .success:
                print("✅ TaskManagerService: Task saved to Firebase - Title: \"\(task.title)\", ID: \(task.id)")
                onComplete(.success(()))
            case .failure(let error):
                print("❌ TaskManagerService: Failed to save task to Firebase - Title: \"\(task.title)\", Error: \(error.localizedDescription)")
                onComplete(.failure(error))
            }
        }
    }
    
    /// Removes a task from local cache and Firebase database.
    ///
    /// The task is deleted from cache immediately, then removed from Firebase in the background.
    /// The completion handler is called when Firebase deletion completes.
    ///
    /// - Parameters:
    ///   - task: The task item to remove
    ///   - userId: The user ID for Firebase path
    ///   - onComplete: Completion handler called with result of Firebase operation
    func removeTask(_ task: TaskItem, userId: String, onComplete: @escaping (Result<Void, Error>) -> Void) {
        let calendar = Calendar.current
        let dateKey = calendar.startOfDay(for: task.timeDate)
        
        print("🗑️ TaskManagerService: Deleting task - Title: \"\(task.title)\", Date: \(dateKey), ID: \(task.id)")
        
        // Update cache immediately on the main actor
        Task { @MainActor in
            self.cacheService.deleteTask(taskId: task.id, date: dateKey, userId: userId)
            print("✅ TaskManagerService: Task deleted from local cache")
        }
        
        // Delete from Firebase (background sync)
        databaseService.deleteTask(userId: userId, taskId: task.id, date: dateKey) { result in
            switch result {
            case .success:
                print("✅ TaskManagerService: Task deleted from Firebase - Title: \"\(task.title)\", ID: \(task.id)")
                onComplete(.success(()))
            case .failure(let error):
                print("❌ TaskManagerService: Failed to delete task from Firebase - Title: \"\(task.title)\", Error: \(error.localizedDescription)")
                onComplete(.failure(error))
            }
        }
    }
    
    /// Updates a task in local cache and Firebase database.
    ///
    /// Handles date changes by moving the task from old date to new date in both cache and Firebase.
    /// If the date changes, the old task is deleted and a new task is created at the new date.
    ///
    /// - Parameters:
    ///   - newTask: The updated task item
    ///   - oldTask: The original task item (for date comparison)
    ///   - userId: The user ID for Firebase path
    ///   - onComplete: Completion handler called with result of Firebase operation
    func updateTask(_ newTask: TaskItem, oldTask: TaskItem, userId: String, onComplete: @escaping (Result<Void, Error>) -> Void) {
        let calendar = Calendar.current
        let oldDateKey = calendar.startOfDay(for: oldTask.timeDate)
        let newDateKey = calendar.startOfDay(for: newTask.timeDate)
        
        let dateChanged = oldDateKey != newDateKey
        
        print("🔄 TaskManagerService: Updating task - Title: \"\(newTask.title)\", Date: \(newDateKey), ID: \(newTask.id)")
        
        // Update cache on the main actor
        Task { @MainActor in
            if oldDateKey == newDateKey {
                self.cacheService.updateTask(newTask, oldDate: oldDateKey, userId: userId)
            } else {
                self.cacheService.deleteTask(taskId: oldTask.id, date: oldDateKey, userId: userId)
                self.cacheService.saveTask(newTask, date: newDateKey, userId: userId)
            }
        }
        
        // Firebase update
        databaseService.saveTask(userId: userId, task: newTask, date: newDateKey) { result in
            switch result {
            case .success:
                print("✅ TaskManagerService: Task updated in Firebase - Title: \"\(newTask.title)\", ID: \(newTask.id)")
                onComplete(.success(()))
            case .failure(let error):
                print("❌ TaskManagerService: Failed to update task in Firebase - Title: \"\(newTask.title)\", Error: \(error.localizedDescription)")
                onComplete(.failure(error))
            }
        }
        
        // If date changed, delete old task from Firebase
        if dateChanged {
            databaseService.deleteTask(userId: userId, taskId: oldTask.id, date: oldDateKey) { result in
                switch result {
                case .success:
                    print("✅ TaskManagerService: Old task deleted from Firebase (date changed)")
                case .failure(let error):
                    print("❌ TaskManagerService: Failed to delete old task from Firebase - Error: \(error.localizedDescription)")
                }
            }
        }
    }
    
    /// Loads tasks for a specific date from cache or Firebase.
    ///
    /// If the date is within the cache window, tasks are loaded from cache immediately.
    /// Otherwise, tasks are loaded from Firebase and the cache window is updated.
    ///
    /// - Parameters:
    ///   - date: The date to load tasks for
    ///   - userId: The user ID for Firebase path
    ///   - completion: Completion handler called with result containing tasks or error
    func loadTasks(for date: Date, userId: String, completion: @escaping (Result<[TaskItem], Error>) -> Void) {
        let calendar = Calendar.current
        let normalizedDate = calendar.startOfDay(for: date)
        
        // Check if date is in cache window
        let (window, _) = cacheService.getCurrentCacheWindow(centerDate: normalizedDate)
        
        if cacheService.isDateInCacheWindow(normalizedDate, windowMin: window.minDate, windowMax: window.maxDate) {
            // Date is in cache window, load from cache
            let tasks = cacheService.getTasks(for: normalizedDate, userId: userId)
            completion(.success(tasks))
            print("✅ TaskManagerService: Loaded tasks from cache for \(date)")
        } else {
            // Date is outside cache window, load from Firebase and update cache window
            print("📡 TaskManagerService: Date outside cache window, loading from Firebase")
            
            // Update cache window on main actor
            Task { @MainActor in
                self.cacheService.updateCacheWindow(centerDate: normalizedDate, for: userId)
            }
            
            // Load from Firebase
            databaseService.fetchTasksForDate(userId: userId, date: normalizedDate) { result in
                switch result {
                case .success(let tasks):
                    // Update cache (batch save) on main actor
                    Task { @MainActor in
                        self.cacheService.saveTasksForDate(tasks, date: normalizedDate, userId: userId)
                    }
                    completion(.success(tasks))
                    print("✅ TaskManagerService: Loaded \(tasks.count) tasks from Firebase for \(date)")
                case .failure(let error):
                    completion(.failure(error))
                    print("❌ TaskManagerService: Failed to load tasks from Firebase - \(error.localizedDescription)")
                }
            }
        }
    }
}
