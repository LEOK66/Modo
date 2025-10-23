import SwiftUI

struct ForgotPasswordView: View {
    @State private var email: String = ""
    @State private var isSending: Bool = false
    @State private var showEmailError: Bool = false
    @State private var showSuccessMessage: Bool = false
    @State private var isCodeSent: Bool = false
    @State private var resendTimer: Int = 59
    @State private var timer: Timer?

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // Logo
            LogoView(title: "MODO", subtitle: "Forgot Password")
                .padding(.top, 8)

            // Description
            Text("Enter your email address and we'll send you a reset link.")
                .font(.system(size: 15))
                .foregroundColor(Color(hexString: "6A7282"))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            // Email input
            VStack(alignment: .leading, spacing: 4) {
                CustomInputField(
                    placeholder: "Email address",
                    text: $email,
                    keyboardType: .emailAddress,
                    textContentType: .emailAddress
                )
                
                if showEmailError {
                    Text("Please enter a valid email address")
                        .font(.system(size: 10))
                        .foregroundColor(.red)
                        .padding(.leading, 12)
                }
            }

            // Send reset link
            PrimaryButton(
                title: isCodeSent ? "Resend (\(resendTimer)s)" : "Send Reset Link",
                isLoading: isSending
            ) {
                sendReset()
            }
            .disabled(isCodeSent && resendTimer > 0)

            Spacer()
        }
        .padding(.top, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white.ignoresSafeArea())
        .overlay(
            SuccessToast(
                message: "Reset link sent to your email",
                isPresented: showSuccessMessage
            )
        )
        .onDisappear {
            timer?.invalidate()
            timer = nil
        }
    }

    private func sendReset() {
        // Check if email is valid
        withAnimation(.easeInOut(duration: 0.2)) {
            showEmailError = !email.isValidEmail || !email.isNotEmpty
        }
        
        // Only send if email is valid
        if email.isValidEmail {
            // Simulate async sending
            isSending = true
            Task {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                await MainActor.run {
                    isSending = false
                    
                    // Show success message
                    showSuccessMessage = true
                    
                    // Start resend timer
                    isCodeSent = true
                    resendTimer = 59
                    startResendTimer()
                    
                    // Hide success message after 3 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        withAnimation {
                            showSuccessMessage = false
                        }
                    }
                }
            }
        }
    }
    
    private func startResendTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            if resendTimer > 0 {
                resendTimer -= 1
            } else {
                timer.invalidate()
                self.timer = nil
                // Reset the state when timer reaches 0
                isCodeSent = false
            }
        }
    }
}


#Preview {
    NavigationStack {
        ForgotPasswordView()
    }
}
