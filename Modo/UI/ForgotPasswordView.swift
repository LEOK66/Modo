import SwiftUI

struct ForgotPasswordView: View {
    @State private var email: String = ""
    @State private var isSending: Bool = false
    @State private var sent: Bool = false

    var body: some View {
        VStack(spacing: 24) {
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
            CustomInputField(
                placeholder: "Email address",
                text: $email,
                keyboardType: .emailAddress,
                textContentType: .emailAddress
            )

            // Send reset link
            PrimaryButton(
                title: sent ? "Email Sent" : "Send Reset Link",
                isLoading: isSending
            ) {
                Task {
                    await sendReset()
                }
            }
            .disabled(email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            Spacer()
        }
        .padding(.top, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white.ignoresSafeArea())
    }

    private func sendReset() async {
        // Simulate async sending
        isSending = true
        defer { isSending = false }
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        sent = true
    }
}


#Preview {
    NavigationStack {
        ForgotPasswordView()
    }
}
