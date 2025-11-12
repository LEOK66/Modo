import Foundation
import SwiftData

/// Repository for managing DailyCompletion data
/// Coordinates between SwiftData (local) and Firebase (cloud) data sources
final class CompletionRepository: RepositoryProtocol {
    let modelContext: ModelContext
    let databaseService: DatabaseServiceProtocol
    
    /// Initialize CompletionRepository
    /// - Parameters:
    ///   - modelContext: SwiftData model context for local operations
    ///   - databaseService: Database service for Firebase operations
    init(modelContext: ModelContext, databaseService: DatabaseServiceProtocol) {
        self.modelContext = modelContext
        self.databaseService = databaseService
    }
    
    // MARK: - Local Operations (SwiftData)
    
    /// Fetch daily completion from SwiftData
    /// - Parameters:
    ///   - userId: User ID
    ///   - date: Date to fetch completion for
    /// - Returns: DailyCompletion if found, nil otherwise
    func fetchLocalCompletion(userId: String, date: Date) -> DailyCompletion? {
        let calendar = Calendar.current
        let normalizedDate = calendar.startOfDay(for: date)
        
        let descriptor = FetchDescriptor<DailyCompletion>(
            predicate: #Predicate { completion in
                completion.userId == userId && completion.date == normalizedDate
            }
        )
        
