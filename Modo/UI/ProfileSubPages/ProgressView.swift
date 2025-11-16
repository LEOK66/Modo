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
    
    // Get current user's profile
    private var userProfile: UserProfile? {
        guard let userId = authService.currentUser?.uid else { return nil }
        return profiles.first { $0.userId == userId }
    }
    
    var body: some View {
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
                            NutritionRow(color: Color(hexString: "2E90FA"), title: "Protein", amount: viewModel.proteinText, icon: "shield")
                            NutritionRow(color: Color(hexString: "22C55E"), title: "Fat", amount: viewModel.fatText, icon: "heart")
                            NutritionRow(color: Color(hexString: "F59E0B"), title: "Carbohydrates", amount: viewModel.carbText, icon: "capsule")
                        }
                        .padding(.horizontal, 24)
                    }
                    
                    // Current Goal
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Current Goal")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 24)
                        GoalCard(
                            percent: userProgress.progressPercent,
                            goalDescription: viewModel.goalDescriptionText,
                            daysCompleted: viewModel.daysCompletedText
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
            // Setup ViewModel with dependencies
            viewModel.setup(
                modelContext: modelContext,
                authService: authService,
                userProfile: userProfile
            )
        }
        .onChange(of: profiles.count) { oldValue, newValue in
            // Reload when profiles list changes
            if let profile = userProfile {
                viewModel.updateUserProfile(profile)
            }
        }
        .onChange(of: userProfile?.goalStartDate) { oldValue, newValue in
            // Only reload if we have a profile and value actually changed
            guard userProfile != nil, oldValue != newValue else { return }
            if let profile = userProfile {
                viewModel.updateUserProfile(profile)
            }
        }
        .onChange(of: userProfile?.targetDays) { oldValue, newValue in
            // Only reload if we have a profile and value actually changed
            guard userProfile != nil, oldValue != newValue else { return }
            if let profile = userProfile {
                viewModel.updateUserProfile(profile)
            }
        }
        .onChange(of: userProfile?.goal) { oldValue, newValue in
            // Reload when goal changes
            if let profile = userProfile {
                viewModel.updateUserProfile(profile)
            }
        }
        .onChange(of: userProfile?.heightValue) { oldValue, newValue in
            // Reload when profile data changes
            if let profile = userProfile {
                viewModel.updateUserProfile(profile)
            }
        }
        .onChange(of: userProfile?.weightValue) { oldValue, newValue in
            // Reload when profile data changes
            if let profile = userProfile {
                viewModel.updateUserProfile(profile)
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
                    .foregroundColor(.primary)
            }
            Spacer()
            Image(systemName: "info.circle")
                .foregroundColor(.secondary)
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
                        .foregroundColor(.primary)
                    Text(daysCompleted)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
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

#Preview {
    ProgressPageView()
        .environmentObject(AuthService.shared)
        .environmentObject(UserProgress())
        .modelContainer(for: [UserProfile.self, DailyCompletion.self])
}
