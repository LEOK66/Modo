import SwiftUI

struct LoginView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground) // Adapts to light/dark mode
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }

                LoginCard()
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private struct LoginCard: View {
    @EnvironmentObject var authService: AuthService
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var showEmailError: Bool = false
    @State private var showPasswordError: Bool = false
    @State private var isLoading: Bool = false
    @State private var showErrorMessage: Bool = false
    @State private var errorMessage: String = ""

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            LogoView(title: "MODO", subtitle: "Login")
                .padding(.top, 8)
            VStack(spacing: 16) {
                ValidatedInputField(
                    placeholder: "Email address",
                    text: $email,
                    showError: $showEmailError,
                    errorMessage: "Please enter a valid email address",
                    keyboardType: .emailAddress,
                    textContentType: .emailAddress
                )
                ValidatedInputField(
                    placeholder: "Password",
                    text: $password,
                    showError: $showPasswordError,
                    errorMessage: "Password cannot be empty",
                    isSecure: true,
                    showPasswordToggle: true
                )
                HStack {
                    NavigationLink(destination: RegisterView()) {
                        Text("New user?")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary) // Adapts to light/dark mode
                    }
                    Spacer()
                    NavigationLink(destination: ForgotPasswordView()) {
                        Text("Forgot password?")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary) // Adapts to light/dark mode
                    }
                }
                .frame(maxWidth: LayoutConstants.inputFieldMaxWidth)

                PrimaryButton(title: "Sign In", isLoading: isLoading) {
                    signIn()
                }

                DividerWithText(text: "or")
                HStack(spacing: 12) {
                    AppleSignInButton(action: signInWithApple)
                    SocialButton(title: "Google", systemImage: "g.circle.fill") {
                        signInWithGoogle()
                    }
                }
                .frame(maxWidth: LayoutConstants.inputFieldMaxWidth)
            }
            .padding(.top, 8)

            Spacer()
        }
        .ignoresSafeArea(.keyboard)
        .frame(maxHeight: .infinity)
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .overlay(
            ErrorToast(
                message: errorMessage,
                isPresented: showErrorMessage
            )
        )
    }
    
    private func signIn() {
        withAnimation(.easeInOut(duration: 0.2)) {
            showEmailError = !email.isValidEmail || !email.isNotEmpty
            showPasswordError = !password.isNotEmpty
        }
        
        if email.isValidEmail && password.isNotEmpty {
            isLoading = true
            
            authService.signIn(email: email, password: password) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success:
                        break
                    case .failure(let error):
                        isLoading = false
                        print("Sign in error: \(error.localizedDescription)")
                        if !AuthErrorHandler.isUserCancellation(error) {
                            errorMessage = AuthErrorHandler.getMessage(for: error, context: .signIn)
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
    
    private func signInWithApple() {
        authService.startAppleSignInFlow { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    break
                case .failure(let error):
                    print("Apple sign in error: \(error.localizedDescription)")
                    if !AuthErrorHandler.isUserCancellation(error) {
                        errorMessage = AuthErrorHandler.getMessage(for: error, context: .signIn)
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
                    print("Google sign in successful")
                case .failure(let error):
                    print("Google sign in error: \(error.localizedDescription)")
                    if !AuthErrorHandler.isUserCancellation(error) {
                        errorMessage = AuthErrorHandler.getMessage(for: error, context: .signIn)
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


#Preview {
    LoginView()
}

