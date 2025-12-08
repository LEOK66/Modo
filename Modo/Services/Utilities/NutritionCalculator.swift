import Foundation

// MARK: - Daily Nutrition Data

/// Represents daily nutrition data (actual vs target)
struct DailyNutrition {
    let date: Date
    let caloriesActual: Int
    let caloriesTarget: Int
    let proteinActual: Int
    let proteinTarget: Int
    let carbsActual: Int
    let carbsTarget: Int
    let fatsActual: Int
    let fatsTarget: Int
    
    /// Check if calories are within target (must be exactly equal)
    var isCaloriesAccurate: Bool {
        return caloriesActual == caloriesTarget
    }
    
    /// Check if calories are over target by more than 1000
    var isCaloriesOverBy1000: Bool {
        return caloriesActual >= caloriesTarget + 1000
    }
    
    /// Check if protein is within target range (±5%)
    var isProteinAccurate: Bool {
        let tolerance = Double(proteinTarget) * 0.05
        return abs(Double(proteinActual - proteinTarget)) <= tolerance
    }
    
    /// Check if carbs are within target range (±5%)
    var isCarbsAccurate: Bool {
        let tolerance = Double(carbsTarget) * 0.05
        return abs(Double(carbsActual - carbsTarget)) <= tolerance
    }
    
    /// Check if fats are within target range (±5%)
    var isFatsAccurate: Bool {
        let tolerance = Double(fatsTarget) * 0.05
        return abs(Double(fatsActual - fatsTarget)) <= tolerance
    }
    
    /// Check if all macros are accurate
    var areAllMacrosAccurate: Bool {
        return isProteinAccurate && isCarbsAccurate && isFatsAccurate
    }
}

// MARK: - Nutrition Calculator

/// Helper class for calculating nutrition statistics
struct NutritionCalculator {
    /// Calculate daily nutrition from completed tasks for a specific date
    /// - Parameters:
    ///   - date: The date to calculate for
    ///   - tasks: Array of tasks for that date
    ///   - userProfile: User profile with target values
    /// - Returns: DailyNutrition or nil if user profile doesn't have required data
    static func calculateDailyNutrition(
        for date: Date,
        tasks: [TaskItem],
        userProfile: UserProfile
    ) -> DailyNutrition? {
        // Get target values
        guard let caloriesTarget = getCaloriesTarget(userProfile: userProfile),
              let macrosTarget = getMacrosTarget(userProfile: userProfile) else {
            return nil
        }
        
        // Calculate actual values from completed tasks
        var caloriesActual = 0
        var proteinActual = 0
        var carbsActual = 0
        var fatsActual = 0
        
        for task in tasks {
            guard task.isDone else { continue }
            
            // Add calories (diet adds, fitness subtracts)
            caloriesActual += task.totalCalories
            
            // Calculate macros from diet entries
            if task.category == .diet {
                for dietEntry in task.dietEntries {
                    // Calculate macros from food item
                    if let food = dietEntry.food {
                        let macros = calculateMacrosFromDietEntry(dietEntry: dietEntry, food: food)
                        proteinActual += macros.protein
                        carbsActual += macros.carbs
                        fatsActual += macros.fats
                    }
                }
            }
        }
        
        return DailyNutrition(
            date: date,
            caloriesActual: caloriesActual,
            caloriesTarget: caloriesTarget,
            proteinActual: proteinActual,
            proteinTarget: macrosTarget.protein,
            carbsActual: carbsActual,
            carbsTarget: macrosTarget.carbohydrates,
            fatsActual: fatsActual,
            fatsTarget: macrosTarget.fat
        )
    }
    
