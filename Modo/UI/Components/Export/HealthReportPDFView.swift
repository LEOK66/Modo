import SwiftUI

/// SwiftUI view representing the health report PDF content
/// Designed for A4 PDF export (595x842 points)
struct HealthReportPDFView: View {
    let data: PDFExportService.HealthReportData
    
    // A4 dimensions in points
    private let pageWidth: CGFloat = 595
    private let pageHeight: CGFloat = 842
    private let horizontalPadding: CGFloat = 50
    
    private var contentWidth: CGFloat {
        pageWidth - (horizontalPadding * 2)
    }
    
    private var generatedDateText: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .short
        return formatter.string(from: Date())
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Cover Page Section
            coverPage
                .frame(height: 230)
            
            Divider()
                .padding(.vertical, 16)
            
            // Body Metrics Section
            bodyMetricsSection
                .padding(.bottom, 16)
            
            Divider()
                .padding(.vertical, 16)
            
            // Nutrition Recommendations Section
            nutritionSection
                .padding(.bottom, 16)
            
            Divider()
                .padding(.vertical, 16)
            
            // Goal Progress Section
            goalProgressSection
                .padding(.bottom, 16)
            
            Spacer()
            
            // Footer
            footer
        }
        .frame(width: pageWidth, height: pageHeight)
        .padding(.horizontal, horizontalPadding)
        .padding(.vertical, 40)
        .background(Color.white)
    }
    
    // MARK: - Cover Page
    private var coverPage: some View {
        VStack(spacing: 0) {
            Spacer()
                .frame(height: 20)
            
            // App Title
            VStack(spacing: 14) {
                // App Name
                Text("Modor")
                    .font(.system(size: 40, weight: .bold))
                    .foregroundColor(.primary)
                
                Text("Health & Fitness Report")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundColor(.primary)
            }
            
            Spacer()
                .frame(height: 24)
            
            // User Info
            VStack(spacing: 6) {
                if let username = data.userProfile.username, !username.isEmpty {
                    Text(username)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.primary)
                }
            }
            
            Spacer()
                .frame(height: 18)
            
            // Generated Date
            Text("Generated on \(generatedDateText)")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .lineSpacing(2)
            
            Spacer()
                .frame(height: 10)
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Body Metrics Section
    private var bodyMetricsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Body Metrics")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.primary)
            
            HStack(spacing: 12) {
                metricCard(
                    title: "Height",
                    value: data.profileMetrics.height.isEmpty ? "N/A" : data.profileMetrics.height
                )
                metricCard(
                    title: "Weight",
                    value: data.profileMetrics.weight.isEmpty ? "N/A" : data.profileMetrics.weight
                )
                metricCard(
                    title: "Age",
                    value: data.profileMetrics.age.isEmpty ? "N/A" : data.profileMetrics.age
                )
            }
        }
    }
    
    // MARK: - Nutrition Section
    private var nutritionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Daily Nutrition Recommendations")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.primary)
            
            VStack(spacing: 10) {
                nutritionRow(
                    color: Color(hexString: "2E90FA"),
                    title: "Protein",
                    amount: data.nutritionRecommendations.protein.isEmpty ? "N/A" : data.nutritionRecommendations.protein,
                    icon: "shield.fill"
                )
                
                nutritionRow(
                    color: Color(hexString: "22C55E"),
                    title: "Fat",
                    amount: data.nutritionRecommendations.fat.isEmpty ? "N/A" : data.nutritionRecommendations.fat,
                    icon: "heart.fill"
                )
                
                nutritionRow(
                    color: Color(hexString: "F59E0B"),
                    title: "Carbohydrates",
                    amount: data.nutritionRecommendations.carbohydrates.isEmpty ? "N/A" : data.nutritionRecommendations.carbohydrates,
                    icon: "bolt.fill"
                )
            }
        }
    }
    
    // MARK: - Goal Progress Section
    private var goalProgressSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Goal Progress")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.primary)
            
            VStack(alignment: .leading, spacing: 10) {
                Text(data.goalProgress.description.isEmpty ? "No active goal" : data.goalProgress.description)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                
                Text("\(data.goalProgress.completedDays)/\(data.goalProgress.targetDays) days completed")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                
                // Progress Bar with fixed width
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: contentWidth - 32, height: 10)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(hexString: "7C3AED"))
                        .frame(
                            width: (contentWidth - 32) * CGFloat(max(0, min(1, data.goalProgress.percentage))),
                            height: 10
                        )
                }
                .frame(height: 10)
                
                Text(String(format: "%.0f%%", min(100, max(0, data.goalProgress.percentage * 100))))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color(hexString: "7C3AED"))
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(red: 0.95, green: 0.95, blue: 0.97))
            .cornerRadius(10)
        }
    }
    
    // MARK: - Footer
    private var footer: some View {
        VStack(spacing: 8) {
            Divider()
            
            VStack(spacing: 4) {
                Text("This report contains your personal health and fitness data.")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                
                Text("Please keep this document secure and private.")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Helper Views
    private func metricCard(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(red: 0.95, green: 0.95, blue: 0.97))
        .cornerRadius(8)
    }
    
    private func nutritionRow(color: Color, title: String, amount: String, icon: String) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(color.opacity(0.15))
                    .frame(width: 38, height: 38)
                
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.system(size: 17))
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(color)
                
                Text(amount)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)
            }
            
            Spacer()
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(red: 0.95, green: 0.95, blue: 0.97))
        .cornerRadius(8)
    }
}

// MARK: - Preview
#Preview {
    let sampleData = PDFExportService.HealthReportData(
        userProfile: UserProfile(userId: "test"),
        profileMetrics: PDFExportService.HealthReportData.ProfileMetrics(
            height: "175 cm",
            weight: "70 kg",
            age: "25 years"
        ),
        nutritionRecommendations: PDFExportService.HealthReportData.NutritionRecommendations(
            protein: "150g",
            fat: "65g",
            carbohydrates: "200g"
        ),
        goalProgress: PDFExportService.HealthReportData.GoalProgress(
            description: "Lose 5 kg",
            completedDays: 15,
            targetDays: 30,
            percentage: 0.5
        )
    )
    
    ScrollView {
        HealthReportPDFView(data: sampleData)
    }
}
