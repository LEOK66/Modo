import SwiftUI
import FirebaseAuth

struct ForgotPasswordView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var timerManager = ResendTimerManager()
    @State private var email: String = ""
    @State private var isSending: Bool = false
    @State private var showEmailError: Bool = false
    @State private var showSuccessMessage: Bool = false
    @State private var showErrorMessage: Bool = false
    @State private var errorMessage: String = ""
    @State private var isCodeSent: Bool = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // Logo
            LogoView(title: "MODO", subtitle: "Forgot Password")
                .padding(.top, 8)

            // Description
            VStack(spacing: 8) {
                Text("Enter your email address and we'll send you a reset link.")
                    .font(.system(size: 15))
                    .foregroundColor(.secondary) // Adapts to light/dark mode
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                
                Text("Note: You will only receive the link if this email is registered.")
                    .font(.system(size: 13))
                    .foregroundColor(Color(.tertiaryLabel)) // Adapts to light/dark mode
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            // Email input
            ValidatedInputField(
                placeholder: "Email address",
                text: $email,
                showError: $showEmailError,
                errorMessage: "Please enter a valid email address",
                keyboardType: .emailAddress,
                textContentType: .emailAddress
            )

            // Send reset link
            PrimaryButton(
                title: isCodeSent ? "Resend (\(timerManager.remainingTime)s)" : "Send Reset Link",
                isLoading: isSending
            ) {
                sendReset()
            }
            .disabled(isCodeSent && !timerManager.canResend)

            Spacer()
        }
        .padding(.top, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            Color(.systemBackground) // Adapts to light/dark mode
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
        )
        .overlay(
            SuccessToast(
                message: "Reset link sent to your email",
                isPresented: showSuccessMessage
            )
        )
        .overlay(
            ErrorToast(
                message: errorMessage,
                isPresented: showErrorMessage
            )
        )
        .onChange(of: timerManager.canResend) { _, canResend in
            // When timer ends and canResend becomes true, reset isCodeSent
            if canResend && isCodeSent {
                isCodeSent = false
            }
        }
        .onDisappear {
            timerManager.stop()
        }
    }

    private func sendReset() {
        // Check if email is valid
        withAnimation(.easeInOut(duration: 0.2)) {
            showEmailError = !email.isValidEmail || !email.isNotEmpty
        }
        
        // Only send if email is valid
        if email.isValidEmail {
            isSending = true
            
            authService.resetPassword(email: email) { result in
                DispatchQueue.main.async {
                    isSending = false
                    
                    switch result {
                    case .success:
                        // Show success message
                        showSuccessMessage = true
                        
                        // Start resend timer
                        isCodeSent = true
                        timerManager.start(duration: 59)
                        
                        // Hide success message after 3 seconds
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            withAnimation {
                                showSuccessMessage = false
                            }
                        }
                        
                    case .failure(let error):
                        print("Password reset error: \(error.localizedDescription)")
                        
                        let appError = AppError.from(error)
                        if !appError.isUserCancellation {
                            errorMessage = appError.userMessage(context: .passwordReset)
                            showErrorMessage = true
                            
                            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                withAnimation {
                                    showErrorMessage = false
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}


#Preview {
    NavigationStack {
        ForgotPasswordView()
    }
}
