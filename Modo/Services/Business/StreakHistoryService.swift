import Foundation
import FirebaseDatabase

// MARK: - Streak History Model

/// Represents streak history for tracking restarts and comebacks
struct StreakHistory: Codable, Equatable {
    var lastStreak: Int
    var maxStreak: Int
    var restartCount: Int
    var lastBreakDate: Date?
    
    init(
        lastStreak: Int = 0,
        maxStreak: Int = 0,
        restartCount: Int = 0,
        lastBreakDate: Date? = nil
    ) {
        self.lastStreak = lastStreak
        self.maxStreak = maxStreak
        self.restartCount = restartCount
        self.lastBreakDate = lastBreakDate
    }
    
    /// Encode to Firebase format
    func encodeToFirebase() -> [String: Any] {
        var data: [String: Any] = [
            "lastStreak": lastStreak,
            "maxStreak": maxStreak,
            "restartCount": restartCount
        ]
        
        if let lastBreakDate = lastBreakDate {
            data["lastBreakDate"] = Int64(lastBreakDate.timeIntervalSince1970 * 1000)
        }
        
        return data
    }
    
    /// Decode from Firebase format
    static func decodeFromFirebase(_ data: [String: Any]) -> StreakHistory? {
        guard let lastStreak = data["lastStreak"] as? Int,
              let maxStreak = data["maxStreak"] as? Int,
              let restartCount = data["restartCount"] as? Int else {
            return nil
        }
        
        var lastBreakDate: Date?
        if let timestamp = data["lastBreakDate"] as? Int64 {
            lastBreakDate = Date(timeIntervalSince1970: Double(timestamp) / 1000.0)
        } else if let timestamp = data["lastBreakDate"] as? Int {
            lastBreakDate = Date(timeIntervalSince1970: TimeInterval(timestamp) / 1000.0)
        }
        
        return StreakHistory(
            lastStreak: lastStreak,
            maxStreak: maxStreak,
            restartCount: restartCount,
            lastBreakDate: lastBreakDate
        )
    }
}

// MARK: - Streak History Service

/// Service for tracking and managing streak history
class StreakHistoryService {
    private let database = Database.database().reference()
    
    /// Update streak history when streak changes
    /// - Parameters:
    ///   - userId: User ID
    ///   - currentStreak: Current streak value
    ///   - previousStreak: Previous streak value (from last check)
    /// - Returns: Updated streak history
    func updateStreakHistory(
        userId: String,
        currentStreak: Int,
        previousStreak: Int?
    ) async throws -> StreakHistory {
        // Get current history
        let currentHistory = try await getStreakHistory(userId: userId)
        
        var updatedHistory = currentHistory
        
        // Check if streak was broken (current < previous)
        if let previousStreak = previousStreak, currentStreak < previousStreak {
            // Streak was broken
            updatedHistory.restartCount += 1
            updatedHistory.lastBreakDate = Date()
            updatedHistory.lastStreak = previousStreak
            
            // Update max streak if previous was higher
            if previousStreak > updatedHistory.maxStreak {
                updatedHistory.maxStreak = previousStreak
            }
        } else {
            // Streak is continuing or increasing
            updatedHistory.lastStreak = currentStreak
            
            // Update max streak if current is higher
            if currentStreak > updatedHistory.maxStreak {
                updatedHistory.maxStreak = currentStreak
            }
        }
        
        // Save to Firebase
        try await saveStreakHistory(userId: userId, history: updatedHistory)
        
        return updatedHistory
    }
    
    /// Get streak history for a user
    /// - Parameter userId: User ID
    /// - Returns: StreakHistory (defaults to empty if not found)
    func getStreakHistory(userId: String) async throws -> StreakHistory {
        let path = "users/\(userId)/streakHistory"
        
        return try await withCheckedThrowingContinuation { continuation in
            database.child(path).observeSingleEvent(of: .value) { snapshot in
                guard snapshot.exists(),
                      let data = snapshot.value as? [String: Any],
                      let history = StreakHistory.decodeFromFirebase(data) else {
                    // Return default history if not found
                    continuation.resume(returning: StreakHistory())
                    return
                }
                
                continuation.resume(returning: history)
            }
        }
    }
    
    /// Save streak history to Firebase
    /// - Parameters:
    ///   - userId: User ID
    ///   - history: StreakHistory to save
    private func saveStreakHistory(userId: String, history: StreakHistory) async throws {
        let path = "users/\(userId)/streakHistory"
        let data = history.encodeToFirebase()
        
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            database.child(path).setValue(data) { error, _ in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }
    
    /// Calculate streak comeback value
    /// - Parameters:
    ///   - currentStreak: Current streak value
    ///   - history: Streak history
    /// - Returns: Comeback streak value (current streak if >= 7 and had a break before)
    func calculateStreakComeback(currentStreak: Int, history: StreakHistory) -> Int {
        // Comeback is triggered if:
        // 1. Current streak >= 7
        // 2. User had a break before (restartCount > 0 or lastBreakDate exists)
        if currentStreak >= 7 && (history.restartCount > 0 || history.lastBreakDate != nil) {
            return currentStreak
        }
        return 0
    }
}

