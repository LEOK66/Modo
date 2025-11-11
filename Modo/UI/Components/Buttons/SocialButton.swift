import SwiftUI

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
            .foregroundColor(.primary) // Adapts to light/dark mode
            .frame(width: 125.5, height: 48)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(.systemBackground)) // Adapts to light/dark mode
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color(.separator), lineWidth: 1) // Adapts to light/dark mode
            )
        }
    }
}

// MARK: - Preview
#Preview {
    HStack {
        SocialButton(title: "Apple", systemImage: "apple.logo") {
            print("Apple tapped")
        }
        SocialButton(title: "Google", systemImage: "g.circle.fill") {
            print("Google tapped")
        }
    }
    .padding()
}

