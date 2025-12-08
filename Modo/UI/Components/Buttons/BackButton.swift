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

// MARK: - Preview
#Preview {
    BackButton {
        print("Back tapped")
    }
}

