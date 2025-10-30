import SwiftUI

// MARK: - Coming Soon Icon Component
struct ComingSoonIcon: View {
    var body: some View {
        ZStack {
            // Outermost circle - lightest gray
            Circle()
                .fill(Color(hexString: "F9FAFB"))
                .frame(width: 128, height: 128)
            
            // Middle circle - light gray
            Circle()
                .fill(Color(hexString: "F3F4F6"))
                .frame(width: 96, height: 96)
            
            // Inner circle - gradient dark
            Circle()
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color(hexString: "101828"),
                            Color(hexString: "364153")
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 64, height: 64)
                .overlay(
                    // Star/sparkle icon
                    Image(systemName: "sparkles")
                        .font(.system(size: 28))
                        .foregroundColor(.white)
                )
            
            // Decorative dots around the icon
            Circle()
                .fill(Color.black.opacity(0.8))
                .frame(width: 16, height: 16)
                .offset(x: 58, y: -66)
            
            Circle()
                .fill(Color(hexString: "99A1AF"))
                .frame(width: 12, height: 12)
                .offset(x: -72, y: 58)
            
            Circle()
                .fill(Color(hexString: "D1D5DC"))
                .frame(width: 8, height: 8)
                .offset(x: 66, y: -2)
        }
    }
}

// MARK: - Preview
#Preview {
    ComingSoonIcon()
        .padding()
        .background(Color.white)
}

