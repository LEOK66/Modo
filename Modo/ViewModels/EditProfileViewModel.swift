import Foundation
import SwiftUI
import SwiftData
import Combine
import FirebaseAuth

/// ViewModel for managing edit profile form state and business logic
///
/// This ViewModel handles:
/// - Form state management
/// - Form validation
/// - Data saving (SwiftData + Firebase)
/// - Health calculations (calories, protein recommendations)
final class EditProfileViewModel: ObservableObject {
    // MARK: - Published Properties - Form State
    
    /// Local editable states (initialized from existing profile)
    @Published var heightValue: String = ""
    @Published var heightUnit: String = "in"
    @Published var weightValue: String = ""
    @Published var weightUnit: String = "lbs"
    @Published var ageValue: String = ""
    @Published var genderCode: String? = nil
    @Published var lifestyleCode: String? = nil
    @Published var goalCode: String? = nil
    @Published var dailyCalories: String = ""
    @Published var dailyProtein: String = ""
    @Published var targetWeightLoss: String = ""
    @Published var targetWeightLossUnit: String = "lbs"
    @Published var targetDays: String = ""
    
    // MARK: - Published Properties - Validation State
    
    /// Validation error flags
    @Published var showHeightError: Bool = false
    @Published var showWeightError: Bool = false
    @Published var showTargetDaysError: Bool = false
    
    // MARK: - Private Properties
    
    /// Database service for Firebase operations
    private let databaseService: DatabaseServiceProtocol
    
    /// Auth service for user operations
    private weak var authService: AuthService?
    
    /// User profile service
    private weak var userProfileService: UserProfileService?
    
    /// Model context for SwiftData operations
    private var modelContext: ModelContext?
    
    /// Current user profile
    private var userProfile: UserProfile?
    
    // MARK: - Initialization
    
    /// Initialize ViewModel with dependencies
    /// - Parameters:
    ///   - databaseService: Database service for Firebase operations
    init(databaseService: DatabaseServiceProtocol = ServiceContainer.shared.databaseService) {
        self.databaseService = databaseService
    }
    
    // MARK: - Setup Methods
    
    /// Setup ViewModel with Environment dependencies
    /// - Parameters:
    ///   - modelContext: Model context for SwiftData operations
    ///   - authService: Auth service for user operations
    ///   - userProfileService: User profile service
    ///   - userProfile: Current user profile
    func setup(
        modelContext: ModelContext,
        authService: AuthService,
        userProfileService: UserProfileService,
        userProfile: UserProfile?
    ) {
        self.modelContext = modelContext
        self.authService = authService
        self.userProfileService = userProfileService
        self.userProfile = userProfile
        
        // Hydrate form from profile
        hydrateFromProfile()
    }
    
    // MARK: - Data Loading Methods
    
    /// Hydrate form fields from user profile
    private func hydrateFromProfile() {
        guard let profile = userProfile else { return }
        
        if let height = profile.heightValue {
            heightValue = String(Int(height))
        }
        heightUnit = profile.heightUnit ?? heightUnit
        
        if let weight = profile.weightValue {
            weightValue = String(Int(weight))
        }
        weightUnit = profile.weightUnit ?? weightUnit
        
        if let age = profile.age {
            ageValue = String(age)
        }
        
        genderCode = profile.gender
        lifestyleCode = profile.lifestyle
        goalCode = profile.goal
        
        if let calories = profile.dailyCalories {
            dailyCalories = String(calories)
        }
        
        if let protein = profile.dailyProtein {
            dailyProtein = String(protein)
        }
        
        if let targetWeight = profile.targetWeightLossValue {
            targetWeightLoss = String(Int(targetWeight))
        }
        targetWeightLossUnit = profile.targetWeightLossUnit ?? targetWeightLossUnit
        
        if let days = profile.targetDays {
            targetDays = String(days)
        }
    }
    
    // MARK: - Validation Methods
    
    /// Validate height
    /// - Returns: Whether height is valid
    func validateHeight() -> Bool {
        guard !heightValue.isEmpty else { return true }
        let isValid = heightValue.isValidHeight(unit: heightUnit)
        showHeightError = !isValid
        return isValid
    }
    
    /// Validate weight
    /// - Returns: Whether weight is valid
    func validateWeight() -> Bool {
        guard !weightValue.isEmpty else { return true }
        let isValid = weightValue.isValidWeight(unit: weightUnit)
        showWeightError = !isValid
        return isValid
    }
    
    /// Validate target days
    /// - Returns: Whether target days is valid
    func validateTargetDays() -> Bool {
        guard !targetDays.isEmpty else { return true }
        guard let days = Int(targetDays) else {
            showTargetDaysError = true
            return false
        }
        let isValid = (1...365).contains(days)
        showTargetDaysError = !isValid
        return isValid
    }
    
