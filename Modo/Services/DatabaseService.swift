import Foundation
import FirebaseDatabase

final class DatabaseService {
    static let shared = DatabaseService()
    private let db: DatabaseReference
    private init() {
        self.db = Database.database().reference()
    }
    
    func saveUserProfile(_ profile: UserProfile, completion: ((Result<Void, Error>) -> Void)? = nil) {
        let path = db.child("users").child(profile.userId).child("profile")
        var payload: [String: Any] = [
            "userId": profile.userId,
            "createdAt": profile.createdAt.timeIntervalSince1970,
            "updatedAt": profile.updatedAt.timeIntervalSince1970
        ]
        if let heightValue = profile.heightValue { payload["heightValue"] = heightValue }
        if let heightUnit = profile.heightUnit { payload["heightUnit"] = heightUnit }
        if let weightValue = profile.weightValue { payload["weightValue"] = weightValue }
        if let weightUnit = profile.weightUnit { payload["weightUnit"] = weightUnit }
        if let age = profile.age { payload["age"] = age }
        if let gender = profile.gender { payload["gender"] = gender }
        if let lifestyle = profile.lifestyle { payload["lifestyle"] = lifestyle }
        if let goal = profile.goal { payload["goal"] = goal }
        if let dailyCalories = profile.dailyCalories { payload["dailyCalories"] = dailyCalories }
        if let dailyProtein = profile.dailyProtein { payload["dailyProtein"] = dailyProtein }
        if let targetWeightLossValue = profile.targetWeightLossValue { payload["targetWeightLossValue"] = targetWeightLossValue }
        if let targetWeightLossUnit = profile.targetWeightLossUnit { payload["targetWeightLossUnit"] = targetWeightLossUnit }
        if let targetDays = profile.targetDays { payload["targetDays"] = targetDays }
        
        path.setValue(payload) { error, _ in
            if let error = error {
                completion?(.failure(error))
            } else {
                completion?(.success(()))
            }
        }
    }
}


