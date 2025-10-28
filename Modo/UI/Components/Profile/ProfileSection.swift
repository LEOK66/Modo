import SwiftUI

// MARK: - Profile Section Component
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

// MARK: - Preview
#Preview {
    ProfileSection(title: "Account") {
        Text("Profile content here")
    }
}