    // MARK: - Health Calculation Methods
    
    /// Convert weight to kg
    /// - Returns: Weight in kg or nil
    func weightInKg() -> Double? {
        guard let value = Double(weightValue) else { return nil }
        return HealthCalculator.convertWeightToKg(value, unit: weightUnit)
    }
    
    /// Convert height to cm
    /// - Returns: Height in cm or nil
    func heightInCm() -> Double? {
        guard let value = Double(heightValue) else { return nil }
        return HealthCalculator.convertHeightToCm(value, unit: heightUnit)
    }
    
    /// Calculate recommended calories
    /// - Returns: Recommended calories or nil
    func recommendedCaloriesValue() -> Int? {
        guard let age = Int(ageValue),
              let gender = genderCode,
              let kg = weightInKg(),
              let cm = heightInCm(),
              let lifestyle = lifestyleCode else { return nil }
        return HealthCalculator.recommendedCalories(
            age: age,
            genderCode: gender,
            weightKg: kg,
            heightCm: cm,
            lifestyleCode: lifestyle
        )
    }
    
    /// Calculate recommended protein
    /// - Returns: Recommended protein or nil
    func recommendedProteinValue() -> Int? {
        guard let kg = weightInKg() else { return nil }
        return HealthCalculator.recommendedProtein(weightKg: kg)
    }
    
    // MARK: - Data Saving Methods
    
    /// Save changes to user profile
    func saveChanges() {
        // Validate inputs
        if !heightValue.isEmpty {
            guard validateHeight() else { return }
        }
        
        if !weightValue.isEmpty {
            guard validateWeight() else { return }
        }
        
        if !targetDays.isEmpty {
            guard validateTargetDays() else { return }
        }
        
        guard let userId = authService?.currentUser?.uid,
              let modelContext = modelContext else { return }
        
        // Get or create profile
        let profile: UserProfile
        if let existing = userProfile {
            profile = existing
        } else {
            profile = UserProfile(userId: userId)
            modelContext.insert(profile)
        }
        
        // Save old values before updating (needed for goalStartDate logic)
        let oldGoal = profile.goal
        let oldTargetDays = profile.targetDays
        let oldGoalStartDate = profile.goalStartDate
        
        // Parse numbers softly: empty strings mean keep nil
        let heightDouble = Double(heightValue)
        let weightDouble = Double(weightValue)
        let ageInt = Int(ageValue)
        let caloriesInt = Int(dailyCalories)
        let proteinInt = Int(dailyProtein)
        let targetLossDouble = Double(targetWeightLoss)
        let targetDaysInt = Int(targetDays)
        
        profile.updateProfile(
            heightValue: heightValue.isEmpty ? nil : heightDouble,
            heightUnit: heightUnit,
            weightValue: weightValue.isEmpty ? nil : weightDouble,
            weightUnit: weightUnit,
            age: ageValue.isEmpty ? nil : ageInt,
            genderCode: genderCode,
            lifestyleCode: lifestyleCode,
            goalCode: goalCode,
            dailyCalories: dailyCalories.isEmpty ? nil : caloriesInt,
            dailyProtein: dailyProtein.isEmpty ? nil : proteinInt,
            targetWeightLossValue: targetWeightLoss.isEmpty ? nil : targetLossDouble,
            targetWeightLossUnit: targetWeightLossUnit,
            targetDays: targetDays.isEmpty ? nil : targetDaysInt
        )
        
        // Reset goalStartDate if:
        // 1. Goal changed
        // 2. Goal is nil (new goal being set) but goalCode is set
        // 3. Current goal is expired (endDate < today) and user is setting new targetDays
        // 4. targetDays changed significantly (user wants to restart)
        let shouldResetStartDate: Bool
        if let newGoal = goalCode {
            // Goal changed
            if newGoal != oldGoal {
                shouldResetStartDate = true
            } else {
                // Same goal, check if expired or targetDays changed
                let calendar = Calendar.current
                let today = calendar.startOfDay(for: Date())
                
                if let existingStartDate = oldGoalStartDate,
                   let existingTargetDays = oldTargetDays {
                    let normalizedStart = calendar.startOfDay(for: existingStartDate)
                    if let endDate = calendar.date(byAdding: .day, value: existingTargetDays, to: normalizedStart) {
                        // Check if goal is expired
                        let isExpired = endDate < today
                        // Check if targetDays changed
                        let targetDaysChanged = targetDaysInt != nil && targetDaysInt != existingTargetDays
                        
                        // Reset if expired or if targetDays changed (user wants to restart)
                        shouldResetStartDate = isExpired || targetDaysChanged
                    } else {
                        shouldResetStartDate = false
                    }
                } else {
                    // No existing start date or target days, set it
                    shouldResetStartDate = true
                }
            }
        } else {
            // No goal set, don't reset
            shouldResetStartDate = false
        }
        
        if shouldResetStartDate {
            let newStartDate = Date()
            let oldStartDate = profile.goalStartDate
            profile.goalStartDate = newStartDate
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d, yyyy"
            print("✅ EditProfileViewModel: Reset goalStartDate to \(formatter.string(from: newStartDate))")
            
            // Clear old completion records for the new goal date range
            // This prevents old test data from showing up when setting a new goal
            // IMPORTANT: Clear BEFORE saving, so that when ProgressViewModel queries,
            // it won't find any local records and won't trigger Firebase sync
            if let targetDays = targetDaysInt, targetDays > 0 {
                clearCompletionRecordsForNewGoal(startDate: newStartDate, targetDays: targetDays)
            }
            
            // Also clear completion records for the old goal range (if it existed)
            if let oldStart = oldStartDate, let oldTargetDays = profile.targetDays, oldTargetDays > 0 {
                let calendar = Calendar.current
                let normalizedOldStart = calendar.startOfDay(for: oldStart)
                if let oldEndDate = calendar.date(byAdding: .day, value: oldTargetDays, to: normalizedOldStart) {
                    clearCompletionRecordsForDateRange(startDate: normalizedOldStart, endDate: oldEndDate)
                }
            }
        }
        
        // Save to SwiftData
        do {
            try modelContext.save()
        } catch {
            print("Save error: \(error.localizedDescription)")
        }
        
        // Save to Firebase
        databaseService.saveUserProfile(profile) { _ in }
        
        // Refresh the shared service
        userProfileService?.setProfile(profile)
    }
    
