import Foundation
import SwiftData
import FirebaseAuth

/// Service for calculating and managing user streak (consecutive completed days)
///
/// Streak calculation rules:
/// - Counts consecutive days where all tasks were completed
/// - Skips days with no tasks (doesn't break streak)
/// - If today is not yet completed, calculates streak up to yesterday
/// - Uses DailyCompletion records to determine completion status
class StreakService {
    static let shared = StreakService()
    
    private let progressService: ProgressCalculationService
    private let completionRepository: CompletionRepository?
    
    /// Initialize with dependencies
    /// - Parameters:
    ///   - progressService: Progress calculation service (defaults to shared instance)
    ///   - completionRepository: Optional completion repository for local queries
    init(
        progressService: ProgressCalculationService = ProgressCalculationService.shared,
        completionRepository: CompletionRepository? = nil
    ) {
        self.progressService = progressService
        self.completionRepository = completionRepository
    }
    
    /// Calculate current streak count for a user
    ///
    /// Strategy: Strict mode - skip days with no tasks, break streak if tasks incomplete
    /// - Parameter userId: User ID
    /// - Parameter modelContext: SwiftData ModelContext for local queries
    /// - Parameter tasksByDate: Dictionary of dates to tasks (to check if day has tasks)
    /// - Returns: Current streak count (0 if no streak)
    func calculateStreak(
        userId: String,
        modelContext: ModelContext,
        tasksByDate: [Date: [TaskItem]]? = nil
    ) -> Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        // Check if today has completion record in database
        // Streak should only reflect saved database records, not real-time task status
        // Today's completion will only be saved at midnight settlement
        let todayCompletion = fetchCompletion(userId: userId, date: today, modelContext: modelContext)
        let todayHasCompletionRecord = todayCompletion != nil && todayCompletion?.isCompleted == true
        
        // Start from today only if today has a completion record in database
        let startDate = todayHasCompletionRecord
            ? today
            : calendar.date(byAdding: .day, value: -1, to: today) ?? today
        
        return calculateStreakFromDate(
            startDate: startDate,
            userId: userId,
            modelContext: modelContext,
            tasksByDate: tasksByDate
        )
    }
    
    /// Calculate streak starting from a specific date going backwards
    /// - Parameters:
    ///   - startDate: Date to start counting from (going backwards)
    ///   - userId: User ID
    ///   - modelContext: SwiftData ModelContext
    ///   - tasksByDate: Optional dictionary to check if days have tasks
    /// - Returns: Streak count
    private func calculateStreakFromDate(
        startDate: Date,
        userId: String,
        modelContext: ModelContext,
        tasksByDate: [Date: [TaskItem]]?
    ) -> Int {
        let calendar = Calendar.current
        var currentDate = calendar.startOfDay(for: startDate)
        var streakCount = 0
        let maxLookbackDays = 365 // Limit lookback to prevent infinite loops
        
        // Fetch completions for a reasonable date range (from maxLookbackDays ago to startDate)
        guard let rangeStartDate = calendar.date(byAdding: .day, value: -maxLookbackDays, to: startDate) else {
            return 0
        }
        
        // Get all completions in range (from rangeStartDate to startDate)
        let completions = fetchCompletions(
            userId: userId,
            startDate: rangeStartDate,  // Start from 365 days ago
            endDate: startDate,         // End at startDate (yesterday or today)
            modelContext: modelContext
        )
        
        // Create a map for quick lookup
        var completionMap: [Date: Bool] = [:]
        for completion in completions {
            completionMap[completion.date] = completion.isCompleted
        }
        
        // Go backwards from start date
        for _ in 0..<maxLookbackDays {
            // Check completion status
            if let isCompleted = completionMap[currentDate] {
                if isCompleted {
                    // Day is completed, continue streak
                    streakCount += 1
                } else {
                    // Day has tasks but not completed, break streak
                    break
                }
            } else {
                // No completion record - check if day has tasks
                if hasTasks(for: currentDate, tasksByDate: tasksByDate) {
                    // Has tasks but no completion record means not completed, break streak
                    break
                } else {
                    // No tasks, skip this day (don't break streak)
                    // Continue to previous day
                }
            }
            
            // Move to previous day
            guard let previousDate = calendar.date(byAdding: .day, value: -1, to: currentDate) else {
                break
            }
            currentDate = previousDate
        }
        
        return streakCount
    }
    
    /// Check if a date has tasks
    /// - Parameters:
    ///   - date: Date to check
    ///   - tasksByDate: Optional tasks dictionary
    /// - Returns: True if date has tasks
    private func hasTasks(for date: Date, tasksByDate: [Date: [TaskItem]]?) -> Bool {
        guard let tasksByDate = tasksByDate else { return false }
        let calendar = Calendar.current
        let normalizedDate = calendar.startOfDay(for: date)
        
        // Check exact date match
        if let tasks = tasksByDate[normalizedDate], !tasks.isEmpty {
            return true
        }
        
        // Also check if any task in dictionary matches this date
        for (taskDate, tasks) in tasksByDate where !tasks.isEmpty {
            if calendar.isDate(taskDate, inSameDayAs: normalizedDate) {
                return true
            }
        }
        
        return false
    }
    
    /// Fetch completion for a specific date
    private func fetchCompletion(userId: String, date: Date, modelContext: ModelContext) -> DailyCompletion? {
        if let repository = completionRepository {
            return repository.fetchLocalCompletion(userId: userId, date: date)
        }
        
        // Fallback: direct SwiftData query
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
            print("❌ StreakService: Failed to fetch completion - \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Fetch completions for a date range
    private func fetchCompletions(
        userId: String,
        startDate: Date,
        endDate: Date,
        modelContext: ModelContext
    ) -> [DailyCompletion] {
        if let repository = completionRepository {
            return repository.fetchLocalCompletions(userId: userId, startDate: startDate, endDate: endDate)
        }
        
        // Fallback: direct SwiftData query
        let calendar = Calendar.current
        let normalizedStart = calendar.startOfDay(for: startDate)
        let normalizedEnd = calendar.startOfDay(for: endDate)
        
        let descriptor = FetchDescriptor<DailyCompletion>(
            predicate: #Predicate { completion in
                completion.userId == userId &&
                completion.date >= normalizedStart &&
                completion.date <= normalizedEnd
            },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        
        do {
            return try modelContext.fetch(descriptor)
        } catch {
            print("❌ StreakService: Failed to fetch completions - \(error.localizedDescription)")
            return []
        }
    }
    
    /// Check if a milestone is reached (e.g., 7, 14, 30, 100 days)
    /// - Parameter streakCount: Current streak count
    /// - Returns: Milestone value if reached, nil otherwise
    func checkMilestone(streakCount: Int) -> Int? {
        let milestones = [7, 14, 30, 50, 100, 200, 365]
        return milestones.first { milestone in
            streakCount == milestone
        }
    }
}

