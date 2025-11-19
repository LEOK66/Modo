import SwiftUI
import FirebaseAuth

struct ChangePasswordView: View {
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) var dismiss
    @State private var currentPassword: String = ""
    @State private var newPassword: String = ""
    @State private var confirmPassword: String = ""
    @State private var showCurrentPasswordError: Bool = false
    @State private var showNewPasswordError: Bool = false
    @State private var showConfirmPasswordError: Bool = false
    @State private var isChanging: Bool = false
    @State private var showSuccessMessage: Bool = false
    @State private var showErrorMessage: Bool = false
    @State private var errorMessage: String = ""
    
    var body: some View {
        ZStack(alignment: .top) {
            Color(.systemBackground).ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                PageHeader(title: "Change Password")
                    .padding(.top, 12)
                    .padding(.horizontal, 24)
                
                Spacer().frame(height: 12)
                
                // Content
                ScrollView {
                    VStack(spacing: 24) {
                        // Description
                        Text("Enter your current password and choose a new one.")
                            .font(.system(size: 15))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                            .padding(.top, 8)
                        
                        // Current Password
                        ValidatedInputField(
                            placeholder: "Current Password",
                            text: $currentPassword,
                            showError: $showCurrentPasswordError,
                            errorMessage: "Please enter your current password",
                            isSecure: true,
                            textContentType: .password,
                            showPasswordToggle: true
                        )
                        .padding(.horizontal, 24)
                        
                        // New Password
                        ValidatedInputField(
                            placeholder: "New Password",
                            text: $newPassword,
                            showError: $showNewPasswordError,
                            errorMessage: "At least 8 characters with letters and numbers",
                            isSecure: true,
                            textContentType: .newPassword,
                            showPasswordToggle: true
                        )
                        .padding(.horizontal, 24)
                        
                        // Confirm Password
                        ValidatedInputField(
                            placeholder: "Confirm New Password",
                            text: $confirmPassword,
                            showError: $showConfirmPasswordError,
                            errorMessage: "Passwords do not match",
                            isSecure: true,
                            textContentType: .newPassword,
                            showPasswordToggle: true
                        )
                        .padding(.horizontal, 24)
                        
                        // Change Password Button
                        PrimaryButton(
                            title: "Change Password",
                            isLoading: isChanging
                        ) {
                            changePassword()
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 8)
                        
                        Spacer().frame(height: 20)
                    }
                    .padding(.vertical, 16)
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .overlay(
            SuccessToast(
                message: "Password changed successfully",
                isPresented: showSuccessMessage
            )
        )
        .overlay(
            ErrorToast(
                message: errorMessage,
                isPresented: showErrorMessage
            )
        )
        .onTapGesture {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
    }
    
    private func changePassword() {
        // Reset error states
        showCurrentPasswordError = false
        showNewPasswordError = false
        showConfirmPasswordError = false
        
        // Validate inputs
        var hasError = false
        
        if currentPassword.isEmpty {
            showCurrentPasswordError = true
            hasError = true
        }
        
        if newPassword.isEmpty || !newPassword.isValidPassword {
            showNewPasswordError = true
            hasError = true
        }
        
        if confirmPassword.isEmpty || newPassword != confirmPassword {
            showConfirmPasswordError = true
            hasError = true
        }
        
        guard !hasError else {
            return
        }
        
        // Change password
        isChanging = true
        
        authService.changePassword(currentPassword: currentPassword, newPassword: newPassword) { result in
            DispatchQueue.main.async {
                isChanging = false
                
                switch result {
                case .success:
                    // Show success message
                    showSuccessMessage = true
                    
                    // Clear fields
                    currentPassword = ""
                    newPassword = ""
                    confirmPassword = ""
                    
                    // Hide success message and dismiss after 2 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation {
                            showSuccessMessage = false
                        }
                        dismiss()
                    }
                    
                case .failure(let error):
                    print("Change password error: \(error.localizedDescription)")
                    
                    let appError = AppError.from(error)
                    if !appError.isUserCancellation {
                        errorMessage = appError.userMessage(context: .passwordChange)
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

// MARK: - Preview
#Preview {
    NavigationStack {
        ChangePasswordView()
            .environmentObject(AuthService.shared)
    }
}



