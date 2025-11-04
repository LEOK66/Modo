import SwiftUI
import SwiftData
import Combine
import FirebaseAuth

class UserProgress: ObservableObject {
    // MARK: - Published properties for progress percentage
    @Published var progressPercent: Double = 0.0
}

struct ProgressView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var userProgress: UserProgress
    @Query private var profiles: [UserProfile]
    
    @State private var progressData: (completedDays: Int, targetDays: Int) = (0, 0)
    
    private let progressService = ProgressCalculationService.shared
    
    // Get current user's profile
    private var userProfile: UserProfile? {
        guard let userId = authService.currentUser?.uid else { return nil }
        return profiles.first { $0.userId == userId }
    }
    
    var body: some View {
        ZStack {
            Color(hexString: "F9FAFB").ignoresSafeArea()
            ScrollView {
                VStack(spacing: 16) {
                    // Header
                    HStack(spacing: 12) {
                        BackButton(action: { dismiss() })
                        Spacer()
                        Text("Progress")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(Color(hexString: "101828"))
                        Spacer()
                        NavigationLink(destination: EditProfileView().environmentObject(authService)) {
                            Text("Change")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(Color(hexString: "7C3AED"))
                        }
                        .frame(width: 66, height: 44)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 12)
                    
                    // Body Metrics
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Body Metrics")
                            .font(.system(size: 14))
                            .foregroundColor(Color(hexString: "6A7282"))
                            .padding(.horizontal, 24)
                        HStack(spacing: 12) {
                            MetricCard(
                                title: "Height",
                                value: heightValueText,
                                unit: heightUnitText
                            )
                            MetricCard(
                                title: "Weight",
                                value: weightValueText,
                                unit: weightUnitText
                            )
                            MetricCard(
                                title: "Age",
                                value: ageText,
                                unit: "years"
                            )
                        }
                        .padding(.horizontal, 24)
                    }
                    .padding(.top, 4)
                    
                    // Daily Nutrition
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Daily Nutrition Recommend")
                            .font(.system(size: 14))
                            .foregroundColor(Color(hexString: "6A7282"))
                            .padding(.horizontal, 24)
                        VStack(spacing: 12) {
                            NutritionRow(color: Color(hexString: "2E90FA"), title: "Protein", amount: proteinText, icon: "shield")
                            NutritionRow(color: Color(hexString: "22C55E"), title: "Fat", amount: fatText, icon: "heart")
                            NutritionRow(color: Color(hexString: "F59E0B"), title: "Carbohydrates", amount: carbText, icon: "capsule")
                        }
                        .padding(.horizontal, 24)
                    }
                    
                    // Current Goal
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Current Goal")
                            .font(.system(size: 14))
                            .foregroundColor(Color(hexString: "6A7282"))
                            .padding(.horizontal, 24)
                        GoalCard(
                            percent: userProgress.progressPercent,
                            goalDescription: goalDescriptionText,
                            daysCompleted: daysCompletedText
                        )
                        .padding(.horizontal, 24)
                    }
                    
                    Spacer().frame(height: 24)
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .gesture(
            DragGesture(minimumDistance: 50)
                .onEnded { value in
                    let horizontalAmount = value.translation.width
                    let verticalAmount = value.translation.height
                    
                    // Only handle horizontal swipes (ignore vertical)
                    // Swipe from left to right: go back to profile page
                    if abs(horizontalAmount) > abs(verticalAmount) && horizontalAmount > 0 {
                        dismiss()
                    }
                }
        )
        .onAppear {
            loadProgressData()
        }
        .onChange(of: profiles.count) { oldValue, newValue in
            // Reload when profiles list changes
            loadProgressData()
        }
        .onChange(of: userProfile?.goalStartDate) { oldValue, newValue in
            // Only reload if we have a profile and value actually changed
            guard userProfile != nil, oldValue != newValue else { return }
            loadProgressData()
        }
        .onChange(of: userProfile?.targetDays) { oldValue, newValue in
            // Only reload if we have a profile and value actually changed
            guard userProfile != nil, oldValue != newValue else { return }
            loadProgressData()
        }
        .onChange(of: userProfile?.goal) { oldValue, newValue in
            // Reload when goal changes
            loadProgressData()
        }
        .onChange(of: userProfile?.heightValue) { oldValue, newValue in
            // Reload when profile data changes
            loadProgressData()
        }
        .onChange(of: userProfile?.weightValue) { oldValue, newValue in
            // Reload when profile data changes
            loadProgressData()
        }
    }
    
    // MARK: - Computed Properties
    
    private var heightValueText: String {
        guard let value = userProfile?.heightValue else { return "-" }
        return "\(Int(value))"
    }
    
    private var heightUnitText: String {
        userProfile?.heightUnit ?? "cm"
    }
    
    private var weightValueText: String {
        guard let value = userProfile?.weightValue else { return "-" }
        return "\(Int(value))"
    }
    
    private var weightUnitText: String {
        userProfile?.weightUnit ?? "kg"
    }
    
    private var ageText: String {
        guard let age = userProfile?.age else { return "-" }
        return "\(age)"
    }
    
    private var proteinText: String {
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
    
    private func weightInKg() -> Double? {
        guard let profile = userProfile,
              let value = profile.weightValue,
              let unit = profile.weightUnit else { return nil }
        return HealthCalculator.convertWeightToKg(value, unit: unit)
    }
    
    private var fatText: String {
        guard let macros = recommendedMacros else { return "-" }
        return "\(macros.fat)g"
    }
    
    private var carbText: String {
        guard let macros = recommendedMacros else { return "-" }
        return "\(macros.carbohydrates)g"
    }
    
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
    
    private var goalDescriptionText: String {
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
    
    private var goalSubDescriptionText: String {
        guard let targetDays = userProfile?.targetDays else { return "-" }
        return "\(targetDays) days target"
    }
    
    private var daysCompletedText: String {
        if progressData.targetDays == 0 {
            return "0/0 days"
        }
        return "\(progressData.completedDays)/\(progressData.targetDays) days"
    }
    
    // MARK: - Methods
    
    private func loadProgressData() {
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
              let targetDays = profile.targetDays else {
            let targetDaysValue = profile.targetDays ?? 0
            // Only update if current state is different
            if progressData != (0, targetDaysValue) {
                DispatchQueue.main.async {
                    self.progressData = (0, targetDaysValue)
                }
            }
            return
        }
        
        Task {
            let completedDays = await progressService.getCompletedDays(
                userId: profile.userId,
                startDate: startDate,
                targetDays: targetDays,
                modelContext: modelContext
            )
            
            await MainActor.run {
                self.progressData = (completedDays, targetDays)
            }
        }
    }
}

// MARK: - MetricCard
private struct MetricCard: View {
    let title: String
    let value: String
    let unit: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 14))
                .foregroundColor(Color(hexString: "6A7282"))
            Text(value)
                .font(.system(size: 28, weight: .semibold))
                .foregroundColor(Color(hexString: "101828"))
            Text(unit)
                .font(.system(size: 12))
                .foregroundColor(Color(hexString: "6A7282"))
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 96, alignment: .leading)
        .background(Color.white)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(hexString: "E5E7EB"), lineWidth: 1)
        )
    }
}

