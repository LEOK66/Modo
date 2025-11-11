import SwiftUI
import UIKit

// MARK: - UITextField Wrapper for Smooth Password Toggle
struct UITextFieldWrapper: UIViewRepresentable {
    @Binding var text: String
    let placeholder: String
    let isSecure: Bool
    let isPasswordVisible: Bool
    let keyboardType: UIKeyboardType
    let textContentType: UITextContentType?
    let toggleAction: (() -> Void)?
    let onCoordinatorReady: ((@escaping () -> Void) -> Void)?
    
    func makeUIView(context: Context) -> UITextField {
        let textField = UITextField()
        textField.font = UIFont.systemFont(ofSize: 14)
        textField.textColor = .label // Adapts to light/dark mode
        
        // Set placeholder with adaptive color for light/dark mode
        let placeholderColor = UIColor.placeholderText
        textField.attributedPlaceholder = NSAttributedString(
            string: placeholder,
            attributes: [
                .foregroundColor: placeholderColor,
                .font: UIFont.systemFont(ofSize: 14)
            ]
        )
        
        textField.keyboardType = keyboardType
        textField.autocapitalizationType = .none
        textField.autocorrectionType = .no
        textField.textContentType = textContentType
        textField.isSecureTextEntry = isSecure && !isPasswordVisible
        textField.text = text
        
        // Use same return key type for all fields to prevent keyboard changes
        textField.returnKeyType = .next
        textField.enablesReturnKeyAutomatically = false
        
        // Store reference to textField in coordinator
        textField.delegate = context.coordinator
        context.coordinator.textField = textField
        context.coordinator.toggleAction = toggleAction
        
        // Add notification observer for text changes (catches autofill, paste, etc.)
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.textFieldDidChange(_:)),
            name: UITextField.textDidChangeNotification,
            object: textField
        )
        
        // Provide toggle function to parent
        onCoordinatorReady? {
            context.coordinator.togglePasswordVisibility()
        }
        
        return textField
    }
    
    func updateUIView(_ uiView: UITextField, context: Context) {
        // Update keyboard type if changed (only when not editing)
        if !uiView.isFirstResponder && uiView.keyboardType != keyboardType {
            uiView.keyboardType = keyboardType
        }
        
        // Update text content type if changed (only when not editing)
        if !uiView.isFirstResponder && uiView.textContentType != textContentType {
            uiView.textContentType = textContentType
        }
        
        // Update placeholder if it changed (with adaptive color)
        if uiView.attributedPlaceholder?.string != placeholder {
            let placeholderColor = UIColor.placeholderText
            uiView.attributedPlaceholder = NSAttributedString(
                string: placeholder,
                attributes: [
                    .foregroundColor: placeholderColor,
                    .font: UIFont.systemFont(ofSize: 14)
                ]
            )
        }
        
        // Only update text if UITextField is NOT being edited (avoids cursor jumping)
        if !uiView.isFirstResponder && uiView.text != text {
            uiView.text = text
        }
        
        // Only update secure text entry on initial setup or when visibility changes externally
        // When button is clicked, toggle happens directly on UITextField via coordinator
        if isSecure {
            let shouldBeSecure = !isPasswordVisible
            if uiView.isSecureTextEntry != shouldBeSecure {
                uiView.isSecureTextEntry = shouldBeSecure
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }
    
    class Coordinator: NSObject, UITextFieldDelegate {
        @Binding var text: String
        weak var textField: UITextField?
        var toggleAction: (() -> Void)?
        
        init(text: Binding<String>) {
            self._text = text
        }
        
        deinit {
            NotificationCenter.default.removeObserver(self)
        }
        
        // Sync text to binding in real-time as user types
        func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
            // Calculate the new text
            let currentText = textField.text ?? ""
            guard let textRange = Range(range, in: currentText) else { return true }
            let newText = currentText.replacingCharacters(in: textRange, with: string)
            
            // Update binding immediately
            DispatchQueue.main.async { [weak self] in
                self?.text = newText
            }
            
            return true
        }
        
        // Sync text to binding when editing ends (fallback for autofill, password managers, etc.)
        func textFieldDidEndEditing(_ textField: UITextField) {
            // Sync text when editing ends to catch cases like autofill
            DispatchQueue.main.async { [weak self] in
                self?.text = textField.text ?? ""
            }
        }
        
        // Handle text changes via notification (catches autofill, paste, programmatic changes)
        @objc func textFieldDidChange(_ notification: Notification) {
            guard let textField = notification.object as? UITextField,
                  textField === self.textField else { return }
            
            DispatchQueue.main.async { [weak self] in
                self?.text = textField.text ?? ""
            }
        }
        
        // Toggle visibility directly on UITextField
        func togglePasswordVisibility() {
            guard let textField = textField else { return }
            let selectedRange = textField.selectedTextRange
            
            // Toggle secure text entry
            textField.isSecureTextEntry.toggle()
            
            // Restore cursor position
            if let range = selectedRange {
                textField.selectedTextRange = range
            }
            
            // Update SwiftUI state for icon update
            toggleAction?()
        }
    }
}

