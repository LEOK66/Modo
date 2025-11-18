import SwiftUI

// MARK: - Profile Data Change Modifier

struct ProfileDataChangeModifier: ViewModifier {
    @EnvironmentObject var userProfileService: UserProfileService
    let onAppear: () -> Void
    let onDataChange: () -> Void
    
    func body(content: Content) -> some View {
        content
            .onAppear {
                onAppear()
            }
            .modifier(UserProfileChangeModifier(onDataChange: onDataChange))
    }
}

// MARK: - User Profile Change Modifier

struct UserProfileChangeModifier: ViewModifier {
    @EnvironmentObject var userProfileService: UserProfileService
    let onDataChange: () -> Void
    
    func body(content: Content) -> some View {
        content
            .onChange(of: userProfileService.currentProfile?.goalStartDate) { oldValue, newValue in
                guard userProfileService.currentProfile != nil, oldValue != newValue else { return }
                onDataChange()
            }
            .onChange(of: userProfileService.currentProfile?.targetDays) { oldValue, newValue in
                guard userProfileService.currentProfile != nil, oldValue != newValue else { return }
                onDataChange()
            }
            .onChange(of: userProfileService.currentProfile?.goal) { _, _ in
                onDataChange()
            }
            .modifier(ProfileMetricsChangeModifier(onDataChange: onDataChange))
    }
}

// MARK: - Profile Metrics Change Modifier

struct ProfileMetricsChangeModifier: ViewModifier {
    @EnvironmentObject var userProfileService: UserProfileService
    let onDataChange: () -> Void
    
    func body(content: Content) -> some View {
        content
            .onChange(of: userProfileService.currentProfile?.heightValue) { _, _ in
                onDataChange()
            }
            .onChange(of: userProfileService.currentProfile?.weightValue) { _, _ in
                onDataChange()
            }
            .onChange(of: userProfileService.currentProfile?.dailyCalories) { _, _ in
                onDataChange()
            }
    }
}

// MARK: - Logout Alert Modifier

struct LogoutAlertModifier: ViewModifier {
    @Binding var isPresented: Bool
    let onLogout: () -> Void
    
    func body(content: Content) -> some View {
        content
            .alert("Logout", isPresented: $isPresented) {
                Button("Cancel", role: .cancel) { }
                Button("Logout", role: .destructive) {
                    onLogout()
                }
            } message: {
                Text("Are you sure you want to logout?")
            }
    }
}

// MARK: - Username Alert Modifier

struct UsernameAlertModifier: ViewModifier {
    @Binding var isPresented: Bool
    @Binding var username: String
    let onSave: () -> Void
    
    func body(content: Content) -> some View {
        content
            .alert("Edit Username", isPresented: $isPresented) {
                TextField("Username", text: $username)
                Button("Cancel", role: .cancel) { }
                Button("Save") {
                    onSave()
                }
            } message: {
                Text("Enter your username")
            }
    }
}

