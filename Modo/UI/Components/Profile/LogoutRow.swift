import SwiftUI

struct LogoutRow: View {
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color(hexString: "FEF2F2"))
                        .frame(width: 44, height: 44)
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(Color(hexString: "E7000B"))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Logout")
                        .font(.system(size: 16))
                        .foregroundColor(Color(hexString: "E7000B"))
                    Text("Sign out of your account")
                        .font(.system(size: 12))
                        .foregroundColor(Color(hexString: "FF6467"))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(Color(hexString: "FF6467"))
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color(hexString: "FFE2E2"), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 1)
                    .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .frame(width: 327)
    }
}

