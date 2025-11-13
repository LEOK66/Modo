import SwiftUI

/// Display view for diet entries (read-only)
struct DietEntriesDisplayView: View {
    let entries: [DietEntry]
    
    private var totalCalories: Int {
        entries.map { Int($0.caloriesText) ?? 0 }.reduce(0, +)
    }
    
    var body: some View {
        card {
            VStack(alignment: .leading, spacing: 16) {
                Text("Food Items")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)
                
                ForEach(entries, id: \.id) { entry in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(entry.food?.name ?? entry.customName)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.primary)
                        HStack(spacing: 12) {
                            Text("\(entry.quantityText) \(entry.unit)")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                            Text("\(entry.caloriesText) cal")
                                .font(.system(size: 14))
                                .foregroundColor(Color(hexString: "16A34A"))
                        }
                    }
                    .padding(12)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                
                Divider()
                    .background(Color(UIColor.separator))
                
                HStack {
                    Text("Total Calories")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                    Spacer()
                    Text("\(totalCalories) cal")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color(hexString: "16A34A"))
                }
            }
        }
    }
    
    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            content()
                .padding(16)
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Color.primary.opacity(0.05), radius: 3, x: 0, y: 1)
        .shadow(color: Color.primary.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

