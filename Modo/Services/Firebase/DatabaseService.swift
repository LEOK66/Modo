import Foundation
import FirebaseDatabase

final class DatabaseService: DatabaseServiceProtocol {
    static let shared = DatabaseService()
    private let db: DatabaseReference
    private var taskListeners: [String: DatabaseHandle] = [:]
    
    // CRITICAL FIX: Add operation tracking to prevent cascading saves
    private var pendingOperations: Set<String> = []
    private let operationsQueue = DispatchQueue(label: "com.app.database.operations")
    
    private init() {
        // Note: Persistence is enabled in ModoApp.init() before any services are initialized
        // This ensures persistence is configured before any database access occurs
        self.db = Database.database().reference()
        
        // Monitor connection status for debugging
        setupConnectionMonitoring()
    }
    
    // MARK: - Connection Monitoring
    
    /// Monitor Firebase connection status
    /// This helps track when data is being synced from offline queue
    private func setupConnectionMonitoring() {
        let connectedRef = Database.database().reference(withPath: ".info/connected")
        connectedRef.observe(.value) { snapshot in
            if let connected = snapshot.value as? Bool, connected {
                print("✅ DatabaseService: Connected to Firebase - syncing offline changes")
            } else {
                print("⚠️ DatabaseService: Offline - writes will be queued and synced when online")
            }
        }
    }
    
    func saveUserProfile(_ profile: UserProfile, completion: ((Result<Void, Error>) -> Void)? = nil) {
        let path = db.child("users").child(profile.userId).child("profile")
        var payload: [String: Any] = [
            "userId": profile.userId,
            "createdAt": profile.createdAt.timeIntervalSince1970,
            "updatedAt": profile.updatedAt.timeIntervalSince1970
        ]
        if let username = profile.username { payload["username"] = username }
        if let avatarName = profile.avatarName { payload["avatarName"] = avatarName }
        if let profileImageURL = profile.profileImageURL { payload["profileImageURL"] = profileImageURL }
        if let heightValue = profile.heightValue { payload["heightValue"] = heightValue }
        if let heightUnit = profile.heightUnit { payload["heightUnit"] = heightUnit }
        if let weightValue = profile.weightValue { payload["weightValue"] = weightValue }
        if let weightUnit = profile.weightUnit { payload["weightUnit"] = weightUnit }
        if let age = profile.age { payload["age"] = age }
        if let gender = profile.gender { payload["gender"] = gender }
        if let lifestyle = profile.lifestyle { payload["lifestyle"] = lifestyle }
        if let goal = profile.goal { payload["goal"] = goal }
        if let dailyCalories = profile.dailyCalories { payload["dailyCalories"] = dailyCalories }
        if let dailyProtein = profile.dailyProtein { payload["dailyProtein"] = dailyProtein }
        if let targetWeightLossValue = profile.targetWeightLossValue { payload["targetWeightLossValue"] = targetWeightLossValue }
        if let targetWeightLossUnit = profile.targetWeightLossUnit { payload["targetWeightLossUnit"] = targetWeightLossUnit }
        if let targetDays = profile.targetDays { payload["targetDays"] = targetDays }
        
        path.setValue(payload) { error, _ in
            if let error = error {
                completion?(.failure(error))
            } else {
                completion?(.success(()))
            }
        }
    }
    
    /// Update user profile username only (preserves other fields)
    /// - Parameters:
    ///   - userId: User ID
    ///   - username: New username to save
    ///   - completion: Completion handler with result
    func updateUsername(userId: String, username: String, completion: ((Result<Void, Error>) -> Void)? = nil) {
        let path = db.child("users").child(userId).child("profile")
        let payload: [String: Any] = [
            "username": username,
            "updatedAt": Date().timeIntervalSince1970
        ]
        
        path.updateChildValues(payload) { error, _ in
            if let error = error {
                completion?(.failure(error))
            } else {
                completion?(.success(()))
            }
        }
    }
    
