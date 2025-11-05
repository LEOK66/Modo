import SwiftUI
import SwiftData

struct MainContainerView: View {
    @State private var selectedTab: Tab = .todos
    @EnvironmentObject var userProfileService: UserProfileService
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]
    
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
                
                // Check for date change when view appears
                DailyChallengeService.shared.checkAndResetForNewDay()
            }
            .onChange(of: profiles) { _, newProfiles in
                // Update when profiles change
                userProfileService.updateProfile(from: newProfiles)
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                // Check for date change when app returns from background
                DailyChallengeService.shared.checkAndResetForNewDay()
            }
        }
    }
}

#Preview {
    MainContainerView()
}
