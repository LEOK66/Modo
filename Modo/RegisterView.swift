
import SwiftUI

struct RegisterView: View {
    @State private var emailAddress = ""
    @State private var password = ""
    @State private var verificationCode = ""
    @State private var isPasswordVisible = false
    @State private var resendTimer = 57
    @Environment(\.dismiss) private var dismiss

    @State private var showTerms = false
    @State private var showPrivacy = false
    
    var body: some View {
        ZStack {

            Color.white
                .ignoresSafeArea()
            
            VStack(spacing: 0) {

                CustomNavigationBar(showBackButton: true) {
                    dismiss()
                }

                VStack(spacing: 24) {
                    

                    LogoView(title: "MODO", subtitle: "Register")
                    .padding(.top, 4)
                    
                    VStack(spacing: 16) {
                        CustomInputField(
                            placeholder: "Email address",
                            text: $emailAddress,
                            keyboardType: .emailAddress,
                            textContentType: .emailAddress
                        )
                        
                        CustomInputField(
                            placeholder: "Password",
                            text: $password,
                            isSecure: true,
                            showPasswordToggle: true
                        )
                        
                        // Verification Code input
                        HStack {
                            TextField("Verification code", text: $verificationCode)
                                .font(.system(size: 14))
                                .foregroundColor(Color(hexString: "717182"))
                                .kerning(-0.15)
                            
                            Spacer()
                            
                            Text("\(resendTimer)s")
                                .font(.system(size: 14))
                                .foregroundColor(Color(hexString: "717182"))
                                .kerning(-0.15)
                        }
                        .padding(.horizontal, 12)
                        .frame(height: 48)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color(hexString: "F9FAFB").opacity(0.5))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Color(hexString: "E5E7EB"), lineWidth: 1)
                        )
                        .frame(maxWidth: 263)
                        
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
                            .frame(width: 242)
                            .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: 263)
                        
                        PrimaryButton(title: "Sign Up") {
                            signUp()
                        }
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, 4)
                .padding(.bottom, 12)
                
                Rectangle()
                    .fill(Color.black)
                    .frame(width: 144, height: 5)
                    .cornerRadius(100)
                    .padding(.bottom, 8)
            }
        }
        .navigationBarBackButtonHidden(true)
        #if os(iOS)
        .toolbar(.hidden, for: .navigationBar)
        #endif
        .onAppear {
            startResendTimer()
        }
        .fullScreenCover(isPresented: $showTerms) {
            TermsOfServiceView()
        }
        .fullScreenCover(isPresented: $showPrivacy) {
            PrivacyPolicyView()
        }
    }
    
    
    private func signUp() {
        // Implement your sign up logic here
        print("Signing up with email: \(emailAddress)")
        print("Password: \(password)")
        print("Verification code: \(verificationCode)")
    }
    
    private func startResendTimer() {
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            if resendTimer > 0 {
                resendTimer -= 1
            } else {
                timer.invalidate()
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

private extension Color {
    init(hex: String, alpha: Double = 1.0) {
        var cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if cleaned.hasPrefix("#") { cleaned.removeFirst() }
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)
        let r, g, b: Double
        switch cleaned.count {
        case 6:
            r = Double((value >> 16) & 0xFF) / 255.0
            g = Double((value >> 8) & 0xFF) / 255.0
            b = Double(value & 0xFF) / 255.0
        default:
            r = 0; g = 0; b = 0
        }
        self = Color(red: r, green: g, blue: b).opacity(alpha)
    }
}

#Preview {
    RegisterView()
}
