import SwiftUI
import SwiftData
import FirebaseAuth

struct MainContainerView: View {
    @State private var selectedTab: Tab = .todos
    @EnvironmentObject var userProfileService: UserProfileService
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]
    
    // Services from Container
    private let challengeService = ServiceContainer.shared.challengeService
    private let databaseService = ServiceContainer.shared.databaseService
    
    var body: some View {
        NavigationStack {
            ZStack {
                switch selectedTab {
                case .todos:
                    MainPageView(selectedTab: $selectedTab)
                        .transition(.opacity)
                case .insights:
                    InsightsPageView(selectedTab: $selectedTab)
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: selectedTab)
            .background(Color.white.ignoresSafeArea())
            .onAppear {
                // Update shared profile service when profiles load
                userProfileService.updateProfile(from: profiles)
                
                // Ensure default avatar is assigned for new users
                ensureDefaultAvatarIfNeeded()
                
                // Check for date change when view appears
                challengeService.checkAndResetForNewDay()
            }
            .onChange(of: profiles) { _, newProfiles in
                // Update when profiles change
                userProfileService.updateProfile(from: newProfiles)
                // Ensure default avatar is assigned when profile loads
                ensureDefaultAvatarIfNeeded()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                // Check for date change when app returns from background
                challengeService.checkAndResetForNewDay()
            }
        }
    }
    
    /// Ensure new users have a default avatar assigned
    /// This is called when the main view loads so avatar appears immediately
    private func ensureDefaultAvatarIfNeeded() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        // ✅ Ensure profile exists - create if missing (e.g., after database migration)
        var profile = userProfileService.currentProfile
        if profile == nil {
            // Create new profile if it doesn't exist
            profile = UserProfile(userId: userId)
            modelContext.insert(profile!)
            do {
                try modelContext.save()
                userProfileService.setProfile(profile)
                print("✅ MainContainerView: Created new profile for user")
            } catch {
                print("❌ MainContainerView: Failed to create profile - \(error.localizedDescription)")
                return
            }
        }
        
        guard let profile = profile else { return }
        
        // If no uploaded photo and no default avatar, assign one
        if (profile.profileImageURL == nil || profile.profileImageURL?.isEmpty == true) &&
            (profile.avatarName == nil || profile.avatarName?.isEmpty == true) {
            if let randomName = DefaultAvatars.random() {
                profile.avatarName = randomName
                profile.updatedAt = Date()
                do { 
                    try modelContext.save() 
                    print("✅ MainContainerView: Assigned default avatar '\(randomName)' to new user")
                } catch { 
                    print("❌ MainContainerView: Failed to save default avatar - \(error.localizedDescription)") 
                }
                databaseService.saveUserProfile(profile) { _ in }
                // Refresh the shared service to update UI immediately
                userProfileService.setProfile(profile)
            }
        }
    }
}

#Preview {
    MainContainerView()
}
