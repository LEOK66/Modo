import SwiftUI
import SwiftData
import FirebaseCore

@main
struct ModoApp: App {
    @StateObject private var authService = AuthService.shared
    @State private var isEmailVerified = false
    
    init() {
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
                if authService.isAuthenticated {
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
            .animation(.easeInOut(duration: 0.5), value: authService.isAuthenticated)
            .animation(.easeInOut(duration: 0.5), value: isEmailVerified)
            .onAppear {
                checkVerificationStatus()
            }
            .onChange(of: authService.isAuthenticated) { _, newValue in
                if newValue {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        checkVerificationStatus()
                    }
                } else {
                    isEmailVerified = false
                }
            }
        }
        .modelContainer(sharedModelContainer)
    }

    @State private var verificationTimer: Timer?

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
        if authService.isAuthenticated && !isEmailVerified {
            authService.checkEmailVerification { verified in
                if verified {
                    self.isEmailVerified = verified
                    // Stop polling since they're verified
                    stopVerificationPolling()
                }
            }
        }
    }
}
