import SwiftUI

// MARK: - Navigation Row Component (for Profile)
struct NavigationRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let destination: AnyView

    init(icon: String, title: String, subtitle: String, destination: AnyView) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.destination = destination
    }

    var body: some View {
        NavigationLink(destination: destination) {
            HStack(spacing: 16) {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(.secondarySystemBackground))
                    .frame(width: 44, height: 44)
                    .overlay(
                        Image(systemName: icon)
                            .foregroundColor(.primary)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .shadow(color: Color.primary.opacity(0.1), radius: 3, x: 0, y: 1)
                    .shadow(color: Color.primary.opacity(0.1), radius: 2, x: 0, y: 1)
            )
            .frame(width: 327)
        }
    }
}

// MARK: - Preview
#Preview {
    NavigationRow(
        icon: "gear",
        title: "Settings",
        subtitle: "Manage your preferences",
        destination: AnyView(Text("Settings View"))
    )
    .padding()
}

