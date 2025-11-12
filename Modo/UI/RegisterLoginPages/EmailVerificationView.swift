import SwiftUI
import FirebaseAuth

struct EmailVerificationView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var timerManager = ResendTimerManager()
    @State private var isVerified = false
    @State private var isChecking = false
    @State private var showResendSuccess = false
    @State private var showResendError = false
    @State private var resendErrorMessage = ""
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // Logo
            LogoView(title: "MODO", subtitle: "Verify Email")
                .padding(.top, 8)
            
            // Email icon
            Image(systemName: "envelope.badge")
                .font(.system(size: 80))
                .foregroundColor(.blue)
                .padding(.top, 20)
            
            // Title
            Text("Check Your Email")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.primary) // Adapts to light/dark mode
            
            // Description
            VStack(spacing: 8) {
                if let email = authService.currentUser?.email {
                    Text("We've sent a verification link to")
                        .font(.system(size: 15))
                        .foregroundColor(.secondary) // Adapts to light/dark mode
                    
                    Text(email)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.primary) // Adapts to light/dark mode
                }
                
                Text("Please click the link to verify your email address")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary) // Adapts to light/dark mode
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            // Actions
            VStack(spacing: 12) {
                // Instructions
                Text("We'll automatically detect when you verify")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary) // Adapts to light/dark mode
                    .multilineTextAlignment(.center)
                    .padding(.top, 8)
                
                // Resend email button
                Button {
                    resendVerificationEmail()
                } label: {
                    HStack(spacing: 8) {
                        if !timerManager.canResend {
                            Image(systemName: "clock")
                                .font(.system(size: 12))
                        }
                        Text(timerManager.canResend ? "Resend Verification Email" : "Resend in \(timerManager.remainingTime)s")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(timerManager.canResend ? .blue : Color(.tertiaryLabel)) // Adapts to light/dark mode
                    .padding(.vertical, 12)
                    .padding(.horizontal, 24)
                }
                .disabled(!timerManager.canResend)
                
                // Tip text
                if !timerManager.canResend {
                    Text("Please wait before requesting another email")
                        .font(.system(size: 12))
                        .foregroundColor(Color(.tertiaryLabel)) // Adapts to light/dark mode
                        .padding(.top, 4)
                }
                
                // Check spam folder reminder
                Text("Don't see the email? Check your spam folder")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary) // Adapts to light/dark mode
                    .multilineTextAlignment(.center)
                    .padding(.top, 8)
                
                Button {
                    signOutAndReturnToLogin()
                } label: {
                    Text("Back to Login")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary) // Adapts to light/dark mode
                        .padding(.vertical, 12)
                        .padding(.horizontal, 24)
                }
                .padding(.top, 16)
                
            }
            .padding(.top, 24)
            
            Spacer()
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            Color(.systemBackground)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
        )
        .overlay(
            SuccessToast(
                message: "Verification email sent!",
                isPresented: showResendSuccess
            )
        )
        .overlay(
            ErrorToast(
                message: resendErrorMessage,
                isPresented: showResendError
            )
        )
        .onAppear {
            timerManager.start(duration: 60)
            // Check verification status when view appears
            checkVerification()
        }
        .onDisappear {
            timerManager.stop()
        }
    }
    
    private func checkVerification() {
        isChecking = true
        
        authService.checkEmailVerification { verified in
            DispatchQueue.main.async {
                isChecking = false
                isVerified = verified
            }
        }
    }
    
    private func resendVerificationEmail() {
        guard let user = authService.currentUser, timerManager.canResend else { return }
        
        user.sendEmailVerification { error in
            DispatchQueue.main.async {
                if let error = error {
                    print("Error resending verification email: \(error.localizedDescription)")
                    let appError = AppError.from(error)
                    if !appError.isUserCancellation {
                        resendErrorMessage = appError.userMessage(context: .emailVerification)
                        showResendError = true
                        
                        // Hide error message after 3 seconds
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            withAnimation {
                                showResendError = false
                            }
                        }
                    }
                } else {
                    showResendSuccess = true
                    
                    // Restart the timer
                    timerManager.reset()
                    
                    // Hide success message after 3 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        withAnimation {
                            showResendSuccess = false
                        }
                    }
                }
            }
        }
    }
    
    
    private func signOutAndReturnToLogin() {
        do {
            try authService.signOut()
            // The auth state listener will automatically update and navigate back to login
        } catch {
            print("Error signing out: \(error.localizedDescription)")
        }
    }
}

#Preview {
    EmailVerificationView()
        .environmentObject(AuthService.shared)
}
