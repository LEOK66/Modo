import SwiftUI
import Combine

class UserProgress: ObservableObject {
    // MARK: - Published properties for progress percentage
    @Published var progressPercent: Double = 0.75
}

struct ProgressView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var userProgress: UserProgress
    
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
                        Color.clear.frame(width: 44, height: 44)
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
                            MetricCard(title: "Height", value: "170", unit: "cm")
                            MetricCard(title: "Weight", value: "65", unit: "kg")
                            MetricCard(title: "Age", value: "28", unit: "years")
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
                            NutritionRow(color: Color(hexString: "2E90FA"), title: "Protein", amount: "150g", icon: "shield")
                            NutritionRow(color: Color(hexString: "22C55E"), title: "Fat", amount: "70g", icon: "heart")
                            NutritionRow(color: Color(hexString: "F59E0B"), title: "Carbohydrates", amount: "300g", icon: "capsule")
                        }
                        .padding(.horizontal, 24)
                    }
                    
                    // Current Goal
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Current Goal")
                                .font(.system(size: 14))
                                .foregroundColor(Color(hexString: "6A7282"))
                            Spacer()
                            NavigationLink(destination: InfoGatheringView().environmentObject(authService)) {
                                Text("Change")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(Color(hexString: "7C3AED"))
                            }
                        }
                        .padding(.horizontal, 24)
                        GoalCard(percent: userProgress.progressPercent)
                            .padding(.horizontal, 24)
                    }
                    
                    Spacer().frame(height: 24)
                }
            }
        }
        .navigationBarBackButtonHidden(true)
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
                    Text("Lose Weight")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(Color(hexString: "101828"))
                    Text("Target: Lose 5kg in 3 months with healthy habits")
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
                    }
                }
                .frame(height: 8)
                Text("36 days streak 🔥")
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
    ProgressView().environmentObject(AuthService.shared).environmentObject(UserProgress())
}
