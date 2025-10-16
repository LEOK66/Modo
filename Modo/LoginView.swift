

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

private struct StatusBar: View {
    var body: some View {
        HStack {
            // Time
            HStack(spacing: 0) {
                Text(Date(), style: .time)
                    .font(.system(size: 17, weight: .semibold))
                    .frame(minWidth: 60)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Dynamic Island placeholder
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.black.opacity(0.08))
                .frame(width: 124, height: 10)

            // Signal / Wi‑Fi / Battery placeholders
            HStack(spacing: 8) {
                Capsule().fill(Color.black).frame(width: 19, height: 12)
                Capsule().fill(Color.black).frame(width: 17, height: 12)
                BatteryIcon()
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .frame(height: 54)
        .padding(.horizontal, 0)
        .padding(.top, 21)
        .background(.thinMaterial)
    }
}

private struct BatteryIcon: View {
    var body: some View {
        ZStack(alignment: .trailing) {
            RoundedRectangle(cornerRadius: 4.3, style: .continuous)
                .stroke(Color.black.opacity(0.35), lineWidth: 1)
                .frame(width: 25, height: 13)

            RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                .fill(Color.black)
                .frame(width: 21, height: 9)

            Rectangle()
                .fill(Color.black.opacity(0.4))
                .frame(width: 2, height: 6)
                .offset(x: 14) // Battery cap
        }
    }
}


// Utility: hex color initializer
private extension Color {
    init(hex: UInt32, alpha: Double = 1.0) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self = Color(red: r, green: g, blue: b).opacity(alpha)
    }
}

#Preview {
    LoginView()
}

