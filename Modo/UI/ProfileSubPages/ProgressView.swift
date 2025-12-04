import SwiftUI
import SwiftData
import Combine
import FirebaseAuth

class UserProgress: ObservableObject {
    // MARK: - Published properties for progress percentage
    @Published var progressPercent: Double = 0.0
}

struct ProgressPageView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var userProgress: UserProgress
    @Query private var profiles: [UserProfile]
    
    // ViewModel - manages all business logic and state
    @StateObject private var viewModel = ProgressViewModel()
    
    // Navigation state
    @State private var showEditProfile = false
    @State private var showMacroBreakdown = false
    
    // Extract userId separately to reduce optional chaining inside closures
    private var currentUserId: String? {
        authService.currentUser?.uid
    }
    
    // Get current user's profile (avoid complex closure capture)
    private var userProfile: UserProfile? {
        guard let uid = currentUserId else { return nil }
        for p in profiles where p.userId == uid {
            return p
        }
        return nil
    }
    
    // Mirror simple, Equatable-friendly values for onChange to reduce type-checking cost
    private var goalStartDateValue: Date? { userProfile?.goalStartDate }
    private var targetDaysValue: Int? { userProfile?.targetDays }
    private var goalValue: String? { userProfile?.goal }
    private var heightValue: Double? { userProfile?.heightValue }
    private var weightValue: Double? { userProfile?.weightValue }
    
    // Progress data components for onChange observation
    private var progressCompletedDays: Int { viewModel.progressData.completedDays }
    private var progressTargetDays: Int { viewModel.progressData.targetDays }
    
    var body: some View {
        // Break large chains into smaller parts for the type checker
        let view = contentView
            .navigationBarBackButtonHidden(true)
            .gesture(swipeGesture)
        
        view
            .onAppear(perform: handleAppear)
            .onChange(of: profiles.count) { oldValue, newValue in
                handleProfilesCountChange(oldValue: oldValue, newValue: newValue)
            }
            .onChange(of: goalStartDateValue) { oldValue, newValue in
                handleProfileChange(oldValue: oldValue, newValue: newValue)
            }
            .onChange(of: targetDaysValue) { oldValue, newValue in
                handleProfileChange(oldValue: oldValue, newValue: newValue)
            }
            .onChange(of: goalValue) { oldValue, newValue in
                handleProfileChange(oldValue: oldValue, newValue: newValue)
            }
            .onChange(of: heightValue) { oldValue, newValue in
                handleProfileChange(oldValue: oldValue, newValue: newValue)
            }
            .onChange(of: weightValue) { oldValue, newValue in
                handleProfileChange(oldValue: oldValue, newValue: newValue)
            }
            // Observe progress data changes (observe both components separately)
            .onChange(of: progressCompletedDays) { oldValue, newValue in
                handleProgressDataChange()
            }
            .onChange(of: progressTargetDays) { oldValue, newValue in
                handleProgressDataChange()
            }
            .sheet(isPresented: $showEditProfile) {
                NavigationStack {
                    EditProfileView()
                        .environmentObject(authService)
                }
            }
            .sheet(isPresented: $showMacroBreakdown) {
                MacroBreakdownView(
                    macroType: viewModel.selectedMacroType,
                    viewModel: viewModel
                )
            }
    }
    
    // MARK: - View Components
    private var contentView: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            ScrollView {
                VStack(spacing: 16) {
                    // Header
                    HStack(spacing: 12) {
                        BackButton(action: { dismiss() })
                            .frame(width: 66, height: 44)
                        Spacer()
                        Text("Progress")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.primary)
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
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 24)
                        HStack(spacing: 12) {
                            MetricCard(
                                title: "Height",
                                value: viewModel.heightValueText,
                                unit: viewModel.heightUnitText
                            )
                            MetricCard(
                                title: "Weight",
                                value: viewModel.weightValueText,
                                unit: viewModel.weightUnitText
                            )
                            MetricCard(
                                title: "Age",
                                value: viewModel.ageText,
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
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 24)
                        VStack(spacing: 12) {
                            NutritionRow(
                                color: Color(hexString: "2E90FA"),
                                title: "Protein",
                                recommended: viewModel.proteinText,
                                actual: viewModel.todayProtein,
                                progress: viewModel.proteinProgress,
                                icon: "shield",
                                onInfoTap: {
                                    viewModel.selectedMacroType = .protein
                                    showMacroBreakdown = true
                                }
                            )
                            NutritionRow(
                                color: Color(hexString: "22C55E"),
                                title: "Fat",
                                recommended: viewModel.fatText,
                                actual: viewModel.todayFat,
                                progress: viewModel.fatProgress,
                                icon: "heart",
                                onInfoTap: {
                                    viewModel.selectedMacroType = .fat
                                    showMacroBreakdown = true
                                }
                            )
                            NutritionRow(
                                color: Color(hexString: "F59E0B"),
                                title: "Carbohydrates",
                                recommended: viewModel.carbText,
                                actual: viewModel.todayCarbs,
                                progress: viewModel.carbsProgress,
                                icon: "capsule",
                                onInfoTap: {
                                    viewModel.selectedMacroType = .carbs
                                    showMacroBreakdown = true
                                }
                            )
                        }
                        .padding(.horizontal, 24)
                        
                        if viewModel.hasMetAllMacroGoals {
                            MacroGoalCelebrationView()
                                .padding(.horizontal, 24)
                                .transition(.opacity)
                        }
                    }
                    
                    // Current Goal
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Current Goal")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 24)
                        
                        if viewModel.isGoalExpired {
                            // Show expired goal UI
                            ExpiredGoalCard(
                                goalDescription: viewModel.goalDescriptionText,
                                daysCompleted: viewModel.daysCompletedText,
                                isCompleted: viewModel.isGoalCompleted,
                                endDate: viewModel.goalEndDateText ?? "",
                                onResetGoal: {
                                    showEditProfile = true
                                }
                            )
                            .padding(.horizontal, 24)
                        } else if viewModel.isGoalCompleted {
                            // Show completed goal UI (goal reached 100% but not expired yet)
                            CompletedGoalCard(
                                goalDescription: viewModel.goalDescriptionText,
                                daysCompleted: viewModel.daysCompletedText,
                                endDate: viewModel.goalEndDateText,
                                onSetNewGoal: {
                                    showEditProfile = true
                                }
                            )
                            .padding(.horizontal, 24)
                        } else {
                            // Show active goal UI
                            GoalCard(
                                percent: userProgress.progressPercent,
                                goalDescription: viewModel.goalDescriptionText,
                                daysCompleted: viewModel.daysCompletedText,
                                startDate: viewModel.goalStartDateText,
                                endDate: viewModel.goalEndDateText
                            )
                            .padding(.horizontal, 24)
                        }
                    }
                    
                    Spacer().frame(height: 24)
                }
            }
        }
    }
    
    // MARK: - Gestures
    private var swipeGesture: some Gesture {
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
    }
    
    // MARK: - Event Handlers
    private func handleAppear() {
        // Setup ViewModel with dependencies
        viewModel.setup(
            modelContext: modelContext,
            authService: authService,
            userProfile: userProfile
        )
        // Refresh macro data when view appears (in case tasks were updated)
        viewModel.loadTodayMacros()
    }
    
    private func handleProfilesCountChange(oldValue: Int, newValue: Int) {
        // Reload when profiles list changes
        if let profile = userProfile {
            viewModel.updateUserProfile(profile)
        }
    }
    
    /// Handle profile property changes - updates viewModel when any profile property changes
    private func handleProfileChange<T: Equatable>(oldValue: T?, newValue: T?) {
        // Only reload if we have a profile and value actually changed
        guard let profile = userProfile, oldValue != newValue else { return }
        viewModel.updateUserProfile(profile)
    }
    
    private func handleProgressDataChange() {
        // Update userProgress.progressPercent when progressData changes
        // This ensures the progress bar updates automatically when goal is edited and saved
        let progressData = viewModel.progressData
        guard progressData.targetDays > 0 else {
            userProgress.progressPercent = 0.0
            return
        }
        
        // Calculate progress percentage
        let progress = Double(progressData.completedDays) / Double(progressData.targetDays)
        userProgress.progressPercent = min(1.0, max(0.0, progress))
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
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(size: 28, weight: .semibold))
                .foregroundColor(.primary)
            Text(unit)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 96, alignment: .leading)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(.separator), lineWidth: 1)
        )
    }
}

