import SwiftUI

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