    /// Fetch username only from Firebase
    /// - Parameters:
    ///   - userId: User ID to fetch username for
    ///   - completion: Completion handler with username string or error
    func fetchUsername(userId: String, completion: @escaping (Result<String?, Error>) -> Void) {
        let path = db.child("users").child(userId).child("profile").child("username")
        
        path.observeSingleEvent(of: .value) { snapshot in
            guard snapshot.exists(), let username = snapshot.value as? String else {
                completion(.success(nil))
                return
            }
            completion(.success(username))
        }
    }
    
    /// Fetch user profile from Firebase
    /// - Parameters:
    ///   - userId: User ID to fetch profile for
    ///   - completion: Completion handler with UserProfile or error
    func fetchUserProfile(userId: String, completion: @escaping (Result<UserProfile, Error>) -> Void) {
        let path = db.child("users").child(userId).child("profile")
        
        path.observeSingleEvent(of: .value) { snapshot in
            guard snapshot.exists() else {
                let profile = UserProfile(userId: userId)
                completion(.success(profile))
                return
            }
            
            guard let profileDict = snapshot.value as? [String: Any] else {
                let profile = UserProfile(userId: userId)
                completion(.success(profile))
                return
            }
            
            do {
                let profile = try self.parseProfileDictionary(profileDict)
                completion(.success(profile))
            } catch {
                print("❌ DatabaseService: Failed to parse user profile - \(error.localizedDescription)")
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - Task CRUD Methods
    
    /// Save or update a task in Firebase
    /// - Parameters:
    ///   - task: Task to save
    ///   - date: Date the task belongs to (normalized to start of day)
    ///   - completion: Completion handler with result
    func saveTask(userId: String, task: TaskItem, date: Date, completion: ((Result<Void, Error>) -> Void)? = nil) {
        let dateKey = dateToKey(date)
        let operationKey = "\(userId)_\(dateKey)_\(task.id.uuidString)"
        
        // CRITICAL FIX: Check if operation is already in progress
        operationsQueue.sync {
            if pendingOperations.contains(operationKey) {
                print("⚠️ DatabaseService: Save operation already in progress for task \(task.id)")
                completion?(.success(())) // Don't fail, just skip duplicate
                return
            }
            pendingOperations.insert(operationKey)
        }
        
        let taskPath = db.child("users").child(userId).child("tasks").child(dateKey).child(task.id.uuidString)
        
        do {
            let taskDict = try taskToDictionary(task)
            
            taskPath.setValue(taskDict) { [weak self] error, _ in
                // Clean up operation tracking
                self?.operationsQueue.sync {
                    self?.pendingOperations.remove(operationKey)
                }
                
                if let error = error {
                    print("❌ DatabaseService: Failed to save task to Firebase - \(error.localizedDescription)")
                    completion?(.failure(error))
                } else {
                    print("✅ DatabaseService: Task saved to Firebase - ID: \(task.id)")
                    completion?(.success(()))
                }
            }
        } catch {
            // Clean up on encoding error
            operationsQueue.sync {
                pendingOperations.remove(operationKey)
            }
            print("❌ DatabaseService: Failed to convert task to dictionary - \(error.localizedDescription)")
            completion?(.failure(error))
        }
    }
    
    /// Delete a task from Firebase
    /// - Parameters:
    ///   - taskId: UUID of task to delete
    ///   - date: Date the task belongs to
    ///   - completion: Completion handler with result
    func deleteTask(userId: String, taskId: UUID, date: Date, completion: ((Result<Void, Error>) -> Void)? = nil) {
        let dateKey = dateToKey(date)
        let taskPath = db.child("users").child(userId).child("tasks").child(dateKey).child(taskId.uuidString)
        
        taskPath.removeValue { error, _ in
            if let error = error {
                print("❌ DatabaseService: Failed to delete task - \(error.localizedDescription)")
                completion?(.failure(error))
            } else {
                print("✅ DatabaseService: Task deleted from Firebase - ID: \(taskId)")
                completion?(.success(()))
            }
        }
    }
    
    
    /// Fetch tasks for a specific date
    /// - Parameters:
    ///   - date: Date to fetch tasks for
    ///   - completion: Completion handler with tasks or error
    func fetchTasksForDate(userId: String, date: Date, completion: @escaping (Result<[TaskItem], Error>) -> Void) {
        let dateKey = dateToKey(date)
        let tasksPath = db.child("users").child(userId).child("tasks").child(dateKey)
        
        tasksPath.observeSingleEvent(of: .value) { snapshot in
            guard snapshot.exists() else {
                completion(.success([]))
                return
            }
            
            guard let taskDict = snapshot.value as? [String: Any] else {
                completion(.success([]))
                return
            }
            
            do {
                let tasks = try self.parseTaskDictionary(taskDict)
                completion(.success(tasks))
            } catch {
                print("❌ DatabaseService: Failed to parse tasks in fetch - \(error.localizedDescription)")
                completion(.failure(error))
            }
        }
    }
    
    
    
    /// Listen to real-time changes for tasks on a specific date
    /// - Parameters:
    ///   - date: Date to listen to
    ///   - callback: Callback with updated tasks
    /// - Returns: Listener handle (store this to stop listening later)
    func listenToTasks(userId: String, date: Date, callback: @escaping ([TaskItem]) -> Void) -> DatabaseHandle? {
        let dateKey = dateToKey(date)
        let tasksPath = db.child("users").child(userId).child("tasks").child(dateKey)
        
        // Create unique key for this listener
        let listenerKey = "\(userId)_\(dateKey)"
        
        // CRITICAL FIX: Remove existing listener if any
        if let existingHandle = taskListeners[listenerKey] {
            print("⚠️ DatabaseService: Removing existing listener for \(listenerKey)")
            db.removeObserver(withHandle: existingHandle)
            taskListeners.removeValue(forKey: listenerKey)
        }
        
        print("🔌 DatabaseService: Setting up listener for \(listenerKey)")
        
        let handle = tasksPath.observe(.value) { [weak self] snapshot in
            guard self != nil else { return }
            
            guard snapshot.exists() else {
                print("📡 DatabaseService: Listener update - no data for user \(userId)")
                callback([])
                return
            }
            
            guard let taskDict = snapshot.value as? [String: Any] else {
                print("📡 DatabaseService: Listener update - invalid data for user \(userId)")
                callback([])
                return
            }
            
            do {
                let tasks = try self!.parseTaskDictionary(taskDict)
                print("📡 DatabaseService: Listener update - \(tasks.count) tasks for user \(userId)")
                callback(tasks)
            } catch {
                print("❌ DatabaseService: Failed to parse tasks in listener - \(error.localizedDescription)")
                callback([])
            }
        }
        
        taskListeners[listenerKey] = handle
        return handle
    }
    
    /// Stop a real-time listener
    /// - Parameter handle: Handle returned from listenToTasks
    func stopListening(handle: DatabaseHandle) {
        db.removeObserver(withHandle: handle)
        
        // Clean up from tracking dictionary
        taskListeners = taskListeners.filter { $0.value != handle }
        print("🛑 DatabaseService: Stopped listener")
    }
    
    
    
    /// Delete all tasks from Firebase for a user
    /// - Parameters:
    ///   - userId: User ID
    ///   - completion: Completion handler with result
    func deleteAllTasks(userId: String, completion: ((Result<Void, Error>) -> Void)? = nil) {
        let tasksPath = db.child("users").child(userId).child("tasks")
        
        tasksPath.removeValue { error, _ in
            if let error = error {
                print("❌ DatabaseService: Failed to delete all tasks from Firebase - \(error.localizedDescription)")
                completion?(.failure(error))
            } else {
                print("🗑️ DatabaseService: All tasks deleted from Firebase for user \(userId)")
                completion?(.success(()))
            }
        }
    }
    
    // MARK: - Helper Methods
    
    /// Convert Date to string key (YYYY-MM-DD)
    private func dateToKey(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = DateFormats.standardDate
        formatter.timeZone = TimeZone.current
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: date)
    }
    
    private func taskToDictionary(_ task: TaskItem) throws -> [String: Any] {
        let encoder = JSONEncoder()
        let data = try encoder.encode(task)
        
        guard let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NSError(domain: "DatabaseService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to convert task to dictionary"])
        }
        
        return dict
    }
    
