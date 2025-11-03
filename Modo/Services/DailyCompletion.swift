import Foundation
import SwiftData

@Model
final class DailyCompletion {
    var userId: String
    var date: Date  // normalized to start of day
    var isCompleted: Bool
    var completedAt: Date?
    
    init(userId: String, date: Date, isCompleted: Bool, completedAt: Date? = nil) {
        self.userId = userId
        // Normalize date to start of day
        let calendar = Calendar.current
        self.date = calendar.startOfDay(for: date)
        self.isCompleted = isCompleted
        self.completedAt = completedAt
    }
}

