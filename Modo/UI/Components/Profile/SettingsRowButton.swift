import SwiftUI

// MARK: - Settings Row Button Component
struct SettingsRowButton: View {
    let icon: String
    let title: String
    let subtitle: String
    let showDivider: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 0) {
                HStack(spacing: 16) {
                    // Icon
                    ZStack {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color(.secondarySystemBackground))
                            .frame(width: 40, height: 40)
                        
                        Image(systemName: icon)
                            .font(.system(size: 20))
                            .foregroundColor(.primary)
                    }
                    
                    // Text
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.primary)
                        
                        Text(subtitle)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // Chevron
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .padding(20)
                
                // Divider
                if showDivider {
                    Divider()
                        .padding(.leading, 76)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 0) {
        SettingsRowButton(
            icon: "globe",
            title: "Language",
            subtitle: "English",
            showDivider: true
        ) {
            print("Language tapped")
        }
        
        SettingsRowButton(
            icon: "ruler",
            title: "Units",
            subtitle: "Metric (kg, km, cal)",
            showDivider: false
        ) {
            print("Units tapped")
        }
    }
    .background(Color(.systemBackground))
    .cornerRadius(16)
    .shadow(color: Color.primary.opacity(0.05), radius: 4, x: 0, y: 2)
    .padding()
}

