import SwiftUI

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
        .frame(maxWidth: LayoutConstants.inputFieldMaxWidth)
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 20) {
        PrimaryButton(title: "Sign In") {
            print("Button tapped")
        }
        
        PrimaryButton(title: "Loading", isLoading: true) {
            print("Button tapped")
        }
    }
    .padding()
}

