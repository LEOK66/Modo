import SwiftUI

// MARK: - Input Field Component
struct CustomInputField: View {
    let placeholder: String
    @Binding var text: String
    let isSecure: Bool
    let keyboardType: UIKeyboardType
    let textContentType: UITextContentType?
    let showPasswordToggle: Bool
    let suffix: String?
    @State private var isPasswordVisible: Bool = false
    
    init(
        placeholder: String,
        text: Binding<String>,
        isSecure: Bool = false,
        keyboardType: UIKeyboardType = .default,
        textContentType: UITextContentType? = nil,
        showPasswordToggle: Bool = false,
        suffix: String? = nil
    ) {
        self.placeholder = placeholder
        self._text = text
        self.isSecure = isSecure
        self.keyboardType = keyboardType
        self.textContentType = textContentType
        self.showPasswordToggle = showPasswordToggle
        self.suffix = suffix
    }
    
    var body: some View {
        HStack(spacing: 8) {
            if isSecure && !isPasswordVisible {
                SecureField(placeholder, text: $text)
                    .font(.system(size: 14))
                    .foregroundColor(Color(hexString: "717182"))
                    .kerning(-0.15)
                    .textContentType(textContentType)
                    .keyboardType(keyboardType)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
            } else {
                TextField(placeholder, text: $text)
                    .font(.system(size: 14))
                    .foregroundColor(Color(hexString: "717182"))
                    .kerning(-0.15)
                    .textContentType(textContentType)
                    .keyboardType(keyboardType)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
            }
            
            if let suffix = suffix {
                Text(suffix)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color(hexString: "6A7282"))
            }
            
            if showPasswordToggle {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isPasswordVisible.toggle()
                    }
                } label: {
                    Image(systemName: isPasswordVisible ? "eye.slash" : "eye")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(Color(hexString: "99A1AF"))
                        .frame(width: 20, height: 20)
                }
            }
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
        .frame(maxWidth: LayoutConstants.inputFieldMaxWidth)
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 20) {
        CustomInputField(
            placeholder: "Email address",
            text: .constant(""),
            keyboardType: .emailAddress,
            textContentType: .emailAddress
        )
        
        CustomInputField(
            placeholder: "Password",
            text: .constant(""),
            isSecure: true,
            showPasswordToggle: true
        )
    }
    .padding()
}

