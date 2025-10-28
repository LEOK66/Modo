import SwiftUI
import FirebaseAuth

struct EmailVerificationView: View {
    @EnvironmentObject var authService: AuthService
    @State private var isVerified = false
    @State private var isChecking = false
    @State private var showResendSuccess = false
    
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
                    Text("Resend Verification Email")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.blue)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 24)
                }
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
            // Check verification status when view appears
            checkVerification()
        }
    }
    
    private func checkVerification() {
        isChecking = true
        
        authService.checkEmailVerification { verified in
            DispatchQueue.main.async {
                isChecking = false
                isVerified = verified
                
                if verified {
                    // Verification status updated automatically via listener
                    // No need to do anything, ModoApp will detect the change
                }
            }
        }
    }
    
    private func resendVerificationEmail() {
        guard let user = authService.currentUser else { return }
        
        user.sendEmailVerification { error in
            DispatchQueue.main.async {
                if let error = error {
                    print("Error resending verification email: \(error.localizedDescription)")
                } else {
                    showResendSuccess = true
                    
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
}

#Preview {
    EmailVerificationView()
        .environmentObject(AuthService.shared)
}
