import SwiftUI
import SwiftData
import FirebaseCore
import FirebaseDatabase
import GoogleSignIn
import FirebaseAuth

@main
struct ModoApp: App {
    @StateObject private var authService = ServiceContainer.shared.authService
    @StateObject private var userProgress = UserProgress()
    @StateObject private var dailyCaloriesService = DailyCaloriesService()
    @StateObject private var userProfileService = UserProfileService()
    @StateObject private var themeManager = ThemeManager()
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
            // ⚠️ Model migration failed - likely due to schema changes
            print("❌ ModelContainer creation failed: \(error)")
            print("🔄 Attempting to delete old database and recreate...")
            
            // Try to delete old database files
            let fileManager = FileManager.default
            if let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
                let storeURL = appSupportURL.appendingPathComponent("default.store")
                try? fileManager.removeItem(at: storeURL)
                print("🗑️ Deleted old database at: \(storeURL.path)")
                
                // Try creating ModelContainer again after deletion
                do {
                    let freshContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
                    print("✅ Successfully created fresh ModelContainer")
                    return freshContainer
                } catch {
                    print("❌ Still failed after deletion: \(error)")
                }
            }
            
            // Final fallback: in-memory storage
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
            SystemColorSchemeObserver(themeManager: themeManager) {
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
                .animation(.easeInOut(          duration: 0.3), value: currentState)
                .applyColorScheme(themeManager.colorScheme)
                .task {
                    // ✅ Inject UserProfileService into DailyChallengeService as early as possible
                    // Using .task ensures this runs before child views appear
                    ServiceContainer.shared.challengeService.setUserProfileService(userProfileService)
                }
                .environmentObject(authService)
                .environmentObject(userProgress)
                .environmentObject(dailyCaloriesService)
                .environmentObject(userProfileService)
                .environmentObject(themeManager)
                .onOpenURL { url in
                    GIDSignIn.sharedInstance.handle(url)
                }
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

// MARK: - System Color Scheme Observer
struct SystemColorSchemeObserver<Content: View>: View {
    @ObservedObject var themeManager: ThemeManager
    @Environment(\.colorScheme) var systemColorScheme
    let content: () -> Content
    
    init(themeManager: ThemeManager, @ViewBuilder content: @escaping () -> Content) {
        self.themeManager = themeManager
        self.content = content
    }
    
    var body: some View {
        content()
            .onChange(of: systemColorScheme) { oldValue, newValue in
                // Update theme manager when system color scheme changes
                themeManager.updateFromSystem(systemColorScheme: newValue)
            }
            .onAppear {
                // Initialize from system on appear
                themeManager.updateFromSystem(systemColorScheme: systemColorScheme)
            }
    }
}
