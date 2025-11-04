import SwiftUI
import AuthenticationServices
import FirebaseAuth

// MARK: - Apple Sign In Button
struct AppleSignInButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: "apple.logo")
                Text("Apple")
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundColor(Color(hexString: "0A0A0A"))
            .frame(width: 125.5, height: 48)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color(hexString: "E5E7EB"), lineWidth: 1)
            )
        }
    }
}

// MARK: - Apple Sign In Delegate
class AppleSignInDelegate: NSObject, ASAuthorizationControllerDelegate {
    let nonce: String
    let onSuccess: (User) -> Void
    let onError: (Error) -> Void
    
    init(nonce: String, onSuccess: @escaping (User) -> Void, onError: @escaping (Error) -> Void) {
        self.nonce = nonce
        self.onSuccess = onSuccess
        self.onError = onError
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        AuthService.shared.signInWithApple(authorization: authorization, nonce: nonce) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let user):
                    self.onSuccess(user)
                case .failure(let error):
                    self.onError(error)
                }
            }
        }
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        onError(error)
    }
}

// MARK: - Apple Sign In Presentation Context Provider
class AppleSignInPresentationContextProvider: NSObject, ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            fatalError("No window found")
        }
        return window
    }
}