    private func parseTaskDictionary(_ taskDict: [String: Any]) throws -> [TaskItem] {
        var tasks: [TaskItem] = []
        
        for (_, taskValue) in taskDict {
            guard let taskData = taskValue as? [String: Any] else {
                continue
            }
            
            let jsonData = try JSONSerialization.data(withJSONObject: taskData)
            let decoder = JSONDecoder()
            do {
                let task = try decoder.decode(TaskItem.self, from: jsonData)
                tasks.append(task)
            } catch {
                print("❌ DatabaseService: Failed to decode single task - \(error.localizedDescription)")
                throw error
            }
        }
        
        return tasks
    }
    
    private func parseProfileDictionary(_ profileDict: [String: Any]) throws -> UserProfile {
        guard let userId = profileDict["userId"] as? String else {
            throw NSError(domain: "DatabaseService", code: 2, userInfo: [NSLocalizedDescriptionKey: "Missing userId in profile dictionary"])
        }
        
        let profile = UserProfile(userId: userId)
        
        // Parse username
        if let username = profileDict["username"] as? String {
            profile.username = username
        }
        // Parse avatar fields
        if let avatarName = profileDict["avatarName"] as? String {
            profile.avatarName = avatarName
        }
        if let profileImageURL = profileDict["profileImageURL"] as? String {
            profile.profileImageURL = profileImageURL
        }
        
        // Parse height
        if let heightValue = profileDict["heightValue"] as? Double {
            profile.heightValue = heightValue
        }
        if let heightUnit = profileDict["heightUnit"] as? String {
            profile.heightUnit = heightUnit
        }
        
        // Parse weight
        if let weightValue = profileDict["weightValue"] as? Double {
            profile.weightValue = weightValue
        }
        if let weightUnit = profileDict["weightUnit"] as? String {
            profile.weightUnit = weightUnit
        }
        
        // Parse age
        if let age = profileDict["age"] as? Int {
            profile.age = age
        }
        
        // Parse gender
        if let gender = profileDict["gender"] as? String {
            profile.gender = gender
        }
        
        // Parse lifestyle
        if let lifestyle = profileDict["lifestyle"] as? String {
            profile.lifestyle = lifestyle
        }
        
        // Parse goal
        if let goal = profileDict["goal"] as? String {
            profile.goal = goal
        }
        
        // Parse dailyCalories
        if let dailyCalories = profileDict["dailyCalories"] as? Int {
            profile.dailyCalories = dailyCalories
        }
        
        // Parse dailyProtein
        if let dailyProtein = profileDict["dailyProtein"] as? Int {
            profile.dailyProtein = dailyProtein
        }
        
        // Parse targetWeightLossValue
        if let targetWeightLossValue = profileDict["targetWeightLossValue"] as? Double {
            profile.targetWeightLossValue = targetWeightLossValue
        }
        if let targetWeightLossUnit = profileDict["targetWeightLossUnit"] as? String {
            profile.targetWeightLossUnit = targetWeightLossUnit
        }
        
        // Parse targetDays
        if let targetDays = profileDict["targetDays"] as? Int {
            profile.targetDays = targetDays
        }
        
        // Parse timestamps
        if let createdAtTimestamp = profileDict["createdAt"] as? TimeInterval {
            profile.createdAt = Date(timeIntervalSince1970: createdAtTimestamp)
        }
        if let updatedAtTimestamp = profileDict["updatedAt"] as? TimeInterval {
            profile.updatedAt = Date(timeIntervalSince1970: updatedAtTimestamp)
        }
        
        return profile
    }
    
