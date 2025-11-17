import SwiftUI

// MARK: - Achievements View
struct AchievementsView: View {
    @State private var achievements = Achievement.allAchievements
    
    private var unlockedCount: Int {
        achievements.filter { $0.isUnlocked }.count
    }
    
    private var totalCount: Int {
        achievements.count
    }
    
    private var progress: Double {
        Double(unlockedCount) / Double(totalCount)
    }
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [Color(hexString: "F9FAFB"), Color.white],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                PageHeader(title: "Achievements")
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 32) {
                        // Progress Card
                        ProgressCard(
                            unlockedCount: unlockedCount,
                            totalCount: totalCount,
                            progress: progress
                        )
                        .padding(.horizontal, 16)
                        .padding(.top, 24)
                        
                        // Unlocked Section
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Unlocked")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(Color(hexString: "364153"))
                                .padding(.horizontal, 16)
                            
                            BadgeGrid(achievements: Achievement.unlockedAchievements)
                                .padding(.horizontal, 16)
                        }
                        
                        // Locked Section
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Locked")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(Color(hexString: "364153"))
                                .padding(.horizontal, 16)
                            
                            BadgeGrid(achievements: Achievement.lockedAchievements)
                                .padding(.horizontal, 16)
                        }
                        .padding(.bottom, 24)
                    }
                }
            }
        }
    }
}

// MARK: - Progress Card
private struct ProgressCard: View {
    let unlockedCount: Int
    let totalCount: Int
    let progress: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header with icon
            HStack(spacing: 12) {
                Image(systemName: "star.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(Color(hexString: "FDC700"))
                
                Text("Badges Collected")
                    .font(.system(size: 16))
                    .foregroundColor(.white)
                    .tracking(-0.31)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            
            // Count
            Text("\(unlockedCount)/\(totalCount)")
                .font(.system(size: 48, weight: .regular))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .center)
                .tracking(0.35)
            
            // Progress bar
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 100)
                    .fill(Color(hexString: "364153"))
                    .frame(height: 8)
                
                GeometryReader { geometry in
                    RoundedRectangle(cornerRadius: 100)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(hexString: "FDC700"),
                                    Color(hexString: "FFDF20"),
                                    Color(hexString: "F0B100")
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * progress, height: 8)
                }
                .frame(height: 8)
            }
            .padding(.top, 8)
        }
        .padding(24)
        .background(
            LinearGradient(
                colors: [
                    Color(hexString: "000000"),
                    Color(hexString: "101828"),
                    Color(hexString: "1E2939")
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(24)
        .shadow(color: Color.black.opacity(0.1), radius: 20, x: 0, y: 20)
        .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 8)
    }
}

// MARK: - Badge Grid
private struct BadgeGrid: View {
    let achievements: [Achievement]
    
    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]
    
    var body: some View {
        LazyVGrid(columns: columns, spacing: 16) {
            ForEach(achievements) { achievement in
                BadgeCard(achievement: achievement)
            }
        }
    }
}

// MARK: - Preview
#Preview {
    AchievementsView()
}
