
import SwiftUI

struct RegisterView: View {
    @EnvironmentObject var authService: AuthService
    @State private var emailAddress = ""
    @State private var password = ""
    @State private var verificationCode = ""
    @State private var resendTimer = 59
    @State private var isCodeSent = false
    @State private var timer: Timer?
    @State private var showTerms = false
    @State private var showPrivacy = false
    @State private var showEmailError = false
    @State private var showPasswordError = false
    @State private var showSuccessMessage = false
    
    private var isEmailAndPasswordValid: Bool {
        emailAddress.isValidEmail && password.isValidPassword
    }
    
    var body: some View {
        ZStack {

            Color.white
                .ignoresSafeArea()

            VStack(spacing: 24) {
                LogoView(title: "MODO", subtitle: "Register")
                .padding(.top, 4)
                
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        CustomInputField(
                            placeholder: "Email address",
                            text: $emailAddress,
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
                    
                    VStack(alignment: .leading, spacing: 4) {
                        CustomInputField(
                            placeholder: "Password",
                            text: $password,
                            isSecure: true,
                            showPasswordToggle: true
                        )
                        
                        if showPasswordError {
                            Text("At least 8 characters with letters and numbers")
                                .font(.system(size: 10))
                                .foregroundColor(.red)
                                .padding(.leading, 12)
                        }
                    }
                    
                    VStack(spacing: 8) {
                        Text("By signing up, you agree to our")
                            .font(.system(size: 12))
                            .foregroundColor(Color(hexString: "6A7282"))
                            .multilineTextAlignment(.center)
                        
                        HStack(spacing: 4) {
                            Button {
                                showTerms = true
                            } label: {
                                Text("Terms of Service")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(Color.blue)
                            }
                            
                            Text("and")
                                .font(.system(size: 12))
                                .foregroundColor(Color(hexString: "6A7282"))
                            
                            Button {
                                showPrivacy = true
                            } label: {
                                Text("Privacy Policy")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(Color.blue)
                            }
                        }
                        .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: LayoutConstants.inputFieldMaxWidth)
                    
                    PrimaryButton(title: "Send Verify Link") {
                        sendLink()
                    }
                }
                
                Spacer()
            }
            .frame(maxHeight: .infinity)
            .padding(.horizontal, 24)
            .padding(.top, 4)
            .padding(.bottom, 12)
        }
        .fullScreenCover(isPresented: $showTerms) {
            TermsOfServiceView()
        }
        .fullScreenCover(isPresented: $showPrivacy) {
            PrivacyPolicyView()
        }
        .overlay(
            SuccessToast(
                message: "Verification code sent to your email",
                isPresented: showSuccessMessage
            )
        )
        .onDisappear {
            timer?.invalidate()
            timer = nil
        }
    }
    
    
    private func sendLink() {
        // Validate email and password
        withAnimation(.easeInOut(duration: 0.2)) {
            showEmailError = !emailAddress.isValidEmail || !emailAddress.isNotEmpty
            showPasswordError = !password.isValidPassword || !password.isNotEmpty
        }
        
        // Only proceed if both are valid
        if emailAddress.isValidEmail && password.isValidPassword {
            authService.signUp(email: emailAddress, password: password) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success:
                        // Auth state will automatically update via the listener
                        break
                    case .failure(let error):
                        print("Sign up error: \(error.localizedDescription)")
                        // Handle error here if needed
                    }
                }
            }
        }
    }
    
    private func sendVerificationCode() {
        print("Sending verification code...")
        // Check if email and password are valid
        withAnimation(.easeInOut(duration: 0.2)) {
            showEmailError = !emailAddress.isValidEmail || !emailAddress.isNotEmpty
            showPasswordError = !password.isValidPassword || !password.isNotEmpty
        }
        
        // Only send if both are valid
        if emailAddress.isValidEmail && password.isValidPassword {
            // Send verification code logic here
            print("Sending verification code to: \(emailAddress)")
            
            // Show success message
            showSuccessMessage = true
            
            // Start the timer and mark code as sent
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

private struct TermsOfServiceView: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            ScrollView {
                Text(sampleTOS)
                    .font(.system(size: 15))
                    .foregroundColor(Color(hexString: "101828"))
                    .padding()
            }
            .navigationTitle("Terms of Service")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                }
            }
            .background(Color.white.ignoresSafeArea())
        }
    }
}

private struct PrivacyPolicyView: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            ScrollView {
                Text(samplePrivacy)
                    .font(.system(size: 15))
                    .foregroundColor(Color(hexString: "101828"))
                    .padding()
            }
            .navigationTitle("Privacy Policy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                }
            }
            .background(Color.white.ignoresSafeArea())
        }
    }
}

private let sampleTOS = """
Your Terms of Service content goes here.
Add your sections, headings, and details.
"""

private let samplePrivacy = """
Your Privacy Policy content goes here.
Describe data collection, usage, and retention.
"""

#Preview {
    RegisterView()
}
