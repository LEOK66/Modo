import Foundation
import SwiftData

extension Notification.Name {
    static let dayCompletionDidChange = Notification.Name("dayCompletionDidChange")
}

class ProgressCalculationService {
    static let shared = ProgressCalculationService()
    private let databaseService: DatabaseServiceProtocol
    
    /// Initialize with database service dependency
    /// - Parameter databaseService: Database service for Firebase operations (defaults to shared instance)
    init(databaseService: DatabaseServiceProtocol = DatabaseService.shared) {
        self.databaseService = databaseService
    }
    
    // MARK: - Day Completion Check
    
    /// Check if a day is completed (all tasks for that day are done)
    /// - Parameters:
    ///   - tasks: All tasks to check
    ///   - date: Date to check
    /// - Returns: True if the day has at least one task and all tasks are completed
    func isDayCompleted(tasks: [TaskItem], date: Date) -> Bool {
        let calendar = Calendar.current
        let normalizedDate = calendar.startOfDay(for: date)
        
        // Filter tasks for the specified date
        let dayTasks = tasks.filter { task in
            calendar.isDate(task.timeDate, inSameDayAs: normalizedDate)
        }
        
        // At least one task exists and all tasks are completed
        guard !dayTasks.isEmpty else { return false }
        return dayTasks.allSatisfy { $0.isDone }
    }
    
    // MARK: - Progress Calculation
    
    /// Calculate progress percentage
    /// - Parameters:
    ///   - completedDays: Number of completed days
    ///   - targetDays: Target number of days
    ///   - bufferDays: Number of buffer days (days that can be skipped)
    /// - Returns: Progress percentage (0.0-1.0, capped at 1.0)
    func calculateProgress(completedDays: Int, targetDays: Int, bufferDays: Int = 0) -> Double {
        // Calculate effective days (targetDays minus bufferDays, minimum 1 to avoid division by zero)
        let effectiveDays = max(1, targetDays - bufferDays)
        let progress = Double(completedDays) / Double(effectiveDays)
        return min(1.0, max(0.0, progress)) // Limit between 0.0 and 1.0
    }
    
    // MARK: - Completed Days
    
    /// Get number of completed days for a user within a date range
    /// - Parameters:
    ///   - userId: User ID
    ///   - startDate: Start date (inclusive)
    ///   - targetDays: Target number of days
    ///   - modelContext: SwiftData ModelContext for local queries
    /// - Returns: Number of completed days
    func getCompletedDays(userId: String, startDate: Date, targetDays: Int, modelContext: ModelContext) async -> Int {
        let calendar = Calendar.current
        let normalizedStart = calendar.startOfDay(for: startDate)
        
        // Calculate end date: goalStartDate + targetDays (exclusive)
        guard let endDate = calendar.date(byAdding: .day, value: targetDays, to: normalizedStart) else {
            return 0
        }
        
        // Query all completions from startDate to endDate (exclusive)
        // DayCompletionService ensures today won't be marked as completed until midnight,
        // so even if today is in the range, it won't affect the count
        let localCompletions = getLocalCompletions(
            userId: userId, 
            startDate: normalizedStart, 
            endDate: endDate, 
            modelContext: modelContext
        )
        let completedCompletions = localCompletions.filter { $0.isCompleted }
        let localCompletedCount = completedCompletions.count
        
        // Debug: Print results
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        print("📊 ProgressCalculationService: Querying completed days")
        print("   Goal Start Date: \(formatter.string(from: normalizedStart))")
        print("   End Date (exclusive): \(formatter.string(from: endDate))")
        print("   Target Days: \(targetDays)")
        print("   Query Range: [\(formatter.string(from: normalizedStart)), \(formatter.string(from: endDate)))")
        
        // Calculate expected number of days
        let expectedDays = targetDays
        let actualDays = localCompletedCount
        print("   Expected days: \(expectedDays), Actual completed: \(actualDays), Difference: \(expectedDays - actualDays)")
        print("   Found \(localCompletions.count) completion records, \(localCompletedCount) completed")
        
        // Debug: Print all completion dates to help diagnose
        if !localCompletions.isEmpty {
            let allDates = localCompletions.map { formatter.string(from: $0.date) }.sorted()
            let completedDates = completedCompletions.map { formatter.string(from: $0.date) }.sorted()
            print("   All completion dates: \(allDates.prefix(10).joined(separator: ", "))\(allDates.count > 10 ? "..." : "") (total: \(allDates.count))")
            if !completedDates.isEmpty {
                print("   Completed dates (first 10): \(completedDates.prefix(10).joined(separator: ", "))")
                print("   Completed dates (last 10): \(completedDates.suffix(10).joined(separator: ", "))")
            }
        } else {
            print("   ⚠️ No completion records found in query range!")
        }
        
        // Background sync with Firebase (non-blocking)
        // Note: Only sync if we don't have any local data
        // If we have local data (even if incomplete), skip Firebase sync to avoid overwriting with stale data
        // This prevents old Firebase data from appearing when setting a new goal
        // CRITICAL FIX: If goalStartDate is today or very recent (within last 2 days), and we have no local data,
        // this likely means the goal was just reset. Don't sync from Firebase to avoid syncing old records.
        // This is especially important when targetDays is large (e.g., 10000), as old records might fall within
        // the new goal's date range and cause incorrect progress calculation.
        let today = calendar.startOfDay(for: Date())
        let daysSinceGoalStart = calendar.dateComponents([.day], from: normalizedStart, to: today).day ?? 0
        let isRecentlyReset = daysSinceGoalStart <= 2 && localCompletions.isEmpty
        
        if localCompletions.isEmpty {
            if isRecentlyReset {
                print("   ⚠️ Goal appears to be recently reset (started \(daysSinceGoalStart) day(s) ago, targetDays: \(targetDays))")
                print("   ⚠️ Skipping Firebase sync to avoid syncing old records that might fall within the new goal's date range")
                print("   ⚠️ This prevents incorrect progress calculation when targetDays is large")
            } else {
                print("   ℹ️ No local completion records, syncing from Firebase...")
                print("   ℹ️ Date range: [\(formatter.string(from: normalizedStart)), \(formatter.string(from: endDate)))")
                Task.detached {
                    await self.syncCompletionsFromFirebase(
                        userId: userId,
                        startDate: normalizedStart,
                        endDate: endDate,
                        modelContext: modelContext
                    )
                }
            }
        } else {
            print("   ℹ️ Skipping Firebase sync - have local data (\(localCompletions.count) records)")
        }
        
        return localCompletedCount
    }
    
