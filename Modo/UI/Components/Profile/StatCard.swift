import SwiftUI

// MARK: - Stat Card Component (for Profile)
struct StatCard: View {
    let title: String
    let value: String
    let emoji: String

    var body: some View {
        VStack(spacing: 8) {
            Text(value)
                .font(.system(size: 24))
                .foregroundColor(Color(hexString: "0A0A0A"))
            Text(title)
                .font(.system(size: 12))
                .foregroundColor(Color(hexString: "4A5565"))
            Text(emoji)
                .font(.system(size: 18))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 1)
                .shadow(color: Color.black.opacity(0.1), radius: 6, x: 0, y: 4)
        )
    }
}

// MARK: - Preview
#Preview {
    HStack {
        StatCard(title: "Tasks", value: "42", emoji: "✓")
        StatCard(title: "Streak", value: "7", emoji: "🔥")
    }
    .padding()
}

