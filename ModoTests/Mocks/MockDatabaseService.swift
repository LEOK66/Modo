import Foundation
import FirebaseDatabase
@testable import Modo

/// Mock implementation of DatabaseServiceProtocol for testing
/// This allows tests to run without actual Firebase database connections
final class MockDatabaseService: DatabaseServiceProtocol {
    // MARK: - Test Data Storage
    private var userProfiles: [String: UserProfile] = [:]
    private var tasks: [String: [Date: [TaskItem]]] = [:]
    private var dailyCompletions: [String: [Date: Bool]] = [:]
    private var dailyChallenges: [String: [Date: [String: Any]]] = [:]
    private var usernames: [String: String] = [:]
    
    // MARK: - Test Configuration
    var shouldSucceed = true
    var mockError: Error?
    
    // MARK: - Call Tracking
    var saveUserProfileCallCount = 0
    var fetchUserProfileCallCount = 0
    var saveTaskCallCount = 0
    var deleteTaskCallCount = 0
    var fetchTasksCallCount = 0
    
    // MARK: - User Profile Methods
    func saveUserProfile(_ profile: UserProfile, completion: ((Result<Void, Error>) -> Void)?) {
        saveUserProfileCallCount += 1
        
        if let error = mockError {
            completion?(.failure(error))
            return
        }
        
        if shouldSucceed {
            userProfiles[profile.userId] = profile
            completion?(.success(()))
        } else {
            completion?(.failure(NSError(domain: "MockDatabaseService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Save failed"])))
        }
    }
    
    func updateUsername(userId: String, username: String, completion: ((Result<Void, Error>) -> Void)?) {
        if let error = mockError {
            completion?(.failure(error))
            return
        }
        
        if shouldSucceed {
            usernames[userId] = username
            completion?(.success(()))
        } else {
            completion?(.failure(NSError(domain: "MockDatabaseService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Update failed"])))
        }
    }
    
    func fetchUsername(userId: String, completion: @escaping (Result<String?, Error>) -> Void) {
        if let error = mockError {
            completion(.failure(error))
            return
        }
        
        if shouldSucceed {
            completion(.success(usernames[userId]))
        } else {
            completion(.failure(NSError(domain: "MockDatabaseService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Fetch failed"])))
        }
    }
    
    func fetchUserProfile(userId: String, completion: @escaping (Result<UserProfile, Error>) -> Void) {
        fetchUserProfileCallCount += 1
        
        if let error = mockError {
            completion(.failure(error))
            return
        }
        
        if shouldSucceed, let profile = userProfiles[userId] {
            completion(.success(profile))
        } else {
            completion(.failure(NSError(domain: "MockDatabaseService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Profile not found"])))
        }
    }
    
    // MARK: - Task Methods
    func saveTask(userId: String, task: TaskItem, date: Date, completion: ((Result<Void, Error>) -> Void)?) {
        saveTaskCallCount += 1
        
        if let error = mockError {
            completion?(.failure(error))
            return
        }
        
        if shouldSucceed {
            if tasks[userId] == nil {
                tasks[userId] = [:]
            }
            if tasks[userId]?[date] == nil {
                tasks[userId]?[date] = []
            }
            tasks[userId]?[date]?.append(task)
            completion?(.success(()))
        } else {
            completion?(.failure(NSError(domain: "MockDatabaseService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Save failed"])))
        }
    }
    
    func deleteTask(userId: String, taskId: UUID, date: Date, completion: ((Result<Void, Error>) -> Void)?) {
        deleteTaskCallCount += 1
        
        if let error = mockError {
            completion?(.failure(error))
            return
        }
        
        if shouldSucceed {
            tasks[userId]?[date]?.removeAll { $0.id == taskId }
            completion?(.success(()))
        } else {
            completion?(.failure(NSError(domain: "MockDatabaseService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Delete failed"])))
        }
    }
    
    func fetchTasksForDate(userId: String, date: Date, completion: @escaping (Result<[TaskItem], Error>) -> Void) {
        fetchTasksCallCount += 1
        
        if let error = mockError {
            completion(.failure(error))
            return
        }
        
        if shouldSucceed {
            let tasksForDate = tasks[userId]?[date] ?? []
            completion(.success(tasksForDate))
        } else {
            completion(.failure(NSError(domain: "MockDatabaseService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Fetch failed"])))
        }
    }
    
    func listenToTasks(userId: String, date: Date, callback: @escaping ([TaskItem]) -> Void) -> DatabaseHandle? {
        // For mock, we'll return nil and call callback immediately with current tasks
        let tasksForDate = tasks[userId]?[date] ?? []
        callback(tasksForDate)
        return nil
    }
    
    func stopListening(handle: DatabaseHandle) {
        // No-op for mock
    }
    
    func deleteAllTasks(userId: String, completion: ((Result<Void, Error>) -> Void)?) {
        if let error = mockError {
            completion?(.failure(error))
            return
        }
        
        if shouldSucceed {
            tasks[userId] = [:]
            completion?(.success(()))
        } else {
            completion?(.failure(NSError(domain: "MockDatabaseService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Delete failed"])))
        }
    }
    
    // MARK: - Daily Completion Methods
    func saveDailyCompletion(userId: String, date: Date, isCompleted: Bool, completion: ((Result<Void, Error>) -> Void)?) {
        if let error = mockError {
            completion?(.failure(error))
            return
        }
        
        if shouldSucceed {
            if dailyCompletions[userId] == nil {
                dailyCompletions[userId] = [:]
            }
            dailyCompletions[userId]?[date] = isCompleted
            completion?(.success(()))
        } else {
            completion?(.failure(NSError(domain: "MockDatabaseService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Save failed"])))
        }
    }
    
    func fetchDailyCompletion(userId: String, date: Date, completion: @escaping (Result<Bool, Error>) -> Void) {
        if let error = mockError {
            completion(.failure(error))
            return
        }
        
        if shouldSucceed {
            let isCompleted = dailyCompletions[userId]?[date] ?? false
            completion(.success(isCompleted))
        } else {
            completion(.failure(NSError(domain: "MockDatabaseService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Fetch failed"])))
        }
    }
    
    func fetchDailyCompletions(userId: String, startDate: Date, endDate: Date, completion: @escaping (Result<[Date: Bool], Error>) -> Void) {
        if let error = mockError {
            completion(.failure(error))
            return
        }
        
        if shouldSucceed {
            var result: [Date: Bool] = [:]
            let userCompletions = dailyCompletions[userId] ?? [:]
            
            var currentDate = startDate
            while currentDate <= endDate {
                result[currentDate] = userCompletions[currentDate] ?? false
                currentDate = Calendar.current.date(byAdding: .day, value: 1, to: currentDate) ?? endDate
            }
            
            completion(.success(result))
        } else {
            completion(.failure(NSError(domain: "MockDatabaseService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Fetch failed"])))
        }
    }
    
    func deleteDailyCompletions(userId: String, startDate: Date, endDate: Date, completion: ((Result<Void, Error>) -> Void)?) {
        if let error = mockError {
            completion?(.failure(error))
            return
        }
        
        if shouldSucceed {
            if var userCompletions = dailyCompletions[userId] {
                var currentDate = startDate
                while currentDate <= endDate {
                    userCompletions.removeValue(forKey: currentDate)
                    currentDate = Calendar.current.date(byAdding: .day, value: 1, to: currentDate) ?? endDate
                }
                dailyCompletions[userId] = userCompletions
            }
            completion?(.success(()))
        } else {
            completion?(.failure(NSError(domain: "MockDatabaseService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Delete failed"])))
        }
    }
    
    // MARK: - Daily Challenge Methods
    func saveDailyChallenge(userId: String, challenge: DailyChallenge, date: Date, isCompleted: Bool, isLocked: Bool, completedAt: Date?, taskId: UUID?, completion: ((Result<Void, Error>) -> Void)?) {
        if let error = mockError {
            completion?(.failure(error))
            return
        }
        
        if shouldSucceed {
            if dailyChallenges[userId] == nil {
                dailyChallenges[userId] = [:]
            }
            
            var challengeData: [String: Any] = [:]
            challengeData["challenge"] = challenge
            challengeData["isCompleted"] = isCompleted
            challengeData["isLocked"] = isLocked
            if let completedAt = completedAt {
                challengeData["completedAt"] = completedAt
            }
            if let taskId = taskId {
                challengeData["taskId"] = taskId.uuidString
            }
            
            dailyChallenges[userId]?[date] = challengeData
            completion?(.success(()))
        } else {
            completion?(.failure(NSError(domain: "MockDatabaseService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Save failed"])))
        }
    }
    
    func fetchDailyChallenge(userId: String, date: Date, completion: @escaping (Result<[String: Any]?, Error>) -> Void) {
        if let error = mockError {
            completion(.failure(error))
            return
        }
        
        if shouldSucceed {
            let challengeData = dailyChallenges[userId]?[date]
            completion(.success(challengeData))
        } else {
            completion(.failure(NSError(domain: "MockDatabaseService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Fetch failed"])))
        }
    }
    
    func updateDailyChallengeCompletion(userId: String, date: Date, isCompleted: Bool, isLocked: Bool, completedAt: Date?, completion: ((Result<Void, Error>) -> Void)?) {
        if let error = mockError {
            completion?(.failure(error))
            return
        }
        
        if shouldSucceed {
            if var challengeData = dailyChallenges[userId]?[date] {
                challengeData["isCompleted"] = isCompleted
                challengeData["isLocked"] = isLocked
                if let completedAt = completedAt {
                    challengeData["completedAt"] = completedAt
                }
                dailyChallenges[userId]?[date] = challengeData
            }
            completion?(.success(()))
        } else {
            completion?(.failure(NSError(domain: "MockDatabaseService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Update failed"])))
        }
    }
    
    func updateDailyChallengeTaskId(userId: String, date: Date, taskId: UUID?, completion: ((Result<Void, Error>) -> Void)?) {
        if let error = mockError {
            completion?(.failure(error))
            return
        }
        
        if shouldSucceed {
            if var challengeData = dailyChallenges[userId]?[date] {
                if let taskId = taskId {
                    challengeData["taskId"] = taskId.uuidString
                } else {
                    challengeData.removeValue(forKey: "taskId")
                }
                dailyChallenges[userId]?[date] = challengeData
            }
            completion?(.success(()))
        } else {
            completion?(.failure(NSError(domain: "MockDatabaseService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Update failed"])))
        }
    }
    
    func listenToDailyChallenge(userId: String, date: Date, callback: @escaping ([String: Any]?) -> Void) -> DatabaseHandle? {
        // For mock, we'll return nil and call callback immediately with current challenge
        let challengeData = dailyChallenges[userId]?[date]
        callback(challengeData)
        return nil
    }
    
    // MARK: - Test Helpers
    func reset() {
        userProfiles.removeAll()
        tasks.removeAll()
        dailyCompletions.removeAll()
        dailyChallenges.removeAll()
        usernames.removeAll()
        shouldSucceed = true
        mockError = nil
        saveUserProfileCallCount = 0
        fetchUserProfileCallCount = 0
        saveTaskCallCount = 0
        deleteTaskCallCount = 0
        fetchTasksCallCount = 0
    }
}

