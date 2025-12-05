import Foundation

// MARK: - Weekly Completion Data

/// Represents weekly completion data for achievement statistics
struct WeeklyCompletion {
    let weekStartDate: Date // Monday of the week
    let completedCategories: Set<String> // ["diet", "fitness", "others"]
    let weekendOnly: Bool // Whether tasks were only completed on weekends
    
    init(
        weekStartDate: Date,
        completedCategories: Set<String>,
        weekendOnly: Bool
    ) {
        self.weekStartDate = weekStartDate
        self.completedCategories = completedCategories
        self.weekendOnly = weekendOnly
    }
}

// MARK: - Week Helper

/// Helper class for week-based calculations
struct WeekHelper {
    /// Get the start date (Monday) of the week for a given date
    /// - Parameter date: The date to get the week start for
    /// - Returns: Monday of the week (start of day)
    static func weekStartDate(for date: Date) -> Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return calendar.date(from: components) ?? calendar.startOfDay(for: date)
    }
    
    /// Check if a date is a weekend (Saturday or Sunday)
    /// - Parameter date: The date to check
    /// - Returns: True if the date is Saturday or Sunday
    static func isWeekend(_ date: Date) -> Bool {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: date)
        // weekday: 1 = Sunday, 2 = Monday, ..., 7 = Saturday
        return weekday == 1 || weekday == 7
    }
    
    /// Check if a date is a weekday (Monday to Friday)
    /// - Parameter date: The date to check
    /// - Returns: True if the date is Monday through Friday
    static func isWeekday(_ date: Date) -> Bool {
        return !isWeekend(date)
    }
    
    /// Group tasks by week and calculate weekly completion data
    /// - Parameter tasksByDate: Dictionary of dates to tasks
    /// - Returns: Dictionary mapping week start date to WeeklyCompletion
    static func calculateWeeklyCompletions(
        tasksByDate: [Date: [TaskItem]]
    ) -> [Date: WeeklyCompletion] {
        let calendar = Calendar.current
        var weeklyData: [Date: WeeklyCompletion] = [:]
        
        // Group tasks by week
        var tasksByWeek: [Date: [TaskItem]] = [:]
        
        for (date, tasks) in tasksByDate {
            let weekStart = weekStartDate(for: date)
            let normalizedWeekStart = calendar.startOfDay(for: weekStart)
            
            if tasksByWeek[normalizedWeekStart] == nil {
                tasksByWeek[normalizedWeekStart] = []
            }
            tasksByWeek[normalizedWeekStart]?.append(contentsOf: tasks)
        }
        
        // Calculate completion data for each week
        for (weekStart, weekTasks) in tasksByWeek {
            var completedCategories: Set<String> = []
            var weekdayTaskDates: Set<Date> = []
            var weekendTaskDates: Set<Date> = []
            
            // Analyze completed tasks
            for task in weekTasks {
                guard task.isDone else { continue }
                
                // Track completed categories
                switch task.category {
                case .diet:
                    completedCategories.insert("diet")
                case .fitness:
                    completedCategories.insert("fitness")
                case .others:
                    completedCategories.insert("others")
                }
                
                // Track task dates
                let taskDate = calendar.startOfDay(for: task.timeDate)
                if isWeekend(taskDate) {
                    weekendTaskDates.insert(taskDate)
                } else {
                    weekdayTaskDates.insert(taskDate)
                }
            }
            
            // Check if weekend only (has weekend tasks but no weekday tasks)
            let weekendOnly = !weekendTaskDates.isEmpty && weekdayTaskDates.isEmpty
            
            let completion = WeeklyCompletion(
                weekStartDate: weekStart,
                completedCategories: completedCategories,
                weekendOnly: weekendOnly
            )
            
            weeklyData[weekStart] = completion
        }
        
        return weeklyData
    }
    
    /// Calculate consecutive weeks streak meeting a condition
    /// - Parameters:
    ///   - weeklyCompletions: Dictionary of week start dates to WeeklyCompletion
    ///   - condition: Closure that returns true if the week meets the condition
    /// - Returns: Number of consecutive weeks (from most recent week backwards)
    static func calculateConsecutiveWeeksStreak(
        weeklyCompletions: [Date: WeeklyCompletion],
        condition: (WeeklyCompletion) -> Bool
    ) -> Int {
        let calendar = Calendar.current
        let today = Date()
        let currentWeekStart = weekStartDate(for: today)
        let normalizedCurrentWeekStart = calendar.startOfDay(for: currentWeekStart)
        
        var streak = 0
        var currentWeek = normalizedCurrentWeekStart
        
        // Go backwards week by week
        for _ in 0..<52 { // Max 52 weeks lookback
            guard let weekCompletion = weeklyCompletions[currentWeek] else {
                // Week not found - check if we should break or continue
                // If this is the current week and it's not complete yet, don't break
                // Otherwise, break the streak
                break
            }
            
            if condition(weekCompletion) {
                streak += 1
                // Move to previous week
                currentWeek = calendar.date(byAdding: .weekOfYear, value: -1, to: currentWeek) ?? currentWeek
            } else {
                // Condition not met, break streak
                break
            }
        }
        
        return streak
    }
}

