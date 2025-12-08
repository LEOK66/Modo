import Foundation
import SwiftData
import FirebaseAuth

/// Helper class for testing streak functionality
/// Creates fake DailyCompletion records for testing purposes
class StreakTestHelper {
    private static let progressService = ProgressCalculationService.shared
    
    /// Create test completion records for a streak of specified days
    /// - Parameters:
    ///   - streakDays: Number of consecutive completed days (ending today or yesterday)
    ///   - includeToday: Whether to include today in the streak (default: false, since we test past days)
    ///   - userId: User ID (optional, uses current user if nil)
    ///   - modelContext: SwiftData ModelContext
    static func createTestStreak(
        streakDays: Int,
        includeToday: Bool = false,
        userId: String? = nil,
        modelContext: ModelContext
    ) {
        guard streakDays > 0 else { return }
        
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let actualUserId = userId ?? Auth.auth().currentUser?.uid ?? "test_user"
        
        // Determine start date
        let endDate = includeToday ? today : calendar.date(byAdding: .day, value: -1, to: today) ?? today
        let startDate = calendar.date(byAdding: .day, value: -(streakDays - 1), to: endDate) ?? endDate
        
        print("🧪 StreakTestHelper: Creating test streak from \(startDate) to \(endDate) (\(streakDays) days)")
        
        // Create completion records for each day
        var currentDate = startDate
        while currentDate <= endDate {
            let normalizedDate = calendar.startOfDay(for: currentDate)
            
            do {
                // Use ProgressCalculationService to mark day as completed
                // This ensures consistency with the actual completion logic
                // shouldNotify: true to immediately update UI in test mode
                progressService.markDayAsCompleted(
                    userId: actualUserId,
                    date: normalizedDate,
                    modelContext: modelContext,
                    shouldNotify: true
                )
                print("✅ StreakTestHelper: Marked day as completed for \(normalizedDate)")
                
                // Move to next day
                guard let nextDate = calendar.date(byAdding: .day, value: 1, to: currentDate) else {
                    break
                }
                currentDate = nextDate
            } catch {
                print("❌ StreakTestHelper: Failed to create test streak - \(error.localizedDescription)")
                break
            }
        }
        
        // Save changes
        do {
            try modelContext.save()
            print("✅ StreakTestHelper: Saved test streak successfully for userId: \(actualUserId)")
            print("✅ StreakTestHelper: Created \(streakDays) days from \(startDate) to \(endDate)")
            
            // Note: Notification is already sent by markDayAsCompleted with shouldNotify: true
            // No need to send additional notification here
        } catch {
            print("❌ StreakTestHelper: Failed to save test streak - \(error.localizedDescription)")
        }
    }
    
    /// Clear all test completion records for a user
    /// - Parameters:
    ///   - userId: User ID (optional, uses current user if nil)
    ///   - modelContext: SwiftData ModelContext
    static func clearTestStreak(
        userId: String? = nil,
        modelContext: ModelContext
    ) {
        let actualUserId = userId ?? Auth.auth().currentUser?.uid ?? "test_user"
        
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let startDate = calendar.date(byAdding: .day, value: -365, to: today) ?? today
        
        let descriptor = FetchDescriptor<DailyCompletion>(
            predicate: #Predicate { completion in
                completion.userId == actualUserId &&
                completion.date >= startDate &&
                completion.date <= today
            }
        )
        
        do {
            let completions = try modelContext.fetch(descriptor)
            for completion in completions {
                modelContext.delete(completion)
            }
            try modelContext.save()
            print("🗑️ StreakTestHelper: Cleared all test completions")
            
            // Post notification to update UI
            NotificationCenter.default.post(name: .dayCompletionDidChange, object: nil)
        } catch {
            print("❌ StreakTestHelper: Failed to clear test streak - \(error.localizedDescription)")
        }
    }
}