    /// Clear completion records for a new goal date range
    /// This prevents old test data or Firebase-synced data from showing up when setting a new goal
    /// IMPORTANT: Clears both local SwiftData and Firebase records
    private func clearCompletionRecordsForNewGoal(startDate: Date, targetDays: Int) {
        let calendar = Calendar.current
        let normalizedStart = calendar.startOfDay(for: startDate)
        guard let endDate = calendar.date(byAdding: .day, value: targetDays, to: normalizedStart) else {
            return
        }
        
        // Clear local SwiftData records
        clearCompletionRecordsForDateRange(startDate: normalizedStart, endDate: endDate)
        
        // CRITICAL FIX: Also clear Firebase records to prevent them from being synced back
        // When local records are empty, ProgressCalculationService will sync from Firebase
        // If Firebase still has old records in the new goal date range, they will be synced back
        // This causes the progress to show as complete even though the goal was just reset
        if let userId = authService?.currentUser?.uid {
            // endDate is exclusive in clearCompletionRecordsForDateRange, but Firebase uses inclusive
            // So we need to subtract 1 day for Firebase
            if let firebaseEndDate = calendar.date(byAdding: .day, value: -1, to: endDate) {
                databaseService.deleteDailyCompletions(userId: userId, startDate: normalizedStart, endDate: firebaseEndDate) { result in
                    switch result {
                    case .success:
                        let formatter = DateFormatter()
                        formatter.dateFormat = "yyyy-MM-dd"
                        print("✅ EditProfileViewModel: Cleared Firebase completion records for date range [\(formatter.string(from: normalizedStart)) to \(formatter.string(from: firebaseEndDate))]")
                    case .failure(let error):
                        print("❌ EditProfileViewModel: Failed to clear Firebase completion records - \(error.localizedDescription)")
                    }
                }
            }
        }
    }
    
    /// Clear completion records for a date range
    private func clearCompletionRecordsForDateRange(startDate: Date, endDate: Date) {
        guard let userId = authService?.currentUser?.uid,
              let modelContext = modelContext else {
            return
        }
        
        // Delete all completion records in the date range (local only)
        let descriptor = FetchDescriptor<DailyCompletion>(
            predicate: #Predicate { completion in
                completion.userId == userId &&
                completion.date >= startDate &&
                completion.date < endDate
            }
        )
        
        do {
            let completions = try modelContext.fetch(descriptor)
            for completion in completions {
                modelContext.delete(completion)
            }
            try modelContext.save()
            print("🗑️ EditProfileViewModel: Cleared \(completions.count) completion records for date range [\(startDate) to \(endDate))")
            
            // Note: We don't create new completion records here
            // This ensures that when querying, if there's no local data,
            // Firebase sync will be skipped (due to our sync logic that only syncs when localCompletions.isEmpty)
            // This prevents old Firebase data from appearing when setting a new goal
        } catch {
            print("❌ EditProfileViewModel: Failed to clear completion records - \(error.localizedDescription)")
        }
    }
}

