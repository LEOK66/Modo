import SwiftUI
import SwiftData
import FirebaseAuth

// MARK: - Settings View
struct SettingsView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var authService: AuthService
    @Environment(\.modelContext) private var modelContext
    
    // Check if user can change password (only for email/password accounts)
    private var canChangePassword: Bool {
        guard let user = authService.currentUser else { return false }
        return user.providerData.contains { provider in
            provider.providerID == "password"
        }
    }
    
    var body: some View {
        ZStack(alignment: .top) {
            Color(.systemBackground).ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                PageHeader(title: "Settings")
                    .padding(.top, 12)
                    .padding(.horizontal, 24)
                
                Spacer().frame(height: 12)
                
                // Content
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                // Appearance Section
                settingsSection(title: "Appearance") {
                    SettingsToggleRow(
                        icon: "moon.fill",
                        title: "Dark Mode",
                        subtitle: "Switch to dark theme",
                        isOn: $themeManager.isDarkMode
                    )
                }
                
                // Preferences Section
                settingsSection(title: "Preferences") {
                    SettingsRowNavigationLink(
                        icon: "globe",
                        title: "Language",
                        subtitle: "English",
                        showDivider: false
                    ) {
                        ComingSoonView()
                    }
                }
                
                // Privacy & Security Section
                settingsSection(title: "Privacy & Security") {
                    VStack(spacing: 0) {
                        SettingsRowNavigationLink(
                            icon: "shield",
                            title: "Privacy Preferences",
                            subtitle: "Data collection & sharing",
                            showDivider: canChangePassword
                        ) {
                            PrivacyPreferencesView()
                        }
                        
                        if canChangePassword {
                            SettingsRowNavigationLink(
                                icon: "lock",
                                title: "Change Password",
                                subtitle: "Update your password",
                                showDivider: false
                            ) {
                                ChangePasswordView()
                            }
                        }
                    }
                }
                
                // About Section
                settingsSection(title: "About") {
                    HStack(spacing: 16) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color(.secondarySystemBackground))
                                .frame(width: 40, height: 40)
                            
                            Image(systemName: "info.circle")
                                .font(.system(size: 20))
                                .foregroundColor(.primary)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("App Version")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.primary)
                            
                            Text(Bundle.main.versionString)
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Text("Up to date")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Color(hexString: "008335"))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color(hexString: "DCFCE7"))
                            .cornerRadius(10)
                    }
                    .padding(20)
                }
                
                // Debug Section (only in DEBUG mode)
                #if DEBUG
                settingsSection(title: "Debug") {
                    VStack(spacing: 0) {
                        SettingsRowNavigationLink(
                            icon: "flame.fill",
                            title: "Test Streak",
                            subtitle: "Test streak functionality",
                            showDivider: true
                        ) {
                            StreakTestView()
                        }
                        
                        SettingsRowNavigationLink(
                            icon: "target",
                            title: "Test Goal",
                            subtitle: "Test goal progress calculation",
                            showDivider: false
                        ) {
                            GoalTestView()
                        }
                    }
                }
                #endif
                    }
                    .padding(.vertical, 16)
                }
                .background(Color(.secondarySystemBackground))
            }
        }
        .navigationBarBackButtonHidden(true)
    }
    
    // MARK: - Helper Views
    @ViewBuilder
    private func settingsSection<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
                .padding(.leading, 4)
            
            content()
                .background(Color(.systemBackground))
                .cornerRadius(16)
                .shadow(color: Color.primary.opacity(0.1), radius: 3, x: 0, y: 1)
                .shadow(color: Color.primary.opacity(0.1), radius: 2, x: 0, y: 1)
        }
        .padding(.horizontal, 24)
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        SettingsView()
            .environmentObject(ThemeManager())
    }
}
