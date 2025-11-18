import Foundation
import SwiftData
import FirebaseDatabase

/// Repository for managing TaskItem data
/// Coordinates between SwiftData (future), Firebase (cloud), and UserDefaults cache (temporary)
/// 
/// Note: Currently TaskItem is stored in Firebase and cached in UserDefaults.
/// Future migration: Store TaskItem in SwiftData as primary source, sync to Firebase.
final class TaskRepository: RepositoryProtocol {
    let modelContext: ModelContext
    let databaseService: DatabaseServiceProtocol
    private let cacheService: TaskCacheService
    
    /// Initialize TaskRepository
    /// - Parameters:
    ///   - modelContext: SwiftData model context for local operations (future use)
    ///   - databaseService: Database service for Firebase operations
    ///   - cacheService: Cache service for UserDefaults operations (temporary)
    init(modelContext: ModelContext, databaseService: DatabaseServiceProtocol, cacheService: TaskCacheService = TaskCacheService.shared) {
        self.modelContext = modelContext
        self.databaseService = databaseService
        self.cacheService = cacheService
    }
    
    // MARK: - Cache Operations (UserDefaults - Temporary)
    
    /// Fetch tasks from cache for a specific date
    /// - Parameters:
    ///   - userId: User ID
    ///   - date: Date to fetch tasks for
    /// - Returns: Array of TaskItem
    func fetchCachedTasks(userId: String, date: Date) -> [TaskItem] {
        return cacheService.getTasks(for: date, userId: userId)
    }
    
    /// Save tasks to cache for a specific date
    /// - Parameters:
    ///   - userId: User ID
    ///   - date: Date to save tasks for
    ///   - tasks: Array of TaskItem to save
    func saveCachedTasks(userId: String, date: Date, tasks: [TaskItem]) {
        cacheService.saveTasksForDate(tasks, date: date, userId: userId)
    }
    
    /// Check if date is within cache window
    /// - Parameters:
    ///   - userId: User ID
    ///   - date: Date to check
    /// - Returns: True if date is within cache window
    func isDateInCacheWindow(userId: String, date: Date) -> Bool {
        let (window, _) = cacheService.getCurrentCacheWindow()
        return cacheService.isDateInCacheWindow(date, windowMin: window.minDate, windowMax: window.maxDate)
    }
    
    /// Update cache window to center on a specific date
    /// - Parameters:
    ///   - userId: User ID
    ///   - centerDate: Date to center cache window on
    func updateCacheWindow(userId: String, centerDate: Date) {
        cacheService.updateCacheWindow(centerDate: centerDate, for: userId)
    }
    
    /// Get all cached tasks within the current cache window
    /// - Parameters:
    ///   - centerDate: Date to center cache window on
    /// - Returns: Tuple of (cacheWindow, cachedTasksByDate)
    func getAllCachedTasksInWindow(centerDate: Date) -> (window: (minDate: Date, maxDate: Date), tasksByDate: [Date: [TaskItem]]) {
        let (window, tasksByDate) = cacheService.getCurrentCacheWindow(centerDate: centerDate)
        return (window: (minDate: window.minDate, maxDate: window.maxDate), tasksByDate: tasksByDate)
    }
    
    // MARK: - Cloud Operations (Firebase)
    
    /// Fetch tasks from Firebase for a specific date
    /// - Parameters:
    ///   - userId: User ID
    ///   - date: Date to fetch tasks for
    ///   - completion: Completion handler with tasks or error
    func fetchCloudTasks(userId: String, date: Date, completion: @escaping (Result<[TaskItem], Error>) -> Void) {
        databaseService.fetchTasksForDate(userId: userId, date: date, completion: completion)
    }
    
    /// Save task to Firebase
    /// - Parameters:
    ///   - userId: User ID
    ///   - task: TaskItem to save
    ///   - date: Date the task belongs to
    ///   - completion: Completion handler with result
    func saveCloudTask(userId: String, task: TaskItem, date: Date, completion: ((Result<Void, Error>) -> Void)? = nil) {
        databaseService.saveTask(userId: userId, task: task, date: date, completion: completion)
    }
    
