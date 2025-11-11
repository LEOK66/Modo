import Foundation
import SwiftData

extension Notification.Name {
    static let dayCompletionDidChange = Notification.Name("dayCompletionDidChange")
}

class ProgressCalculationService {
    static let shared = ProgressCalculationService()
    private let databaseService = DatabaseService.shared
    
    private init() {}
    
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
    ///   - bufferDays: Buffer days (to subtract from target)
    /// - Returns: Progress percentage (0.0-1.0, capped at 1.0)
    func calculateProgress(completedDays: Int, targetDays: Int, bufferDays: Int) -> Double {
        let effectiveDays = max(1, targetDays - bufferDays) // Avoid division by zero
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
        
        // Calculate end date
        guard let endDate = calendar.date(byAdding: .day, value: targetDays - 1, to: normalizedStart) else {
            return 0
        }
        
        // First, try to get from local SwiftData
        let localCompletions = getLocalCompletions(userId: userId, startDate: normalizedStart, endDate: endDate, modelContext: modelContext)
        let localCompletedCount = localCompletions.filter { $0.isCompleted }.count
        
        // Background sync with Firebase (non-blocking)
        Task.detached {
            await self.syncCompletionsFromFirebase(
                userId: userId,
                startDate: normalizedStart,
                endDate: endDate,
                modelContext: modelContext
            )
        }
        
        return localCompletedCount
    }
    
    /// Get completed days from local SwiftData
    private func getLocalCompletions(userId: String, startDate: Date, endDate: Date, modelContext: ModelContext) -> [DailyCompletion] {
        let descriptor = FetchDescriptor<DailyCompletion>(
            predicate: #Predicate { completion in
                completion.userId == userId &&
                completion.date >= startDate &&
                completion.date <= endDate
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
    private func syncCompletionsFromFirebase(userId: String, startDate: Date, endDate: Date, modelContext: ModelContext) async {
        await withCheckedContinuation { continuation in
            databaseService.fetchDailyCompletions(userId: userId, startDate: startDate, endDate: endDate) { result in
                switch result {
                case .success(let firebaseCompletions):
                    // Merge with local data
                    for (date, isCompleted) in firebaseCompletions {
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
    func markDayAsCompleted(userId: String, date: Date, modelContext: ModelContext) {
        let calendar = Calendar.current
        let normalizedDate = calendar.startOfDay(for: date)
        
        // Save to local SwiftData
        saveOrUpdateCompletion(userId: userId, date: normalizedDate, isCompleted: true, modelContext: modelContext)
        
        // Notify listeners for immediate UI update
        NotificationCenter.default.post(name: .dayCompletionDidChange, object: nil)
        
        // Sync to Firebase (background)
        syncCompletionToFirebase(userId: userId, date: normalizedDate, isCompleted: true)
    }
    
    /// Mark a day as not completed and sync to Firebase
    /// - Parameters:
    ///   - userId: User ID
    ///   - date: Date to mark as not completed
    ///   - modelContext: SwiftData ModelContext for local save
    func markDayAsNotCompleted(userId: String, date: Date, modelContext: ModelContext) {
        let calendar = Calendar.current
        let normalizedDate = calendar.startOfDay(for: date)
        
        // Save to local SwiftData
        saveOrUpdateCompletion(userId: userId, date: normalizedDate, isCompleted: false, modelContext: modelContext)
        
        // Notify listeners for immediate UI update
        NotificationCenter.default.post(name: .dayCompletionDidChange, object: nil)
        
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