    /// Get completed days from local SwiftData
    /// - Parameters:
    ///   - userId: User ID
    ///   - startDate: Start date (inclusive)
    ///   - endDate: End date (exclusive)
    ///   - modelContext: SwiftData ModelContext
    /// - Returns: Array of DailyCompletion records in the date range
    private func getLocalCompletions(userId: String, startDate: Date, endDate: Date, modelContext: ModelContext) -> [DailyCompletion] {
        let descriptor = FetchDescriptor<DailyCompletion>(
            predicate: #Predicate { completion in
                completion.userId == userId &&
                completion.date >= startDate &&
                completion.date < endDate
            },
            sortBy: [SortDescriptor(\.date)]
        )
        
        do {
            return try modelContext.fetch(descriptor)
        } catch {
            print("❌ ProgressCalculationService: Failed to fetch local completions - \(error.localizedDescription)")
            return []
        }
    }
    
    /// Sync completions from Firebase to local SwiftData
    /// Note: endDate is exclusive for local query, but Firebase uses inclusive endDate
    /// So we pass endDate - 1 day to Firebase to match the exclusive semantics
    private func syncCompletionsFromFirebase(userId: String, startDate: Date, endDate: Date, modelContext: ModelContext) async {
        let calendar = Calendar.current
        // Firebase uses inclusive endDate, so subtract 1 day to match exclusive semantics
        let firebaseEndDate = calendar.date(byAdding: .day, value: -1, to: endDate) ?? endDate
        
        await withCheckedContinuation { continuation in
            databaseService.fetchDailyCompletions(userId: userId, startDate: startDate, endDate: firebaseEndDate) { result in
                switch result {
                case .success(let firebaseCompletions):
                    let formatter = DateFormatter()
                    formatter.dateFormat = "yyyy-MM-dd"
                    print("🔄 ProgressCalculationService: Syncing \(firebaseCompletions.count) completion records from Firebase")
                    if !firebaseCompletions.isEmpty {
                        let dates = firebaseCompletions.keys.map { formatter.string(from: $0) }.sorted()
                        print("   Firebase completion dates: \(dates.prefix(10).joined(separator: ", "))\(dates.count > 10 ? "..." : "")")
                    }
                    
                    // Merge with local data
                    for (date, isCompleted) in firebaseCompletions {
                        print("   🔄 Syncing Firebase completion: \(formatter.string(from: date)) = \(isCompleted)")
                        self.saveOrUpdateCompletion(
                            userId: userId,
                            date: date,
                            isCompleted: isCompleted,
                            modelContext: modelContext
                        )
                    }
                    continuation.resume()
                    
                case .failure(let error):
                    print("⚠️ ProgressCalculationService: Failed to sync from Firebase - \(error.localizedDescription)")
                    continuation.resume()
                }
            }
        }
    }
    
    // MARK: - Mark Day as Completed
    
    /// Mark a day as completed and sync to Firebase
    /// - Parameters:
    ///   - userId: User ID
    ///   - date: Date to mark as completed
    ///   - modelContext: SwiftData ModelContext for local save
    ///   - shouldNotify: Whether to notify listeners immediately (default: true for past dates, false for today)
    func markDayAsCompleted(userId: String, date: Date, modelContext: ModelContext, shouldNotify: Bool? = nil) {
        let calendar = Calendar.current
        let normalizedDate = calendar.startOfDay(for: date)
        let today = calendar.startOfDay(for: Date())
        
        // Save to local SwiftData
        saveOrUpdateCompletion(userId: userId, date: normalizedDate, isCompleted: true, modelContext: modelContext)
        
        // Only notify if:
        // 1. shouldNotify is explicitly true, OR
        // 2. shouldNotify is nil (default) and the date is NOT today (past dates can update immediately)
        // For today, progress should only update at midnight settlement
        let isToday = calendar.isDate(normalizedDate, inSameDayAs: today)
        let notify = shouldNotify ?? !isToday
        
        if notify {
            // Notify listeners for immediate UI update (only for past dates)
            NotificationCenter.default.post(name: .dayCompletionDidChange, object: nil)
        }
        
        // Sync to Firebase (background)
        syncCompletionToFirebase(userId: userId, date: normalizedDate, isCompleted: true)
    }
    
    /// Mark a day as not completed and sync to Firebase
    /// - Parameters:
    ///   - userId: User ID
    ///   - date: Date to mark as not completed
    ///   - modelContext: SwiftData ModelContext for local save
    ///   - shouldNotify: Whether to notify listeners immediately (default: true for past dates, false for today)
    func markDayAsNotCompleted(userId: String, date: Date, modelContext: ModelContext, shouldNotify: Bool? = nil) {
        let calendar = Calendar.current
        let normalizedDate = calendar.startOfDay(for: date)
        let today = calendar.startOfDay(for: Date())
        
        // Save to local SwiftData
        saveOrUpdateCompletion(userId: userId, date: normalizedDate, isCompleted: false, modelContext: modelContext)
        
        // Only notify if:
        // 1. shouldNotify is explicitly true, OR
        // 2. shouldNotify is nil (default) and the date is NOT today (past dates can update immediately)
        // For today, progress should only update at midnight settlement
        let isToday = calendar.isDate(normalizedDate, inSameDayAs: today)
        let notify = shouldNotify ?? !isToday
        
        if notify {
            // Notify listeners for immediate UI update (only for past dates)
            NotificationCenter.default.post(name: .dayCompletionDidChange, object: nil)
        }
        
        // Sync to Firebase (background)
        syncCompletionToFirebase(userId: userId, date: normalizedDate, isCompleted: false)
    }
    
    /// Save or update a DailyCompletion in local SwiftData
    private func saveOrUpdateCompletion(userId: String, date: Date, isCompleted: Bool, modelContext: ModelContext) {
        let calendar = Calendar.current
        let normalizedDate = calendar.startOfDay(for: date)
        
        // Check if completion already exists
        let descriptor = FetchDescriptor<DailyCompletion>(
            predicate: #Predicate { completion in
                completion.userId == userId &&
                completion.date == normalizedDate
            }
        )
        
        do {
            let existing = try modelContext.fetch(descriptor).first
            
            if let existing = existing {
                // Update existing
                existing.isCompleted = isCompleted
                existing.completedAt = isCompleted ? Date() : nil
            } else {
                // Create new
                let completion = DailyCompletion(
                    userId: userId,
                    date: normalizedDate,
                    isCompleted: isCompleted,
                    completedAt: isCompleted ? Date() : nil
                )
                modelContext.insert(completion)
            }
            
            try modelContext.save()
        } catch {
            print("❌ ProgressCalculationService: Failed to save completion to local - \(error.localizedDescription)")
        }
    }
    
    // MARK: - Firebase Sync
    
    /// Sync completion status to Firebase
    /// - Parameters:
    ///   - userId: User ID
    ///   - date: Date to sync
    ///   - isCompleted: Completion status
    func syncCompletionToFirebase(userId: String, date: Date, isCompleted: Bool) {
        databaseService.saveDailyCompletion(userId: userId, date: date, isCompleted: isCompleted) { result in
            switch result {
            case .success:
                print("✅ ProgressCalculationService: Synced completion to Firebase - Date: \(self.dateToKey(date)), Completed: \(isCompleted)")
            case .failure(let error):
                print("⚠️ ProgressCalculationService: Failed to sync to Firebase - \(error.localizedDescription)")
                // Note: Local data is already saved, Firebase sync will retry later if needed
            }
        }
    }
    
    // MARK: - Helper
    
    private func dateToKey(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: date)
    }
}