    /// Delete task from Firebase
    /// - Parameters:
    ///   - userId: User ID
    ///   - taskId: Task ID to delete
    ///   - date: Date the task belongs to
    ///   - completion: Completion handler with result
    func deleteCloudTask(userId: String, taskId: UUID, date: Date, completion: ((Result<Void, Error>) -> Void)? = nil) {
        databaseService.deleteTask(userId: userId, taskId: taskId, date: date, completion: completion)
    }
    
    /// Listen to real-time changes for tasks on a specific date
    /// - Parameters:
    ///   - userId: User ID
    ///   - date: Date to listen to
    ///   - callback: Callback with updated tasks
    /// - Returns: Listener handle (store this to stop listening later)
    func listenToCloudTasks(userId: String, date: Date, callback: @escaping ([TaskItem]) -> Void) -> DatabaseHandle? {
        return databaseService.listenToTasks(userId: userId, date: date, callback: callback)
    }
    
    /// Stop a real-time listener
    /// - Parameter handle: Handle returned from listenToCloudTasks
    func stopListening(handle: DatabaseHandle) {
        databaseService.stopListening(handle: handle)
    }
    
    // MARK: - Synchronization
    
    /// Load tasks for a specific date (cache-first, then Firebase)
    /// - Parameters:
    ///   - userId: User ID
    ///   - date: Date to load tasks for
    ///   - completion: Completion handler with tasks or error
    func loadTasks(userId: String, date: Date, completion: @escaping (Result<[TaskItem], Error>) -> Void) {
        let calendar = Calendar.current
        let normalizedDate = calendar.startOfDay(for: date)
        
        // Check if date is in cache window
        if isDateInCacheWindow(userId: userId, date: normalizedDate) {
            // Load from cache
            let tasks = fetchCachedTasks(userId: userId, date: normalizedDate)
            completion(.success(tasks))
            print("✅ TaskRepository: Loaded \(tasks.count) tasks from cache for \(normalizedDate)")
        } else {
            // Date is outside cache window, load from Firebase and update cache
            print("📡 TaskRepository: Date outside cache window, loading from Firebase")
            
            // Update cache window
            updateCacheWindow(userId: userId, centerDate: normalizedDate)
            
            // Load from Firebase
            fetchCloudTasks(userId: userId, date: normalizedDate) { [weak self] result in
                guard let self = self else { return }
                
                switch result {
                case .success(let tasks):
                    // Update cache
                    self.saveCachedTasks(userId: userId, date: normalizedDate, tasks: tasks)
                    completion(.success(tasks))
                    print("✅ TaskRepository: Loaded \(tasks.count) tasks from Firebase for \(normalizedDate)")
                case .failure(let error):
                    completion(.failure(error))
                    print("❌ TaskRepository: Failed to load tasks from Firebase - \(error.localizedDescription)")
                }
            }
        }
    }
    
    /// Save task to both cache and Firebase (offline-first)
    /// - Parameters:
    ///   - userId: User ID
    ///   - task: TaskItem to save
    ///   - date: Date the task belongs to
    ///   - syncToCloud: Whether to sync to Firebase (default: true)
    ///   - completion: Completion handler with result
    func saveTask(userId: String, task: TaskItem, date: Date, syncToCloud: Bool = true, completion: ((Result<Void, Error>) -> Void)? = nil) {
        // Save to cache first (offline-first)
        saveCachedTasks(userId: userId, date: date, tasks: [task])
        
        // Sync to Firebase in background if requested
        if syncToCloud {
            saveCloudTask(userId: userId, task: task, date: date) { result in
                switch result {
                case .success:
                    print("✅ TaskRepository: Task synced to Firebase - TaskId: \(task.id)")
                case .failure(let error):
                    print("⚠️ TaskRepository: Failed to sync task to Firebase - \(error.localizedDescription)")
                }
                completion?(result)
            }
        } else {
            completion?(.success(()))
        }
    }
    
