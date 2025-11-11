import SwiftUI

struct RegisterView: View {
    @EnvironmentObject var authService: AuthService
    @State private var emailAddress = ""
    @State private var password = ""
    @State private var showTerms = false
    @State private var showPrivacy = false
    @State private var showEmailError = false
    @State private var showPasswordError = false
    @State private var showErrorMessage = false
    @State private var errorMessage = ""
    @State private var isLoading = false
    
    var body: some View {
        ZStack {
            Color(.systemBackground) // Adapts to light/dark mode
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }

            VStack(spacing: 24) {
                Spacer()
                
                LogoView(title: "MODO", subtitle: "Register")
                    .padding(.top, 4)
                
                VStack(spacing: 16) {
                    // Email input field with validation
                    ValidatedInputField(
                        placeholder: "Email address",
                        text: $emailAddress,
                        showError: $showEmailError,
                        errorMessage: "Please enter a valid email address",
                        keyboardType: .emailAddress,
                        textContentType: .emailAddress
                    )
                    
                    // Password input field with validation
                    ValidatedInputField(
                        placeholder: "Password",
                        text: $password,
                        showError: $showPasswordError,
                        errorMessage: "At least 8 characters with letters and numbers",
                        isSecure: true,
                        showPasswordToggle: true
                    )
                    
                    // Terms and Privacy
                    VStack(spacing: 8) {
                        Text("By signing up, you agree to our")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary) // Adapts to light/dark mode
                            .multilineTextAlignment(.center)
                        
                        HStack(spacing: 4) {
                            Button {
                                showTerms = true
                            } label: {
                                Text("Terms of Service")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.blue) // System blue adapts to dark mode
                            }
                            
                            Text("and")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary) // Adapts to light/dark mode
                            
                            Button {
                                showPrivacy = true
                            } label: {
                                Text("Privacy Policy")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.blue) // System blue adapts to dark mode
                            }
                        }
                        .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: LayoutConstants.inputFieldMaxWidth)
                    
                    // Sign up button
                    PrimaryButton(title: "Sign Up", isLoading: isLoading) {
                        signUp()
                    }
                    
                    // Divider
                    DividerWithText(text: "or")
                    
                    // Apple/Google login
                    HStack(spacing: 12) {
                        AppleSignInButton(action: signInWithApple)
                        SocialButton(title: "Google", systemImage: "g.circle.fill") {
                            signInWithGoogle()
                        }
                    }
                    .frame(maxWidth: LayoutConstants.inputFieldMaxWidth)
                }
                
                Spacer()
            }
            .frame(maxHeight: .infinity)
            .padding(.horizontal, 24)
            .padding(.top, 4)
            .padding(.bottom, 12)
        }
        .ignoresSafeArea(.keyboard)
        .fullScreenCover(isPresented: $showTerms) {
            TermsOfServiceView()
        }
        .fullScreenCover(isPresented: $showPrivacy) {
            PrivacyPolicyView()
        }
        .overlay(
            ErrorToast(
                message: errorMessage,
                isPresented: showErrorMessage,
                topInset: 20 // push lower to avoid overlapping logo
            )
        )
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
                        isLoading = false
                        // Auth state will automatically update via the listener
                        // User will be taken to EmailVerificationView
                    case .failure(let error):
                        isLoading = false
                        print("Sign up error: \(error.localizedDescription)")
                        
                        // Use AuthErrorHandler for error processing
                        errorMessage = AuthErrorHandler.getMessage(for: error, context: .signUp)
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
    
    private func signInWithApple() {
        authService.startAppleSignInFlow { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    // Auth state will automatically update via the listener
                    break
                case .failure(let error):
                    print("Apple sign in error: \(error.localizedDescription)")
                    
                    // Use AuthErrorHandler for error processing
                    if !AuthErrorHandler.isUserCancellation(error) {
                        errorMessage = AuthErrorHandler.getMessage(for: error, context: .signUp)
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
    
    private func signInWithGoogle() {
        authService.startGoogleSignInFlow { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    // Auth state will automatically update via the listener
                    print("Google sign in successful")
                case .failure(let error):
                    print("Google sign in error: \(error.localizedDescription)")
                    
                    // Use AuthErrorHandler for error processing
                    if !AuthErrorHandler.isUserCancellation(error) {
                        errorMessage = AuthErrorHandler.getMessage(for: error, context: .signUp)
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

private struct TermsOfServiceView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                Text(LegalDocuments.termsOfService)
                    .font(.system(size: 15))
                    .foregroundColor(.primary) // Adapts to light/dark mode
                    .padding()
            }
            .navigationTitle("Terms of Service")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                }
            }
            .background(Color(.systemBackground)) // Adapts to light/dark mode
        }
    }
}

private struct PrivacyPolicyView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                Text(LegalDocuments.privacyPolicy)
                    .font(.system(size: 15))
                    .foregroundColor(.primary) // Adapts to light/dark mode
                    .padding()
            }
            .navigationTitle("Privacy Policy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                }
            }
            .background(Color(.systemBackground)) // Adapts to light/dark mode
        }
    }
}


#Preview {
    RegisterView()
}
