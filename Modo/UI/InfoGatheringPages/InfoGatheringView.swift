import SwiftUI
import SwiftData
import FirebaseAuth

struct InfoGatheringView: View {
    @EnvironmentObject var authService: AuthService
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    // ViewModel - manages all business logic and state
    @StateObject private var viewModel = InfoGatheringViewModel()
    
    
    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
            
            VStack(spacing: 0) {
                ProgressBar(currentStep: viewModel.currentStep, totalSteps: viewModel.totalSteps)
                    .padding(.horizontal, 24)
                    .padding(.top, 12)
                
                ZStack {
                    switch viewModel.currentStep {
                    case 1:
                        HeightStepView(height: $viewModel.height, heightUnit: $viewModel.heightUnit, showError: $viewModel.showHeightError, onContinue: viewModel.nextStep, onSkip: viewModel.nextStep, onBack: nil)
                            .id(viewModel.currentStep)
                    case 2:
                        WeightStepView(weight: $viewModel.weight, weightUnit: $viewModel.weightUnit, showError: $viewModel.showWeightError, onContinue: viewModel.nextStep, onSkip: viewModel.nextStep, onBack: viewModel.lastStep)
                            .id(viewModel.currentStep)
                    case 3:
                        AgeStepView(age: $viewModel.age, showError: $viewModel.showAgeError, onContinue: viewModel.nextStep, onSkip: viewModel.nextStep, onBack: viewModel.lastStep)
                            .id(viewModel.currentStep)
                    case 4:
                        GenderStepView(gender: $viewModel.gender, onContinue: viewModel.nextStep, onSkip: viewModel.nextStep, onBack: viewModel.lastStep)
                            .id(viewModel.currentStep)
                    case 5:
                        LifestyleStepView(lifestyle: $viewModel.lifestyle, onContinue: viewModel.nextStep, onSkip: viewModel.nextStep, onBack: viewModel.lastStep)
                            .id(viewModel.currentStep)
                    case 6:
                        GoalStepView(goal: $viewModel.goal, onContinue: viewModel.nextStep, onSkip: viewModel.nextStep, onBack: viewModel.lastStep)
                            .id(viewModel.currentStep)
                    case 7:
                        FinalStepView(
                            goal: viewModel.goal,
                            actualCalories: $viewModel.actualCalories,
                            recommendedCalories: viewModel.recommendedCalories(),
                            actualProtein: $viewModel.actualProtein,
                            recommendedProtein: viewModel.recommendedProtein(),
                            targetWeightLoss: $viewModel.targetWeightLoss, lossUnit: $viewModel.lossUnit, targetDays: $viewModel.targetDays,
                            showWeightError: $viewModel.showTargetWeightError, showDaysError: $viewModel.showTargetDaysError,
                            onDone: {
                                viewModel.completeOnboarding()
                                dismiss()
                            }, onSkip: {
                                viewModel.completeOnboarding()
                                dismiss()
                            }, onBack: viewModel.lastStep)
                            .id(viewModel.currentStep)
                    default:
                        EmptyView().id(viewModel.currentStep)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(.asymmetric(
                    insertion: .move(edge: viewModel.isBackwards ? .leading : .trailing),
                    removal: .move(edge: viewModel.isBackwards ? .trailing : .leading)
                ))
                .animation(.easeInOut(duration: 0.3), value: viewModel.currentStep)
            }
        }
        .onAppear {
            viewModel.setup(
                modelContext: modelContext,
                authService: authService
            )
        }
    }
}


// MARK: - Step 1: Height
private struct HeightStepView: View {
    @Binding var height: String
    @Binding var heightUnit: String
    @Binding var showError: Bool
    let onContinue: () -> Void
    let onSkip: () -> Void
    let onBack: (() -> Void)?
    
