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
                    .foregroundColor(Color(hexString: "101828"))
                
                ForEach(entries, id: \.id) { entry in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(entry.exercise?.name ?? entry.customName)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Color(hexString: "101828"))
                        HStack(spacing: 12) {
                            Text(durationText(forMinutes: entry.minutesInt))
                                .font(.system(size: 14))
                                .foregroundColor(Color(hexString: "6A7282"))
                            Text("\(entry.caloriesText) cal")
                                .font(.system(size: 14))
                                .foregroundColor(Color(hexString: "364153"))
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
                    Text("-\(totalCalories) cal")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color(hexString: "364153"))
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

