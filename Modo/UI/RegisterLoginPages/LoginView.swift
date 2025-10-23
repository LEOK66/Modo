import SwiftUI

struct LoginView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                // Full-screen white background
                Color.white
                    .ignoresSafeArea()

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
    @State private var showMain = false
    @State private var showEmailError: Bool = false
    @State private var showPasswordError: Bool = false
    @State private var isLoading: Bool = false
    @State private var showErrorMessage: Bool = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Logo
            LogoView(title: "MODO", subtitle: "Login")
                .padding(.top, 8)

            // Inputs
            VStack(spacing: 16) {
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

                // Password input
                VStack(alignment: .leading, spacing: 4) {
                    CustomInputField(
                        placeholder: "Password",
                        text: $password,
                        isSecure: true,
                        showPasswordToggle: true
                    )
                    
                    if showPasswordError {
                        Text("Password cannot be empty")
                            .font(.system(size: 10))
                            .foregroundColor(.red)
                            .padding(.leading, 12)
                    }
                }

                // Forgot password / new user
                HStack {
                    NavigationLink(destination: RegisterView()) {
                        Text("New user?")
                            .font(.system(size: 14))
                            .foregroundColor(Color(hexString: "4A5565"))
                    }
                    Spacer()
                    NavigationLink(destination: ForgotPasswordView()) {
                        Text("Forgot password?")
                            .font(.system(size: 14))
                            .foregroundColor(Color(hexString: "4A5565"))
                    }
                }
                .frame(maxWidth: LayoutConstants.inputFieldMaxWidth)

                // Sign in button

                PrimaryButton(title: "Sign In", isLoading: isLoading) {
                    signIn()
                }

                // Divider
                DividerWithText(text: "or")

                // Apple/Google login
                HStack(spacing: 12) {
                    SocialButton(title: "Apple", systemImage: "apple.logo") {
                        // Apple login action
                    }
                    SocialButton(title: "Google", systemImage: "g.circle.fill") {
                        // Google login action
                    }
                }
                .frame(maxWidth: LayoutConstants.inputFieldMaxWidth)
            }
            .padding(.top, 8)

            Spacer()
        }
        .frame(maxHeight: .infinity)
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .overlay(
            ErrorToast(
                message: "Invalid email or password",
                isPresented: showErrorMessage
            )
        )
    }
    
    private func signIn() {
        // Validate email and password
        withAnimation(.easeInOut(duration: 0.2)) {
            showEmailError = !email.isValidEmail || !email.isNotEmpty
            showPasswordError = !password.isNotEmpty
        }
        
        // Only proceed if both are valid
        if email.isValidEmail && password.isNotEmpty {
            isLoading = true
            
            authService.signIn(email: email, password: password) { result in
                DispatchQueue.main.async {
                    isLoading = false
                    
                    switch result {
                    case .success:
                        // Auth state will automatically update via the listener
                        break
                    case .failure(let error):
                        print("Sign in error: \(error.localizedDescription)")
                        showErrorMessage = true
                        
                        // Hide error message after 3 seconds
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