    var body: some View {
        let range = heightUnit == "cm" ? (50, 250) : (20, 96)
        StepTemplate(
            title: "What's your height?",
            subtitle: "This helps us personalize your experience",
            buttonTitle: "Continue",
            buttonEnabled: !height.isEmpty,
            onButtonTap: {
                let valid = height.isValidHeight(unit: heightUnit)
                showError = !valid && !height.isEmpty
                if height.isEmpty || valid {
                    showError = false
                    onContinue()
                }
            },
            onSkip: onSkip,
            onBack: onBack
        ) {
            VStack(alignment: .leading, spacing: 4) {
                CustomInputField(
                    placeholder: "Enter height",
                    text: $height,
                    keyboardType: .decimalPad,
                    trailingAccessory: AnyView(UnitSelector(selection: $heightUnit, options: ["in", "cm"]))
                )
                .onChange(of: height) {
                    let valid = height.isValidHeight(unit: heightUnit)
                    showError = !valid && !height.isEmpty
                }
                .onChange(of: heightUnit) {
                    let valid = height.isValidHeight(unit: heightUnit)
                    showError = !valid && !height.isEmpty
                }
                if showError {
                    Text("Please enter a valid height (\(Int(range.0))-\(Int(range.1)) \(heightUnit))")
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
    @Binding var weightUnit: String
    @Binding var showError: Bool
    let onContinue: () -> Void
    let onSkip: () -> Void
    let onBack: (() -> Void)?
    
    private func weightRange(for unit: String) -> (Double, Double) {
        unit == "kg" ? (20, 500) : (44, 1100) // kg/lb
    }

    var body: some View {
        let range = weightRange(for: weightUnit)
        StepTemplate(
            title: "What's your weight?",
            subtitle: "We use this to provide better recommendations",
            buttonTitle: "Continue",
            buttonEnabled: !weight.isEmpty,
            onButtonTap: {
                let valid = weight.isValidWeight(unit: weightUnit)
                showError = !valid && !weight.isEmpty
                if weight.isEmpty || valid {
                    showError = false
                    onContinue()
                }
            },
            onSkip: onSkip,
            onBack: onBack
        ) {
            VStack(alignment: .leading, spacing: 4) {
                CustomInputField(
                    placeholder: "Enter weight",
                    text: $weight,
                    keyboardType: .decimalPad,
                    trailingAccessory: AnyView(UnitSelector(selection: $weightUnit, options: ["lbs", "kg"]))
                )
                .onChange(of: weight) {
                    let valid = weight.isValidWeight(unit: weightUnit)
                    showError = !valid && !weight.isEmpty
                }
                .onChange(of: weightUnit) {
                    let valid = weight.isValidWeight(unit: weightUnit)
                    showError = !valid && !weight.isEmpty
                }
                if showError {
                    Text("Please enter a valid weight (\(Int(range.0))-\(Int(range.1)) \(weightUnit))")
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
    let onBack: (() -> Void)?
    
    var body: some View {
        StepTemplate(
            title: "How old are you?",
            subtitle: "Help us tailor the content for you",
            buttonTitle: "Continue",
            buttonEnabled: !age.isEmpty,
            onButtonTap: {
                if age.isValidAge {
                    showError = false
                    onContinue()
                } else if !age.isEmpty {
                    showError = true
                } else {
                    showError = false
                    onContinue()
                }
            },
            onSkip: onSkip,
            onBack: onBack
        ) {
            VStack(alignment: .leading, spacing: 4) {
                CustomInputField(
                    placeholder: "Enter age",
                    text: $age,
                    keyboardType: .numberPad,
                    suffix: "years"
                )
                .onChange(of: age) {
                    if age.isValidAge {
                        showError = false
                    } else if !age.isEmpty {
                        showError = true
                    }
                }
                
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

// MARK: - Gender Option
enum GenderOption: String, CaseIterable {
    case male = "Male"
    case female = "Female"
    case other = "Other"
    
    var code: String {
        switch self {
        case .male: return "male"
        case .female: return "female"
        case .other: return "other"
        }
    }
}

// MARK: - Step 4: Gender
private struct GenderStepView: View {
    @Binding var gender: GenderOption?
    let onContinue: () -> Void
    let onSkip: () -> Void
    let onBack: (() -> Void)?
    
    var body: some View {
        StepTemplate(
            title: "What's your gender?",
            subtitle: "This helps us give you better health recommendations.",
            buttonTitle: "Continue",
            buttonEnabled: gender != nil,
            onButtonTap: onContinue,
            onSkip: onSkip,
            onBack: onBack
        ) {
            VStack(spacing: 12) {
                ForEach(GenderOption.allCases, id: \.self) { option in
                    SelectionButton(
                        title: option.rawValue,
                        isSelected: gender == option
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            gender = option
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Lifestyle Option
enum LifestyleOption: String, CaseIterable {
    case longSitting = "Sedentary"
    case moderatelyActive = "Moderately Active"
    case veryActive = "Athletic"
}

extension LifestyleOption {
    var code: String {
        switch self {
        case .longSitting: return "sedentary"
        case .moderatelyActive: return "moderately_active"
        case .veryActive: return "athletic"
        }
    }
}

// MARK: - Step 5: Lifestyle
private struct LifestyleStepView: View {
    @Binding var lifestyle: LifestyleOption?
    let onContinue: () -> Void
    let onSkip: () -> Void
    let onBack: (() -> Void)?
    
    var body: some View {
        StepTemplate(
            title: "What's your lifestyle?",
            subtitle: "Select the option that best describes you",
            buttonTitle: "Continue",
            buttonEnabled: lifestyle != nil,
            onButtonTap: onContinue,
            onSkip: onSkip,
            onBack: onBack
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

extension GoalOption {
    var code: String {
        switch self {
        case .loseWeight: return "lose_weight"
        case .keepHealthy: return "keep_healthy"
        case .gainMuscle: return "gain_muscle"
        }
    }
}

// MARK: - Step 6: Goal
private struct GoalStepView: View {
    @Binding var goal: GoalOption?
    let onContinue: () -> Void
    let onSkip: () -> Void
    let onBack: (() -> Void)?
    
    var body: some View {
        StepTemplate(
            title: "What's your goal?",
            subtitle: "Select the option that best describes you",
            buttonTitle: "Continue",
            buttonEnabled: goal != nil,
            onButtonTap: onContinue,
            onSkip: onSkip,
            onBack: onBack
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

// MARK: - Step 7: Final Step (Redesigned for consistency)
private struct FinalStepView: View {
    let goal: GoalOption?
    @Binding var actualCalories: String
    let recommendedCalories: Int?
    @Binding var actualProtein: String
    let recommendedProtein: Int?
    @Binding var targetWeightLoss: String
    @Binding var lossUnit: String
    @Binding var targetDays: String
    @Binding var showWeightError: Bool
    @Binding var showDaysError: Bool
    let onDone: () -> Void
    let onSkip: () -> Void
    let onBack: (() -> Void)?
    @State private var showCaloriesError: Bool = false
    @State private var showProteinError: Bool = false
    
    
    private func lossRange(for unit: String) -> (Double, Double) {
        unit == "kg" ? (0.2, 100) : (0.5, 220)
    }

    var body: some View {
        if goal == nil {
            StepTemplate(
                title: "Profile Not Completed",
                subtitle: "You can always finish your profile and set goals later in Profile Settings.",
                buttonTitle: "Done",
                buttonEnabled: true,
                onButtonTap: onDone,
                onSkip: onSkip,
                onBack: onBack
            ) {
                EmptyView()
            }
        } else {
            StepTemplate(
                title: goalTitle,
                subtitle: goalSubtitle,
                buttonTitle: "Done",
                buttonEnabled: isCurrentInputValid,
                onButtonTap: onDone,
                onSkip: onSkip,
                onBack: onBack
            ) {
                if goal == .loseWeight {
                    weightLossBlock
                } else if goal == .keepHealthy {
                    healthyBlock
                } else if goal == .gainMuscle {
                    proteinBlock
                }
            }
        }
    }
    private var goalTitle: String {
        switch goal {
          case .loseWeight: return "Set your targets"
          case .keepHealthy: return "Stay healthy!"
          case .gainMuscle: return "Gain muscle goal!"
          default: return ""
        }
    }
    private var goalSubtitle: String {
        switch goal {
          case .loseWeight: return "Choose your weight loss goal and timeframe"
          case .keepHealthy: return "Recommended daily intake based on your info"
          case .gainMuscle: return "Recommended daily protein intake for muscle gain"
          default: return ""
        }
    }

    private var isCurrentInputValid: Bool {
        switch goal {
        case .loseWeight:
            let range = lossRange(for: lossUnit)
            let validWeight = targetWeightLoss.isValidTargetWeight(unit: lossUnit)
            let validDays = targetDays.isValidTargetDays
            return (!targetWeightLoss.isEmpty && validWeight) && (!targetDays.isEmpty && validDays)
        case .keepHealthy:
            let validDays = targetDays.isValidTargetDays
            return (!actualCalories.isEmpty && Int(actualCalories) ?? 0 > 600) && (!targetDays.isEmpty && validDays)
        case .gainMuscle:
            let validDays = targetDays.isValidTargetDays
            return (!actualProtein.isEmpty && Int(actualProtein) ?? 0 >= 20) && (!targetDays.isEmpty && validDays)
        default: return false
        }
    }

    private var weightLossBlock: some View {
        let range = lossRange(for: lossUnit)
        let errorView: some View = Group {
            if showWeightError {
                Text("Please enter a valid target (\(range.0)-\(range.1) \(lossUnit))")
                    .font(.system(size: 10))
                    .foregroundColor(.red)
                    .padding(.leading, 12)
            }
        }
        return VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Weight loss")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color(hexString: "6A7282"))
                    .padding(.leading, 4)
                CustomInputField(
                    placeholder: "Target weight",
                    text: $targetWeightLoss,
                    keyboardType: .decimalPad,
                    trailingAccessory: AnyView(UnitSelector(selection: $lossUnit, options: ["lbs", "kg"]))
                )
                .onChange(of: targetWeightLoss) {
                    let valid = targetWeightLoss.isValidTargetWeight(unit: lossUnit)
                    showWeightError = !valid && !targetWeightLoss.isEmpty
                }
                .onChange(of: lossUnit) {
                    let valid = targetWeightLoss.isValidTargetWeight(unit: lossUnit)
                    showWeightError = !valid && !targetWeightLoss.isEmpty
                }
                errorView
            }
            timeframeBlock
        }
    }

    @State var showInfoTip = false
    private var healthyBlock: some View {
        let errorView: some View = Group {
            if showCaloriesError {
                Text("Please enter a valid calories (>600 kcal)")
                    .font(.system(size: 10))
                    .foregroundColor(.red)
                    .padding(.leading, 12)
            }
        }
        return VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Text("Recommended calories")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color(hexString: "6A7282"))
                        .padding(.leading, 4)
                    Button(action: { showInfoTip = true }) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 15))
                            .foregroundColor(.gray)
                    }
                    .alert("Get Recommendation", isPresented: $showInfoTip) {
                        Button("OK", role: .cancel) { }
                    } message: {
                        Text("Fill in more info to get a personalized recommendation, or simply input your own value.")
                    }
                }
                CustomInputField(
                    placeholder: "Daily calories",
                    text: $actualCalories,
                    keyboardType: .numberPad,
                    trailingAccessory: AnyView(
                        Text("kcal")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color(hexString: "6A7282"))
                    )
                )
                .onAppear {
                    if let val = recommendedCalories {
                        actualCalories = String(val)
                    }
                }
                .onChange(of: recommendedCalories) {
                    if let val = recommendedCalories {
                        actualCalories = String(val)
                    }
                }
                .onChange(of: actualCalories) {
                    let value = Int(actualCalories) ?? 0
                    let valid = value > 250
                    showCaloriesError = !valid && !actualCalories.isEmpty
                }
                errorView
            }
            timeframeBlock
        }
    }
    // gain muscle
    private var proteinBlock: some View {
        let errorView: some View = Group {
            if showProteinError {
                Text("Please enter a valid protein (≥20 g)")
                    .font(.system(size: 10))
                    .foregroundColor(.red)
                    .padding(.leading, 12)
            }
        }
        return VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Text("Recommended protein")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color(hexString: "6A7282"))
                        .padding(.leading, 4)
                    Button(action: { showInfoTip = true }) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 15))
                            .foregroundColor(.gray)
                    }
                    .alert("Get Recommendation", isPresented: $showInfoTip) {
                        Button("OK", role: .cancel) { }
                    } message: {
                        Text("Fill in more info to get a personalized recommendation, or simply input your own value.")
                    }
                }
                CustomInputField(
                    placeholder: "Daily protein",
                    text: $actualProtein,
                    keyboardType: .numberPad,
                    trailingAccessory: AnyView(
                        Text("g")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color(hexString: "6A7282"))
                    )
                )
                .onAppear {
                    if let val = recommendedProtein {
                        actualProtein = String(val)
                    }
                }
                .onChange(of: recommendedProtein) {
                    if let val = recommendedProtein {
                        actualProtein = String(val)
                    }
                }
                .onChange(of: actualProtein) {
                    let value = Int(actualProtein) ?? 0
                    let valid = value >= 20
                    showProteinError = !valid && !actualProtein.isEmpty
                }
                errorView
            }
            timeframeBlock
        }
    }
    private var timeframeBlock: some View {
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
            .onChange(of: targetDays) {
                let valid = targetDays.isValidTargetDays
                showDaysError = !valid && !targetDays.isEmpty
            }
            if showDaysError {
                Text("Please enter a valid timeframe (1-365 days)")
                    .font(.system(size: 10))
                    .foregroundColor(.red)
                    .padding(.leading, 12)
            }
        }
    }
}


#Preview {
    InfoGatheringView()
        .environmentObject(AuthService.shared)
}
