import SwiftUI

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
            ZStack {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color(.systemBackground)) // Inverted: white in light mode, black in dark mode
                    .opacity(isLoading ? 0 : 1)
                
                if isLoading {
                    LoadingDotsView(
                        dotSize: 8,
                        dotColor: Color(.systemBackground),
                        spacing: 8,
                        isAnimating: isLoading
                    )
                }
            }
            .frame(maxWidth: .infinity, minHeight: 52)
        }
        .background(Color.primary) // Adapts to light/dark mode (black in light, white in dark)
        .cornerRadius(12)
        .disabled(isLoading)
        .frame(maxWidth: LayoutConstants.inputFieldMaxWidth)
    }
}

#Preview {
    VStack(spacing: 20) {
        PrimaryButton(title: "Sign In") {}
        PrimaryButton(title: "Continue", isLoading: true) {}
    }
    .padding()
}
