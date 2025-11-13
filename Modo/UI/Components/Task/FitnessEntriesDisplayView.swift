import SwiftUI

/// Display view for fitness entries (read-only)
struct FitnessEntriesDisplayView: View {
    let entries: [FitnessEntry]
    
    private var totalCalories: Int {
        entries.map { Int($0.caloriesText) ?? 0 }.reduce(0, +)
    }
    
    private func durationText(forMinutes minutes: Int) -> String {
        let total = max(0, minutes)
        let hours: Int = total / 60
        let mins: Int = total % 60
        if hours > 0 && mins > 0 {
            return "\(hours)h \(mins)m"
        } else if hours > 0 {
            return "\(hours)h"
        } else {
            return "\(mins)m"
        }
    }
    
    var body: some View {
        card {
            VStack(alignment: .leading, spacing: 16) {
                Text("Exercises")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)
                
                ForEach(entries, id: \.id) { entry in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(entry.exercise?.name ?? entry.customName)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.primary)
                        HStack(spacing: 12) {
                            Text(durationText(forMinutes: entry.minutesInt))
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                            Text("\(entry.caloriesText) cal")
                                .font(.system(size: 14))
                                .foregroundColor(.primary)
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
                    Text("-\(totalCalories) cal")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
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

