import SwiftUI
import SwiftData
import FirebaseCore
import FirebaseDatabase
import GoogleSignIn
import FirebaseAuth

@main
struct ModoApp: App {
    @ObservedObject private var authService = AuthService.shared
    @StateObject private var userProgress = UserProgress()
    @StateObject private var dailyCaloriesService = DailyCaloriesService()
    @StateObject private var userProfileService = UserProfileService()
    @State private var verificationTimer: Timer?
    
    init() {
        FirebaseApp.configure()
        Database.database().isPersistenceEnabled = true
        
        // Configure URLCache for image caching
        // Memory cache: 50MB, Disk cache: 100MB
        let cacheSizeMemory = 50 * 1024 * 1024  // 50 MB
        let cacheSizeDisk = 100 * 1024 * 1024   // 100 MB
        let cache = URLCache(memoryCapacity: cacheSizeMemory, diskCapacity: cacheSizeDisk, diskPath: "image_cache")
        URLCache.shared = cache
    }
    
    // MARK: - App State Management
    private var currentState: AppState {
        guard authService.isAuthenticated else {
            return .login
        }
        
        if authService.needsEmailVerification {
            return .emailVerification
        }
        
        if !authService.hasCompletedOnboarding {
            return .onboarding
        }
        
        return .main
    }
    
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            UserProfile.self,
            FirebaseChatMessage.self,
            DailyCompletion.self,
        ])
        
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: true
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            // Temporary solution that only falling back to in-memory storage but in the future we need to
            // think about how to do data migration
            print("⚠️ Falling back to in-memory storage")
            let inMemoryOnly = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: true
            )
            do {
                return try ModelContainer(for: schema, configurations: [inMemoryOnly])
            } catch {
                fatalError("Could not create ModelContainer even in-memory: \(error)")
            }
        }
    }()
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                switch currentState {
                case .login:
                    LoginView()
                        .transition(.opacity)
                    
                case .emailVerification:
                    EmailVerificationView()
                        .transition(.opacity)
                        .onAppear {
                            startVerificationPolling()
                        }
                        .onDisappear {
                            stopVerificationPolling()
                        }
                    
                case .onboarding:
                    InfoGatheringView()
                        .transition(.opacity)
                    
                case .main:
                    MainContainerView()
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.3), value: currentState)
            .environmentObject(authService)
            .environmentObject(userProgress)
            .environmentObject(dailyCaloriesService)
            .environmentObject(userProfileService)
            .onChange(of: authService.isAuthenticated) { _, newValue in
                if !newValue {
                    stopVerificationPolling()
                }
            }
            .onOpenURL { url in
                GIDSignIn.sharedInstance.handle(url)
            }
        }
        .modelContainer(sharedModelContainer)
    }


    private func startVerificationPolling() {
        verificationTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            checkVerificationStatus()
        }
    }

    private func stopVerificationPolling() {
        verificationTimer?.invalidate()
        verificationTimer = nil
    }

    private func checkVerificationStatus() {
        authService.checkEmailVerification { verified in
            if verified {
                DispatchQueue.main.async {
                    self.stopVerificationPolling()
                }
            }
        }
    }
}
