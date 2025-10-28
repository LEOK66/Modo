import SwiftUI
import SwiftData
import FirebaseCore

@main
struct ModoApp: App {
    @StateObject private var authService = AuthService.shared
    @State private var isEmailVerified = false
    @State private var verificationTimer: Timer?
    @State private var hasCheckedInitialVerification = false
    
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
                if authService.isAuthenticated {
                    if !hasCheckedInitialVerification {
                        Color.white
                            .ignoresSafeArea()
                    } else if isEmailVerified {
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
                
                if authService.isCheckingEmailVerification {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                        .overlay(
                            VStack(spacing: 16) {
                                ProgressView()
                                    .scaleEffect(1.5)
                                    .tint(.white)
                                
                                Text("Signing in...")
                                    .foregroundColor(.white)
                                    .font(.system(size: 16))
                            }
                        )
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.3), value: authService.isAuthenticated)
            .animation(.easeInOut(duration: 0.3), value: isEmailVerified)
            .animation(.easeInOut(duration: 0.3), value: authService.isCheckingEmailVerification)
            .animation(.easeInOut(duration: 0.3), value: hasCheckedInitialVerification)
            .onChange(of: authService.isAuthenticated) { _, newValue in
                if newValue {
                    hasCheckedInitialVerification = false
                    hasCheckedInitialVerification = false
                    checkVerificationStatus()
                } else {
                    isEmailVerified = false
                    stopVerificationPolling()
                }
            }
            .onAppear {
                if authService.isAuthenticated {
                    hasCheckedInitialVerification = false
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
                self.hasCheckedInitialVerification = true
                
                if verified {
                    self.stopVerificationPolling()
                }
            }
        }
    }
}
