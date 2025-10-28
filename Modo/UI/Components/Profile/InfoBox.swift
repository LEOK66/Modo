import SwiftUI

// MARK: - Info Box Component
/// A simple informational box with centered text
struct InfoBox: View {
    let text: String
    
    var body: some View {
        Text(text)
            .font(.system(size: 14))
            .foregroundColor(Color(hexString: "6A7282"))
            .multilineTextAlignment(.center)
            .padding(16)
            .frame(maxWidth: .infinity)
            .background(Color.white)
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 1)
            .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

// MARK: - Preview
#Preview {
    InfoBox(text: "We typically respond within 24 hours on business days")
        .padding()
        .background(Color(hexString: "F3F4F6"))
}