// MARK: - NutritionRow
private struct NutritionRow: View {
    let color: Color
    let title: String
    let amount: String
    let icon: String
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(color.opacity(0.12))
                    .frame(width: 44, height: 44)
                Image(systemName: icon)
                    .foregroundColor(color)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(color)
                Text(amount)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(Color(hexString: "101828"))
            }
            Spacer()
            Image(systemName: "info.circle")
                .foregroundColor(Color(hexString: "99A1AF"))
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(hexString: "E5E7EB"), lineWidth: 1)
        )
    }
}

// MARK: - Goal Card
private struct GoalCard: View {
    let percent: Double
    let goalDescription: String
    let daysCompleted: String
    var percentText: String { String(format: "%.0f%%", percent * 100) }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(LinearGradient(colors: [Color(hexString: "7C3AED"), Color(hexString: "A78BFA")], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 48, height: 48)
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .foregroundColor(.white)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(goalDescription)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(Color(hexString: "101828"))
                    Text(daysCompleted)
                        .font(.system(size: 14))
                        .foregroundColor(Color(hexString: "6A7282"))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Progress")
                        .font(.system(size: 14))
                        .foregroundColor(Color(hexString: "6A7282"))
                    Spacer()
                    Text(percentText)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color(hexString: "7C3AED"))
                }
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(hexString: "E5E7EB"))
                            .frame(height: 8)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(hexString: "A78BFA"))
                            .frame(width: geometry.size.width * CGFloat(percent), height: 8)
                            .animation(.easeInOut(duration: 0.5), value: percent)
                    }
                }
                .frame(height: 8)
                Text(daysCompleted)
                    .font(.system(size: 12))
                    .foregroundColor(Color(hexString: "6A7282"))
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(hexString: "E5E7EB"), lineWidth: 1)
        )
    }
}

#Preview {
    ProgressView()
        .environmentObject(AuthService.shared)
        .environmentObject(UserProgress())
        .modelContainer(for: [UserProfile.self, DailyCompletion.self])
}
