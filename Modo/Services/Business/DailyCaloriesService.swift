import Foundation
import Combine

/// Service to share daily calories data between MainPageView and ProfilePageView
class DailyCaloriesService: ObservableObject {
    @Published var todayCalories: Int = 0
    
    /// Update calories for today
    /// - Parameters:
    ///   - calories: Total calories for today (from completed tasks)
    ///   - date: Date to check if it's today
    func updateCalories(_ calories: Int, for date: Date) {
        let calendar = Calendar.current
        let normalizedDate = calendar.startOfDay(for: date)
        let today = calendar.startOfDay(for: Date())
        
        // Only update if the date is today
        guard calendar.isDate(normalizedDate, inSameDayAs: today) else {
            return
        }
        
        // Use async dispatch to avoid "Publishing changes from within view updates" error
        // This ensures the @Published property update happens after the current view update cycle
        DispatchQueue.main.async { [weak self] in
            self?.todayCalories = calories
        }
    }
}