    // MARK: - DailyCompletion Methods
    
    /// Save daily completion status to Firebase
    /// - Parameters:
    ///   - userId: User ID
    ///   - date: Date to save completion for (will be normalized to start of day)
    ///   - isCompleted: Whether the day is completed
    ///   - completion: Completion handler with result
    func saveDailyCompletion(userId: String, date: Date, isCompleted: Bool, completion: ((Result<Void, Error>) -> Void)? = nil) {
        let calendar = Calendar.current
        let normalizedDate = calendar.startOfDay(for: date)
        let dateKey = dateToKey(normalizedDate)
        
        let path = db.child("users").child(userId).child("dailyCompletions").child(dateKey)
        let payload: [String: Any] = [
            "isCompleted": isCompleted,
            "completedAt": Date().timeIntervalSince1970
        ]
        
        path.setValue(payload) { error, _ in
            if let error = error {
                print("❌ DatabaseService: Failed to save daily completion - \(error.localizedDescription)")
                completion?(.failure(error))
            } else {
                print("✅ DatabaseService: Daily completion saved - Date: \(dateKey), Completed: \(isCompleted)")
                completion?(.success(()))
            }
        }
    }
    
    /// Fetch daily completion status from Firebase
    /// - Parameters:
    ///   - userId: User ID
    ///   - date: Date to fetch completion for
    ///   - completion: Completion handler with isCompleted Bool or error
    func fetchDailyCompletion(userId: String, date: Date, completion: @escaping (Result<Bool, Error>) -> Void) {
        let calendar = Calendar.current
        let normalizedDate = calendar.startOfDay(for: date)
        let dateKey = dateToKey(normalizedDate)
        
        let path = db.child("users").child(userId).child("dailyCompletions").child(dateKey).child("isCompleted")
        
        path.observeSingleEvent(of: .value) { snapshot in
            guard snapshot.exists(), let isCompleted = snapshot.value as? Bool else {
                // No data means not completed
                completion(.success(false))
                return
            }
            completion(.success(isCompleted))
        }
    }
    
