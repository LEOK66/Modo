import Foundation
import FirebaseAuth

/// Task cache service - manages local cache window and UserDefaults storage
/// Implements 2-month sliding window cache strategy (1 month before and after current date)
final class TaskCacheService {
    
    // MARK: - Singleton
    static let shared = TaskCacheService()
    private init() {}
    
    // MARK: - Constants
    /// Cache window size (in months): 1 month before and after, 2 months total
    private let cacheWindowMonths = 1
    
    // MARK: - Helper Methods
    
    /// Get current user ID
    private func getCurrentUserId() -> String? {
        return Auth.auth().currentUser?.uid
    }
    
    /// Get UserDefaults key for cache
    private func getCacheKey(for userId: String) -> String {
        return "task_cache_\(userId)"
    }
    
    /// Calculate cache window range (1 month before and after center date)
    /// - Returns: (minDate, maxDate) both dates normalized to 00:00:00 of the day
    func calculateCacheWindow(centerDate: Date = Date()) -> (minDate: Date, maxDate: Date) {
        let calendar = Calendar.current
        let center = calendar.startOfDay(for: centerDate)
        
        // Calculate minimum date (1 month before)
        guard let minDate = calendar.date(byAdding: .month, value: -cacheWindowMonths, to: center) else {
            return (center, center)
        }
        
        // Calculate maximum date (1 month after)
        guard let maxDate = calendar.date(byAdding: .month, value: cacheWindowMonths, to: center) else {
            return (center, center)
        }
        
        return (
            minDate: calendar.startOfDay(for: minDate),
            maxDate: calendar.startOfDay(for: maxDate)
        )
    }
    
    /// Check if date is within cache window
    func isDateInCacheWindow(_ date: Date, windowMin: Date, windowMax: Date) -> Bool {
        let calendar = Calendar.current
        let normalizedDate = calendar.startOfDay(for: date)
        return normalizedDate >= windowMin && normalizedDate <= windowMax
    }
    
