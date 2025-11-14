import SwiftUI

/// A reusable input field component with validation error display
struct ValidatedInputField: View {
    let placeholder: String
    @Binding var text: String
    @Binding var showError: Bool
    let errorMessage: String
    var isSecure: Bool = false
    var keyboardType: UIKeyboardType = .default
    var textContentType: UITextContentType? = nil
    var showPasswordToggle: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            CustomInputField(
                placeholder: placeholder,
                text: $text,
                isSecure: isSecure,
                keyboardType: keyboardType,
                textContentType: textContentType,
                showPasswordToggle: showPasswordToggle
            )
            
            if showError {
                Text(errorMessage)
                    .font(.system(size: 10))
                    .foregroundColor(.red)
                    .padding(.leading, 12)
            }
        }
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 20) {
        ValidatedInputField(
            placeholder: "Email address",
            text: .constant(""),
            showError: .constant(true),
            errorMessage: "Please enter a valid email address",
            keyboardType: .emailAddress,
            textContentType: .emailAddress
        )
        
        ValidatedInputField(
            placeholder: "Password",
            text: .constant(""),
            showError: .constant(true),
            errorMessage: "Password cannot be empty",
            isSecure: true,
            showPasswordToggle: true
        )
    }
    .padding()
}

