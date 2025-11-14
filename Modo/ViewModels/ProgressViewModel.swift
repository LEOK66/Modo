import Foundation
import SwiftUI
import SwiftData
import Combine
import FirebaseAuth

/// ViewModel for managing progress page state and business logic
///
/// This ViewModel handles:
/// - Progress data loading
/// - Health metrics calculation (macronutrients)
/// - Progress percentage calculation
final class ProgressViewModel: ObservableObject {
    // MARK: - Published Properties
    
    /// Progress data (completedDays, targetDays)
    @Published private(set) var progressData: (completedDays: Int, targetDays: Int) = (0, 0)
    
    /// Loading state
    @Published private(set) var isLoading: Bool = false
    
    // MARK: - Private Properties
    
    /// Progress calculation service
    private let progressService: ProgressCalculationService
    
    /// Auth service for user operations
    private weak var authService: AuthService?
    
    /// Model context for SwiftData operations
    private var modelContext: ModelContext?
    
    /// Current user profile
    private var userProfile: UserProfile?
    
    // MARK: - Initialization
    
    /// Initialize ViewModel with dependencies
    /// - Parameters:
    ///   - progressService: Progress calculation service
    init(progressService: ProgressCalculationService = ProgressCalculationService.shared) {
        self.progressService = progressService
    }
    
    // MARK: - Setup Methods
    
    /// Setup ViewModel with Environment dependencies
    /// - Parameters:
    ///   - modelContext: Model context for SwiftData operations
    ///   - authService: Auth service for user operations
    ///   - userProfile: Current user profile
    func setup(
        modelContext: ModelContext,
        authService: AuthService,
        userProfile: UserProfile?
    ) {
        self.modelContext = modelContext
        self.authService = authService
        self.userProfile = userProfile
        
        // Load progress data
        loadProgressData()
    }
    
    /// Update user profile (called when profile changes)
    /// - Parameter userProfile: Updated user profile
    func updateUserProfile(_ userProfile: UserProfile?) {
        self.userProfile = userProfile
        loadProgressData()
    }
    
    // MARK: - Data Loading Methods
    
    /// Load progress data
    func loadProgressData() {
        guard let profile = userProfile else {
            // Only update if current state is not already the default
            if progressData != (0, 0) {
                DispatchQueue.main.async {
                    self.progressData = (0, 0)
                }
            }
            return
        }
        
        guard profile.hasMinimumDataForProgress(),
              let startDate = profile.goalStartDate,
              let targetDays = profile.targetDays,
              let modelContext = modelContext else {
            let targetDaysValue = profile.targetDays ?? 0
            // Only update if current state is different
            if progressData != (0, targetDaysValue) {
                DispatchQueue.main.async {
                    self.progressData = (0, targetDaysValue)
                }
            }
            return
        }
        
        isLoading = true
        
        Task {
            let completedDays = await progressService.getCompletedDays(
                userId: profile.userId,
                startDate: startDate,
                targetDays: targetDays,
                modelContext: modelContext
            )
            
            await MainActor.run {
                self.progressData = (completedDays, targetDays)
                self.isLoading = false
            }
        }
    }
    
    // MARK: - Computed Properties - Display Text
    
    /// Height value text for display
    var heightValueText: String {
        guard let value = userProfile?.heightValue else { return "-" }
        return "\(Int(value))"
    }
    
    /// Height unit text for display
    var heightUnitText: String {
        userProfile?.heightUnit ?? "cm"
    }
    
    /// Weight value text for display
    var weightValueText: String {
        guard let value = userProfile?.weightValue else { return "-" }
        return "\(Int(value))"
    }
    
    /// Weight unit text for display
    var weightUnitText: String {
        userProfile?.weightUnit ?? "kg"
    }
    
    /// Age text for display
    var ageText: String {
        guard let age = userProfile?.age else { return "-" }
        return "\(age)"
    }
    
    /// Protein text for display
    var proteinText: String {
        // For gain_muscle goal, use weight-based protein recommendation (more reliable)
        if userProfile?.goal == "gain_muscle" {
            guard let weightKg = weightInKg() else { return "-" }
            let protein = HealthCalculator.recommendedProtein(weightKg: weightKg)
            return "\(protein)g"
        }
        // For other goals, use macro-based calculation
        guard let macros = recommendedMacros else { return "-" }
        return "\(macros.protein)g"
    }
    
    /// Fat text for display
    var fatText: String {
        guard let macros = recommendedMacros else { return "-" }
        return "\(macros.fat)g"
    }
    
    /// Carbohydrates text for display
    var carbText: String {
        guard let macros = recommendedMacros else { return "-" }
        return "\(macros.carbohydrates)g"
    }
    
    /// Goal description text for display
    var goalDescriptionText: String {
        guard let goal = userProfile?.goal else { return "-" }
        
        switch goal {
        case "lose_weight":
            if let target = userProfile?.targetWeightLossValue,
               let unit = userProfile?.targetWeightLossUnit {
                return "Lose \(Int(target)) \(unit)"
            }
            return "Lose Weight"
        case "keep_healthy":
            return "Keep Healthy"
        case "gain_muscle":
            if let protein = userProfile?.dailyProtein {
                return "Gain Muscle - \(protein)g protein/day"
            }
            return "Gain Muscle"
        default:
            return "-"
        }
    }
    
    /// Days completed text for display
    var daysCompletedText: String {
        if progressData.targetDays == 0 {
            return "0/0 days"
        }
        return "\(progressData.completedDays)/\(progressData.targetDays) days"
    }
    
    // MARK: - Health Calculation Methods
    
    /// Convert weight to kg
    /// - Returns: Weight in kg or nil
    private func weightInKg() -> Double? {
        guard let profile = userProfile,
              let value = profile.weightValue,
              let unit = profile.weightUnit else { return nil }
        return HealthCalculator.convertWeightToKg(value, unit: unit)
    }
    
    /// Calculate recommended macronutrients
    /// - Returns: Recommended macronutrients or nil
    private var recommendedMacros: HealthCalculator.Macronutrients? {
        guard let profile = userProfile else { return nil }
        
        // Calculate target calories first
        let weightKg: Double? = {
            guard let value = profile.weightValue,
                  let unit = profile.weightUnit else { return nil }
            return HealthCalculator.convertWeightToKg(value, unit: unit)
        }()
        
        let heightCm: Double? = {
            guard let value = profile.heightValue,
                  let unit = profile.heightUnit else { return nil }
            return HealthCalculator.convertHeightToCm(value, unit: unit)
        }()
        
        // Ensure goal is not empty
        guard let goal = profile.goal, !goal.isEmpty else {
            return nil
        }
        
        guard let totalCalories = HealthCalculator.targetCalories(
            goal: goal,
            age: profile.age,
            genderCode: profile.gender,
            weightKg: weightKg,
            heightCm: heightCm,
            lifestyleCode: profile.lifestyle,
            userInputCalories: profile.dailyCalories
        ) else {
            return nil
        }
        
        return HealthCalculator.recommendedMacros(
            goal: goal,
            totalCalories: totalCalories
        )
    }
}

