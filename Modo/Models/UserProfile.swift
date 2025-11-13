import Foundation
import SwiftData

@Model
final class UserProfile {
    var userId: String
    var username: String?
    var avatarName: String?        // default animal avatar asset name
    var profileImageURL: String?   // uploaded photo URL (Firebase Storage)
    var heightValue: Double?
    var heightUnit: String?
    var weightValue: Double?
    var weightUnit: String?
    var age: Int?
    var gender: String?
    var lifestyle: String?
    var goal: String?
    var dailyCalories: Int?
    var dailyProtein: Int?
    var targetWeightLossValue: Double?
    var targetWeightLossUnit: String?
    var targetDays: Int?
    var goalStartDate: Date?
    var bufferDays: Int?
    var createdAt: Date
    var updatedAt: Date
    
    init(userId: String) {
        self.userId = userId
        self.username = "Modor"  // Default username
        self.avatarName = DefaultAvatars.random()  // Assign random default avatar
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    
    func updateProfile(
        heightValue: Double?,
        heightUnit: String?,
        weightValue: Double?,
        weightUnit: String?,
        age: Int?,
        genderCode: String?,
        lifestyleCode: String?,
        goalCode: String?,
        dailyCalories: Int?,
        dailyProtein: Int?,
        targetWeightLossValue: Double?,
        targetWeightLossUnit: String?,
        targetDays: Int?
    ) {
        self.heightValue = heightValue
        self.heightUnit = heightUnit
        self.weightValue = weightValue
        self.weightUnit = weightUnit
        self.age = age
        self.gender = genderCode
        self.lifestyle = lifestyleCode
        self.goal = goalCode
        self.dailyCalories = dailyCalories
        self.dailyProtein = dailyProtein
        self.targetWeightLossValue = targetWeightLossValue
        self.targetWeightLossUnit = targetWeightLossUnit
        self.targetDays = targetDays
        self.updatedAt = Date()
    }
    
    // MARK: - Data Validation Helpers

    func hasMinimumDataForProgress() -> Bool {
        guard goal != nil, goalStartDate != nil else { return false }
        
        switch goal {
        case "lose_weight":
            return targetWeightLossValue != nil && targetDays != nil
        case "keep_healthy":
            return dailyCalories != nil && targetDays != nil
        case "gain_muscle":
            return dailyProtein != nil && targetDays != nil
        default:
            return false
        }
    }
    
    func hasDataForCaloriesCalculation() -> Bool {
        return heightValue != nil && weightValue != nil &&
               age != nil && gender != nil && lifestyle != nil
    }
    
    // MARK: - Daily Challenge Data Validation
    
    /// Check if user has minimum data for Daily Challenge feature
    func hasMinimumDataForDailyChallenge() -> Bool {
        // Check if user has basic health information
        return heightValue != nil && weightValue != nil &&
               age != nil && gender != nil
    }
}

