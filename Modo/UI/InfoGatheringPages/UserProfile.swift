import Foundation
import SwiftData

@Model
final class UserProfile {
    var userId: String
    var username: String?
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
    var createdAt: Date
    var updatedAt: Date
    
    init(userId: String) {
        self.userId = userId
        self.username = "Modor"  // Default username
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
}

