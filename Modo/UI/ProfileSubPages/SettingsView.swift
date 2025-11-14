import SwiftUI

// MARK: - Settings View
struct SettingsView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @State private var notificationsEnabled = true
    
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
                    VStack(spacing: 0) {
                        SettingsRowNavigationLink(
                            icon: "globe",
                            title: "Language",
                            subtitle: "English",
                            showDivider: true
                        ) {
                            ComingSoonView()
                        }
                        
                        SettingsToggleRow(
                            icon: "bell",
                            title: "Notifications",
                            subtitle: "Push alerts & reminders",
                            isOn: $notificationsEnabled
                        )
                    }
                }
                
                // Privacy & Security Section
                settingsSection(title: "Privacy & Security") {
                    VStack(spacing: 0) {
                        SettingsRowNavigationLink(
                            icon: "shield",
                            title: "Privacy Preferences",
                            subtitle: "Data collection & sharing",
                            showDivider: true
                        ) {
                            ComingSoonView()
                        }
                        
                        SettingsRowNavigationLink(
                            icon: "envelope",
                            title: "Change Email",
                            subtitle: "sarah.j@email.com",
                            showDivider: true
                        ) {
                            ComingSoonView()
                        }
                        
                        SettingsRowNavigationLink(
                            icon: "lock",
                            title: "Change Password",
                            subtitle: "Last updated 30 days ago",
                            showDivider: false
                        ) {
                            ComingSoonView()
                        }
                    }
                }
                
                // Data Management Section
                settingsSection(title: "Data Management") {
                    SettingsRowNavigationLink(
                        icon: "arrow.down.doc",
                        title: "Export Data",
                        subtitle: "Download your information",
                        showDivider: false
                    ) {
                        ComingSoonView()
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
                            
                            Text("1.0.0 (Build 2025)")
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
