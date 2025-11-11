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
                    .foregroundColor(Color(hexString: "101828"))
                
                ForEach(entries, id: \.id) { entry in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(entry.food?.name ?? entry.customName)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Color(hexString: "101828"))
                        HStack(spacing: 12) {
                            Text("\(entry.quantityText) \(entry.unit)")
                                .font(.system(size: 14))
                                .foregroundColor(Color(hexString: "6A7282"))
                            Text("\(entry.caloriesText) cal")
                                .font(.system(size: 14))
                                .foregroundColor(Color(hexString: "16A34A"))
                        }
                    }
                    .padding(12)
                    .background(Color(hexString: "F9FAFB"))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                
                Divider()
                
                HStack {
                    Text("Total Calories")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color(hexString: "0A0A0A"))
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
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 1)
        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

