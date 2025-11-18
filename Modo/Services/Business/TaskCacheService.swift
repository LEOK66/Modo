import Foundation
import FirebaseAuth

/// Task cache service - manages local cache window and UserDefaults storage
/// Implements 2-month sliding window cache strategy (1 month before and after current date)
/// 
/// **Cache Strategy**:
/// - Sliding window: 1 month before and after current date (2 months total)
/// - Cache invalidation: Based on timestamp (tasks older than cache window are removed)
/// - Cache preloading: Preload adjacent dates when user navigates
/// - Performance: Batch operations, minimize UserDefaults reads/writes
final class TaskCacheService {
    
    // MARK: - Singleton
    static let shared = TaskCacheService()
    private init() {}
    
    // MARK: - Constants
    /// Cache window size (in months): 1 month before and after, 2 months total
    private let cacheWindowMonths = AppConstants.Cache.windowMonths
    
    /// Cache invalidation: Maximum age for cached data (in seconds)
    /// Data older than this will be considered stale and reloaded from Firebase
    private let cacheMaxAge: TimeInterval = 3600 // 1 hour
    
    /// Cache preload range: Number of days to preload on each side of current date
    private let preloadDays: Int = 7 // Preload 7 days before and after
    
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
        formatter.dateFormat = DateFormats.standardDate
        formatter.timeZone = TimeZone.current
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: date)
    }
    
    /// Convert string key to Date
    private func keyToDate(_ key: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = DateFormats.standardDate
        formatter.timeZone = TimeZone.current
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.date(from: key)
    }
    
    // MARK: - Cache Metadata
    
    /// Cache metadata structure to track cache age and validity
    private struct CacheMetadata: Codable {
        var lastUpdated: Date
        var version: Int // For future cache format migrations
    }
    
    /// Get cache metadata key
    private func getMetadataKey(for userId: String) -> String {
        return "task_cache_metadata_\(userId)"
    }
    
    /// Load cache metadata
    private func loadCacheMetadata(for userId: String) -> CacheMetadata? {
        let key = getMetadataKey(for: userId)
        guard let data = UserDefaults.standard.data(forKey: key) else {
            return nil
        }
        
        do {
            let decoder = JSONDecoder()
            return try decoder.decode(CacheMetadata.self, from: data)
        } catch {
            print("⚠️ TaskCacheService: Failed to load cache metadata - \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Save cache metadata
    private func saveCacheMetadata(_ metadata: CacheMetadata, for userId: String) {
        let key = getMetadataKey(for: userId)
        
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(metadata)
            UserDefaults.standard.set(data, forKey: key)
        } catch {
            print("⚠️ TaskCacheService: Failed to save cache metadata - \(error.localizedDescription)")
        }
    }
    
    /// Check if cache is valid (not stale)
    /// - Parameters:
    ///   - userId: User ID
    ///   - date: Date to check cache validity for
    /// - Returns: True if cache is valid, false if stale
    func isCacheValid(for userId: String, date: Date) -> Bool {
        guard let metadata = loadCacheMetadata(for: userId) else {
            return false
        }
        
        let age = Date().timeIntervalSince(metadata.lastUpdated)
        return age < cacheMaxAge
    }
    
    // MARK: - UserDefaults Storage
    
    /// Load cached tasks from UserDefaults
    /// - Returns: [Date: [TaskItem]] dictionary, Date normalized to 00:00:00 of the day
    func loadCachedTasks(for userId: String) -> [Date: [TaskItem]] {
        let key = getCacheKey(for: userId)
        guard let data = UserDefaults.standard.data(forKey: key) else {
            return [:]
        }
        
        do {
            // Decode JSON data
            let decoder = JSONDecoder()
            // JSON format: { "2025-01-15": [TaskItem...], "2025-01-16": [TaskItem...] }
            let taskDict = try decoder.decode([String: [TaskItem]].self, from: data)
            
            // Convert String keys to Date keys
            var result: [Date: [TaskItem]] = [:]
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
    func saveCachedTasks(_ tasksByDate: [Date: [TaskItem]], for userId: String) {
        let key = getCacheKey(for: userId)
        
        do {
            // Convert Date keys to String keys
            var taskDict: [String: [TaskItem]] = [:]
            for (date, tasks) in tasksByDate {
                let dateKey = dateToKey(date)
                taskDict[dateKey] = tasks
            }
            
            // Encode to JSON (without pretty printing for better performance)
            let encoder = JSONEncoder()
            let data = try encoder.encode(taskDict)
            
            // Save to UserDefaults
            UserDefaults.standard.set(data, forKey: key)
            
            // Update cache metadata
            let metadata = CacheMetadata(lastUpdated: Date(), version: 1)
            saveCacheMetadata(metadata, for: userId)
            
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
    /// - Parameters:
    ///   - userId: User ID (optional, uses current user if nil)
    ///   - databaseService: Optional database service to clear Firebase tasks (if provided and alsoClearFirebase is true)
    ///   - alsoClearFirebase: If true, also deletes all tasks from Firebase (requires databaseService parameter)
    func clearCache(userId: String? = nil, databaseService: DatabaseServiceProtocol? = nil, alsoClearFirebase: Bool = false) {
        let userId = userId ?? getCurrentUserId() ?? ""
        guard !userId.isEmpty else {
            print("⚠️ TaskCacheService: No user ID provided, cannot clear cache")
            return
        }
        
        let key = getCacheKey(for: userId)
        UserDefaults.standard.removeObject(forKey: key)
        
        // Also clear metadata when clearing cache
        let metadataKey = getMetadataKey(for: userId)
        UserDefaults.standard.removeObject(forKey: metadataKey)
        
        print("🗑️ TaskCacheService: Cache cleared for user \(userId)")
        
        // Also clear Firebase if requested and database service is provided
        if alsoClearFirebase {
            guard let databaseService = databaseService else {
                print("⚠️ TaskCacheService: DatabaseService not provided, cannot clear Firebase tasks")
                return
            }
            
            databaseService.deleteAllTasks(userId: userId) { result in
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
    func getCurrentCacheWindow(centerDate: Date = Date()) -> (window: (minDate: Date, maxDate: Date), tasks: [Date: [TaskItem]]) {
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
    
    // MARK: - Cache Preloading
    
    /// Preload tasks for dates around the given center date
    /// This improves performance by loading adjacent dates in advance
    /// - Parameters:
    ///   - centerDate: Center date to preload around
    ///   - userId: User ID
    ///   - databaseService: Database service to fetch from Firebase if needed
    ///   - completion: Completion handler called when preload completes
    func preloadCache(centerDate: Date, userId: String, databaseService: DatabaseServiceProtocol, completion: ((Result<Void, Error>) -> Void)? = nil) {
        let calendar = Calendar.current
        let normalizedCenter = calendar.startOfDay(for: centerDate)
        
        // Calculate preload range
        guard let startDate = calendar.date(byAdding: .day, value: -preloadDays, to: normalizedCenter),
              let endDate = calendar.date(byAdding: .day, value: preloadDays, to: normalizedCenter) else {
            completion?(.failure(NSError(domain: "TaskCacheService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to calculate preload range"])))
            return
        }
        
        let normalizedStart = calendar.startOfDay(for: startDate)
        let normalizedEnd = calendar.startOfDay(for: endDate)
        
        // Check which dates need to be loaded
        let cachedTasks = loadCachedTasks(for: userId)
        var datesToLoad: [Date] = []
        
        var currentDate = normalizedStart
        while currentDate <= normalizedEnd {
            // Check if date is in cache window and not already cached
            let window = calculateCacheWindow(centerDate: normalizedCenter)
            if isDateInCacheWindow(currentDate, windowMin: window.minDate, windowMax: window.maxDate) {
                if cachedTasks[currentDate] == nil {
                    datesToLoad.append(currentDate)
                }
            }
            guard let nextDate = calendar.date(byAdding: .day, value: 1, to: currentDate) else { break }
            currentDate = nextDate
        }
        
        guard !datesToLoad.isEmpty else {
            print("✅ TaskCacheService: All dates already cached, no preload needed")
            completion?(.success(()))
            return
        }
        
        print("📥 TaskCacheService: Preloading \(datesToLoad.count) dates")
        
        // Load dates in parallel (batch)
        let group = DispatchGroup()
        var errors: [Error] = []
        var loadedTasks: [Date: [TaskItem]] = [:]
        
        for date in datesToLoad {
            group.enter()
            databaseService.fetchTasksForDate(userId: userId, date: date) { result in
                switch result {
                case .success(let tasks):
                    loadedTasks[date] = tasks
                case .failure(let error):
                    errors.append(error)
                }
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            // Save all loaded tasks to cache
            if !loadedTasks.isEmpty {
                var allCachedTasks = self.loadCachedTasks(for: userId)
                for (date, tasks) in loadedTasks {
                    allCachedTasks[date] = tasks
                }
                self.saveCachedTasks(allCachedTasks, for: userId)
                print("✅ TaskCacheService: Preloaded \(loadedTasks.count) dates")
            }
            
            if errors.isEmpty {
                completion?(.success(()))
            } else {
                completion?(.failure(errors.first!))
            }
        }
    }
    
    // MARK: - Cache Statistics
    
    /// Get cache statistics
    /// - Parameter userId: User ID
    /// - Returns: Cache statistics (date count, total tasks, cache age)
    func getCacheStatistics(for userId: String) -> (dateCount: Int, totalTasks: Int, cacheAge: TimeInterval?) {
        let cachedTasks = loadCachedTasks(for: userId)
        let dateCount = cachedTasks.count
        let totalTasks = cachedTasks.values.reduce(0) { $0 + $1.count }
        
        let cacheAge: TimeInterval?
        if let metadata = loadCacheMetadata(for: userId) {
            cacheAge = Date().timeIntervalSince(metadata.lastUpdated)
        } else {
            cacheAge = nil
        }
        
        return (dateCount: dateCount, totalTasks: totalTasks, cacheAge: cacheAge)
    }
    
    // MARK: - Task CRUD (Local Cache Only)
    
    /// Get task list for specified date (from cache only)
    func getTasks(for date: Date, userId: String? = nil) -> [TaskItem] {
        let userId = userId ?? getCurrentUserId() ?? ""
        guard !userId.isEmpty else { return [] }
        
        let calendar = Calendar.current
        let dateKey = calendar.startOfDay(for: date)
        
        let cachedTasks = loadCachedTasks(for: userId)
        return cachedTasks[dateKey] ?? []
    }
    
    /// Save task to cache (local update immediately)
    func saveTask(_ task: TaskItem, date: Date, userId: String? = nil) {
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
    func saveTasksForDate(_ tasks: [TaskItem], date: Date, userId: String? = nil) {
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
    func updateTask(_ task: TaskItem, oldDate: Date, userId: String? = nil) {
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

