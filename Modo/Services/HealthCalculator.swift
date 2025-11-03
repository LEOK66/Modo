import Foundation

public enum HealthCalculator {
    // Unit conversion
    public static func convertWeightToKg(_ value: Double, unit: String) -> Double {
        return unit.lowercased() == "kg" ? value : value * 0.45359237
    }

    public static func convertHeightToCm(_ value: Double, unit: String) -> Double {
        return unit.lowercased() == "cm" ? value : value * 2.54
    }

    // Mifflin-St Jeor BMR
    public static func bmrMifflinStJeor(age: Int, genderCode: String, weightKg: Double, heightCm: Double) -> Double {
        let gender = genderCode.lowercased()
        switch gender {
        case "male":
            return 10 * weightKg + 6.25 * heightCm - 5 * Double(age) + 5
        case "female":
            return 10 * weightKg + 6.25 * heightCm - 5 * Double(age) - 161
        default:
            let m = 10 * weightKg + 6.25 * heightCm - 5 * Double(age) + 5
            let f = 10 * weightKg + 6.25 * heightCm - 5 * Double(age) - 161
            return (m + f) / 2.0
        }
    }

    // Activity factor by lifestyle code
    public static func activityFactor(for lifestyleCode: String) -> Double {
        switch lifestyleCode.lowercased() {
        case "sedentary": return 1.2
        case "moderately_active": return 1.55
        case "athletic": return 1.725
        default: return 1.2
        }
    }

    public static func tdee(bmr: Double, lifestyleCode: String) -> Double {
        return bmr * activityFactor(for: lifestyleCode)
    }

    // Recommended calories (rounded Int)
    public static func recommendedCalories(age: Int, genderCode: String, weightKg: Double, heightCm: Double, lifestyleCode: String) -> Int {
        let bmr = bmrMifflinStJeor(age: age, genderCode: genderCode, weightKg: weightKg, heightCm: heightCm)
        return Int(tdee(bmr: bmr, lifestyleCode: lifestyleCode))
    }

    // Recommended protein (g) — default 1.8 g/kg
    public static func recommendedProtein(weightKg: Double, gramsPerKg: Double = 1.8) -> Int {
        return Int(round(weightKg * gramsPerKg))
    }
    
    // MARK: - Target Calories Calculation
    
    /// Calculates target calories based on goal and user data
    /// - Parameters:
    ///   - goal: "lose_weight", "keep_healthy", or "gain_muscle"
    ///   - age: User's age
    ///   - genderCode: "male" or "female"
    ///   - weightKg: Weight in kilograms
    ///   - heightCm: Height in centimeters
    ///   - lifestyleCode: "sedentary", "moderately_active", or "athletic"
    ///   - userInputCalories: User-provided calories (used for keep_healthy goal)
    /// - Returns: Target calories or nil if data is insufficient
    public static func targetCalories(
        goal: String,
        age: Int?,
        genderCode: String?,
        weightKg: Double?,
        heightCm: Double?,
        lifestyleCode: String?,
        userInputCalories: Int?
    ) -> Int? {
        // Return nil if goal is empty
        guard !goal.isEmpty else {
            return nil
        }
        
        // For keep_healthy goal, use user input if available
        if goal.lowercased() == "keep_healthy", let input = userInputCalories {
            return input
        }
        
        // Need all data to calculate TDEE
        guard let age = age,
              let genderCode = genderCode,
              let weightKg = weightKg,
              let heightCm = heightCm,
              let lifestyleCode = lifestyleCode else {
            // If keep_healthy and no TDEE data but has user input, already handled above
            return nil
        }
        
        // Calculate TDEE using existing recommendedCalories function
        let tdee = recommendedCalories(
            age: age,
            genderCode: genderCode,
            weightKg: weightKg,
            heightCm: heightCm,
            lifestyleCode: lifestyleCode
        )
        
        // Adjust based on goal
        switch goal.lowercased() {
        case "lose_weight":
            return max(800, tdee - 500) // Minimum 800 calories for safety
        case "keep_healthy":
            return userInputCalories ?? tdee
        case "gain_muscle":
            return tdee + 400
        default:
            return tdee
        }
    }
    
    // MARK: - Macronutrients Calculation
    
    /// Macronutrients structure for daily nutrition recommendations
    public struct Macronutrients {
        public let protein: Int      // grams
        public let carbohydrates: Int  // grams
        public let fat: Int         // grams
        
        public init(protein: Int, carbohydrates: Int, fat: Int) {
            self.protein = protein
            self.carbohydrates = carbohydrates
            self.fat = fat
        }
    }
    
    /// Calculates recommended macronutrients based on goal and total calories
    /// - Parameters:
    ///   - goal: "lose_weight", "keep_healthy", or "gain_muscle"
    ///   - totalCalories: Total daily calories
    /// - Returns: Macronutrients or nil if totalCalories is invalid
    public static func recommendedMacros(
        goal: String,
        totalCalories: Int
    ) -> Macronutrients? {
        guard totalCalories > 0 else { return nil }
        
        // Define macro ratios based on goal
        let proteinRatio: Double
        let carbRatio: Double
        let fatRatio: Double
        
        switch goal.lowercased() {
        case "lose_weight":
            proteinRatio = 0.30
            carbRatio = 0.45
            fatRatio = 0.25
        case "keep_healthy":
            proteinRatio = 0.20
            carbRatio = 0.55
            fatRatio = 0.25
        case "gain_muscle":
            proteinRatio = 0.35
            carbRatio = 0.45
            fatRatio = 0.20
        default:
            // Default to keep_healthy ratios
            proteinRatio = 0.20
            carbRatio = 0.55
            fatRatio = 0.25
        }
        
        // Calculate calories for each macro
        let proteinCalories = Double(totalCalories) * proteinRatio
        let carbCalories = Double(totalCalories) * carbRatio
        let fatCalories = Double(totalCalories) * fatRatio
        
        // Convert to grams: protein/carb = 4 cal/g, fat = 9 cal/g
        let proteinGrams = Int(round(proteinCalories / 4.0))
        let carbGrams = Int(round(carbCalories / 4.0))
        let fatGrams = Int(round(fatCalories / 9.0))
        
        return Macronutrients(protein: proteinGrams, carbohydrates: carbGrams, fat: fatGrams)
    }
}


