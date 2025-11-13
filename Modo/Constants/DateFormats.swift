import Foundation

/// Date format constants and formatting functions used throughout the application
enum DateFormats {
    static let standardDate: String = "yyyy-MM-dd"
    static let time: String = "HH:mm"
}

// MARK: - Date Formatting Extension
extension Date {
    func headerDisplayString() -> String {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let selected = calendar.startOfDay(for: self)
        
        if calendar.isDate(selected, inSameDayAs: today) {
            return "Today"
        }
        
        let df = DateFormatter()
        df.setLocalizedDateFormatFromTemplate("MMMM d")
        df.locale = .current
        return df.string(from: self)
    }
}

