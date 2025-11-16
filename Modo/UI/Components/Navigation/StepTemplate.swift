import SwiftUI

struct StepTemplate<Content: View>: View {
    let title: String
    let subtitle: String
    let buttonTitle: String
    let buttonEnabled: Bool
    let onButtonTap: () -> Void
    let onSkip: () -> Void
    let onBack: (() -> Void)?
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // Title and subtitle
            VStack(spacing: 12) {
                Text(title)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                
                Text(subtitle)
                    .font(.system(size: 16))
                    .foregroundColor(Color(hexString: "6A7282"))
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 24)
            
            content
                .padding(.horizontal, 24)
                .padding(.top, 24)
            
            Spacer()
            
            VStack(spacing: 16) {
                if let onBack = onBack {
                    Button(action: onBack) {
                        Text("Back")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(Color(hexString: "6A7282"))
                            .underline()
                            .frame(maxWidth: .infinity)
                            .frame(height: 40)
                    }
                }
                Button(action: onButtonTap) {
                    Text(buttonTitle)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(buttonEnabled ? .white : Color(hexString: "6A7282"))
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(buttonEnabled ? Color.black : Color(hexString: "E5E7EB"))
                        )
                }
                .disabled(!buttonEnabled)
                
                Button(action: onSkip) {
                    Text("Skip")
                        .font(.system(size: 14))
                        .foregroundColor(Color(hexString: "6A7282"))
                        .underline()
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
    }
}

