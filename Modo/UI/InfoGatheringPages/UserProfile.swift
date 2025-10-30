import Foundation
import SwiftData

@Model
final class UserProfile {
    var userId: String
    var height: Double?
    var weight: Double?
    var age: Int?
    var lifestyle: String?
    var goal: String?
    var targetWeightLoss: Double?
    var targetDays: Int?
    var createdAt: Date
    var updatedAt: Date
    
    init(userId: String) {
        self.userId = userId
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    
    func updateProfile(
        height: Double?,
        weight: Double?,
        age: Int?,
        lifestyle: String?,
        goal: String?,
        targetWeightLoss: Double?,
        targetDays: Int?
    ) {
        self.height = height
        self.weight = weight
        self.age = age
        self.lifestyle = lifestyle
        self.goal = goal
        self.targetWeightLoss = targetWeightLoss
        self.targetDays = targetDays
        self.updatedAt = Date()
    }
}

