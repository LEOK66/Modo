import SwiftUI
import SwiftData
import FirebaseAuth

struct InfoGatheringView: View {
    @EnvironmentObject var authService: AuthService
    @Environment(\.modelContext) private var modelContext
    @State private var currentStep = 1
    
    // User data
    @State private var height = ""
    @State private var weight = ""
    @State private var age = ""
    @State private var lifestyle: LifestyleOption? = nil
    @State private var goal: GoalOption? = nil
    @State private var targetWeightLoss = ""
    @State private var targetDays = ""
    
    // Validation states
    @State private var showHeightError = false
    @State private var showWeightError = false
    @State private var showAgeError = false
    @State private var showTargetWeightError = false
    @State private var showTargetDaysError = false
    
    let totalSteps = 6
    
    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Progress bar
                ProgressBar(currentStep: currentStep, totalSteps: totalSteps)
                    .padding(.horizontal, 24)
                    .padding(.top, 12)
                
                // Content area with transition
                ZStack {
                    switch currentStep {
                    case 1:
                        HeightStepView(height: $height, showError: $showHeightError, onContinue: validateAndNextStep(field: height, validator: \.isValidHeight, errorBinding: $showHeightError), onSkip: nextStep)
                            .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
                    case 2:
                        WeightStepView(weight: $weight, showError: $showWeightError, onContinue: validateAndNextStep(field: weight, validator: \.isValidWeight, errorBinding: $showWeightError), onSkip: nextStep)
                            .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
                    case 3:
                        AgeStepView(age: $age, showError: $showAgeError, onContinue: validateAndNextStep(field: age, validator: \.isValidAge, errorBinding: $showAgeError), onSkip: nextStep)
                            .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
                    case 4:
                        LifestyleStepView(lifestyle: $lifestyle, onContinue: nextStep, onSkip: nextStep)
                            .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
                    case 5:
                        GoalStepView(goal: $goal, onContinue: nextStep, onSkip: nextStep)
                            .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
                    case 6:
                        FinalStepView(targetWeightLoss: $targetWeightLoss, targetDays: $targetDays, showWeightError: $showTargetWeightError, showDaysError: $showTargetDaysError, onDone: validateAndComplete, onSkip: completeOnboarding)
                            .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
                    default:
                        EmptyView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
    
    private func nextStep() {
        withAnimation(.easeInOut(duration: 0.3)) {
            if currentStep < totalSteps {
                currentStep += 1
            }
        }
    }
    
    private func validateAndNextStep(field: String, validator: KeyPath<String, Bool>, errorBinding: Binding<Bool>) -> () -> Void {
        return {
            withAnimation(.easeInOut(duration: 0.2)) {
                errorBinding.wrappedValue = !field[keyPath: validator] && field.isNotEmpty
            }
            
            // Only proceed if valid or empty (allow skip)
            if field.isEmpty || field[keyPath: validator] {
                errorBinding.wrappedValue = false
                nextStep()
            }
        }
    }
    
    private func validateAndComplete() {
        withAnimation(.easeInOut(duration: 0.2)) {
            showTargetWeightError = !targetWeightLoss.isValidTargetWeight && targetWeightLoss.isNotEmpty
            showTargetDaysError = !targetDays.isValidTargetDays && targetDays.isNotEmpty
        }
        
        // Only complete if both are valid or empty
        if (targetWeightLoss.isEmpty || targetWeightLoss.isValidTargetWeight) &&
           (targetDays.isEmpty || targetDays.isValidTargetDays) {
            completeOnboarding()
        }
    }
    
    private func completeOnboarding() {
        // Save user data here (to Firebase/SwiftData)
        saveUserData()
        
        // Mark onboarding as completed
        // ModoApp will automatically navigate to MainContainerView
        authService.completeOnboarding()
    }
    
    private func saveUserData() {
        guard let userId = authService.currentUser?.uid else { return }
        
        // Only save valid data, skip invalid inputs
        let validHeight = height.isValidHeight ? Double(height) : nil
        let validWeight = weight.isValidWeight ? Double(weight) : nil
        let validAge = age.isValidAge ? Int(age) : nil
        let validTargetWeightLoss = targetWeightLoss.isValidTargetWeight ? Double(targetWeightLoss) : nil
        let validTargetDays = targetDays.isValidTargetDays ? Int(targetDays) : nil
        
        // Create user profile
        let profile = UserProfile(userId: userId)
        profile.updateProfile(
            height: validHeight,
            weight: validWeight,
            age: validAge,
            lifestyle: lifestyle?.rawValue,
            goal: goal?.rawValue,
            targetWeightLoss: validTargetWeightLoss,
            targetDays: validTargetDays
        )
        
        // Save to SwiftData
        modelContext.insert(profile)
        
        do {
            try modelContext.save()
            print("User profile saved successfully")
        } catch {
            print("Failed to save user profile: \(error.localizedDescription)")
        }
        
        // TODO: Also save to Firebase for cloud backup
        print("Saving user data:")
        print("Height: \(validHeight != nil ? "\(validHeight!) inches" : "not provided")")
        print("Weight: \(validWeight != nil ? "\(validWeight!) lbs" : "not provided")")
        print("Age: \(validAge != nil ? "\(validAge!) years" : "not provided")")
        print("Lifestyle: \(lifestyle?.rawValue ?? "not provided")")
        print("Goal: \(goal?.rawValue ?? "not provided")")
        print("Target weight loss: \(validTargetWeightLoss != nil ? "\(validTargetWeightLoss!) lbs" : "not provided")")
        print("Target days: \(validTargetDays != nil ? "\(validTargetDays!) days" : "not provided")")
    }
}

// MARK: - Progress Bar
private struct ProgressBar: View {
    let currentStep: Int
    let totalSteps: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(hexString: "E5E7EB"))
                        .frame(height: 6)
                    
                    // Progress
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.black)
                        .frame(width: geometry.size.width * CGFloat(currentStep) / CGFloat(totalSteps), height: 6)
                        .animation(.easeInOut(duration: 0.3), value: currentStep)
                }
            }
            .frame(height: 6)
            
            Text("Step \(currentStep) of \(totalSteps)")
                .font(.system(size: 14))
                .foregroundColor(Color(hexString: "6A7282"))
        }
    }
}

