import SwiftUI

// MARK: - Back Button Component
struct BackButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(Color.white)
                    .frame(width: 36, height: 36)
                    .overlay(
                        Circle()
                            .stroke(Color(hexString: "E5E7EB"), lineWidth: 1)
                    )
                
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color(hexString: "364153"))
            }
        }
    }
}

// MARK: - Custom Navigation Bar Component
struct CustomNavigationBar: View {
    let title: String?
    let showBackButton: Bool
    let backAction: (() -> Void)?
    
    init(title: String? = nil, showBackButton: Bool = true, backAction: (() -> Void)? = nil) {
        self.title = title
        self.showBackButton = showBackButton
        self.backAction = backAction
    }
    
    var body: some View {
        HStack {
            if showBackButton, let backAction = backAction {
                BackButton(action: backAction)
                    .padding(.leading, 16)
            } else if showBackButton {
                // Default back button using environment dismiss
                BackButton {
                    // This will be handled by the parent view
                }
                .padding(.leading, 16)
            }
            
            if let title = title {
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(Color(hexString: "101828"))
                    .frame(maxWidth: .infinity)
            } else {
                Spacer()
            }
        }
        .padding(.top, 12)
        .frame(height: 44)
        .background(Color.white)
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
    @State private var isPasswordVisible: Bool = false
    
    init(
        placeholder: String,
        text: Binding<String>,
        isSecure: Bool = false,
        keyboardType: UIKeyboardType = .default,
        textContentType: UITextContentType? = nil,
        showPasswordToggle: Bool = false
    ) {
        self.placeholder = placeholder
        self._text = text
        self.isSecure = isSecure
        self.keyboardType = keyboardType
        self.textContentType = textContentType
        self.showPasswordToggle = showPasswordToggle
    }
    
    var body: some View {
        HStack {
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
        .frame(maxWidth: 263)
    }
}

// MARK: - Primary Button Component
struct PrimaryButton: View {
    let title: String
    let action: () -> Void
    let isLoading: Bool
    
    init(title: String, isLoading: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.isLoading = isLoading
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            if isLoading {
                ProgressView()
                    .tint(.white)
                    .frame(maxWidth: .infinity, minHeight: 48)
            } else {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, minHeight: 48)
            }
        }
        .background(Color.black)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .disabled(isLoading)
        .frame(maxWidth: 263)
    }
}

// MARK: - Social Button Component
struct SocialButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void
    
    init(title: String, systemImage: String, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                Text(title)
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

// MARK: - Logo Component
struct LogoView: View {
    let title: String
    let subtitle: String?
    
    init(title: String, subtitle: String? = nil) {
        self.title = title
        self.subtitle = subtitle
    }
    
    var body: some View {
        VStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.black)
                .frame(width: 80, height: 80)
                .overlay(
                    Text("M")
                        .font(.system(size: 24, weight: .medium, design: .default))
                        .foregroundColor(.white)
                )
            
            Text("MODO")
                .font(.system(size: 30, weight: .heavy))
                .foregroundColor(Color(hexString: "101828"))
                .padding(.top, 8)
            
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.system(size: 30, weight: .medium))
                    .foregroundColor(Color(hexString: "101828"))
                    .padding(.top, 8)
            }
        }
        .padding(.top, 8)
    }
}

// MARK: - Divider with Text Component
struct DividerWithText: View {
    let text: String
    
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Rectangle()
                .fill(Color(hexString: "E5E7EB"))
                .frame(height: 1)
                .opacity(1.0)
            
            Text(text)
                .font(.system(size: 12))
                .foregroundColor(Color(hexString: "6A7282"))
                .textCase(.uppercase)
            
            Rectangle()
                .fill(Color(hexString: "E5E7EB"))
                .frame(height: 1)
                .opacity(1.0)
        }
        .frame(width: 263, height: 16)
    }
}

// MARK: - Input Validation Extension
extension String {
    /// Validates email format
    var isValidEmail: Bool {
        let emailRegex = "^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: self)
    }
    
    /// Validates password strength (at least 8 characters, contains letters and numbers)
    var isValidPassword: Bool {
        let passwordRegex = "^(?=.*[A-Za-z])(?=.*\\d)[A-Za-z\\d@$!%*#?&]{8,}$"
        let passwordPredicate = NSPredicate(format: "SELF MATCHES %@", passwordRegex)
        return passwordPredicate.evaluate(with: self)
    }
    
    
    /// Checks if string is not empty (after trimming whitespace)
    var isNotEmpty: Bool {
        !self.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

// MARK: - Color Extension
extension Color {
    init(hexString: String, alpha: Double = 1.0) {
        var cleaned = hexString.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
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

// MARK: - Bottom Bar Components
public enum Tab: String, CaseIterable {
    case todos = "TODOs"
    case insights = "Insights"
}

public struct BottomBar: View {
    @Binding var selectedTab: Tab

    public init(selectedTab: Binding<Tab>) {
        self._selectedTab = selectedTab
    }

    public var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color(hexString: "E5E7EB"))
                .frame(height: 1)
            HStack(spacing: 64) {
                BottomBarItem(icon: "doc.text", label: Tab.todos.rawValue, isSelected: selectedTab == .todos) {
                    selectedTab = .todos
                }
                BottomBarItem(icon: "message", label: Tab.insights.rawValue, isSelected: selectedTab == .insights) {
                    selectedTab = .insights
                }
            }
            .padding(.vertical, 12)
        }
        .background(Color.white)
    }
}

struct BottomBarItem: View {
    let icon: String
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                Text(label)
                    .font(.system(size: 12, weight: .medium))
            }
            .frame(minWidth: 72)
            .foregroundColor(isSelected ? Color(hexString: "7C3AED") : Color(hexString: "101828"))
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected ? Color(hexString: "F5F3FF") : Color.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isSelected ? Color(hexString: "E9D5FF") : Color.clear, lineWidth: 1)
            )
        }
    }
}

