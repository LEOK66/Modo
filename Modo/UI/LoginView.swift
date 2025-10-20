import SwiftUI

struct LoginView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                // Full-screen white background
                Color.white
                    .ignoresSafeArea()

                LoginCard()
                    .frame(maxWidth: 402, maxHeight: 874)
                    .padding()
            }
            .navigationTitle("") // keep title area compact
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private struct LoginCard: View {
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var isPasswordVisible: Bool = false

    var body: some View {

        VStack(spacing: 24) {

            // Logo
            LogoView(title: "MODO", subtitle: "Login")
            .padding(.top, 8)

            // Inputs
            VStack(spacing: 16) {
                // Email input
                CustomInputField(
                    placeholder: "Email address",
                    text: $email,
                    keyboardType: .emailAddress,
                    textContentType: .emailAddress
                )

                // Password input
                CustomInputField(
                    placeholder: "Password",
                    text: $password,
                    isSecure: true,
                    showPasswordToggle: true
                )

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
                .frame(maxWidth: 263)

                // Sign in button
                PrimaryButton(title: "Sign In") {
                    // Sign In action
                }

                // Divider "or" with left/right thin gray lines, total width 263
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
                .frame(maxWidth: 263)
            }
            .padding(.top, 8)

            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .padding(.bottom, 12)
    }
}

#Preview {
    LoginView()
}