// MARK: - Step 1: Height
private struct HeightStepView: View {
    @Binding var height: String
    @Binding var showError: Bool
    let onContinue: () -> Void
    let onSkip: () -> Void
    
    var body: some View {
        StepTemplate(
            title: "What's your height?",
            subtitle: "This helps us personalize your experience",
            buttonTitle: "Continue",
            buttonEnabled: !height.isEmpty,
            onButtonTap: onContinue,
            onSkip: onSkip
        ) {
            VStack(alignment: .leading, spacing: 4) {
                CustomInputField(
                    placeholder: "Enter height",
                    text: $height,
                    keyboardType: .decimalPad,
                    suffix: "inches"
                )
                
                if showError {
                    Text("Please enter a valid height (20-96 inches)")
                        .font(.system(size: 10))
                        .foregroundColor(.red)
                        .padding(.leading, 12)
                }
            }
        }
    }
}

// MARK: - Step 2: Weight
private struct WeightStepView: View {
    @Binding var weight: String
    @Binding var showError: Bool
    let onContinue: () -> Void
    let onSkip: () -> Void
    
    var body: some View {
        StepTemplate(
            title: "What's your weight?",
            subtitle: "We use this to provide better recommendations",
            buttonTitle: "Continue",
            buttonEnabled: !weight.isEmpty,
            onButtonTap: onContinue,
            onSkip: onSkip
        ) {
            VStack(alignment: .leading, spacing: 4) {
                CustomInputField(
                    placeholder: "Enter weight",
                    text: $weight,
                    keyboardType: .decimalPad,
                    suffix: "lbs"
                )
                
                if showError {
                    Text("Please enter a valid weight (44-1100 lbs)")
                        .font(.system(size: 10))
                        .foregroundColor(.red)
                        .padding(.leading, 12)
                }
            }
        }
    }
}

// MARK: - Step 3: Age
private struct AgeStepView: View {
    @Binding var age: String
    @Binding var showError: Bool
    let onContinue: () -> Void
    let onSkip: () -> Void
    
    var body: some View {
        StepTemplate(
            title: "How old are you?",
            subtitle: "Help us tailor the content for you",
            buttonTitle: "Continue",
            buttonEnabled: !age.isEmpty,
            onButtonTap: onContinue,
            onSkip: onSkip
        ) {
            VStack(alignment: .leading, spacing: 4) {
                CustomInputField(
                    placeholder: "Enter age",
                    text: $age,
                    keyboardType: .numberPad,
                    suffix: "years"
                )
                
                if showError {
                    Text("Please enter a valid age (10-120 years)")
                        .font(.system(size: 10))
                        .foregroundColor(.red)
                        .padding(.leading, 12)
                }
            }
        }
    }
}

// MARK: - Lifestyle Option
enum LifestyleOption: String, CaseIterable {
    case longSitting = "Long Sitting"
    case moderatelyActive = "Moderately Active"
    case veryActive = "Very Active"
}

// MARK: - Step 4: Lifestyle
private struct LifestyleStepView: View {
    @Binding var lifestyle: LifestyleOption?
    let onContinue: () -> Void
    let onSkip: () -> Void
    
