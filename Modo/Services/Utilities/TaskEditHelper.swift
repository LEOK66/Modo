import Foundation

/// Helper utilities for task editing (calories calculation, formatting, etc.)
struct TaskEditHelper {
    /// Calculate calories for a diet entry
    static func dietEntryCalories(_ entry: DietEntry) -> Int {
        guard let food = entry.food else { return 0 }
        guard let qtyDouble = Double(entry.quantityText), qtyDouble > 0 else { return 0 }
        
        if entry.unit == "g" {
            guard let per100 = food.caloriesPer100g else { return 0 }
            return Int(round(per100 * qtyDouble / 100.0))
        } else if entry.unit == "lbs" {
            guard let per100 = food.caloriesPer100g else { return 0 }
            let grams = qtyDouble * 453.592
            return Int(round(per100 * grams / 100.0))
        } else if entry.unit == "kg" {
            guard let per100 = food.caloriesPer100g else { return 0 }
            let grams = qtyDouble * 1000.0
            return Int(round(per100 * grams / 100.0))
        } else {
            guard let per = food.servingCalories else { return 0 }
            return Int(round(Double(per) * qtyDouble))
        }
    }
    
    /// Format duration text from minutes
    static func durationText(forMinutes minutes: Int) -> String {
        let total = max(0, minutes)
        let hours: Int = total / 60
        let mins: Int = total % 60
        if hours > 0 && mins > 0 {
            return "\(hours)h \(mins)m"
        } else if hours > 0 {
            return "\(hours)h"
        } else {
            return "\(mins)m"
        }
    }
    
    /// Format duration from hours and minutes
    static func formattedDuration(hours: Int, minutes: Int) -> String {
        if hours > 0 && minutes > 0 { return "\(hours)h \(minutes)m" }
        if hours > 0 { return "\(hours)h" }
        return "\(minutes)m"
    }
    
    /// Get placeholder for unit
    static func placeholderForUnit(_ unit: String) -> String {
        switch unit {
        case "g": return "100"
        case "lbs": return "1"
        case "kg": return "1"
        default: return "1"
        }
    }
    
    /// Get unit label
    static func unitLabel(_ unit: String) -> String {
        switch unit {
        case "g": return "grams"
        case "lbs": return "lbs"
        case "kg": return "kg"
        default: return "serving"
        }
    }
    
    /// Truncate subtitle text
    static func truncateSubtitle(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "" }
        
        let firstSentence = trimmed
            .components(separatedBy: CharacterSet(charactersIn: ".!?"))
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? trimmed
        
        if firstSentence.count > 50 {
            let truncated = String(firstSentence.prefix(47))
            return truncated + "..."
        }
        
        return firstSentence
    }
    
    /// Get calories label for food item in quick pick
    static func quickPickCaloriesLabel(food: MenuData.FoodItem) -> String {
        if food.defaultUnit == "g" || (food.caloriesPer100g != nil && food.servingCalories == nil) {
            if let per100 = food.caloriesPer100g {
                return "\(Int(round(per100))) cal/100g"
            }
        } else {
            if let per = food.servingCalories {
                return "\(per) cal"
            }
        }
        return "—"
    }
}

