import SwiftUI

// MARK: - Privacy Preferences View
struct PrivacyPreferencesView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack(alignment: .top) {
            Color(.systemBackground).ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                PageHeader(title: "Privacy Preferences")
                    .padding(.top, 12)
                    .padding(.horizontal, 24)
                
                Spacer().frame(height: 12)
                
                // Content
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Privacy Policy Section
                        settingsSection(title: "Legal") {
                            SettingsRowNavigationLink(
                                icon: "doc.text",
                                title: "Privacy Policy",
                                subtitle: "View our complete privacy policy",
                                showDivider: false
                            ) {
                                PrivacyPolicyDetailView()
                            }
                        }
                        
                        // Data Usage Section
                        settingsSection(title: "How We Use Your Data") {
                            VStack(alignment: .leading, spacing: 16) {
                                SettingsInfoRow(
                                    icon: "person.circle",
                                    title: "Profile Information",
                                    description: "Your profile data (name, avatar, age, height, weight) is used to personalize your experience and provide tailored recommendations."
                                )
                                
                                Divider()
                                    .padding(.leading, 76)
                                
                                SettingsInfoRow(
                                    icon: "heart.circle",
                                    title: "Health & Fitness Data",
                                    description: "Your tasks, exercises, and diet entries help us track your progress and generate personalized insights and challenges."
                                )
                                
                                Divider()
                                    .padding(.leading, 76)
                                
                                SettingsInfoRow(
                                    icon: "sparkles",
                                    title: "AI Features",
                                    description: "We use AI to analyze your data and provide personalized recommendations, insights, and task suggestions."
                                )
                            }
                            .padding(.vertical, 8)
                        }
                        
                        // Data Storage Section
                        settingsSection(title: "Data Storage") {
                            SettingsInfoRow(
                                icon: "lock.shield",
                                title: "Secure Storage",
                                description: "Your data is securely stored using Firebase, which employs industry-standard security measures to protect your information."
                            )
                            .padding(.vertical, 8)
                        }
                        
                        // Third-Party Services Section
                        settingsSection(title: "Third-Party Services") {
                            VStack(alignment: .leading, spacing: 16) {
                                SettingsInfoRow(
                                    icon: "flame",
                                    title: "Firebase",
                                    description: "Used for secure authentication and database storage of your data."
                                )
                                
                                Divider()
                                    .padding(.leading, 76)
                                
                                SettingsInfoRow(
                                    icon: "person.badge.key",
                                    title: "Google Sign-In & Apple Sign-In",
                                    description: "Used to securely authenticate your account and sign in to the app."
                                )
                                
                                Divider()
                                    .padding(.leading, 76)
                                
                                SettingsInfoRow(
                                    icon: "brain.head.profile",
                                    title: "OpenAI",
                                    description: "Used to power AI features that provide personalized recommendations and insights."
                                )
                            }
                            .padding(.vertical, 8)
                        }
                        
                        // Data Management Section
                        settingsSection(title: "Your Rights") {
                            VStack(spacing: 0) {
                                SettingsRowNavigationLink(
                                    icon: "arrow.down.doc",
                                    title: "Export Data",
                                    subtitle: "Download your health report",
                                    showDivider: true
                                ) {
                                    ExportDataView()
                                }
                                
                                SettingsRowNavigationLink(
                                    icon: "trash",
                                    title: "Delete Account",
                                    subtitle: "Permanently delete your account and data",
                                    showDivider: false
                                ) {
                                    DeleteAccountView()
                                }
                            }
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

// MARK: - Settings Info Row Component
struct SettingsInfoRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(.secondarySystemBackground))
                    .frame(width: 40, height: 40)
                
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(.primary)
            }
            
            // Text
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
}

// MARK: - Privacy Policy Detail View
private struct PrivacyPolicyDetailView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack(alignment: .top) {
            Color(.systemBackground).ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                PageHeader(title: "Privacy Policy")
                    .padding(.top, 12)
                    .padding(.horizontal, 24)
                
                // Content
                ScrollView {
                    Text(LegalDocuments.privacyPolicy)
                        .font(.system(size: 15))
                        .foregroundColor(.primary)
                        .padding(24)
                }
            }
        }
        .navigationBarBackButtonHidden(true)
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        PrivacyPreferencesView()
    }
}

