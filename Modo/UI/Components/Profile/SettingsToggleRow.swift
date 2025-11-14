import SwiftUI

// MARK: - Settings Toggle Row Component
struct SettingsToggleRow: View {
    let icon: String
    let title: String
    let subtitle: String
    @Binding var isOn: Bool
    
    var body: some View {
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
            
            // Toggle
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(SwitchToggleStyle(tint: Color(hexString: "7C3AED")))
        }
        .padding(20)
    }
}

// MARK: - Preview
#Preview {
    @Previewable @State var isEnabled = true
    
    SettingsToggleRow(
        icon: "bell",
        title: "Notifications",
        subtitle: "Push alerts & reminders",
        isOn: $isEnabled
    )
    .background(Color(.systemBackground))
    .cornerRadius(16)
    .shadow(color: Color.primary.opacity(0.05), radius: 4, x: 0, y: 2)
    .padding()
}

