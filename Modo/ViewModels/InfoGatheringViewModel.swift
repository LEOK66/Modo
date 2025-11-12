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
    @Published var weightUnit: String = "lb"
    @Published var lossUnit: String = "lb"
    
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
    
    /// User profiles query result
    private var profiles: [UserProfile] = []
    
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
    ///   - profiles: User profiles query result
    func setup(
        modelContext: ModelContext,
        authService: AuthService,
        profiles: [UserProfile]
    ) {
        self.modelContext = modelContext
        self.authService = authService
        self.profiles = profiles
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
    
    // MARK: - Validation Methods
    
    /// Validate height
    /// - Returns: Whether height is valid
    func validateHeight() -> Bool {
        guard !height.isEmpty else { return true } // Empty is allowed (skip)
        let range = heightUnit == "cm" ? (50.0, 250.0) : (20.0, 96.0)
        guard let value = Double(height) else {
            showHeightError = true
            return false
        }
        let isValid = value >= range.0 && value <= range.1
        showHeightError = !isValid
        return isValid
    }
    
    /// Validate weight
    /// - Returns: Whether weight is valid
    func validateWeight() -> Bool {
        guard !weight.isEmpty else { return true } // Empty is allowed (skip)
        let range = weightUnit == "kg" ? (20.0, 500.0) : (44.0, 1100.0)
        guard let value = Double(weight) else {
            showWeightError = true
            return false
        }
        let isValid = value >= range.0 && value <= range.1
        showWeightError = !isValid
        return isValid
    }
    
    /// Validate age
    /// - Returns: Whether age is valid
    func validateAge() -> Bool {
        guard !age.isEmpty else { return true } // Empty is allowed (skip)
        guard let ageValue = Int(age) else {
            showAgeError = true
            return false
        }
        let isValid = ageValue >= 10 && ageValue <= 120
        showAgeError = !isValid
        return isValid
    }
    
    /// Validate target weight loss
    /// - Returns: Whether target weight loss is valid
    func validateTargetWeightLoss() -> Bool {
        guard !targetWeightLoss.isEmpty else { return false }
        let range = lossUnit == "kg" ? (0.2, 100.0) : (0.5, 220.0)
        guard let value = Double(targetWeightLoss) else {
            showTargetWeightError = true
            return false
        }
        let isValid = value >= range.0 && value <= range.1
        showTargetWeightError = !isValid
        return isValid
    }
    
    /// Validate target days
    /// - Returns: Whether target days is valid
    func validateTargetDays() -> Bool {
        guard !targetDays.isEmpty else { return false }
        guard let days = Int(targetDays) else {
            showTargetDaysError = true
            return false
        }
        let isValid = days >= 1 && days <= 365
        showTargetDaysError = !isValid
        return isValid
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
        let validHeight = height.isValidHeight(unit: heightUnit) ? Double(height) : nil
        let validWeight = weight.isValidWeight(unit: weightUnit) ? Double(weight) : nil
        let validAge = age.isValidAge ? Int(age) : nil
        let validTargetWeightLoss = targetWeightLoss.isValidTargetWeight(unit: lossUnit) ? Double(targetWeightLoss) : nil
        let validTargetDays = targetDays.isValidTargetDays ? Int(targetDays) : nil
        
        // Check if profile already exists
        let existingProfile = profiles.first { $0.userId == userId }
        let profile: UserProfile
        
        if let existing = existingProfile {
            // Update existing profile
            profile = existing
            print("Updating existing profile for userId=\(userId)")
        } else {
            // Create new profile
            profile = UserProfile(userId: userId)
            modelContext.insert(profile)
            print("Creating new profile for userId=\(userId)")
        }
        
        // Goal-specific values
        let validCalories: Int? = {
            if goal == .keepHealthy { return Int(actualCalories) }
            return nil
        }()
        let validProtein: Int? = {
            if goal == .gainMuscle { return Int(actualProtein) }
            return nil
        }()
        
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

