import SwiftUI
import UIKit
import Foundation
import AuthenticationServices
import CryptoKit
import FirebaseAuth

struct LoginView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                // Full-screen white background
                Color.white
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
    @State private var showMain = false
    @State private var showEmailError: Bool = false
    @State private var showPasswordError: Bool = false
    @State private var isLoading: Bool = false
    @State private var showErrorMessage: Bool = false
    @State private var errorMessage: String = "Invalid email or password"
    @State private var appleSignInDelegate: AppleSignInDelegate?
    @State private var appleSignInPresentationProvider: AppleSignInPresentationContextProvider?

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
                        keyboardType: .emailAddress,
                        textContentType: .emailAddress,
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
                    switch result {
                    case .success:
                        // Auth state will automatically update via the listener
                        break
                    case .failure(let error):
                        isLoading = false
                        print("Sign in error: \(error.localizedDescription)")
                        
                        // Determine error message based on error type
                        errorMessage = getErrorMessage(for: error)
                        
                        // Only show error if it's not a user cancellation
                        if !isUserCancellationError(error) {
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
    
    private func signInWithApple() {
        let nonce = AuthService.randomNonceString()
        let hashedNonce = AuthService.sha256(nonce)
        
        let appleIDProvider = ASAuthorizationAppleIDProvider()
        let request = appleIDProvider.createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = hashedNonce
        
        // Create delegate and presentation provider - store in @State to keep strong references
        appleSignInDelegate = AppleSignInDelegate(
            nonce: nonce,
            onSuccess: { _ in
                // Auth state will automatically update via the listener
            },
            onError: { error in
                DispatchQueue.main.async { [self] in
                    // Check if user canceled - this should be checked FIRST
                    let isCancelled = isUserCancellationError(error)
                    
                    if isCancelled {
                        // Don't show any error message for cancellation
                        return
                    }
                    
                    // Only show error if it's not a cancellation
                    let errorDescription = error.localizedDescription.lowercased()
                    if errorDescription.contains("audience") && errorDescription.contains("does not match") {
                        errorMessage = "Bundle ID configuration mismatch. Please check Firebase Console settings."
                    } else {
                        errorMessage = getErrorMessage(for: error)
                    }
                    showErrorMessage = true
                    
                    // Hide error message after 5 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                        withAnimation {
                            showErrorMessage = false
                        }
                    }
                }
            }
        )
        
        appleSignInPresentationProvider = AppleSignInPresentationContextProvider()
        
        guard let delegate = appleSignInDelegate, let provider = appleSignInPresentationProvider else {
            return
        }
        
        let authorizationController = ASAuthorizationController(authorizationRequests: [request])
        authorizationController.delegate = delegate
        authorizationController.presentationContextProvider = provider
        authorizationController.performRequests()
    }
    
    private func signInWithGoogle() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            print("Could not find window")
            errorMessage = "Unable to start Google Sign In. Please try again."
            showErrorMessage = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                withAnimation { showErrorMessage = false }
            }
            return
        }
        
        // Find the top-most view controller
        var topController = window.rootViewController
        while let presentedController = topController?.presentedViewController {
            topController = presentedController
        }
        
        guard let presentingController = topController else {
            print("Could not find presenting controller")
            errorMessage = "Unable to start Google Sign In. Please try again."
            showErrorMessage = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                withAnimation { showErrorMessage = false }
            }
            return
        }
        
        print("Starting Google Sign In with controller: \(type(of: presentingController))")
        
        authService.signInWithGoogle(presentingViewController: presentingController) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    // Auth state will automatically update via the listener
                    print("Google sign in successful")
                case .failure(let error):
                    print("Google sign in error: \(error.localizedDescription)")
                    
                    // Don't show error if user canceled
                    if !isUserCancellationError(error) {
                        errorMessage = getErrorMessage(for: error)
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
    
    // MARK: - Error Handling
    private func isUserCancellationError(_ error: Error) -> Bool {
        let nsError = error as NSError
        
        // Check for Google Sign-In cancellation error
        // Google Sign-In cancellation can be identified by:
        // 1. Domain "com.google.GIDSignIn" with code -5
        // 2. Error description containing "cancel" or "cancelled"
        let errorDomain = nsError.domain
        let errorCode = nsError.code
        let errorDescription = nsError.localizedDescription.lowercased()
        
        // Check for Google Sign-In cancellation
        if errorDomain == "com.google.GIDSignIn" && errorCode == -5 {
            return true
        }
        
        // Check for Apple Sign-In cancellation
        // ASAuthorizationError with code 1001 indicates user cancellation
        if errorDomain == "com.apple.AuthenticationServices.AuthorizationError" && errorCode == 1001 {
            return true
        }
        
        // Check for other Apple Sign-In error domains
        if errorDomain.contains("AuthenticationServices") || errorDomain.contains("ASAuthorization") {
            if errorCode == 1001 || errorCode == -1001 {
                return true
            }
        }
        
        // Check for cancellation in error description
        if errorDescription.contains("cancel") || errorDescription.contains("cancelled") || errorDescription.contains("user canceled") {
            return true
        }
        
        // Check for URL cancellation errors
        if errorDomain == NSURLErrorDomain && errorCode == NSURLErrorCancelled {
            return true
        }
        
        return false
    }
    
    private func getErrorMessage(for error: Error) -> String {
        let nsError = error as NSError
        
        // Check for network errors
        if isNetworkError(nsError) {
            return "Network not available. Please check your connection and try again."
        }
        
        // Check for Firebase Auth errors
        if nsError.domain == "FIRAuthErrorDomain" {
            switch nsError.code {
            case 17020: // Network error
                return "Network not available. Please check your connection and try again."
            case 17007: // Email already in use (shouldn't happen in login, but handle it)
                return "This email is already registered. Please try logging in."
            case 17008: // Invalid email
                return "Invalid email address. Please check and try again."
            case 17009: // Wrong password
                return "Invalid email or password"
            case 17010: // Too many requests
                return "Too many attempts. Please try again later."
            default:
                // Check if it's a network-related error by checking the underlying error
                if isNetworkError(nsError) {
                    return "Network not available. Please check your connection and try again."
                }
                return "Invalid email or password"
            }
        }
        
        // Check for general network errors
        if isNetworkError(nsError) {
            return "Network not available. Please check your connection and try again."
        }
        
        // Default error message
        return "Invalid email or password"
    }
    
    private func isNetworkError(_ error: NSError) -> Bool {
        // Check for network-related error codes
        let networkErrorCodes: [Int] = [
            NSURLErrorNotConnectedToInternet,
            NSURLErrorNetworkConnectionLost,
            NSURLErrorTimedOut,
            NSURLErrorCannotConnectToHost,
            NSURLErrorCannotFindHost,
            NSURLErrorDNSLookupFailed
        ]
        
        if error.domain == NSURLErrorDomain && networkErrorCodes.contains(error.code) {
            return true
        }
        
        // Check error description for network-related keywords
        let errorDescription = error.localizedDescription.lowercased()
        let networkKeywords = ["network", "internet", "connection", "offline", "unreachable", "timeout"]
        if networkKeywords.contains(where: { errorDescription.contains($0) }) {
            return true
        }
        
        return false
    }
}


#Preview {
    LoginView()
}