// MARK: - Helper function for formatting macro values
private func formatMacroValue(_ value: Double) -> String {
    if value < 0.1 {
        // Very small values, show 0
        return "0g"
    } else if value < 1.0 {
        // Values less than 1, show 1 decimal place
        return String(format: "%.1fg", value)
    } else {
        // Values >= 1, show as integer
        return "\(Int(round(value)))g"
    }
}

// MARK: - NutritionRow
private struct NutritionRow: View {
    let color: Color
    let title: String
    let recommended: String // e.g., "150g"
    let actual: Double // Actual intake in grams
    let progress: Double // Progress from 0.0 to 1.0
    let icon: String
    let onInfoTap: () -> Void
    
    private var fractionText: String {
        let formattedActual = formatMacroValue(actual)
        return "\(formattedActual)/\(recommended)"
    }
    
    private var percentText: String {
        String(format: "%.0f%%", progress * 100)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
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
                    Text(recommended)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.primary)
                }
                Spacer()
                Button(action: onInfoTap) {
                    Image(systemName: "info.circle")
                        .foregroundColor(.secondary)
                }
            }
            
            // Progress section - similar to GoalCard
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Progress")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(percentText)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(color)
                }
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(.separator))
                            .frame(height: 8)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(color)
                            .frame(width: geometry.size.width * CGFloat(progress), height: 8)
                            .animation(.easeInOut(duration: 0.5), value: progress)
                    }
                }
                .frame(height: 8)
                Text(fractionText)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(.separator), lineWidth: 1)
        )
    }
}

