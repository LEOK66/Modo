import SwiftUI

struct ProfileContent: View {
    let username: String
    let email: String
    let progressPercent: Double
    let daysCompletedText: String
    let expectedCaloriesText: String
    let currentlyCaloriesText: String
    let avatarName: String?
    let profileImageURL: String?
    let onEditUsername: () -> Void
    let onLogoutTap: () -> Void
    let onEditAvatar: () -> Void
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                // MARK: - Profile header
                ProfileHeaderView(
                    username: username,
                    email: email,
                    avatarName: avatarName,
                    profileImageURL: profileImageURL,
                    onEdit: onEditUsername,
                    onEditAvatar: onEditAvatar
                )
                .padding(.top, 8)

                // MARK: - Stats row
                NavigationLink(destination: ProgressView()) {
                    StatsCardView(
                        progressPercent: progressPercent,
                        daysCompletedText: daysCompletedText,
                        expectedCaloriesText: expectedCaloriesText,
                        currentlyCaloriesText: currentlyCaloriesText
                    )
                }
                .buttonStyle(PlainButtonStyle())

                // MARK: - Daily Challenge
                DailyChallengeCardView()
                    .padding(.top, -16)
                    .frame(maxWidth: .infinity, alignment: .center)

                // MARK: - Performance & Achievements section
                VStack(spacing: 12) {
                    NavigationRow(icon: "rosette", title: "Achievements", subtitle: "Unlock badges", destination: AnyView(AchievementsView()))
                    NavigationRow(icon: "gearshape", title: "Settings", subtitle: "App preferences", destination: AnyView(SettingsView()))
                    NavigationRow(icon: "questionmark.circle", title: "Help & Support", subtitle: "Get assistance", destination: AnyView(HelpSupportView()))
                }
                .frame(maxWidth: .infinity, alignment: .center)
                
                // MARK: - Logout
                LogoutRow {
                    onLogoutTap()
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.bottom, 24)
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

