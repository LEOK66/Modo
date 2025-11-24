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
    
    /// Task cache service for getting today's tasks
    private let taskCacheService = TaskCacheService.shared
    
    /// Today's actual macro intake (protein, fat, carbs)
    @Published private(set) var todayMacros: (protein: Double, fat: Double, carbs: Double) = (0, 0, 0)
    
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
        // Load today's macro intake
        loadTodayMacros()
    }
    
    /// Update user profile (called when profile changes)
    /// - Parameter userProfile: Updated user profile
    func updateUserProfile(_ userProfile: UserProfile?) {
        self.userProfile = userProfile
        loadProgressData()
        loadTodayMacros()
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
    
    /// Load today's macro intake from completed diet tasks
    func loadTodayMacros() {
        guard let authService = authService,
              let userId = authService.currentUser?.uid else {
            DispatchQueue.main.async {
                self.todayMacros = (0, 0, 0)
            }
            return
        }
        
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        // Get today's tasks from cache
        let tasks = taskCacheService.getTasks(for: today, userId: userId)
        
        // Filter only completed diet tasks
        let completedDietTasks = tasks.filter { task in
            task.category == .diet && task.isDone
        }
        
        // Calculate total macros from all diet entries
        var totalProtein: Double = 0
        var totalFat: Double = 0
        var totalCarbs: Double = 0
        
        for task in completedDietTasks {
            for entry in task.dietEntries {
                totalProtein += calculateMacroValue(for: entry, type: .protein)
                totalFat += calculateMacroValue(for: entry, type: .fat)
                totalCarbs += calculateMacroValue(for: entry, type: .carbs)
            }
        }
        
        DispatchQueue.main.async {
            self.todayMacros = (totalProtein, totalFat, totalCarbs)
        }
    }
    
    // MARK: - Macro Calculation Helper
    
    private enum MacroType {
        case protein
        case fat
        case carbs
    }
    
    /// Calculate macro value for a diet entry
    private func calculateMacroValue(for entry: DietEntry, type: MacroType) -> Double {
        guard let food = entry.food else { return 0.0 }
        
        // Parse quantity from text
        let quantity = Double(entry.quantityText) ?? 0.0
        guard quantity > 0 else { return 0.0 }
        
        // Get base nutrient value based on type
        let per100g: Double?
        let perServing: Double?
        
        switch type {
        case .protein:
            per100g = food.proteinPer100g
            perServing = food.proteinPerServing
        case .fat:
            per100g = food.fatPer100g
            perServing = food.fatPerServing
        case .carbs:
            per100g = food.carbsPer100g
            perServing = food.carbsPerServing
        }
        
        // Calculate actual value based on unit and quantity
        let calculatedValue: Double?
        
        if entry.unit == "g" {
            // User entered grams
            if let per100g = per100g {
                // Use per-100g data: (per-100g value / 100) * quantity
                calculatedValue = (per100g / 100.0) * quantity
            } else if let perServing = perServing {
                // Fallback to per-serving if per-100g not available
                // This is approximate - we assume 1 serving = 100g if not specified
                calculatedValue = (perServing / 100.0) * quantity
            } else {
                calculatedValue = nil
            }
        } else {
            // User entered servings (or other units)
            if let perServing = perServing {
                // Use per-serving data: per-serving value * quantity
                calculatedValue = perServing * quantity
            } else if let per100g = per100g {
                // Fallback to per-100g if per-serving not available
                // Assume 1 serving = 100g (standard assumption)
                calculatedValue = per100g * quantity
            } else {
                calculatedValue = nil
            }
        }
        
        return calculatedValue ?? 0.0
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
    
    /// Today's actual protein intake
    var todayProtein: Double {
        todayMacros.protein
    }
    
    /// Today's actual fat intake
    var todayFat: Double {
        todayMacros.fat
    }
    
    /// Today's actual carbs intake
    var todayCarbs: Double {
        todayMacros.carbs
    }
    
    /// Protein progress (actual / recommended)
    var proteinProgress: Double {
        guard let recommended = recommendedMacros?.protein, recommended > 0 else { return 0 }
        return min(todayMacros.protein / Double(recommended), 1.0) // Cap at 100%
    }
    
    /// Fat progress (actual / recommended)
    var fatProgress: Double {
        guard let recommended = recommendedMacros?.fat, recommended > 0 else { return 0 }
        return min(todayMacros.fat / Double(recommended), 1.0) // Cap at 100%
    }
    
    /// Carbs progress (actual / recommended)
    var carbsProgress: Double {
        guard let recommended = recommendedMacros?.carbohydrates, recommended > 0 else { return 0 }
        return min(todayMacros.carbs / Double(recommended), 1.0) // Cap at 100%
    }
    
    /// Whether the user has met all macro goals for today
    var hasMetAllMacroGoals: Bool {
        // Use a small tolerance to avoid floating point issues
        let threshold = 0.99
        return proteinProgress >= threshold &&
               fatProgress >= threshold &&
               carbsProgress >= threshold &&
               recommendedMacros != nil
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

