import SwiftUI

// MARK: - Achievements Page View

struct AchievementsPageView: View {
    // Mock data for preview - will be replaced with real service later
    @State private var achievements: [Achievement] = Achievement.allAchievements
    @State private var userAchievements: [UserAchievement] = []
    
    // Computed properties
    private var unlockedCount: Int {
        userAchievements.filter { $0.isUnlocked }.count
    }
    
    private var totalCount: Int {
        achievements.count
    }
    
    private var progress: Double {
        guard totalCount > 0 else { return 0 }
        return Double(unlockedCount) / Double(totalCount)
    }
    
    private var unlockedAchievements: [(Achievement, UserAchievement)] {
        achievements.compactMap { achievement in
            guard let userAchievement = userAchievements.first(where: { $0.achievementId == achievement.id }),
                  userAchievement.isUnlocked else {
                return nil
            }
            return (achievement, userAchievement)
        }
        .sorted { $0.0.order < $1.0.order }
    }
    
    private var lockedAchievements: [(Achievement, UserAchievement)] {
        achievements.compactMap { achievement in
            guard let userAchievement = userAchievements.first(where: { $0.achievementId == achievement.id }),
                  !userAchievement.isUnlocked else {
                return nil
            }
            return (achievement, userAchievement)
        }
        .sorted { $0.0.order < $1.0.order }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Progress card
                    progressCard
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                    
                    // Unlocked section
                    if !unlockedAchievements.isEmpty {
                        achievementSection(
                            title: "Unlocked",
                            achievements: unlockedAchievements
                        )
                    }
                    
                    // Locked section
                    if !lockedAchievements.isEmpty {
                        achievementSection(
                            title: "Locked",
                            achievements: lockedAchievements
                        )
                    }
                }
                .padding(.bottom, 32)
            }
            .background(Color(hex: "#F5F6F7"))
            .navigationTitle("Achievements")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            loadMockData()
        }
    }
    
    // MARK: - Progress Card
    
    private var progressCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Trophy icon and title
            HStack(spacing: 12) {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 24))
                    .foregroundColor(Color(hex: "#FFD700"))
                
                Text("Badges Collected")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
            }
            
            // Count
            Text("\(unlockedCount)/\(totalCount)")
                .font(.system(size: 48, weight: .bold))
                .foregroundColor(.white)
            
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background track
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.2))
                        .frame(height: 8)
                    
                    // Progress fill
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(hex: "#FFD700"))
                        .frame(width: geometry.size.width * progress, height: 8)
                }
            }
            .frame(height: 8)
        }
        .padding(24)
        .background(
            LinearGradient(
                colors: [
                    Color(hex: "#1A1F3A"),
                    Color(hex: "#2D3354")
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(20)
        .shadow(
            color: Color.black.opacity(0.15),
            radius: 12,
            x: 0,
            y: 4
        )
    }
    
    // MARK: - Achievement Section
    
    private func achievementSection(
        title: String,
        achievements: [(Achievement, UserAchievement)]
    ) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section title
            Text(title)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(Color(hex: "#1A1A1A"))
                .padding(.horizontal, 20)
            
            // Achievement grid
            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 16),
                    GridItem(.flexible(), spacing: 16),
                    GridItem(.flexible(), spacing: 16)
                ],
                spacing: 24
            ) {
                ForEach(achievements, id: \.0.id) { achievement, userAchievement in
                    AchievementBadgeView(
                        achievement: achievement,
                        userAchievement: userAchievement
                    )
                }
            }
            .padding(.horizontal, 20)
        }
    }
    
    // MARK: - Mock Data Loading
    
    private func loadMockData() {
        // Initialize user achievements with mock data
        // In production, this would be loaded from AchievementService
        userAchievements = achievements.map { achievement in
            // Mock: unlock first 6 achievements
            let isUnlocked = achievement.order <= 6
            return UserAchievement(
                id: achievement.id,
                achievementId: achievement.id,
                status: isUnlocked ? .unlocked : .locked,
                currentProgress: isUnlocked ? achievement.unlockCondition.targetValue : 0,
                unlockedAt: isUnlocked ? Date() : nil
            )
        }
    }
}

// MARK: - Preview

#Preview {
    AchievementsPageView()
}

