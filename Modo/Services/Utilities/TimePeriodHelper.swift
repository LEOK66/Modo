import Foundation

// MARK: - Time Period Enum

/// Represents different time periods of the day
enum TimePeriod: String, CaseIterable {
    case morning      // 6:00 - 12:00
    case afternoon    // 12:00 - 18:00
    case evening      // 18:00 - 22:00
    case night        // 22:00 - 6:00 (次日)
}

// MARK: - Time Period Helper

/// Helper class for time period calculations
struct TimePeriodHelper {
    /// Get the time period for a given date/time
    /// - Parameter date: The date to check
    /// - Returns: The time period (morning, afternoon, evening, night)
    static func timePeriod(for date: Date) -> TimePeriod {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: date)
        
        switch hour {
        case 6..<12:
            return .morning
        case 12..<18:
            return .afternoon
        case 18..<22:
            return .evening
        default: // 22:00 - 5:59 (next day)
            return .night
        }
    }
    
    /// Check if a date is before 7 AM
    /// - Parameter date: The date to check
    /// - Returns: True if the time is before 7:00 AM
    static func isBefore7AM(_ date: Date) -> Bool {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: date)
        return hour < 7
    }
    
    /// Check if a date is after midnight (between 00:00 and 6:00)
    /// - Parameter date: The date to check
    /// - Returns: True if the time is after midnight and before 6:00 AM
    static func isAfterMidnight(_ date: Date) -> Bool {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: date)
        return hour >= 0 && hour < 6
    }
    
    /// Check if a date is after 11 PM (23:00)
    /// - Parameter date: The date to check
    /// - Returns: True if the time is 23:00 or later
    static func isAfter11PM(_ date: Date) -> Bool {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: date)
        return hour >= 23
    }
    
    /// Get all time periods that have tasks completed on a given date
    /// - Parameters:
    ///   - date: The date to check
    ///   - tasks: Array of completed tasks for that date
    /// - Returns: Set of time periods that have at least one completed task
    static func completedTimePeriods(
        for date: Date,
        tasks: [TaskItem]
    ) -> Set<TimePeriod> {
        var periods: Set<TimePeriod> = []
        
        for task in tasks {
            guard task.isDone else { continue }
            let period = timePeriod(for: task.timeDate)
            periods.insert(period)
        }
        
        return periods
    }
    
    /// Check if all 4 time periods have completed tasks on a given date
    /// - Parameters:
    ///   - date: The date to check
    ///   - tasks: Array of completed tasks for that date
    /// - Returns: True if tasks were completed in all 4 time periods
    static func hasAllTimePeriods(
        for date: Date,
        tasks: [TaskItem]
    ) -> Bool {
        let periods = completedTimePeriods(for: date, tasks: tasks)
        return periods.count == 4
    }
}