    /// Convert Date to string key (for UserDefaults)
    /// Uses ISO8601 format, date part only: YYYY-MM-DD
    private func dateToKey(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: date)
    }
    
    /// Convert string key to Date
    private func keyToDate(_ key: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.date(from: key)
    }
    
    // MARK: - UserDefaults Storage
    
    /// Load cached tasks from UserDefaults
    /// - Returns: [Date: [TaskItem]] dictionary, Date normalized to 00:00:00 of the day
    func loadCachedTasks(for userId: String) -> [Date: [MainPageView.TaskItem]] {
        let key = getCacheKey(for: userId)
        guard let data = UserDefaults.standard.data(forKey: key) else {
            return [:]
        }
        
        do {
            // Decode JSON data
            let decoder = JSONDecoder()
            // JSON format: { "2025-01-15": [TaskItem...], "2025-01-16": [TaskItem...] }
            let taskDict = try decoder.decode([String: [MainPageView.TaskItem]].self, from: data)
            
            // Convert String keys to Date keys
            var result: [Date: [MainPageView.TaskItem]] = [:]
            let calendar = Calendar.current
            
            for (dateKey, tasks) in taskDict {
                guard let date = keyToDate(dateKey) else {
                    continue
                }
                let normalizedDate = calendar.startOfDay(for: date)
                result[normalizedDate] = tasks
            }
            
            return result
        } catch {
            print("❌ TaskCacheService: Failed to load cache - \(error.localizedDescription)")
            return [:]
        }
    }
    
    /// Save tasks to UserDefaults
    /// - Parameter tasksByDate: [Date: [TaskItem]] dictionary, Date should be normalized
    func saveCachedTasks(_ tasksByDate: [Date: [MainPageView.TaskItem]], for userId: String) {
        let key = getCacheKey(for: userId)
        
        do {
            // Convert Date keys to String keys
            var taskDict: [String: [MainPageView.TaskItem]] = [:]
            for (date, tasks) in tasksByDate {
                let dateKey = dateToKey(date)
                taskDict[dateKey] = tasks
            }
            
            // Encode to JSON
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(taskDict)
            
            // Save to UserDefaults
            UserDefaults.standard.set(data, forKey: key)
            
            print("✅ TaskCacheService: Cache saved (\(taskDict.count) dates)")
        } catch {
            print("❌ TaskCacheService: Failed to save cache - \(error.localizedDescription)")
        }
    }
    
    /// Clean cache (remove data outside window)
    /// - Parameter windowMin: Window minimum date
    /// - Parameter windowMax: Window maximum date
    func cleanCacheOutsideWindow(windowMin: Date, windowMax: Date, for userId: String) {
        var cachedTasks = loadCachedTasks(for: userId)
        let calendar = Calendar.current
        
        // Remove data outside window
        let filteredTasks = cachedTasks.filter { date, _ in
            let normalizedDate = calendar.startOfDay(for: date)
            return normalizedDate >= windowMin && normalizedDate <= windowMax
        }
        
        if filteredTasks.count < cachedTasks.count {
            print("🧹 TaskCacheService: Cleaned \(cachedTasks.count - filteredTasks.count) dates outside cache window")
            saveCachedTasks(filteredTasks, for: userId)
        }
    }
    
    /// Clear all cached tasks for current user
    /// - Parameter userId: User ID (optional, uses current user if nil)
    /// - Parameter alsoClearFirebase: If true, also deletes all tasks from Firebase
    func clearCache(userId: String? = nil, alsoClearFirebase: Bool = false) {
        let userId = userId ?? getCurrentUserId() ?? ""
        guard !userId.isEmpty else {
            print("⚠️ TaskCacheService: No user ID provided, cannot clear cache")
            return
        }
        
        let key = getCacheKey(for: userId)
        UserDefaults.standard.removeObject(forKey: key)
        print("🗑️ TaskCacheService: Cache cleared for user \(userId)")
        
        // Also clear Firebase if requested
        if alsoClearFirebase {
            DatabaseService.shared.deleteAllTasks(userId: userId) { result in
                switch result {
                case .success:
                    print("✅ TaskCacheService: Firebase tasks also cleared")
                case .failure(let error):
                    print("⚠️ TaskCacheService: Failed to clear Firebase tasks - \(error.localizedDescription)")
                }
            }
        }
    }
    
    // MARK: - Cache Window Management
    
    /// Get current cache window
    /// - Returns: (minDate, maxDate) and cached task data
    func getCurrentCacheWindow(centerDate: Date = Date()) -> (window: (minDate: Date, maxDate: Date), tasks: [Date: [MainPageView.TaskItem]]) {
        guard let userId = getCurrentUserId() else {
            let emptyWindow = calculateCacheWindow(centerDate: centerDate)
            return (window: emptyWindow, tasks: [:])
        }
        
        let window = calculateCacheWindow(centerDate: centerDate)
        let tasks = loadCachedTasks(for: userId)
        
        return (window: window, tasks: tasks)
    }
    
    /// Check if specified date is within current cache window
    func isDateInCurrentCacheWindow(_ date: Date, centerDate: Date = Date()) -> Bool {
        let window = calculateCacheWindow(centerDate: centerDate)
        return isDateInCacheWindow(date, windowMin: window.minDate, windowMax: window.maxDate)
    }
    
    /// Update cache window (slide window to new center date)
    /// If new window exceeds old window, cleans data outside old window
    func updateCacheWindow(centerDate: Date = Date(), for userId: String? = nil) {
        let userId = userId ?? getCurrentUserId() ?? ""
        guard !userId.isEmpty else { return }
        
        let newWindow = calculateCacheWindow(centerDate: centerDate)
        
        // Clean data outside window
        cleanCacheOutsideWindow(windowMin: newWindow.minDate, windowMax: newWindow.maxDate, for: userId)
        
        print("📅 TaskCacheService: Cache window updated - \(dateToKey(newWindow.minDate)) to \(dateToKey(newWindow.maxDate))")
    }
    
    // MARK: - Task CRUD (Local Cache Only)
    
    /// Get task list for specified date (from cache only)
    func getTasks(for date: Date, userId: String? = nil) -> [MainPageView.TaskItem] {
        let userId = userId ?? getCurrentUserId() ?? ""
        guard !userId.isEmpty else { return [] }
        
        let calendar = Calendar.current
        let dateKey = calendar.startOfDay(for: date)
        
        let cachedTasks = loadCachedTasks(for: userId)
        return cachedTasks[dateKey] ?? []
    }
    
    /// Save task to cache (local update immediately)
    func saveTask(_ task: MainPageView.TaskItem, date: Date, userId: String? = nil) {
        let userId = userId ?? getCurrentUserId() ?? ""
        guard !userId.isEmpty else { return }
        
        var cachedTasks = loadCachedTasks(for: userId)
        let calendar = Calendar.current
        let dateKey = calendar.startOfDay(for: task.timeDate)
        
        // Get task list for this date
        var tasks = cachedTasks[dateKey] ?? []
        
        // Check if task already exists (by ID)
        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[index] = task
        } else {
            tasks.append(task)
        }
        
        // Sort by time
        tasks.sort { $0.timeDate < $1.timeDate }
        
        cachedTasks[dateKey] = tasks
        saveCachedTasks(cachedTasks, for: userId)
    }
    
    /// Save multiple tasks for a specific date (batch save, more efficient)
    /// REPLACES the cached list for that date to ensure deletions are respected
    func saveTasksForDate(_ tasks: [MainPageView.TaskItem], date: Date, userId: String? = nil) {
        let userId = userId ?? getCurrentUserId() ?? ""
        guard !userId.isEmpty else { return }
        
        // Load cache once
        var cachedTasks = loadCachedTasks(for: userId)
        let calendar = Calendar.current
        let dateKey = calendar.startOfDay(for: date)
        
        // Replace with provided tasks (sorted). This ensures deletions are persisted.
        var updatedTasks = tasks.sorted { $0.timeDate < $1.timeDate }
        
        // Update cache
        if updatedTasks.isEmpty {
            cachedTasks.removeValue(forKey: dateKey)
        } else {
            cachedTasks[dateKey] = updatedTasks
        }
        
        // Save cache once
        saveCachedTasks(cachedTasks, for: userId)
    }
    
    /// Delete task (local delete immediately)
    func deleteTask(taskId: UUID, date: Date, userId: String? = nil) {
        let userId = userId ?? getCurrentUserId() ?? ""
        guard !userId.isEmpty else { return }
        
        var cachedTasks = loadCachedTasks(for: userId)
        let calendar = Calendar.current
        let dateKey = calendar.startOfDay(for: date)
        
        guard var tasks = cachedTasks[dateKey] else { return }
        
        // Remove task
        tasks.removeAll { $0.id == taskId }
        
        if tasks.isEmpty {
            cachedTasks.removeValue(forKey: dateKey)
        } else {
            cachedTasks[dateKey] = tasks
        }
        
        saveCachedTasks(cachedTasks, for: userId)
    }
    
    /// Update task (local update immediately)
    func updateTask(_ task: MainPageView.TaskItem, oldDate: Date, userId: String? = nil) {
        let userId = userId ?? getCurrentUserId() ?? ""
        guard !userId.isEmpty else { return }
        
        let calendar = Calendar.current
        let oldDateKey = calendar.startOfDay(for: oldDate)
        let newDateKey = calendar.startOfDay(for: task.timeDate)
        
        // If date changed, remove from old date and add to new date
        if oldDateKey != newDateKey {
            deleteTask(taskId: task.id, date: oldDate, userId: userId)
            saveTask(task, date: task.timeDate, userId: userId)
        } else {
            // Date unchanged, update directly
            saveTask(task, date: task.timeDate, userId: userId)
        }
    }
}

