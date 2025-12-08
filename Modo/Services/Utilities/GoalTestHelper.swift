import Foundation
import SwiftData
import FirebaseAuth

/// Helper class for testing goal functionality
/// Creates test goal settings and completion records for testing purposes
class GoalTestHelper {
    private static let progressService = ProgressCalculationService.shared
    
    /// Create test goal with specified parameters
    /// - Parameters:
    ///   - targetDays: Target number of days for the goal
    ///   - completedDays: Number of completed days to create
    ///   - startDate: Start date for the goal (defaults to today - completedDays + 1)
    ///   - userId: User ID (optional, uses current user if nil)
    ///   - modelContext: SwiftData ModelContext
    static func createTestGoal(
        targetDays: Int,
        completedDays: Int,
        startDate: Date? = nil,
        userId: String? = nil,
        modelContext: ModelContext
    ) {
        guard targetDays > 0, completedDays >= 0 else { return }
        
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let actualUserId = userId ?? Auth.auth().currentUser?.uid ?? "test_user"
        
        // Determine start date
        let goalStartDate: Date
        if let providedStartDate = startDate {
            goalStartDate = calendar.startOfDay(for: providedStartDate)
        } else {
            // Default: start from (today - completedDays + 1) so completedDays are within the goal period
            goalStartDate = calendar.date(byAdding: .day, value: -(completedDays - 1), to: today) ?? today
        }
        
        // Calculate end date for completion records
        let endDateForCompletions = calendar.date(byAdding: .day, value: completedDays - 1, to: goalStartDate) ?? goalStartDate
        
        print("🧪 GoalTestHelper: Creating test goal")
        print("   Goal Start Date: \(goalStartDate)")
        print("   Target Days: \(targetDays)")
        print("   Completed Days: \(completedDays)")
        print("   Completion Range: \(goalStartDate) to \(endDateForCompletions)")
        
        // Update or create UserProfile
        do {
            let profileDescriptor = FetchDescriptor<UserProfile>(
                predicate: #Predicate { profile in
                    profile.userId == actualUserId
                }
            )
            
            let userProfile: UserProfile
            if let existing = try modelContext.fetch(profileDescriptor).first {
                userProfile = existing
            } else {
                userProfile = UserProfile(userId: actualUserId)
                modelContext.insert(userProfile)
            }
            
            // Update goal settings
            userProfile.goalStartDate = goalStartDate
            userProfile.targetDays = targetDays
            // Set a default goal if not set
            if userProfile.goal == nil {
                userProfile.goal = "keep_healthy"
            }
            
            print("✅ GoalTestHelper: Updated UserProfile - goalStartDate: \(goalStartDate), targetDays: \(targetDays)")
            
            // Create completion records
            if completedDays > 0 {
                var currentDate = goalStartDate
                var createdCount = 0
                
                while currentDate <= endDateForCompletions && createdCount < completedDays {
                    let normalizedDate = calendar.startOfDay(for: currentDate)
                    
                    // Check if completion already exists
                    let descriptor = FetchDescriptor<DailyCompletion>(
                        predicate: #Predicate { completion in
                            completion.userId == actualUserId && completion.date == normalizedDate
                        }
                    )
                    
                    // Use ProgressCalculationService to mark day as completed
                    // This ensures consistency with the actual completion logic
                    // shouldNotify: true to immediately update UI in test mode
                    progressService.markDayAsCompleted(
                        userId: actualUserId,
                        date: normalizedDate,
                        modelContext: modelContext,
                        shouldNotify: true
                    )
                    print("✅ GoalTestHelper: Marked day as completed for \(normalizedDate)")
                    
                    createdCount += 1
                    
                    // Move to next day
                    guard let nextDate = calendar.date(byAdding: .day, value: 1, to: currentDate) else {
                        break
                    }
                    currentDate = nextDate
                }
                
                print("✅ GoalTestHelper: Created \(createdCount) completion records")
            }
            
