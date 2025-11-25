import SwiftUI
import SwiftData
import FirebaseAuth

/// Test view for quickly testing goal functionality
/// Only available in debug mode
struct GoalTestView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var showSuccessAlert = false
    @State private var successMessage = ""
    @State private var goalStatus: (goalStartDate: Date?, targetDays: Int?, completedDays: Int, isExpired: Bool) = (nil, nil, 0, false)
    
    private var userId: String? {
        Auth.auth().currentUser?.uid ?? "test_user"
    }
    
    private enum GoalScenario: CaseIterable {
        case completed
        case expired
        
        var title: String {
            switch self {
            case .completed:
                return "Completed Goal"
            case .expired:
                return "Expired Goal"
            }
        }
        
        var description: String {
            switch self {
            case .completed:
                return "Creates a new goal with every day finished."
            case .expired:
                return "Creates a goal that ended in the past and is expired."
            }
        }
        
        var configuration: (targetDays: Int, completedDays: Int, startDate: Date?) {
            switch self {
            case .completed:
                // Start today, finish everything
                return (targetDays: 14, completedDays: 14, startDate: nil)
            case .expired:
                // Start 20 days ago with a 7-day target so it is expired
                let calendar = Calendar.current
                let startDate = calendar.date(byAdding: .day, value: -20, to: Date())
                return (targetDays: 7, completedDays: 3, startDate: startDate)
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Toggle preset goal states to preview progress visuals.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                .padding(.top)
                
                CurrentGoalStatusView(goalStatus: goalStatus)
                    .padding(.horizontal)
                
                VStack(spacing: 16) {
                    ForEach(GoalScenario.allCases, id: \.self) { scenario in
                        Button {
                            applyScenario(scenario)
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(scenario.title)
                                    .font(.system(size: 18, weight: .medium))
                                Text(scenario.description)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }
                .padding(.horizontal)
                
                Spacer()
                
                Button(action: {
                    clearTestGoal()
                }) {
                    Text("Clear Goal Data")
                        .font(.system(size: 16, weight: .medium))
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.red.opacity(0.1))
                        .foregroundColor(.red)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
            .navigationTitle("Test Goal")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Success", isPresented: $showSuccessAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(successMessage)
            }
            .onAppear {
                refreshGoalStatus()
            }
        }
    }
    
    private func applyScenario(_ scenario: GoalScenario) {
        guard let userId = userId else {
            successMessage = "Error: No user ID"
            showSuccessAlert = true
            return
        }
        
        let config = scenario.configuration
        print("🧪 GoalTestView: Applying scenario \(scenario.title) - targetDays: \(config.targetDays), completedDays: \(config.completedDays)")
        
        GoalTestHelper.createTestGoal(
            targetDays: config.targetDays,
            completedDays: config.completedDays,
            startDate: config.startDate,
            userId: userId,
            modelContext: modelContext
        )
        
        // Refresh status after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            refreshGoalStatus()
            successMessage = "✅ \(scenario.title) applied. Check the Progress page to see the effect."
            showSuccessAlert = true
        }
    }
    
    private func clearTestGoal() {
        guard let userId = userId else { return }
        
        GoalTestHelper.clearTestGoal(
            userId: userId,
            modelContext: modelContext
        )
        
        refreshGoalStatus()
        successMessage = "Cleared all test goal data."
        showSuccessAlert = true
    }
    
    private func refreshGoalStatus() {
        guard let userId = userId else { return }
        goalStatus = GoalTestHelper.getGoalStatus(
            userId: userId,
            modelContext: modelContext
        )
    }
}

private struct CurrentGoalStatusView: View {
    let goalStatus: (goalStartDate: Date?, targetDays: Int?, completedDays: Int, isExpired: Bool)
    
    var body: some View {
        VStack(spacing: 12) {
            Text("Current Goal Status")
                .font(.headline)
                .foregroundColor(.secondary)
            
            if let startDate = goalStatus.goalStartDate, let target = goalStatus.targetDays {
                infoRow(label: "Start Date", value: formatted(startDate))
                infoRow(label: "Target Days", value: "\(target)")
                infoRow(label: "Completed Days", value: "\(goalStatus.completedDays)/\(target)")
                infoRow(label: "Status", value: goalStatus.isExpired ? "Expired" : "Active", valueColor: goalStatus.isExpired ? .red : .green)
            } else {
                Text("No goal set")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private func infoRow(label: String, value: String, valueColor: Color = .primary) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .foregroundColor(valueColor)
        }
    }
    
    private func formatted(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }
}

// MARK: - Preview
#Preview {
    GoalTestView()
        .modelContainer(for: [UserProfile.self, DailyCompletion.self], inMemory: true)
}

