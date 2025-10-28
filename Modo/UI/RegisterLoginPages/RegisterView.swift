import SwiftUI

struct RegisterView: View {
    @EnvironmentObject var authService: AuthService
    @State private var emailAddress = ""
    @State private var password = ""
    @State private var showTerms = false
    @State private var showPrivacy = false
    @State private var showEmailError = false
    @State private var showPasswordError = false
    @State private var isLoading = false
    
    var body: some View {
        ZStack {
            Color.white
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()
                
                LogoView(title: "MODO", subtitle: "Register")
                    .padding(.top, 4)
                
                VStack(spacing: 16) {
                    // Email input field with validation
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
                    
                    // Password input field with validation
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
                    
                    // Terms and Privacy
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
                    
                    // Sign up button
                    PrimaryButton(title: "Sign Up", isLoading: isLoading) {
                        signUp()
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
    }
    
    private func signUp() {
        // Validate email and password
        withAnimation(.easeInOut(duration: 0.2)) {
            showEmailError = !emailAddress.isValidEmail || !emailAddress.isNotEmpty
            showPasswordError = !password.isValidPassword || !password.isNotEmpty
        }
        
        // Only proceed if both are valid
        if emailAddress.isValidEmail && password.isValidPassword {
            isLoading = true
            
            authService.signUp(email: emailAddress, password: password) { result in
                DispatchQueue.main.async {
                    
                    switch result {
                    case .success:
                        break
                        // Auth state will automatically update via the listener
                        // User will be taken to EmailVerificationView
                    case .failure(let error):
                        print("Sign up error: \(error.localizedDescription)")
                        // Handle error here if needed
                    }
                }
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
