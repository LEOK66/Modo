import SwiftUI

/// Display view for task details (read-only)
struct TaskDetailDisplayView: View {
    let task: TaskItem
    
    var body: some View {
        VStack(spacing: 16) {
            // Task Title Card
            card {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(task.title)
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(Color(hexString: "101828"))
                            if !task.subtitle.isEmpty {
                                Text(task.subtitle)
                                    .font(.system(size: 16))
                                    .foregroundColor(Color(hexString: "6A7282"))
                            }
                        }
                        Spacer()
                    }
                    
                    HStack(spacing: 16) {
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.system(size: 14))
                            Text(task.time)
                                .font(.system(size: 14))
                        }
                        .foregroundColor(Color(hexString: "364153"))
                        if let endTime = task.endTime {
                            HStack(spacing: 4) {
                                Image(systemName: "timer")
                                    .font(.system(size: 14))
                                Text(endTime)
                                    .font(.system(size: 14))
                            }
                            .foregroundColor(Color(hexString: "364153"))
                        }
                        Spacer()
                        // Status badge
                        HStack(spacing: 4) {
                            Circle()
                                .fill(task.isDone ? Color(hexString: task.emphasisHex) : Color(hexString: "E5E7EB"))
                                .frame(width: 8, height: 8)
                            Text(task.isDone ? "Done" : "Pending")
                                .font(.system(size: 12))
                                .foregroundColor(Color(hexString: "6A7282"))
                        }
                    }
                }
            }
            
            // Diet entries
            if task.category == .diet && !task.dietEntries.isEmpty {
                DietEntriesDisplayView(entries: task.dietEntries)
            }
            
            // Fitness entries
            if task.category == .fitness && !task.fitnessEntries.isEmpty {
                FitnessEntriesDisplayView(entries: task.fitnessEntries)
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

