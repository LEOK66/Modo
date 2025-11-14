import Foundation
import SwiftUI
import SwiftData
import Combine
import FirebaseAuth

/// ViewModel for managing info gathering form state and business logic
///
/// This ViewModel handles:
/// - Multi-step form state management
/// - Form validation
/// - Data saving (SwiftData + Firebase)
/// - Health calculations (calories, protein recommendations)
final class InfoGatheringViewModel: ObservableObject {
    // MARK: - Published Properties - Form State
    
    /// Current step in the form
    @Published var currentStep: Int = 1
    
    /// Whether navigation is backwards
    @Published var isBackwards: Bool = false
    
    /// User data
    @Published var height: String = ""
    @Published var weight: String = ""
    @Published var age: String = ""
    @Published var gender: GenderOption? = nil
    @Published var lifestyle: LifestyleOption? = nil
    @Published var goal: GoalOption? = nil
    @Published var targetWeightLoss: String = ""
    @Published var targetDays: String = ""
    
    /// Unit selections
    @Published var heightUnit: String = "in"
    @Published var weightUnit: String = "lbs"
    @Published var lossUnit: String = "lbs"
    
    /// Recommended values
    @Published var actualCalories: String = ""
    @Published var actualProtein: String = ""
    
    // MARK: - Published Properties - Validation State
    
    /// Validation error flags
    @Published var showHeightError: Bool = false
    @Published var showWeightError: Bool = false
    @Published var showAgeError: Bool = false
    @Published var showTargetWeightError: Bool = false
    @Published var showTargetDaysError: Bool = false
    
    // MARK: - Private Properties
    
    /// Total number of steps
    let totalSteps = 7
    
    /// Database service for Firebase operations
    private let databaseService: DatabaseServiceProtocol
    
    /// Auth service for user operations
    private weak var authService: AuthService?
    
    /// Model context for SwiftData operations
    private var modelContext: ModelContext?
    
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
    func setup(
        modelContext: ModelContext,
        authService: AuthService
    ) {
        self.modelContext = modelContext
        self.authService = authService
    }
    
    // MARK: - Navigation Methods
    
    /// Move to next step
    func nextStep() {
        withAnimation(.easeInOut(duration: 0.3)) {
            isBackwards = false
            if currentStep < totalSteps {
                currentStep += 1
            }
        }
    }
    
    /// Move to previous step
    func lastStep() {
        withAnimation(.easeInOut(duration: 0.3)) {
            isBackwards = true
            if currentStep > 1 {
                currentStep -= 1
                // Clear recommended values when going back from final step
                if currentStep < 7 {
                    actualCalories = ""
                    actualProtein = ""
                }
            }
        }
    }
    
    // MARK: - Health Calculation Methods
    
    /// Convert weight to kg
    /// - Returns: Weight in kg or nil
    func weightInKg() -> Double? {
        guard let value = Double(weight) else { return nil }
        return HealthCalculator.convertWeightToKg(value, unit: weightUnit)
    }
    
    /// Convert height to cm
    /// - Returns: Height in cm or nil
    func heightInCm() -> Double? {
        guard let value = Double(height) else { return nil }
        return HealthCalculator.convertHeightToCm(value, unit: heightUnit)
    }
    
    /// Calculate recommended calories
    /// - Returns: Recommended calories or nil
    func recommendedCalories() -> Int? {
        guard let ageValue = Int(age),
              let genderCode = gender?.code,
              let kg = weightInKg(),
              let cm = heightInCm(),
              let lifestyleCode = lifestyle?.code else { return nil }
        return HealthCalculator.recommendedCalories(
            age: ageValue,
            genderCode: genderCode,
            weightKg: kg,
            heightCm: cm,
            lifestyleCode: lifestyleCode
        )
    }
    
    /// Calculate recommended protein
    /// - Returns: Recommended protein or nil
    func recommendedProtein() -> Int? {
        guard let kg = weightInKg() else { return nil }
        return HealthCalculator.recommendedProtein(weightKg: kg)
    }
    
    // MARK: - Data Saving Methods
    
    /// Complete onboarding and save user data
    func completeOnboarding() {
        saveUserData()
        authService?.completeOnboarding()
    }
    
    /// Save user data to SwiftData and Firebase
    private func saveUserData() {
        guard let userId = authService?.currentUser?.uid,
              let modelContext = modelContext else { return }
        
        // Only save valid data, skip invalid inputs
        let validHeight = Double(height)
        let validWeight = Double(weight)
        let validAge = Int(age)
        let validTargetWeightLoss = Double(targetWeightLoss)
        let validTargetDays = Int(targetDays)
        
        // Create new profile (onboarding only happens for brand new users)
        let profile = UserProfile(userId: userId)
        modelContext.insert(profile)
        
        // Goal-specific values
        let validCalories: Int? = goal == .keepHealthy ? Int(actualCalories) : nil
        let validProtein: Int? = goal == .gainMuscle ? Int(actualProtein) : nil
        
        profile.updateProfile(
            heightValue: validHeight,
            heightUnit: heightUnit,
            weightValue: validWeight,
            weightUnit: weightUnit,
            age: validAge,
            genderCode: gender?.code,
            lifestyleCode: lifestyle?.code,
            goalCode: goal?.code,
            dailyCalories: validCalories,
            dailyProtein: validProtein,
            targetWeightLossValue: validTargetWeightLoss,
            targetWeightLossUnit: lossUnit,
            targetDays: validTargetDays
        )
        
        // Set goal start date when saving profile (only if not already set or if goal changed)
        if profile.goalStartDate == nil || profile.goal != goal?.code {
            profile.goalStartDate = Date()
        }
        
        // Save to SwiftData
        do {
            try modelContext.save()
            print("User profile saved successfully")
        } catch {
            print("Failed to save user profile: \(error.localizedDescription)")
        }
        
        // Also save to Firebase for cloud backup
        databaseService.saveUserProfile(profile) { result in
            switch result {
            case .success:
                print("[Firebase] User profile saved for userId=\(userId)")
            case .failure(let error):
                print("[Firebase] Failed to save user profile: \(error.localizedDescription)")
            }
        }
        
        print("Saving user data:")
        print("Height: \(validHeight != nil ? "\(validHeight!) \(heightUnit)" : "not provided")")
        print("Weight: \(validWeight != nil ? "\(validWeight!) \(weightUnit)" : "not provided")")
        print("Age: \(validAge != nil ? "\(validAge!) years" : "not provided")")
        print("Gender: \(gender?.code ?? "not provided")")
        print("Lifestyle: \(lifestyle?.code ?? "not provided")")
        print("Goal: \(goal?.code ?? "not provided")")
        switch goal {
        case .loseWeight:
            print("Target weight loss: \(validTargetWeightLoss != nil ? "\(validTargetWeightLoss!) \(lossUnit)" : "not provided")")
            print("Target days: \(validTargetDays != nil ? "\(validTargetDays!) days" : "not provided")")
        case .keepHealthy:
            print("Daily calories: \(validCalories != nil ? "\(validCalories!) kcal" : "not provided")")
            print("Target days: \(validTargetDays != nil ? "\(validTargetDays!) days" : "not provided")")
        case .gainMuscle:
            print("Daily protein: \(validProtein != nil ? "\(validProtein!) g" : "not provided")")
            print("Target days: \(validTargetDays != nil ? "\(validTargetDays!) days" : "not provided")")
        default:
            break
        }
    }
}

