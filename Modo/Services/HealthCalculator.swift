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

    // TDEE
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
}