// MARK: - Input Field Component
struct CustomInputField: View {
    let placeholder: String
    @Binding var text: String
    let isSecure: Bool
    let keyboardType: UIKeyboardType
    let textContentType: UITextContentType?
    let showPasswordToggle: Bool
    let suffix: String?
    let trailingAccessory: AnyView?
    @State private var isPasswordVisible: Bool = false
    @State private var togglePasswordVisibility: (() -> Void)?
    
    init(
        placeholder: String,
        text: Binding<String>,
        isSecure: Bool = false,
        keyboardType: UIKeyboardType = .default,
        textContentType: UITextContentType? = nil,
        showPasswordToggle: Bool = false,
        suffix: String? = nil,
        trailingAccessory: AnyView? = nil
    ) {
        self.placeholder = placeholder
        self._text = text
        self.isSecure = isSecure
        self.keyboardType = keyboardType
        self.textContentType = textContentType
        self.showPasswordToggle = showPasswordToggle
        self.suffix = suffix
        self.trailingAccessory = trailingAccessory
    }
    
    var body: some View {
        HStack(spacing: 8) {
            if isSecure {
                // Use UITextField wrapper for secure fields to maintain focus when toggling
                UITextFieldWrapper(
                    text: $text,
                    placeholder: placeholder,
                    isSecure: true,
                    isPasswordVisible: isPasswordVisible,
                    keyboardType: keyboardType,
                    textContentType: textContentType,
                    toggleAction: {
                        // Update SwiftUI state for icon update
                        isPasswordVisible.toggle()
                    },
                    onCoordinatorReady: { toggleFunc in
                        // Store the toggle function for button access
                        DispatchQueue.main.async {
                            togglePasswordVisibility = toggleFunc
                        }
                    }
                )
            } else {
                // Use regular TextField for non-secure fields
                // Use ZStack to create a custom placeholder that adapts to light/dark mode
                ZStack(alignment: .leading) {
                    // Custom placeholder that adapts to light/dark mode
                    if text.isEmpty {
                        Text(placeholder)
                            .font(.system(size: 14))
                            .foregroundColor(Color(uiColor: .placeholderText))
                            .allowsHitTesting(false) // Allow taps to pass through to TextField
                    }
                    // TextField without native placeholder (we handle it ourselves)
                    TextField("", text: $text, prompt: Text(""))
                        .font(.system(size: 14))
                        .foregroundColor(.primary) // Adapts to light/dark mode
                        .kerning(-0.15)
                        .textContentType(textContentType)
                        .keyboardType(keyboardType)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                }
            }
            
            if let trailingAccessory = trailingAccessory {
                trailingAccessory
            } else if let suffix = suffix {
                Text(suffix)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color(hexString: "6A7282"))
            }
            
            if showPasswordToggle {
                Button(action: {
                    // Toggle directly on UITextField to avoid keyboard reload
                    if let toggle = togglePasswordVisibility {
                        toggle()
                    } else {
                        // Fallback: just toggle state
                        isPasswordVisible.toggle()
                    }
                }) {
                    Image(systemName: isPasswordVisible ? "eye.slash" : "eye")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(Color(hexString: "99A1AF"))
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(PlainButtonStyle())
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

