import SwiftUI
import SwiftData
import FirebaseCore
import GoogleSignIn

@main
struct ModoApp: App {
    @StateObject private var authService = AuthService.shared
    @StateObject private var userProgress = UserProgress()
    @StateObject private var dailyCaloriesService = DailyCaloriesService()
    @State private var isEmailVerified = false
    @State private var verificationTimer: Timer?
    @State private var showAuthenticatedUI = false
    
    init() {
        print("newest version")
        FirebaseApp.configure()
    }
    
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
            UserProfile.self,
            ChatMessage.self,
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

    var body: some Scene {
        WindowGroup {
            ZStack {
                if showAuthenticatedUI {
                    if isEmailVerified {
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
                    showAuthenticatedUI = false
                    checkVerificationStatus()
                    
                } else {
                    showAuthenticatedUI = false
                    isEmailVerified = false
                    stopVerificationPolling()
                }
            }
            .onAppear {
                if authService.isAuthenticated {
                    showAuthenticatedUI = false
                    checkVerificationStatus()
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
                self.isEmailVerified = verified
                self.showAuthenticatedUI = true
                
                if verified {
                    self.stopVerificationPolling()
                }
            }
        }
    }
}
