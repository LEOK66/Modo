import SwiftUI

struct LogoutRow: View {
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.red.opacity(0.1))
                        .frame(width: 44, height: 44)
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.red)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Logout")
                        .font(.system(size: 16))
                        .foregroundColor(.red)
                    Text("Sign out of your account")
                        .font(.system(size: 12))
                        .foregroundColor(.red.opacity(0.8))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(.red.opacity(0.8))
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.red.opacity(0.2), lineWidth: 1)
                    )
                    .shadow(color: Color.primary.opacity(0.1), radius: 3, x: 0, y: 1)
                    .shadow(color: Color.primary.opacity(0.1), radius: 2, x: 0, y: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .frame(width: 327)
    }
}