    /// Fetch daily completions for a date range from Firebase
    /// - Parameters:
    ///   - userId: User ID
    ///   - startDate: Start date (inclusive)
    ///   - endDate: End date (inclusive)
    ///   - completion: Completion handler with dictionary [Date: Bool] or error
    func fetchDailyCompletions(userId: String, startDate: Date, endDate: Date, completion: @escaping (Result<[Date: Bool], Error>) -> Void) {
        let calendar = Calendar.current
        let normalizedStart = calendar.startOfDay(for: startDate)
        let normalizedEnd = calendar.startOfDay(for: endDate)
        
        let completionsPath = db.child("users").child(userId).child("dailyCompletions")
        
        completionsPath.observeSingleEvent(of: .value) { snapshot in
            guard snapshot.exists(), let completionsDict = snapshot.value as? [String: Any] else {
                completion(.success([:]))
                return
            }
            
            var result: [Date: Bool] = [:]
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            dateFormatter.timeZone = TimeZone.current
            dateFormatter.locale = Locale(identifier: "en_US_POSIX")
            
            for (dateKey, value) in completionsDict {
                guard let completionDict = value as? [String: Any],
                      let isCompleted = completionDict["isCompleted"] as? Bool,
                      let date = dateFormatter.date(from: dateKey) else {
                    continue
                }
                
                // Only include dates in the requested range
                if date >= normalizedStart && date <= normalizedEnd {
                    result[date] = isCompleted
                }
            }
            
            completion(.success(result))
        }
    }
    
    // MARK: - Daily Challenge Methods
    
