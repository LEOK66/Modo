import SwiftUI
import FirebaseAuth

struct EmailVerificationView: View {
    @EnvironmentObject var authService: AuthService
    @State private var isVerified = false
    @State private var isChecking = false
    @State private var showResendSuccess = false
    @State private var resendTimer: Int = 60
    @State private var timer: Timer?
    @State private var canResend: Bool = false
    
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
                .foregroundColor(Color(hexString: "101828"))
            
            // Description
            VStack(spacing: 8) {
                if let email = authService.currentUser?.email {
                    Text("We've sent a verification link to")
                        .font(.system(size: 15))
                        .foregroundColor(Color(hexString: "6A7282"))
                    
                    Text(email)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Color(hexString: "101828"))
                }
                
                Text("Please click the link to verify your email address")
                    .font(.system(size: 14))
                    .foregroundColor(Color(hexString: "6A7282"))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            // Actions
            VStack(spacing: 12) {
                // Instructions
                Text("We'll automatically detect when you verify")
                    .font(.system(size: 13))
                    .foregroundColor(Color(hexString: "6A7282"))
                    .multilineTextAlignment(.center)
                    .padding(.top, 8)
                
                // Resend email button
                Button {
                    resendVerificationEmail()
                } label: {
                    HStack(spacing: 8) {
                        if !canResend {
                            Image(systemName: "clock")
                                .font(.system(size: 12))
                        }
                        Text(canResend ? "Resend Verification Email" : "Resend in \(resendTimer)s")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(canResend ? .blue : Color(hexString: "9CA3AF"))
                    .padding(.vertical, 12)
                    .padding(.horizontal, 24)
                }
                .disabled(!canResend)
                
                // Tip text
                if !canResend {
                    Text("Please wait before requesting another email")
                        .font(.system(size: 12))
                        .foregroundColor(Color(hexString: "9CA3AF"))
                        .padding(.top, 4)
                }
                
                // Check spam folder reminder
                Text("Don't see the email? Check your spam folder")
                    .font(.system(size: 12))
                    .foregroundColor(Color(hexString: "6A7282"))
                    .multilineTextAlignment(.center)
                    .padding(.top, 8)
                
                Button {
                    signOutAndReturnToLogin()
                } label: {
                    Text("Back to Login")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color(hexString: "4A5565"))
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
        .background(Color.white.ignoresSafeArea())
        .overlay(
            SuccessToast(
                message: "Verification email sent!",
                isPresented: showResendSuccess
            )
        )
        .onAppear {
            startResendTimer()
            // Check verification status when view appears
            checkVerification()
        }
        .onDisappear {
            // Clean up timer
            timer?.invalidate()
            timer = nil
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
        guard let user = authService.currentUser, canResend else { return }
        
        user.sendEmailVerification { error in
            DispatchQueue.main.async {
                if let error = error {
                    print("Error resending verification email: \(error.localizedDescription)")
                } else {
                    showResendSuccess = true
                    
                    // Restart the timer
                    startResendTimer()
                    
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
    
    private func startResendTimer() {
        // Start with 60 seconds cooldown
        resendTimer = 60
        canResend = false
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if resendTimer > 0 {
                resendTimer -= 1
            } else {
                canResend = true
                timer?.invalidate()
                timer = nil
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