            // Save changes
            try modelContext.save()
            print("✅ GoalTestHelper: Saved test goal successfully")
            
            // Note: Notification is already sent by markDayAsCompleted with shouldNotify: true
            // No need to send additional notification here
        } catch {
            print("❌ GoalTestHelper: Failed to create test goal - \(error.localizedDescription)")
        }
    }
    
    /// Clear test goal data (reset goalStartDate and targetDays, clear completion records)
    /// - Parameters:
    ///   - userId: User ID (optional, uses current user if nil)
    ///   - modelContext: SwiftData ModelContext
    static func clearTestGoal(
        userId: String? = nil,
        modelContext: ModelContext
    ) {
        let actualUserId = userId ?? Auth.auth().currentUser?.uid ?? "test_user"
        
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let startDate = calendar.date(byAdding: .day, value: -365, to: today) ?? today
        
        // Clear completion records
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
            
            // Reset goal settings
            let profileDescriptor = FetchDescriptor<UserProfile>(
                predicate: #Predicate { profile in
                    profile.userId == actualUserId
                }
            )
            if let userProfile = try modelContext.fetch(profileDescriptor).first {
                userProfile.goalStartDate = nil
                userProfile.targetDays = nil
            }
            
            try modelContext.save()
            print("🗑️ GoalTestHelper: Cleared all test goal data")
            
            // Post notification to update UI
            NotificationCenter.default.post(name: .dayCompletionDidChange, object: nil)
        } catch {
            print("❌ GoalTestHelper: Failed to clear test goal - \(error.localizedDescription)")
        }
    }
    
    /// Get current goal status
    /// - Parameters:
    ///   - userId: User ID (optional, uses current user if nil)
    ///   - modelContext: SwiftData ModelContext
    /// - Returns: Tuple with (goalStartDate, targetDays, completedDays, isExpired)
    static func getGoalStatus(
        userId: String? = nil,
        modelContext: ModelContext
    ) -> (goalStartDate: Date?, targetDays: Int?, completedDays: Int, isExpired: Bool) {
        let actualUserId = userId ?? Auth.auth().currentUser?.uid ?? "test_user"
        
        do {
            let profileDescriptor = FetchDescriptor<UserProfile>(
                predicate: #Predicate { profile in
                    profile.userId == actualUserId
                }
            )
            
            guard let userProfile = try modelContext.fetch(profileDescriptor).first else {
                return (nil, nil, 0, false)
            }
            
            let goalStartDate = userProfile.goalStartDate
            let targetDays = userProfile.targetDays
            
            // Calculate completed days
            var completedDays = 0
            var isExpired = false
            
            if let startDate = goalStartDate, let target = targetDays {
                let calendar = Calendar.current
                let normalizedStart = calendar.startOfDay(for: startDate)
                let today = calendar.startOfDay(for: Date())
                
                guard let endDate = calendar.date(byAdding: .day, value: target, to: normalizedStart) else {
                    return (goalStartDate, targetDays, 0, false)
                }
                
                isExpired = endDate < today
                
                // Query completion records: startDate <= date < endDate (exclusive)
                // DayCompletionService ensures today won't be marked as completed until midnight,
                // so even if today is in the range, it won't affect the count
                let completionDescriptor = FetchDescriptor<DailyCompletion>(
                    predicate: #Predicate { completion in
                        completion.userId == actualUserId &&
                        completion.date >= normalizedStart &&
                        completion.date < endDate &&
                        completion.isCompleted == true
                    }
                )
                
                let completions = try modelContext.fetch(completionDescriptor)
                completedDays = completions.count
            }
            
            return (goalStartDate, targetDays, completedDays, isExpired)
        } catch {
            print("❌ GoalTestHelper: Failed to get goal status - \(error.localizedDescription)")
            return (nil, nil, 0, false)
        }
    }
}

