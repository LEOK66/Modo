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

