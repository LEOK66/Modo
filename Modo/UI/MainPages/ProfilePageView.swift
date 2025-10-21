import SwiftUI

struct ProfilePageView: View {
    var body: some View {
        ZStack(alignment: .top) {
            Color(hexString: "F9FAFB").ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                PageHeader(title: "Profile")
                    .padding(.top, 12)
                    .padding(.horizontal, 24)
                
                Spacer().frame(height: 12)
                
                // Scrollable content
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // MARK: - Profile header
                        VStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .stroke(Color.black, lineWidth: 2)
                                    .frame(width: 96, height: 96)
                                    .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 10)
                                    .background(
                                        Circle()
                                            .fill(Color(hexString: "F3F4F6"))
                                            .padding(4)
                                    )
                                
                                Image(systemName: "person.crop.circle.fill")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 96, height: 96)
                                    .foregroundStyle(Color.gray.opacity(0.6))
                            }
                            Text("Sam Darnold")
                                .font(.system(size: 24, weight: .regular))
                                .foregroundColor(Color(hexString: "0A0A0A"))
                            Text("darnold.sam@email.com")
                                .font(.system(size: 14))
                                .foregroundColor(Color(hexString: "6A7282"))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 8)

                        // MARK: - Stats row
                        HStack(spacing: 16) {
                            StatCard(title: "Day Streak", value: "7", emoji: "🔥")
                            StatCard(title: "Calories", value: "350", emoji: "🍎")
                        }
                        .padding(.horizontal, 24)

                        
                        // MARK: - Performance section
                        ProfileSection(title: "Performance") {
                            NavigationRow(icon: "chart.bar", title: "Progress", subtitle: "Stats, goal & insights", destination: AnyView(ProgressView()))
                            NavigationRow(icon: "rosette", title: "Achievements", subtitle: "Unlock badges", destination: AnyView(AchievementsView()))
                        }

                        // MARK: - Preferences section
                        ProfileSection(title: "Preferences") {
                            NavigationRow(icon: "gearshape", title: "Settings", subtitle: "App preferences", destination: AnyView(SettingsView()))
                            NavigationRow(icon: "questionmark.circle", title: "Help & Support", subtitle: "Get assistance", destination: AnyView(HelpSupportView()))
                        }

                        // MARK: - Logout
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Color(hexString: "FEF2F2"))
                                    .frame(width: 44, height: 44)
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(Color(hexString: "E7000B"))
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Logout")
                                    .font(.system(size: 16))
                                    .foregroundColor(Color(hexString: "E7000B"))
                                Text("Sign out of your account")
                                    .font(.system(size: 12))
                                    .foregroundColor(Color(hexString: "FF6467"))
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(Color(hexString: "FF6467"))
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.white)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color(hexString: "FFE2E2"), lineWidth: 1)
                                )
                                .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 1)
                                .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                        )
                        .padding(.horizontal, 24)
                        .padding(.bottom, 24)
                    }
                    .padding(.top, 8)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .background(Color(hexString: "F3F4F6"))
            }
        }
        .navigationBarBackButtonHidden(true)
    }

}

#Preview {
    NavigationStack {
        ProfilePageView()
    }
}
