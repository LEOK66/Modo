import Foundation

/// AI service utility class
/// 
/// Provides common utility methods for AI services to avoid code duplication
/// 
/// Naming conventions:
/// - All methods start with verbs
/// - Boolean methods use is/can/should prefix
class AIServiceUtils {
    
    // MARK: - Date Formatting
    
    /// Date formatter (thread-safe, lazy-loaded)
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current
        return formatter
    }()
    
    /// Time formatter
    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        formatter.timeZone = TimeZone.current
        return formatter
    }()
    
    /// Format date as string (YYYY-MM-DD)
    /// - Parameter date: Date to format
    /// - Returns: Formatted date string
    static func formatDate(_ date: Date) -> String {
        return dateFormatter.string(from: date)
    }
    
    /// Parse date string to Date object
    /// - Parameter dateString: Date string (YYYY-MM-DD)
    /// - Returns: Date object, or nil if parsing fails
    static func parseDate(_ dateString: String) -> Date? {
        return dateFormatter.date(from: dateString)
    }
    
    /// Format time as string (HH:MM AM/PM)
    /// - Parameter date: Date to format
    /// - Returns: Formatted time string
    static func formatTime(_ date: Date) -> String {
        return timeFormatter.string(from: date)
    }
    
    /// Parse time string to Date object
    /// - Parameter timeString: Time string (HH:MM AM/PM)
    /// - Returns: Date object, or nil if parsing fails
    static func parseTime(_ timeString: String) -> Date? {
        return timeFormatter.date(from: timeString)
    }
    
    // MARK: - Meal Time Utilities
    
    /// Get default time for meal type
    /// - Parameter mealType: Meal type ("breakfast", "lunch", "dinner", "snack")
    /// - Returns: Default time string
    static func getDefaultMealTime(for mealType: String) -> String {
        switch mealType.lowercased() {
        case "breakfast":
            return "8:00 AM"
        case "lunch":
            return "12:00 PM"
        case "dinner":
            return "6:00 PM"
        case "snack":
            return "3:00 PM"
        default:
            return "12:00 PM"
        }
    }
    
    /// Detect meal type from text
    /// - Parameter text: Text containing meal information
    /// - Returns: Meal type, or nil if not detected
    static func detectMealType(from text: String) -> String? {
        let lowercased = text.lowercased()
        if lowercased.contains("breakfast") {
            return "breakfast"
        } else if lowercased.contains("lunch") {
            return "lunch"
        } else if lowercased.contains("dinner") {
            return "dinner"
        } else if lowercased.contains("snack") {
            return "snack"
        }
        return nil
    }
    
    // MARK: - Category Utilities
    
    /// Get icon for task category
    /// - Parameter category: Task category
    /// - Returns: Icon emoji
    static func getCategoryIcon(for category: String) -> String {
        switch category.lowercased() {
        case "fitness":
            return "💪"
        case "diet":
            return "🍽️"
        case "others":
            return "📌"
        default:
            return "📝"
        }
    }
    
    /// Get color for task category (Hex)
    /// - Parameter category: Task category
    /// - Returns: Color hex string
    static func getCategoryColor(for category: String) -> String {
        switch category.lowercased() {
        case "fitness":
            return "#6366F1" // Purple
        case "diet":
            return "#F59E0B" // Orange
        case "others":
            return "#8B5CF6" // Indigo
        default:
            return "#9CA3AF" // Gray
        }
    }
}

