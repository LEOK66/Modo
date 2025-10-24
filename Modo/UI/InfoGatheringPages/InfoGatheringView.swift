import SwiftUI
import SwiftData
import FirebaseAuth

struct InfoGatheringView: View {
    @EnvironmentObject var authService: AuthService
    @Environment(\.modelContext) private var modelContext
    @State private var currentStep = 1
    @State private var isCompleted = false
    
    // User data
    @State private var height = ""
    @State private var weight = ""
    @State private var age = ""
    @State private var lifestyle: LifestyleOption? = nil
    @State private var goal: GoalOption? = nil
    @State private var targetWeightLoss = ""
    @State private var targetDays = ""
    
    let totalSteps = 6
    
    var body: some View {
        NavigationStack {
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
                            HeightStepView(height: $height, onContinue: nextStep, onSkip: nextStep)
                                .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
                        case 2:
                            WeightStepView(weight: $weight, onContinue: nextStep, onSkip: nextStep)
                                .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
                        case 3:
                            AgeStepView(age: $age, onContinue: nextStep, onSkip: nextStep)
                                .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
                        case 4:
                            LifestyleStepView(lifestyle: $lifestyle, onContinue: nextStep, onSkip: nextStep)
                                .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
                        case 5:
                            GoalStepView(goal: $goal, onContinue: nextStep, onSkip: nextStep)
                                .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
                        case 6:
                            FinalStepView(targetWeightLoss: $targetWeightLoss, targetDays: $targetDays, onDone: completeOnboarding, onSkip: completeOnboarding)
                                .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
                        default:
                            EmptyView()
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationDestination(isPresented: $isCompleted) {
                MainContainerView()
                    .navigationBarBackButtonHidden(true)
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
    
    private func completeOnboarding() {
        // Save user data here (to Firebase/SwiftData)
        saveUserData()
        
        // Mark onboarding as completed
        authService.completeOnboarding()
        
        // Navigate to main page
        withAnimation {
            isCompleted = true
        }
    }
    
    private func saveUserData() {
        guard let userId = authService.currentUser?.uid else { return }
        
        // Create user profile
        let profile = UserProfile(userId: userId)
        profile.updateProfile(
            height: Double(height),
            weight: Double(weight),
            age: Int(age),
            lifestyle: lifestyle?.rawValue,
            goal: goal?.rawValue,
            targetWeightLoss: Double(targetWeightLoss),
            targetDays: Int(targetDays)
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
        print("Height: \(height) cm")
        print("Weight: \(weight) kg")
        print("Age: \(age) years")
        print("Lifestyle: \(lifestyle?.rawValue ?? "none")")
        print("Goal: \(goal?.rawValue ?? "none")")
        print("Target weight loss: \(targetWeightLoss)")
        print("Target days: \(targetDays)")
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
            HStack(spacing: 12) {
                TextField("", text: $height)
                    .font(.system(size: 40, weight: .regular))
                    .foregroundColor(Color(hexString: "101828"))
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                
                Text("cm")
                    .font(.system(size: 24))
                    .foregroundColor(Color(hexString: "6A7282"))
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(hexString: "F9FAFB"))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color(hexString: "E5E7EB"), lineWidth: 1)
            )
        }
    }
}

// MARK: - Step 2: Weight
private struct WeightStepView: View {
    @Binding var weight: String
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
            HStack(spacing: 12) {
                TextField("", text: $weight)
                    .font(.system(size: 40, weight: .regular))
                    .foregroundColor(Color(hexString: "101828"))
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                
                Text("kg")
                    .font(.system(size: 24))
                    .foregroundColor(Color(hexString: "6A7282"))
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(hexString: "F9FAFB"))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color(hexString: "E5E7EB"), lineWidth: 1)
            )
        }
    }
}

// MARK: - Step 3: Age
private struct AgeStepView: View {
    @Binding var age: String
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
            HStack(spacing: 12) {
                TextField("", text: $age)
                    .font(.system(size: 40, weight: .regular))
                    .foregroundColor(Color(hexString: "101828"))
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                
                Text("years")
                    .font(.system(size: 24))
                    .foregroundColor(Color(hexString: "6A7282"))
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(hexString: "F9FAFB"))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color(hexString: "E5E7EB"), lineWidth: 1)
            )
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
            VStack(spacing: 24) {
                // Weight loss input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Weight loss")
                        .font(.system(size: 14))
                        .foregroundColor(Color(hexString: "6A7282"))
                    
                    HStack(spacing: 12) {
                        TextField("", text: $targetWeightLoss)
                            .font(.system(size: 32, weight: .regular))
                            .foregroundColor(Color(hexString: "101828"))
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                        
                        Text("lbs")
                            .font(.system(size: 20))
                            .foregroundColor(Color(hexString: "6A7282"))
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(hexString: "F9FAFB"))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color(hexString: "E5E7EB"), lineWidth: 1)
                    )
                }
                
                // Timeframe input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Timeframe")
                        .font(.system(size: 14))
                        .foregroundColor(Color(hexString: "6A7282"))
                    
                    HStack(spacing: 12) {
                        TextField("", text: $targetDays)
                            .font(.system(size: 32, weight: .regular))
                            .foregroundColor(Color(hexString: "101828"))
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                        
                        Text("days")
                            .font(.system(size: 20))
                            .foregroundColor(Color(hexString: "6A7282"))
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(hexString: "F9FAFB"))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color(hexString: "E5E7EB"), lineWidth: 1)
                    )
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