    /// Save daily challenge to Firebase
    func saveDailyChallenge(userId: String, challenge: DailyChallenge, date: Date, isCompleted: Bool, isLocked: Bool, completedAt: Date?, taskId: UUID?, completion: ((Result<Void, Error>) -> Void)?) {
        let dateKey = dateToKey(date)
        let challengeRef = db.child("users").child(userId).child("dailyChallenges").child(dateKey)
        
        var data: [String: Any] = [
            "id": challenge.id.uuidString,
            "title": challenge.title,
            "subtitle": challenge.subtitle,
            "emoji": challenge.emoji,
            "type": challenge.type.rawValue,
            "targetValue": challenge.targetValue,
            "isCompleted": isCompleted,
            "isLocked": isLocked,
            "createdAt": Date().timeIntervalSince1970
        ]
        
        if let completedAt = completedAt {
            data["completedAt"] = completedAt.timeIntervalSince1970
        }
        
        if let taskId = taskId {
            data["taskId"] = taskId.uuidString
        }
        
        challengeRef.setValue(data) { error, _ in
            if let error = error {
                print("❌ DatabaseService: Failed to save daily challenge - \(error.localizedDescription)")
                completion?(.failure(error))
            } else {
                print("✅ DatabaseService: Daily challenge saved - Date: \(dateKey)")
                completion?(.success(()))
            }
        }
    }
    
    /// Fetch daily challenge from Firebase
    func fetchDailyChallenge(userId: String, date: Date, completion: @escaping (Result<[String: Any]?, Error>) -> Void) {
        let dateKey = dateToKey(date)
        let challengeRef = db.child("users").child(userId).child("dailyChallenges").child(dateKey)
        
        challengeRef.observeSingleEvent(of: .value) { snapshot in
            guard snapshot.exists(), let data = snapshot.value as? [String: Any] else {
                completion(.success(nil))
                return
            }
            completion(.success(data))
        }
    }
    
    /// Update daily challenge completion status
    func updateDailyChallengeCompletion(userId: String, date: Date, isCompleted: Bool, isLocked: Bool, completedAt: Date?, completion: ((Result<Void, Error>) -> Void)?) {
        let dateKey = dateToKey(date)
        let challengeRef = db.child("users").child(userId).child("dailyChallenges").child(dateKey)
        
        var updates: [String: Any] = [
            "isCompleted": isCompleted,
            "isLocked": isLocked
        ]
        
        if let completedAt = completedAt {
            updates["completedAt"] = completedAt.timeIntervalSince1970
        }
        
        challengeRef.updateChildValues(updates) { error, _ in
            if let error = error {
                print("❌ DatabaseService: Failed to update daily challenge completion - \(error.localizedDescription)")
                completion?(.failure(error))
            } else {
                print("✅ DatabaseService: Daily challenge completion updated - Date: \(dateKey)")
                completion?(.success(()))
            }
        }
    }
    
    /// Update daily challenge task ID
    func updateDailyChallengeTaskId(userId: String, date: Date, taskId: UUID?, completion: ((Result<Void, Error>) -> Void)?) {
        let dateKey = dateToKey(date)
        let challengeRef = db.child("users").child(userId).child("dailyChallenges").child(dateKey)
        
        let updates: [String: Any] = taskId != nil ? ["taskId": taskId!.uuidString] : ["taskId": NSNull()]
        
        challengeRef.updateChildValues(updates) { error, _ in
            if let error = error {
                print("❌ DatabaseService: Failed to update daily challenge taskId - \(error.localizedDescription)")
                completion?(.failure(error))
            } else {
                print("✅ DatabaseService: Daily challenge taskId updated - Date: \(dateKey)")
                completion?(.success(()))
            }
        }
    }
    
    /// Listen to daily challenge changes in real-time
    func listenToDailyChallenge(userId: String, date: Date, callback: @escaping ([String: Any]?) -> Void) -> DatabaseHandle? {
        let dateKey = dateToKey(date)
        let challengeRef = db.child("users").child(userId).child("dailyChallenges").child(dateKey)
        
        let handle = challengeRef.observe(.value) { snapshot in
            if snapshot.exists(), let data = snapshot.value as? [String: Any] {
                callback(data)
            } else {
                callback(nil)
            }
        }
        
        return handle
    }
}


