import SwiftUI

// MARK: - Settings View
struct SettingsView: View {
    @StateObject private var themeManager = ThemeManager()
    @State private var notificationsEnabled = true
    
    var body: some View {
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
                        SettingsRowButton(
                            icon: "globe",
                            title: "Language",
                            subtitle: "English",
                            showDivider: true
                        ) {
                            // Language action
                        }
                        
                        SettingsRowButton(
                            icon: "ruler",
                            title: "Units",
                            subtitle: "Metric (kg, km, cal)",
                            showDivider: true
                        ) {
                            // Units action
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
                        SettingsRowButton(
                            icon: "shield",
                            title: "Privacy Preferences",
                            subtitle: "Data collection & sharing",
                            showDivider: true
                        ) {
                            // Privacy action
                        }
                        
                        SettingsRowButton(
                            icon: "envelope",
                            title: "Change Email",
                            subtitle: "sarah.j@email.com",
                            showDivider: true
                        ) {
                            // Email action
                        }
                        
                        SettingsRowButton(
                            icon: "lock",
                            title: "Change Password",
                            subtitle: "Last updated 30 days ago",
                            showDivider: false
                        ) {
                            // Password action
                        }
                    }
                }
                
                // Data Management Section
                settingsSection(title: "Data Management") {
                    SettingsRowButton(
                        icon: "arrow.down.doc",
                        title: "Export Data",
                        subtitle: "Download your information",
                        showDivider: false
                    ) {
                        // Export action
                    }
                }
                
                // About Section
                settingsSection(title: "About") {
                    HStack(spacing: 16) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color(hexString: "F3F4F6"))
                                .frame(width: 40, height: 40)
                            
                            Image(systemName: "info.circle")
                                .font(.system(size: 20))
                                .foregroundColor(Color(hexString: "364153"))
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("App Version")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(Color(hexString: "101828"))
                            
                            Text("1.0.0 (Build 2025)")
                                .font(.system(size: 12))
                                .foregroundColor(Color(hexString: "6A7282"))
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
        .background(Color(hexString: "F3F4F6"))
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
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
                .foregroundColor(Color(hexString: "6A7282"))
                .padding(.leading, 4)
            
            content()
                .background(Color.white)
                .cornerRadius(16)
                .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 1)
                .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
        }
        .padding(.horizontal, 24)
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        SettingsView()
    }
}
