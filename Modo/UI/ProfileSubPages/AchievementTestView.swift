import SwiftUI
import SwiftData
import FirebaseAuth

// MARK: - Achievement Test View

/// Debug view for testing achievement unlocks
/// Only available in DEBUG builds
struct AchievementTestView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var userAchievements: [String: UserAchievement] = [:]
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    private let achievementService: AchievementServiceProtocol
    
    private let allCategories: [AchievementCategory] = [
        .streak, .task, .challenge, .fitness, .diet, .ai, .milestone, .mystery
    ]
    
    init() {
        self.achievementService = ServiceContainer.shared.achievementService
    }
    
    var body: some View {
        ZStack(alignment: .top) {
            Color(.systemBackground).ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                PageHeader(title: "Test Achievements")
                    .padding(.top, 12)
                    .padding(.horizontal, 24)
                
                Spacer().frame(height: 12)
                
                // Content
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if let errorMessage = errorMessage {
                            Text("Error: \(errorMessage)")
                                .foregroundColor(.red)
                                .padding()
                        }
                        
                        // Instructions
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Instructions")
                                .font(.system(size: 16, weight: .semibold))
                            
                            Text("Tap any achievement button below to manually unlock it. This will trigger the unlock animation and save the achievement to Firebase.")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(12)
                        .padding(.horizontal, 24)
                        
                        // Achievements grouped by category
                        ForEach(allCategories, id: \.self) { category in
                            let achievements = Achievement.allAchievements.filter { $0.category == category }
                            
                            if !achievements.isEmpty {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text(category.rawValue.capitalized)
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.secondary)
                                        .padding(.leading, 4)
                                    
                                    VStack(spacing: 8) {
                                        ForEach(achievements) { achievement in
                                            AchievementTestRow(
                                                achievement: achievement,
                                                userAchievement: userAchievements[achievement.id],
                                                onUnlock: {
                                                    unlockAchievement(achievement)
                                                }
                                            )
                                        }
                                    }
                                    .background(Color(.systemBackground))
                                    .cornerRadius(16)
                                    .shadow(color: Color.primary.opacity(0.1), radius: 3, x: 0, y: 1)
                                }
                                .padding(.horizontal, 24)
                            }
                        }
                    }
                    .padding(.vertical, 16)
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .task {
            await loadUserAchievements()
        }
    }
    
    private func loadUserAchievements() async {
        guard let userId = Auth.auth().currentUser?.uid else {
            errorMessage = "No user logged in"
            return
        }
        
        isLoading = true
        do {
            userAchievements = try await achievementService.getUserAchievements(userId: userId)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
    
    private func unlockAchievement(_ achievement: Achievement) {
        guard let userId = Auth.auth().currentUser?.uid else {
            errorMessage = "No user logged in"
            return
        }
        
        Task {
            do {
                // Manually set progress to target value to trigger unlock
                try await achievementService.updateProgress(
                    userId: userId,
                    achievementId: achievement.id,
                    progress: achievement.unlockCondition.targetValue
                )
                
                // Reload achievements to get updated status
                await loadUserAchievements()
                
                // Get the updated user achievement and trigger unlock animation
                if let userAchievement = userAchievements[achievement.id],
                   userAchievement.isUnlocked {
                    AchievementUnlockManager.shared.queueUnlock(
                        achievement: achievement,
                        userAchievement: userAchievement
                    )
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

// MARK: - Achievement Test Row

struct AchievementTestRow: View {
    let achievement: Achievement
    let userAchievement: UserAchievement?
    let onUnlock: () -> Void
    
    var isUnlocked: Bool {
        userAchievement?.isUnlocked ?? false
    }
    
    var progress: Int {
        userAchievement?.currentProgress ?? 0
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(hexString: achievement.iconColor).opacity(0.2))
                    .frame(width: 50, height: 50)
                
                Group {
                    if achievement.iconName.starts(with: "system:") {
                        Image(systemName: String(achievement.iconName.dropFirst(7)))
                    } else {
                        Image(achievement.iconName)
                    }
                }
                .font(.system(size: 24))
                .foregroundColor(Color(hexString: achievement.iconColor))
            }
            
            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(achievement.title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)
                
                Text(achievement.description)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                
                // Progress
                if !isUnlocked {
                    Text("Progress: \(progress) / \(achievement.unlockCondition.targetValue)")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Unlock Button
            Button(action: onUnlock) {
                Text(isUnlocked ? "Unlocked" : "Unlock")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(isUnlocked ? .secondary : .white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(isUnlocked ? Color(.secondarySystemBackground) : Color(hexString: achievement.iconColor))
                    .cornerRadius(8)
            }
            .disabled(isUnlocked)
        }
        .padding(16)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        AchievementTestView()
    }
}

