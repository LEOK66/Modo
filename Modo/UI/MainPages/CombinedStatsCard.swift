import SwiftUI

/// Combined statistics card showing task completion and category counts
struct CombinedStatsCard: View {
    let tasks: [TaskItem]
    
    private var completedCount: Int {
        tasks.filter { $0.isDone }.count
    }
    
    private var totalCount: Int {
        tasks.count
    }
    
    private var dietCount: Int {
        tasks.filter { $0.category == .diet && !$0.isDone }.count
    }
    
    private var fitnessCount: Int {
        tasks.filter { $0.category == .fitness && !$0.isDone }.count
    }
    
    private var totalCalories: Int {
        tasks.filter { $0.isDone }.reduce(0) { total, task in
            total + task.totalCalories
        }
    }
    
    var body: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Color.white)
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color(hexString: "E5E7EB"), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.04), radius: 2, x: 0, y: 1)
            .overlay(
                HStack(spacing: 0) {
                    StatItem(value: "\(completedCount)/\(totalCount)", label: "Completed", tint: Color(hexString: "101828"))
                    StatItem(value: "\(dietCount)", label: "Diet", tint: Color(hexString: "00A63E"))
                    StatItem(value: "\(fitnessCount)", label: "Fitness", tint: Color(hexString: "155DFC"))
                    StatItem(value: "\(totalCalories)", label: "Calories", tint: Color(hexString: "4ECDC4"))
                }
                .frame(maxWidth: .infinity)
                .padding(12)
            )
            .frame(width: 327, height: 92)
    }

    // Formats the Text for statistics
    private struct StatItem: View {
        let value: String
        let label: String
        let tint: Color

        var body: some View {
            VStack(spacing: 4) {
                Text(value)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(tint)
                    .contentTransition(.numericText())
                Text(label)
                    .font(.system(size: 12))
                    .foregroundColor(Color(hexString: "6A7282"))
            }
            .frame(maxWidth: .infinity)
        }
    }
}

