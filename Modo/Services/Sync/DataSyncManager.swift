import Foundation
import SwiftData
import FirebaseAuth
import Combine

/// Manages data synchronization between SwiftData (local) and Firebase (cloud)
/// Implements offline-first strategy with conflict resolution
final class DataSyncManager: ObservableObject {
    private let modelContext: ModelContext
    private let databaseService: DatabaseServiceProtocol
    private let userProfileRepository: UserProfileRepository
    private let taskRepository: TaskRepository
    private let completionRepository: CompletionRepository
    
    /// Sync status tracking
    enum SyncStatus: Equatable {
        case idle
        case syncing
        case completed
        case failed(Error)
        
        static func == (lhs: SyncStatus, rhs: SyncStatus) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle), (.syncing, .syncing), (.completed, .completed):
                return true
            case (.failed(let lhsError), .failed(let rhsError)):
                return lhsError.localizedDescription == rhsError.localizedDescription
            default:
                return false
            }
        }
    }
    
    @Published private(set) var syncStatus: SyncStatus = .idle
    @Published private(set) var lastSyncTime: Date?
    
    /// Initialize DataSyncManager
    /// - Parameters:
    ///   - modelContext: SwiftData model context
    ///   - databaseService: Database service for Firebase operations
    init(modelContext: ModelContext, databaseService: DatabaseServiceProtocol) {
        self.modelContext = modelContext
        self.databaseService = databaseService
        
        // Initialize repositories
        self.userProfileRepository = UserProfileRepository(
            modelContext: modelContext,
            databaseService: databaseService
        )
        self.taskRepository = TaskRepository(
            modelContext: modelContext,
            databaseService: databaseService
        )
        self.completionRepository = CompletionRepository(
            modelContext: modelContext,
            databaseService: databaseService
        )
    }
    
    // MARK: - Sync Operations
    
    /// Perform full sync on app launch or when coming online
    /// Syncs data from Firebase to SwiftData, then syncs local changes to Firebase
    /// - Parameters:
    ///   - userId: User ID to sync data for
    ///   - completion: Completion handler with sync result
    func performFullSync(userId: String, completion: ((Result<Void, Error>) -> Void)? = nil) {
        guard syncStatus != .syncing else {
            print("⚠️ DataSyncManager: Sync already in progress, skipping")
            completion?(.failure(NSError(domain: "DataSyncManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Sync already in progress"])))
            return
        }
        
        syncStatus = .syncing
        print("🔄 DataSyncManager: Starting full sync for user \(userId)")
        
        // Step 1: Sync from Firebase to SwiftData (pull)
        syncFromCloud(userId: userId) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success:
                // Step 2: Sync from SwiftData to Firebase (push)
                self.syncToCloud(userId: userId) { pushResult in
                    switch pushResult {
                    case .success:
                        self.syncStatus = .completed
                        self.lastSyncTime = Date()
                        print("✅ DataSyncManager: Full sync completed successfully")
                        completion?(.success(()))
                    case .failure(let error):
                        self.syncStatus = .failed(error)
                        print("❌ DataSyncManager: Failed to push local changes - \(error.localizedDescription)")
                        completion?(.failure(error))
                    }
                }
            case .failure(let error):
                self.syncStatus = .failed(error)
                print("❌ DataSyncManager: Failed to pull cloud changes - \(error.localizedDescription)")
                completion?(.failure(error))
            }
        }
    }
    
    /// Sync data from Firebase to SwiftData (pull)
    /// - Parameters:
    ///   - userId: User ID to sync data for
    ///   - completion: Completion handler with sync result
    private func syncFromCloud(userId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        let group = DispatchGroup()
        var errors: [Error] = []
        
        // Sync user profile
        group.enter()
        userProfileRepository.syncFromCloud(userId: userId) { result in
            switch result {
            case .success:
                print("✅ DataSyncManager: User profile synced from cloud")
            case .failure(let error):
                print("⚠️ DataSyncManager: Failed to sync user profile - \(error.localizedDescription)")
                errors.append(error)
            }
            group.leave()
        }
        
        // Sync daily completions (last 90 days)
        group.enter()
        let calendar = Calendar.current
        let endDate = calendar.startOfDay(for: Date())
        guard let startDate = calendar.date(byAdding: .day, value: -90, to: endDate) else {
            group.leave()
            return
        }
        
        completionRepository.syncFromCloud(userId: userId, startDate: startDate, endDate: endDate) { result in
            switch result {
            case .success:
                print("✅ DataSyncManager: Daily completions synced from cloud")
            case .failure(let error):
                print("⚠️ DataSyncManager: Failed to sync daily completions - \(error.localizedDescription)")
                errors.append(error)
            }
            group.leave()
        }
        
        // Note: Task sync is handled by TaskRepository.loadTasks() on-demand
        // We don't sync all tasks at once to avoid performance issues
        
        group.notify(queue: .main) {
            if errors.isEmpty {
                completion(.success(()))
            } else {
                // Return first error, but log all errors
                completion(.failure(errors.first!))
            }
        }
    }
    
    /// Sync data from SwiftData to Firebase (push)
    /// - Parameters:
    ///   - userId: User ID to sync data for
    ///   - completion: Completion handler with sync result
    private func syncToCloud(userId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        let group = DispatchGroup()
        var errors: [Error] = []
        
        // Sync user profile if it exists locally
        if let localProfile = userProfileRepository.fetchLocalProfile(userId: userId) {
            group.enter()
            userProfileRepository.syncToCloud(userId: userId) { result in
                switch result {
                case .success:
                    print("✅ DataSyncManager: User profile synced to cloud")
                case .failure(let error):
                    print("⚠️ DataSyncManager: Failed to sync user profile - \(error.localizedDescription)")
                    errors.append(error)
                }
                group.leave()
            }
        }
        
        // Sync daily completions (only recent ones, last 30 days)
        group.enter()
        let calendar = Calendar.current
        let endDate = calendar.startOfDay(for: Date())
        guard let startDate = calendar.date(byAdding: .day, value: -30, to: endDate) else {
            group.leave()
            return
        }
        
        let localCompletions = completionRepository.fetchLocalCompletions(userId: userId, startDate: startDate, endDate: endDate)
        
        // Sync each completion
        for completion in localCompletions {
            group.enter()
            completionRepository.syncToCloud(userId: userId, date: completion.date) { result in
                switch result {
                case .success:
                    break // Silent success
                case .failure(let error):
                    print("⚠️ DataSyncManager: Failed to sync completion for \(completion.date) - \(error.localizedDescription)")
                    errors.append(error)
                }
                group.leave()
            }
        }
        
        // Note: Task sync is handled by TaskRepository.saveTask() on write
        // We don't sync all tasks at once to avoid performance issues
        
        group.notify(queue: .main) {
            if errors.isEmpty {
                completion(.success(()))
            } else {
                // Return first error, but log all errors
                completion(.failure(errors.first!))
            }
        }
    }
    
    // MARK: - Conflict Resolution
    
    /// Resolve conflict between local and cloud data using timestamp comparison
    /// Strategy: Last write wins (based on updatedAt timestamp)
    /// - Parameters:
    ///   - localUpdatedAt: Local data updated timestamp
    ///   - cloudUpdatedAt: Cloud data updated timestamp
    /// - Returns: True if local data should be kept, false if cloud data should be kept
    func resolveConflict(localUpdatedAt: Date, cloudUpdatedAt: Date) -> Bool {
        // Last write wins: keep the data with the newer timestamp
        return localUpdatedAt >= cloudUpdatedAt
    }
    
    // MARK: - Incremental Sync
    
    /// Perform incremental sync (only sync changed data since last sync)
    /// - Parameters:
    ///   - userId: User ID to sync data for
    ///   - since: Date to sync changes since
    ///   - completion: Completion handler with sync result
    func performIncrementalSync(userId: String, since: Date, completion: ((Result<Void, Error>) -> Void)? = nil) {
        guard syncStatus != .syncing else {
            print("⚠️ DataSyncManager: Sync already in progress, skipping")
            completion?(.failure(NSError(domain: "DataSyncManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Sync already in progress"])))
            return
        }
        
        syncStatus = .syncing
        print("🔄 DataSyncManager: Starting incremental sync for user \(userId) since \(since)")
        
        // For now, incremental sync is similar to full sync
        // Future optimization: Only sync data changed since 'since' date
        performFullSync(userId: userId, completion: completion)
    }
    
    // MARK: - Sync Status
    
    /// Check if sync is needed
    /// - Parameters:
    ///   - maxAge: Maximum age of last sync before sync is needed (default: 5 minutes)
    /// - Returns: True if sync is needed, false otherwise
    func isSyncNeeded(maxAge: TimeInterval = 300) -> Bool {
        guard let lastSync = lastSyncTime else {
            return true
        }
        
        let age = Date().timeIntervalSince(lastSync)
        return age > maxAge
    }
    
    /// Reset sync status
    func resetSyncStatus() {
        syncStatus = .idle
        lastSyncTime = nil
    }
}