    /// Get calories target from user profile
    private static func getCaloriesTarget(userProfile: UserProfile) -> Int? {
        // First try user's dailyCalories
        if let dailyCalories = userProfile.dailyCalories {
            return dailyCalories
        }
        
        // Otherwise calculate from HealthCalculator
        guard let age = userProfile.age,
              let genderCode = userProfile.gender,
              let weightValue = userProfile.weightValue,
              let weightUnit = userProfile.weightUnit,
              let heightValue = userProfile.heightValue,
              let heightUnit = userProfile.heightUnit,
              let lifestyleCode = userProfile.lifestyle,
              let goal = userProfile.goal else {
            return nil
        }
        
        let weightKg = HealthCalculator.convertWeightToKg(weightValue, unit: weightUnit)
        let heightCm = HealthCalculator.convertHeightToCm(heightValue, unit: heightUnit)
        
        return HealthCalculator.targetCalories(
            goal: goal,
            age: age,
            genderCode: genderCode,
            weightKg: weightKg,
            heightCm: heightCm,
            lifestyleCode: lifestyleCode,
            userInputCalories: userProfile.dailyCalories
        )
    }
    
    /// Get macros target from user profile
    private static func getMacrosTarget(userProfile: UserProfile) -> HealthCalculator.Macronutrients? {
        guard let caloriesTarget = getCaloriesTarget(userProfile: userProfile),
              let goal = userProfile.goal else {
            return nil
        }
        
        // Get recommended macros from HealthCalculator
        return HealthCalculator.recommendedMacros(goal: goal, totalCalories: caloriesTarget)
    }
    
    /// Calculate macros from a diet entry and food item
    private static func calculateMacrosFromDietEntry(
        dietEntry: DietEntry,
        food: MenuData.FoodItem
    ) -> (protein: Int, carbs: Int, fats: Int) {
        // Parse quantity
        guard let quantity = Double(dietEntry.quantityText) else {
            return (0, 0, 0)
        }
        
        // Determine which macro values to use (per serving or per 100g)
        let protein: Double
        let carbs: Double
        let fats: Double
        
        if dietEntry.unit.lowercased() == "g" || dietEntry.unit.lowercased() == "gram" || dietEntry.unit.lowercased() == "grams" {
            // Use per 100g values
            if let proteinPer100g = food.proteinPer100g,
               let carbsPer100g = food.carbsPer100g,
               let fatsPer100g = food.fatPer100g {
                protein = (proteinPer100g * quantity) / 100.0
                carbs = (carbsPer100g * quantity) / 100.0
                fats = (fatsPer100g * quantity) / 100.0
            } else {
                return (0, 0, 0)
            }
        } else {
            // Use per serving values
            if let proteinPerServing = food.proteinPerServing,
               let carbsPerServing = food.carbsPerServing,
               let fatsPerServing = food.fatPerServing {
                protein = proteinPerServing * quantity
                carbs = carbsPerServing * quantity
                fats = fatsPerServing * quantity
            } else {
                return (0, 0, 0)
            }
        }
        
        return (Int(round(protein)), Int(round(carbs)), Int(round(fats)))
    }
    
    /// Calculate streak of consecutive days meeting a condition
    /// - Parameters:
    ///   - dates: Array of dates to check (should be sorted, most recent first)
    ///   - condition: Closure that returns true if condition is met for a date
    /// - Returns: Number of consecutive days (from most recent date backwards)
    static func calculateStreak(
        dates: [Date],
        condition: (Date) -> Bool
    ) -> Int {
        guard !dates.isEmpty else { return 0 }
        
        let calendar = Calendar.current
        var streak = 0
        var currentDate = calendar.startOfDay(for: Date())
        
        // Sort dates (most recent first)
        let sortedDates = dates.sorted(by: >)
        
        for date in sortedDates {
            let dateStart = calendar.startOfDay(for: date)
            
            // Check if this date matches the expected date in the streak
            if calendar.isDate(dateStart, inSameDayAs: currentDate) {
                if condition(date) {
                    streak += 1
                    // Move to previous day
                    currentDate = calendar.date(byAdding: .day, value: -1, to: currentDate) ?? currentDate
                } else {
                    // Streak broken
                    break
                }
            } else {
                // Gap in dates - streak broken
                break
            }
        }
        
        return streak
    }
}