// MARK: - Calendar Icon Component
public struct CalendarIcon: View {
    public var strokeColor: Color
    public var size: CGFloat

    public init(strokeColor: Color = .white, size: CGFloat = 20) {
        self.strokeColor = strokeColor
        self.size = size
    }

    public var body: some View {
        ZStack {
            // Vector 1
            Path { path in
                path.move(to: CGPoint(x: size * 0.3333, y: size * 0.0833))
                path.addLine(to: CGPoint(x: size * 0.6667, y: size * 0.0833))
            }
            .stroke(strokeColor, lineWidth: size * (1.67/20))
            
            // Vector 2
            Path { path in
                path.move(to: CGPoint(x: size * 0.6667, y: size * 0.0833))
                path.addLine(to: CGPoint(x: size * 0.3333, y: size * 0.0833))
            }
            .stroke(strokeColor, lineWidth: size * (1.67/20))
            
            // Vector 3
            Path { path in
                path.addRect(CGRect(
                    x: size * 0.125,
                    y: size * 0.1667,
                    width: size * (1 - 0.125 * 2),
                    height: size * (1 - 0.1667 - 0.0833)
                ))
            }
            .stroke(strokeColor, lineWidth: size * (1.67/20))
            
            // Vector 4
            Path { path in
                path.addRect(CGRect(
                    x: size * 0.125,
                    y: size * 0.4167,
                    width: size * (1 - 0.125 * 2),
                    height: size * (1 - 0.4167 - 0.5833)
                ))
            }
            .stroke(strokeColor, lineWidth: size * (1.67/20))
        }
        .frame(width: size, height: size)
        .accessibilityLabel("Calendar icon")
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 20) {
        CalendarIcon(strokeColor: .black, size: 24)

        StatefulPreviewWrapper(Tab.todos) { selection in
            BottomBar(selectedTab: selection)
        }
        
        CustomNavigationBar(title: "Test", showBackButton: true) {
            print("Back tapped")
        }
        
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
        
        PrimaryButton(title: "Sign In") {
            print("Button tapped")
        }
        
        HStack {
            SocialButton(title: "Apple", systemImage: "apple.logo") {
                print("Apple tapped")
            }
            SocialButton(title: "Google", systemImage: "g.circle.fill") {
                print("Google tapped")
            }
        }
        
        LogoView(title: "MODO", subtitle: "Login")
        
        DividerWithText(text: "or")
    }
    .padding()
}

// MARK: - For header on each page
struct PageHeader: View {
    @Environment(\.dismiss) private var dismiss
    let title: String

    var body: some View {
        HStack {
            BackButton {
                dismiss()
            }

            Spacer()

            Text(title)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(Color(hexString: "101828"))

            Spacer()

            Color.clear.frame(width: 36, height: 36)
        }
    }
}

// MARK: - For each card in the profile page
struct ProfileSection<Content: View>: View {
    let title: String
    let content: () -> Content

    init(title: String, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 14))
                .foregroundColor(Color(hexString: "6A7282"))
                .padding(.horizontal, 24)

            VStack(spacing: 12, content: content)
                .padding(.horizontal, 24)
        }
    }
}

/* COMPONENTS FOR THE PROFILE PAGE */

// MARK: - Reusable navigation row component in Profile
struct NavigationRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let destination: AnyView

    init(icon: String, title: String, subtitle: String, destination: AnyView) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.destination = destination
    }

    var body: some View {
        NavigationLink(destination: destination) {
            HStack(spacing: 16) {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(hexString: "F3F4F6"))
                    .frame(width: 44, height: 44)
                    .overlay(
                        Image(systemName: icon)
                            .foregroundColor(Color(hexString: "364153"))
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color(hexString: "101828"))
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundColor(Color(hexString: "6A7282"))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundColor(Color(hexString: "99A1AF"))
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white)
                    .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 1)
                    .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
            )
        }
    }
}

// MARK: - StatCard in Profile
struct StatCard: View {
    let title: String
    let value: String
    let emoji: String

    var body: some View {
        VStack(spacing: 8) {
            Text(value)
                .font(.system(size: 24))
                .foregroundColor(Color(hexString: "0A0A0A"))
            Text(title)
                .font(.system(size: 12))
                .foregroundColor(Color(hexString: "4A5565"))
            Text(emoji)
                .font(.system(size: 18))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 1)
                .shadow(color: Color.black.opacity(0.1), radius: 6, x: 0, y: 4)
        )
    }
}

// Helper to preview a Binding
struct StatefulPreviewWrapper<Value, Content: View>: View {
    @State var value: Value
    let content: (Binding<Value>) -> Content

    init(_ value: Value, content: @escaping (Binding<Value>) -> Content) {
        _value = State(initialValue: value)
        self.content = content
    }

    var body: some View {
        content($value)
    }
}
