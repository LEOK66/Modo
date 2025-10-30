import SwiftUI

// MARK: - Info Card Component
struct InfoCard: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(Color(hexString: "6A7282"))
                
                Text(title)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Color(hexString: "101828"))
            }
            
            Text(description)
                .font(.system(size: 14))
                .foregroundColor(Color(hexString: "6A7282"))
                .lineSpacing(6)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 1)
        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

// MARK: - Preview
#Preview {
    InfoCard(
        icon: "questionmark.circle",
        title: "How can we assist you?",
        description: "Thank you for reaching out! Our support team is dedicated to providing you with the best assistance. Whether you have questions about your account, need help with features, or want to share feedback, we're here to ensure you have a smooth experience with our app."
    )
    .padding()
    .background(Color(hexString: "F3F4F6"))
}