        do {
            return try modelContext.fetch(descriptor).first
        } catch {
            print("❌ CompletionRepository: Failed to fetch local completion - \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Fetch daily completions for a date range from SwiftData
    /// - Parameters:
    ///   - userId: User ID
    ///   - startDate: Start date (inclusive)
    ///   - endDate: End date (inclusive)
    /// - Returns: Array of DailyCompletion
    func fetchLocalCompletions(userId: String, startDate: Date, endDate: Date) -> [DailyCompletion] {
        let calendar = Calendar.current
        let normalizedStart = calendar.startOfDay(for: startDate)
        let normalizedEnd = calendar.startOfDay(for: endDate)
        
        let descriptor = FetchDescriptor<DailyCompletion>(
            predicate: #Predicate { completion in
                completion.userId == userId &&
                completion.date >= normalizedStart &&
                completion.date <= normalizedEnd
            },
            sortBy: [SortDescriptor(\.date)]
        )
        
        do {
            return try modelContext.fetch(descriptor)
        } catch {
            print("❌ CompletionRepository: Failed to fetch local completions - \(error.localizedDescription)")
            return []
        }
    }
    
    /// Save daily completion to SwiftData
    /// - Parameters:
    ///   - userId: User ID
    ///   - date: Date to save completion for
    ///   - isCompleted: Whether the day is completed
    ///   - completedAt: Optional completion timestamp
    func saveLocalCompletion(userId: String, date: Date, isCompleted: Bool, completedAt: Date? = nil) {
        let calendar = Calendar.current
        let normalizedDate = calendar.startOfDay(for: date)
        
        // Check if completion already exists
        if let existing = fetchLocalCompletion(userId: userId, date: normalizedDate) {
            // Update existing completion
            existing.isCompleted = isCompleted
            existing.completedAt = completedAt
        } else {
            // Create new completion
            let completion = DailyCompletion(
                userId: userId,
                date: normalizedDate,
                isCompleted: isCompleted,
                completedAt: completedAt
            )
            modelContext.insert(completion)
        }
        
        do {
            try modelContext.save()
            print("✅ CompletionRepository: Completion saved to SwiftData - UserId: \(userId), Date: \(normalizedDate), Completed: \(isCompleted)")
        } catch {
            print("❌ CompletionRepository: Failed to save completion to SwiftData - \(error.localizedDescription)")
        }
    }
    
    /// Delete daily completion from SwiftData
    /// - Parameters:
    ///   - userId: User ID
    ///   - date: Date to delete completion for
    func deleteLocalCompletion(userId: String, date: Date) {
        let calendar = Calendar.current
        let normalizedDate = calendar.startOfDay(for: date)
        
        if let completion = fetchLocalCompletion(userId: userId, date: normalizedDate) {
            modelContext.delete(completion)
            
            do {
                try modelContext.save()
                print("✅ CompletionRepository: Completion deleted from SwiftData - UserId: \(userId), Date: \(normalizedDate)")
            } catch {
                print("❌ CompletionRepository: Failed to delete completion from SwiftData - \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Cloud Operations (Firebase)
    
    /// Fetch daily completion from Firebase
    /// - Parameters:
    ///   - userId: User ID
    ///   - date: Date to fetch completion for
    ///   - completion: Completion handler with isCompleted Bool or error
    func fetchCloudCompletion(userId: String, date: Date, completion: @escaping (Result<Bool, Error>) -> Void) {
        databaseService.fetchDailyCompletion(userId: userId, date: date, completion: completion)
    }
    
    /// Fetch daily completions for a date range from Firebase
    /// - Parameters:
    ///   - userId: User ID
    ///   - startDate: Start date (inclusive)
    ///   - endDate: End date (inclusive)
    ///   - completion: Completion handler with dictionary [Date: Bool] or error
    func fetchCloudCompletions(userId: String, startDate: Date, endDate: Date, completion: @escaping (Result<[Date: Bool], Error>) -> Void) {
        databaseService.fetchDailyCompletions(userId: userId, startDate: startDate, endDate: endDate, completion: completion)
    }
    
    /// Save daily completion to Firebase
    /// - Parameters:
    ///   - userId: User ID
    ///   - date: Date to save completion for
    ///   - isCompleted: Whether the day is completed
    ///   - completedAt: Optional completion timestamp
    ///   - completion: Completion handler with result
    func saveCloudCompletion(userId: String, date: Date, isCompleted: Bool, completedAt: Date? = nil, completion: ((Result<Void, Error>) -> Void)? = nil) {
        databaseService.saveDailyCompletion(userId: userId, date: date, isCompleted: isCompleted, completion: completion)
    }
    
    // MARK: - Synchronization
    
    /// Sync daily completions from Firebase to SwiftData
    /// - Parameters:
    ///   - userId: User ID
    ///   - startDate: Start date (inclusive)
    ///   - endDate: End date (inclusive)
    ///   - completion: Completion handler with result
    func syncFromCloud(userId: String, startDate: Date, endDate: Date, completion: @escaping (Result<[DailyCompletion], Error>) -> Void) {
        fetchCloudCompletions(userId: userId, startDate: startDate, endDate: endDate) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let cloudCompletions):
                // Update local completions
                var syncedCompletions: [DailyCompletion] = []
                
                for (date, isCompleted) in cloudCompletions {
                    let existingCompletion = self.fetchLocalCompletion(userId: userId, date: date)
                    let isNewCompletion = existingCompletion == nil
                    
                    let completion = existingCompletion ?? DailyCompletion(
                        userId: userId,
                        date: date,
                        isCompleted: isCompleted
                    )
                    
                    completion.isCompleted = isCompleted
                    if completion.completedAt == nil && isCompleted {
                        completion.completedAt = Date()
                    }
                    
                    // Insert new completions into the context
                    if isNewCompletion {
                        self.modelContext.insert(completion)
                    }
                    
                    syncedCompletions.append(completion)
                }
                
                // Save to SwiftData
                do {
                    try self.modelContext.save()
                    print("✅ CompletionRepository: Synced \(syncedCompletions.count) completions from Firebase")
                    completion(.success(syncedCompletions))
                } catch {
                    print("❌ CompletionRepository: Failed to save synced completions - \(error.localizedDescription)")
                    completion(.failure(error))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    /// Sync daily completion from SwiftData to Firebase
    /// - Parameters:
    ///   - userId: User ID
    ///   - date: Date to sync completion for
    ///   - completion: Completion handler with result
    func syncToCloud(userId: String, date: Date, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let localCompletion = fetchLocalCompletion(userId: userId, date: date) else {
            completion(.failure(NSError(domain: "CompletionRepository", code: 1, userInfo: [NSLocalizedDescriptionKey: "Local completion not found"])))
            return
        }
        
        saveCloudCompletion(
            userId: userId,
            date: date,
            isCompleted: localCompletion.isCompleted,
            completedAt: localCompletion.completedAt,
            completion: completion
        )
    }
    
    /// Save daily completion to both SwiftData and Firebase
    /// - Parameters:
    ///   - userId: User ID
    ///   - date: Date to save completion for
    ///   - isCompleted: Whether the day is completed
    ///   - completedAt: Optional completion timestamp
    ///   - syncToCloud: Whether to sync to Firebase (default: true)
    ///   - completion: Completion handler with result
    func saveCompletion(userId: String, date: Date, isCompleted: Bool, completedAt: Date? = nil, syncToCloud: Bool = true, completion: ((Result<Void, Error>) -> Void)? = nil) {
        // Save to SwiftData first (offline-first)
        saveLocalCompletion(userId: userId, date: date, isCompleted: isCompleted, completedAt: completedAt)
        
        // Sync to Firebase in background if requested
        if syncToCloud {
            saveCloudCompletion(userId: userId, date: date, isCompleted: isCompleted, completedAt: completedAt) { result in
                switch result {
                case .success:
                    print("✅ CompletionRepository: Completion synced to Firebase - UserId: \(userId), Date: \(date)")
                case .failure(let error):
                    print("⚠️ CompletionRepository: Failed to sync completion to Firebase - \(error.localizedDescription)")
                }
                completion?(result)
            }
        } else {
            completion?(.success(()))
        }
    }
}


