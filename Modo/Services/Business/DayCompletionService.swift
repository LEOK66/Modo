import Foundation
import SwiftData
import FirebaseAuth

/// Service for managing day completion evaluation and midnight settlement.
///
/// This service evaluates whether all tasks for a date are completed and syncs
/// the completion status to the database. It defers evaluation of the current day
/// until midnight to ensure accurate completion status.
class DayCompletionService {
    private let progressService = ProgressCalculationService.shared
    private var midnightTimer: Timer?
    
    /// Evaluates whether all tasks for a date are completed and syncs status.
    ///
    /// For the current day, evaluation is deferred until midnight. For past days,
    /// completion status is evaluated immediately and synced to the database.
    ///
    /// - Parameters:
    ///   - date: Date to evaluate completion for
    ///   - tasks: Tasks for the date
    ///   - userId: User ID for database operations
    ///   - modelContext: SwiftData model context for database operations
    func evaluateAndSyncDayCompletion(
        for date: Date,
        tasks: [TaskItem],
        userId: String,
        modelContext: ModelContext
    ) {
        let calendar = Calendar.current
        let normalizedDate = calendar.startOfDay(for: date)
        let today = calendar.startOfDay(for: Date())
        
        // Defer settlement for the current day until midnight
        if calendar.isDate(normalizedDate, inSameDayAs: today) {
            print("⏳ DayCompletionService: Deferring day completion settlement until midnight for \(normalizedDate)")
            return
        }
        
        // Only check when there's at least one task that day
        guard !tasks.isEmpty else {
            progressService.markDayAsNotCompleted(userId: userId, date: normalizedDate, modelContext: modelContext)
            return
        }
        
        let isCompleted = progressService.isDayCompleted(tasks: tasks, date: normalizedDate)
        if isCompleted {
            progressService.markDayAsCompleted(userId: userId, date: normalizedDate, modelContext: modelContext)
        } else {
            progressService.markDayAsNotCompleted(userId: userId, date: normalizedDate, modelContext: modelContext)
        }
    }
    
    /// Schedules a one-shot timer to evaluate today's completion at the next midnight.
    ///
    /// The timer automatically reschedules itself for subsequent midnights.
    /// The callback is called with the date that just ended (yesterday).
    ///
    /// - Parameter onMidnight: Callback called when midnight is reached, with the date that just ended
    func scheduleMidnightSettlement(onMidnight: @escaping (Date) -> Void) {
        cancelMidnightSettlement()
        
        let calendar = Calendar.current
        // Next midnight start of tomorrow
        guard let nextMidnight = calendar.nextDate(
            after: Date(),
            matching: DateComponents(hour: 0, minute: 0, second: 0),
            matchingPolicy: .nextTime,
            direction: .forward
        ) else { return }
        
        let interval = max(1, nextMidnight.timeIntervalSinceNow)
        midnightTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            let today = Date()
            let normalizedToday = calendar.startOfDay(for: today.addingTimeInterval(-60)) // small backoff
            // Evaluate settlement for the day that just ended
            onMidnight(normalizedToday)
            // Reschedule for the following midnight
            self?.scheduleMidnightSettlement(onMidnight: onMidnight)
        }
        RunLoop.main.add(midnightTimer!, forMode: .common)
        print("🕛 DayCompletionService: Scheduled midnight settlement at \(nextMidnight)")
    }
    
    /// Cancels any scheduled midnight settlement timer.
    ///
    /// Should be called when the view disappears or the service is deallocated.
    func cancelMidnightSettlement() {
        midnightTimer?.invalidate()
        midnightTimer = nil
    }
}

