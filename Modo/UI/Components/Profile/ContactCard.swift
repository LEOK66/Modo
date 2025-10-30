import SwiftUI

// MARK: - Contact Card Component
struct ContactCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color(hexString: "F3F4F6"))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: icon)
                        .font(.system(size: 20))
                        .foregroundColor(Color(hexString: "364153"))
                }
                
                // Text content
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color(hexString: "101828"))
                    
                    Text(subtitle)
                        .font(.system(size: 14))
                        .foregroundColor(Color(hexString: "6A7282"))
                }
                
                Spacer()
                
                // Chevron
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(Color(hexString: "99A1AF"))
            }
            .padding(20)
            .frame(maxWidth: .infinity)
            .background(Color.white)
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 1)
            .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 16) {
        ContactCard(
            icon: "envelope.fill",
            title: "Email Support",
            subtitle: "support@example.com"
        ) {
            print("Email tapped")
        }
        
        ContactCard(
            icon: "message.fill",
            title: "Live Chat",
            subtitle: "Available 9am - 5pm EST"
        ) {
            print("Chat tapped")
        }
    }
    .padding()
    .background(Color(hexString: "F3F4F6"))
}