    var body: some View {
        StepTemplate(
            title: "What's your lifestyle?",
            subtitle: "Select the option that best describes you",
            buttonTitle: "Continue",
            buttonEnabled: lifestyle != nil,
            onButtonTap: onContinue,
            onSkip: onSkip
        ) {
            VStack(spacing: 12) {
                ForEach(LifestyleOption.allCases, id: \.self) { option in
                    SelectionButton(
                        title: option.rawValue,
                        isSelected: lifestyle == option
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            lifestyle = option
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Goal Option
enum GoalOption: String, CaseIterable {
    case loseWeight = "Lose Weight"
    case keepHealthy = "Keep Healthy"
    case gainMuscle = "Gain Muscle"
}

// MARK: - Step 5: Goal
private struct GoalStepView: View {
    @Binding var goal: GoalOption?
    let onContinue: () -> Void
    let onSkip: () -> Void
    
    var body: some View {
        StepTemplate(
            title: "What's your goal?",
            subtitle: "Select the option that best describes you",
            buttonTitle: "Continue",
            buttonEnabled: goal != nil,
            onButtonTap: onContinue,
            onSkip: onSkip
        ) {
            VStack(spacing: 12) {
                ForEach(GoalOption.allCases, id: \.self) { option in
                    SelectionButton(
                        title: option.rawValue,
                        isSelected: goal == option
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            goal = option
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Step 6: Final Step (Redesigned for consistency)
private struct FinalStepView: View {
    @Binding var targetWeightLoss: String
    @Binding var targetDays: String
    @Binding var showWeightError: Bool
    @Binding var showDaysError: Bool
    let onDone: () -> Void
    let onSkip: () -> Void
    
    var body: some View {
        StepTemplate(
            title: "Set your targets",
            subtitle: "Choose your weight loss goal and timeframe",
            buttonTitle: "Done",
            buttonEnabled: !targetWeightLoss.isEmpty && !targetDays.isEmpty,
            onButtonTap: onDone,
            onSkip: onSkip
        ) {
            VStack(spacing: 20) {
                // Weight loss input
                VStack(alignment: .leading, spacing: 4) {
                    Text("Weight loss")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color(hexString: "6A7282"))
                        .padding(.leading, 4)
                    
                    CustomInputField(
                        placeholder: "Target weight",
                        text: $targetWeightLoss,
                        keyboardType: .decimalPad,
                        suffix: "lbs"
                    )
                    
                    if showWeightError {
                        Text("Please enter a valid target (0.5-100 lbs)")
                            .font(.system(size: 10))
                            .foregroundColor(.red)
                            .padding(.leading, 12)
                    }
                }
                
                // Timeframe input
                VStack(alignment: .leading, spacing: 4) {
                    Text("Timeframe")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color(hexString: "6A7282"))
                        .padding(.leading, 4)
                    
                    CustomInputField(
                        placeholder: "Number of days",
                        text: $targetDays,
                        keyboardType: .numberPad,
                        suffix: "days"
                    )
                    
                    if showDaysError {
                        Text("Please enter a valid timeframe (1-365 days)")
                            .font(.system(size: 10))
                            .foregroundColor(.red)
                            .padding(.leading, 12)
                    }
                }
            }
        }
    }
}

// MARK: - Selection Button Component
private struct SelectionButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(isSelected ? .white : Color(hexString: "101828"))
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(isSelected ? Color.black : Color.white)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(isSelected ? Color.clear : Color(hexString: "E5E7EB"), lineWidth: 1)
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Step Template
private struct StepTemplate<Content: View>: View {
    let title: String
    let subtitle: String
    let buttonTitle: String
    let buttonEnabled: Bool
    let onButtonTap: () -> Void
    let onSkip: () -> Void
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // Title and subtitle
            VStack(spacing: 12) {
                Text(title)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(Color(hexString: "101828"))
                    .multilineTextAlignment(.center)
                
                Text(subtitle)
                    .font(.system(size: 16))
                    .foregroundColor(Color(hexString: "6A7282"))
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 24)
            
            // Content
            content
                .padding(.horizontal, 24)
                .padding(.top, 24)
            
            Spacer()
            
            // Buttons
            VStack(spacing: 16) {
                Button(action: onButtonTap) {
                    Text(buttonTitle)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(buttonEnabled ? .white : Color(hexString: "6A7282"))
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(buttonEnabled ? Color.black : Color(hexString: "E5E7EB"))
                        )
                }
                .disabled(!buttonEnabled)
                
                Button(action: onSkip) {
                    Text("Skip")
                        .font(.system(size: 14))
                        .foregroundColor(Color(hexString: "6A7282"))
                        .underline()
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
    }
}

#Preview {
    InfoGatheringView()
        .environmentObject(AuthService.shared)
}

