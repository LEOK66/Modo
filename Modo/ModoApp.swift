import SwiftUI
import SwiftData
import FirebaseCore

@main
struct ModoApp: App {
    @StateObject private var authService = AuthService.shared
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
            ZStack {
                if showAuthenticatedUI {
                    if isEmailVerified {
                        AuthenticatedView()
                            .environmentObject(authService)
                            .transition(.opacity)
                    } else {
                        EmailVerificationView()
                            .environmentObject(authService)
                            .transition(.opacity)
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
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.3), value: isEmailVerified)
            .animation(.easeInOut(duration: 0.3), value: showAuthenticatedUI)
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
