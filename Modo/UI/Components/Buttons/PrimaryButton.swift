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
                    .foregroundColor(.white)
                    .opacity(isLoading ? 0 : 1)
                
                if isLoading {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 8, height: 8)
                            .scaleEffect(isLoading ? 1 : 0.5)
                            .animation(.easeInOut(duration: 0.6).repeatForever(), value: isLoading)
                        
                        Circle()
                            .fill(Color.white)
                            .frame(width: 8, height: 8)
                            .scaleEffect(isLoading ? 1 : 0.5)
                            .animation(.easeInOut(duration: 0.6).repeatForever().delay(0.2), value: isLoading)
                        
                        Circle()
                            .fill(Color.white)
                            .frame(width: 8, height: 8)
                            .scaleEffect(isLoading ? 1 : 0.5)
                            .animation(.easeInOut(duration: 0.6).repeatForever().delay(0.4), value: isLoading)
                    }
                }
            }
            .frame(maxWidth: .infinity, minHeight: 52)
        }
        .background(Color.black)
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
