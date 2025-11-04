import SwiftUI
import SwiftData
import FirebaseCore
import GoogleSignIn
import FirebaseAuth

@main
struct ModoApp: App {
    @StateObject private var authService = AuthService.shared
    @StateObject private var userProgress = UserProgress()
    @StateObject private var dailyCaloriesService = DailyCaloriesService()
    @State private var isEmailVerified = false
    @State private var verificationTimer: Timer?
    @State private var showAuthenticatedUI = false
    
    init() {
        FirebaseApp.configure()
        
        // Configure URLCache for image caching
        // Memory cache: 50MB, Disk cache: 100MB
        let cacheSizeMemory = 50 * 1024 * 1024  // 50 MB
        let cacheSizeDisk = 100 * 1024 * 1024   // 100 MB
        let cache = URLCache(memoryCapacity: cacheSizeMemory, diskCapacity: cacheSizeDisk, diskPath: "image_cache")
        URLCache.shared = cache
    }
    
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
            UserProfile.self,
            FirebaseChatMessage.self,
            DailyCompletion.self,
        ])
        
        // Enable auto-migration for schema changes
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: true
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            // If migration fails, try to delete and recreate the container
            print("⚠️ ModelContainer creation failed: \(error)")
            print("🔄 Attempting to reset database...")
            
            // Get the default store URL
            let url = URL.applicationSupportDirectory.appending(path: "default.store")
            
            // Try to delete the old database files
            if FileManager.default.fileExists(atPath: url.path) {
                try? FileManager.default.removeItem(at: url)
                print("✅ Deleted old database at: \(url.path)")
            }
            
            // Try to create container again
            do {
                return try ModelContainer(for: schema, configurations: [modelConfiguration])
            } catch {
                fatalError("Could not create ModelContainer even after reset: \(error)")
            }
        }
    }()
    
    // Computed property to get email verification status
    // Uses cached value from currentUser if available, otherwise uses state
    private var emailVerified: Bool {
        let verified = authService.currentUser?.isEmailVerified ?? isEmailVerified
        // Check if user is Apple/Google user (always verified)
        if let user = authService.currentUser {
            let isAppleOrGoogleUser = user.providerData.contains { provider in
                provider.providerID == "apple.com" || provider.providerID == "google.com"
            }
            if isAppleOrGoogleUser {
                return true
            }
        }
        return verified
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                // Show authenticated UI only if user is authenticated AND explicitly set
                // This prevents showing authenticated views during logout transition
                if authService.isAuthenticated && showAuthenticatedUI {
                    // Use cached verification status if available to prevent flashing
                    if emailVerified {
                        if authService.hasCompletedOnboarding {
                            MainContainerView()
                                .environmentObject(authService)
                                .environmentObject(userProgress)
                                .environmentObject(dailyCaloriesService)
                                .transition(.asymmetric(
                                    insertion: .opacity.combined(with: .scale(scale: 0.95)),
                                    removal: .opacity.combined(with: .scale(scale: 1.05))
                                ))
                        } else {
                            InfoGatheringView()
                                .environmentObject(authService)
                                .environmentObject(userProgress)
                                .transition(.asymmetric(
                                    insertion: .opacity.combined(with: .scale(scale: 0.95)),
                                    removal: .opacity.combined(with: .scale(scale: 1.05))
                                ))
                        }
                    } else {
                        EmailVerificationView()
                            .environmentObject(authService)
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .scale(scale: 0.95)),
                                removal: .opacity.combined(with: .scale(scale: 1.05))
                            ))
                            .onAppear {
                                startVerificationPolling()
                            }
                            .onDisappear {
                                stopVerificationPolling()
                            }
                    }
                } else {
                    LoginView()
                        .environmentObject(authService)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.95)),
                            removal: .opacity.combined(with: .scale(scale: 1.05))
                        ))
                }
            }
            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: authService.isAuthenticated)
            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: isEmailVerified)
            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: showAuthenticatedUI)
            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: authService.hasCompletedOnboarding)
            .onChange(of: authService.isAuthenticated) { _, newValue in
                if newValue {
                    // User just logged in - check verification status
                    showAuthenticatedUI = true
                    if let user = authService.currentUser {
                        // For Apple Sign-In and Google Sign-In, email is usually pre-verified
                        let isAppleOrGoogleUser = user.providerData.contains { provider in
                            provider.providerID == "apple.com" || provider.providerID == "google.com"
                        }
                        
                        if isAppleOrGoogleUser {
                            // Apple/Google users are automatically verified
                            isEmailVerified = true
                        } else {
                            isEmailVerified = user.isEmailVerified
                        }
                    }
                    checkVerificationStatus()
                    
                } else {
                    // User logged out - immediately hide authenticated UI to prevent flashing
                    showAuthenticatedUI = false
                    isEmailVerified = false
                    stopVerificationPolling()
                }
            }
            .onChange(of: authService.hasCompletedOnboarding) { _, newValue in
                // When onboarding status changes to false (during logout), ensure we don't show InfoGatheringView
                if !newValue && !authService.isAuthenticated {
                    showAuthenticatedUI = false
                }
            }
            .task {
                // Check authentication status when view appears
                // This runs asynchronously but immediately when view loads
                if authService.isAuthenticated {
                    // If user is authenticated, use cached verification status immediately
                    // This prevents showing email verification page if already verified
                    if let user = authService.currentUser {
                        // Use cached verification status immediately to avoid flashing
                        isEmailVerified = user.isEmailVerified
                        showAuthenticatedUI = true
                        
                        // Only verify in background if we need to refresh the status
                        // For Google Sign-In users, email is usually pre-verified
                        if !user.isEmailVerified {
                            // Only check if cached status shows unverified
                            checkVerificationStatus()
                        }
                    } else {
                        showAuthenticatedUI = true
                        checkVerificationStatus()
                    }
                } else {
                    showAuthenticatedUI = false
                }
            }
            .onOpenURL { url in
                GIDSignIn.sharedInstance.handle(url)
            }
        }
        .modelContainer(sharedModelContainer)
    }


    private func startVerificationPolling() {
        // Check verification every 2 seconds while on the view
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
            DispatchQueue.main.async {
                // Only update if verification status changed
                // This prevents unnecessary UI updates if already verified
                // Note: In offline mode, this will use cached status, so if user was already verified,
                // it will remain verified even without network
                if self.isEmailVerified != verified {
                    self.isEmailVerified = verified
                }
                self.showAuthenticatedUI = true
                
                if verified {
                    self.stopVerificationPolling()
                }
            }
        }
    }
}
