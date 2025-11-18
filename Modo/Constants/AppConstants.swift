import Foundation

enum AppConstants {
    /// Date range for calendar and task management
    enum DateRange {
        static let pastMonths: Int = 12
        static let futureMonths: Int = 3
    }
    
    /// Cache configuration
    enum Cache {
        static let windowMonths: Int = 1
    }
    
    /// Task generation constants
    enum TaskGeneration {
        static let defaultTasks = ["fitness", "breakfast", "lunch", "dinner"]
    }
}