    /// Delete task from both cache and Firebase
    /// - Parameters:
    ///   - userId: User ID
    ///   - taskId: Task ID to delete
    ///   - date: Date the task belongs to
    ///   - syncToCloud: Whether to sync to Firebase (default: true)
    ///   - completion: Completion handler with result
    func deleteTask(userId: String, taskId: UUID, date: Date, syncToCloud: Bool = true, completion: ((Result<Void, Error>) -> Void)? = nil) {
        // Delete from cache first
        cacheService.deleteTask(taskId: taskId, date: date, userId: userId)
        
        // Delete from Firebase in background if requested
        if syncToCloud {
            deleteCloudTask(userId: userId, taskId: taskId, date: date) { result in
                switch result {
                case .success:
                    print("✅ TaskRepository: Task deleted from Firebase - TaskId: \(taskId)")
                case .failure(let error):
                    print("⚠️ TaskRepository: Failed to delete task from Firebase - \(error.localizedDescription)")
                }
                completion?(result)
            }
        } else {
            completion?(.success(()))
        }
    }
    
    /// Update task in both cache and Firebase
    /// - Parameters:
    ///   - userId: User ID
    ///   - newTask: Updated TaskItem
    ///   - oldTask: Original TaskItem (for date comparison)
    ///   - syncToCloud: Whether to sync to Firebase (default: true)
    ///   - completion: Completion handler with result
    func updateTask(userId: String, newTask: TaskItem, oldTask: TaskItem, syncToCloud: Bool = true, completion: ((Result<Void, Error>) -> Void)? = nil) {
        let calendar = Calendar.current
        let oldDate = calendar.startOfDay(for: oldTask.timeDate)
        let newDate = calendar.startOfDay(for: newTask.timeDate)
        
        // Update cache
        if oldDate == newDate {
            // Date unchanged, update in place
            cacheService.updateTask(newTask, oldDate: oldDate, userId: userId)
        } else {
            // Date changed, delete from old date and add to new date
            cacheService.deleteTask(taskId: oldTask.id, date: oldDate, userId: userId)
            cacheService.saveTask(newTask, date: newDate, userId: userId)
        }
        
        // Sync to Firebase in background if requested
        if syncToCloud {
            // Save new task
            saveCloudTask(userId: userId, task: newTask, date: newDate) { [weak self] result in
                guard let self = self else { return }
                
                switch result {
                case .success:
                    // If date changed, delete old task from Firebase
                    if oldDate != newDate {
                        self.deleteCloudTask(userId: userId, taskId: oldTask.id, date: oldDate) { deleteResult in
                            switch deleteResult {
                            case .success:
                                print("✅ TaskRepository: Old task deleted from Firebase (date changed)")
                            case .failure(let error):
                                print("⚠️ TaskRepository: Failed to delete old task from Firebase - \(error.localizedDescription)")
                            }
                            completion?(result)
                        }
                    } else {
                        completion?(result)
                    }
                    print("✅ TaskRepository: Task updated in Firebase - TaskId: \(newTask.id)")
                case .failure(let error):
                    print("⚠️ TaskRepository: Failed to update task in Firebase - \(error.localizedDescription)")
                    completion?(result)
                }
            }
        } else {
            completion?(.success(()))
        }
    }
    
    /// Sync tasks from Firebase to cache
    /// - Parameters:
    ///   - userId: User ID
    ///   - date: Date to sync tasks for
    ///   - completion: Completion handler with result
    func syncFromCloud(userId: String, date: Date, completion: @escaping (Result<[TaskItem], Error>) -> Void) {
        fetchCloudTasks(userId: userId, date: date) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let tasks):
                // Update cache
                self.saveCachedTasks(userId: userId, date: date, tasks: tasks)
                completion(.success(tasks))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
}