// MARK: - Macro celebration card
private struct MacroGoalCelebrationView: View {
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(hexString: "16A34A").opacity(0.15))
                    .frame(width: 48, height: 48)
                Image(systemName: "sparkles")
                    .foregroundColor(Color(hexString: "16A34A"))
                    .font(.system(size: 20, weight: .semibold))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Great job!")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                Text("You've met today's nutrition goals.")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(hexString: "16A34A").opacity(0.2), lineWidth: 1)
        )
        .shadow(color: Color.primary.opacity(0.04), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Goal Card
private struct GoalCard: View {
    let percent: Double
    let goalDescription: String
    let daysCompleted: String
    let startDate: String?
    let endDate: String?
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
                        .foregroundColor(.primary)
                    Text(daysCompleted)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    if let startDate = startDate {
                        HStack(spacing: 4) {
                            Image(systemName: "calendar")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                            Text("Starts: \(startDate)")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                    }
                    if let endDate = endDate {
                        HStack(spacing: 4) {
                            Image(systemName: "calendar")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                            Text("Ends: \(endDate)")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Progress")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(percentText)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color(hexString: "7C3AED"))
                }
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(.separator))
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
                    .foregroundColor(.secondary)
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(.separator), lineWidth: 1)
        )
    }
}

// MARK: - Expired Goal Card
private struct ExpiredGoalCard: View {
    let goalDescription: String
    let daysCompleted: String
    let isCompleted: Bool
    let endDate: String
    let onResetGoal: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Status header
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(isCompleted ? 
                              LinearGradient(colors: [Color(hexString: "16A34A"), Color(hexString: "22C55E")], startPoint: .topLeading, endPoint: .bottomTrailing) :
                              LinearGradient(colors: [Color(hexString: "F59E0B"), Color(hexString: "F97316")], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 48, height: 48)
                    Image(systemName: isCompleted ? "checkmark.circle.fill" : "clock.fill")
                        .foregroundColor(.white)
                        .font(.system(size: 24))
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(goalDescription)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.primary)
                    Text(isCompleted ? "Goal Completed!" : "Goal Expired")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(isCompleted ? Color(hexString: "16A34A") : Color(hexString: "F59E0B"))
                }
                Spacer()
            }
            
            // Completion details
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Final Result")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(daysCompleted)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)
                }
                
                if !endDate.isEmpty {
                    HStack {
                        Text("End Date")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(endDate)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.primary)
                    }
                }
            }
            
            Divider()
            
            // Reset goal button
            Button(action: onResetGoal) {
                HStack {
                    Spacer()
                    Text("Set New Goal")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                    Spacer()
                }
                .padding(.vertical, 12)
                .background(
                    LinearGradient(
                        colors: [Color(hexString: "7C3AED"), Color(hexString: "A78BFA")],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(12)
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isCompleted ? Color(hexString: "16A34A").opacity(0.3) : Color(hexString: "F59E0B").opacity(0.3), lineWidth: 1.5)
        )
    }
}

