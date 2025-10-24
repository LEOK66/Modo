import SwiftUI
import SwiftData
import FirebaseCore

@main
struct ModoApp: App {
    @StateObject private var authService = AuthService.shared
    
    init() {
        FirebaseApp.configure()
        // TODO: remove print
        print("firebase configured?")
    }
    
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
            UserProfile.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            if authService.isAuthenticated {
                if authService.hasCompletedOnboarding {
                    MainContainerView()
                        .environmentObject(authService)
                } else {
                    InfoGatheringView()
                        .environmentObject(authService)
                }
            } else {
                LoginView()
                    .environmentObject(authService)
            }
        }
        .modelContainer(sharedModelContainer)
    }
}