// MARK: - Completed Goal Card
private struct CompletedGoalCard: View {
    let goalDescription: String
    let daysCompleted: String
    let endDate: String?
    let onSetNewGoal: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Status header
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(
                            LinearGradient(
                                colors: [Color(hexString: "16A34A"), Color(hexString: "22C55E")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 48, height: 48)
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.white)
                        .font(.system(size: 24))
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(goalDescription)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.primary)
                    Text("Goal Completed!")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color(hexString: "16A34A"))
                }
                Spacer()
            }
            
            // Completion details
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Final Result")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(daysCompleted)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)
                }
                
                if let endDate = endDate, !endDate.isEmpty {
                    HStack {
                        Text("End Date")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(endDate)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.primary)
                    }
                }
            }
            
            Divider()
            
            // Set new goal button
            Button(action: onSetNewGoal) {
                HStack {
                    Spacer()
                    Text("Set New Goal")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                    Spacer()
                }
                .padding(.vertical, 12)
                .background(
                    LinearGradient(
                        colors: [Color(hexString: "7C3AED"), Color(hexString: "A78BFA")],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(12)
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(hexString: "16A34A").opacity(0.3), lineWidth: 1.5)
        )
    }
}

// MARK: - Macro Breakdown View
private struct MacroBreakdownView: View {
    let macroType: ProgressViewModel.MacroType
    @ObservedObject var viewModel: ProgressViewModel
    @Environment(\.dismiss) private var dismiss
    
    private var macroColor: Color {
        Color(hexString: macroType.color)
    }
    
    private var sources: [ProgressViewModel.MacroSource] {
        viewModel.getMacroBreakdown(for: macroType)
    }
    
    private var totalAmount: Double {
        sources.reduce(0) { $0 + $1.amount }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground)
                    .ignoresSafeArea()
                
                if sources.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "fork.knife")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("No \(macroType.displayName.lowercased()) intake today")
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                    }
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            // Header summary
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Total \(macroType.displayName)")
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                                Text(formatMacroValue(totalAmount))
                                    .font(.system(size: 32, weight: .bold))
                                    .foregroundColor(macroColor)
                            }
                            .padding(.horizontal, 24)
                            .padding(.top, 16)
                            
                            Divider()
                                .padding(.horizontal, 24)
                            
                            // Food sources list
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Sources")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.primary)
                                    .padding(.horizontal, 24)
                                
                                ForEach(sources) { source in
                                    MacroSourceRow(
                                        foodName: source.foodName,
                                        amount: source.amount,
                                        quantity: source.quantity,
                                        color: macroColor
                                    )
                                }
                            }
                            .padding(.top, 8)
                        }
                    }
                }
            }
            .navigationTitle(macroType.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(macroColor)
                }
            }
        }
    }
}

// MARK: - Macro Source Row
private struct MacroSourceRow: View {
    let foodName: String
    let amount: Double
    let quantity: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 16) {
            // Food name and quantity
            VStack(alignment: .leading, spacing: 4) {
                Text(foodName)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)
                Text(quantity)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Amount only
            Text(formatMacroValue(amount))
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(color)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
    }
}

#Preview {
    ProgressPageView()
        .environmentObject(AuthService.shared)
        .environmentObject(UserProgress())
        .modelContainer(for: [UserProfile.self, DailyCompletion.self])
}
