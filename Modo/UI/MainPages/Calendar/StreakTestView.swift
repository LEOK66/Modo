import SwiftUI
import SwiftData
import FirebaseAuth

/// Test view for quickly testing streak functionality
/// Only available in debug mode
struct StreakTestView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var selectedFlame: FlameLevel? = nil
    @State private var showSuccessAlert = false
    @State private var successMessage = ""
    
    private var userId: String? {
        Auth.auth().currentUser?.uid ?? "test_user"
    }
    
    // Flame levels with corresponding streak days
    private enum FlameLevel: String, CaseIterable {
        case noFlame = "No Flame"
        case smallFlame = "Small Flame"
        case mediumFlame = "Medium Flame"
        case largeFlame = "Large Flame"
        
        var days: Int {
            switch self {
            case .noFlame: return 0
            case .smallFlame: return 3
            case .mediumFlame: return 7
            case .largeFlame: return 30
            }
        }
        
        var color: Color {
            switch self {
            case .noFlame: return .secondary
            case .smallFlame: return Color(red: 1.0, green: 0.7, blue: 0.2)
            case .mediumFlame: return Color(red: 1.0, green: 0.6, blue: 0.0)
            case .largeFlame: return Color(red: 1.0, green: 0.4, blue: 0.0)
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Instructions
                Text("Select a flame level to preview the color states.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.top)
                
                // Flame buttons
                VStack(spacing: 16) {
                    ForEach(FlameLevel.allCases, id: \.self) { flame in
                        Button(action: {
                            createStreak(days: flame.days)
                            selectedFlame = flame
                        }) {
                            HStack {
                                Image(systemName: "flame.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(flame.color)
                                
                                Text(flame.rawValue)
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                if selectedFlame == flame {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.blue)
                                }
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(
                                selectedFlame == flame
                                ? Color.blue.opacity(0.1)
                                : Color(.secondarySystemBackground)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }
                .padding(.horizontal)
                
                Spacer()
                
                // Clear button
                Button(action: {
                    clearStreak()
                }) {
                    Text("Clear")
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
            .navigationTitle("Test Streak")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Success", isPresented: $showSuccessAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(successMessage)
            }
        }
    }
    
    private func createStreak(days: Int) {
        guard let userId = userId else {
            successMessage = "Error: No user ID"
            showSuccessAlert = true
            return
        }
        
        if days == 0 {
            clearStreak()
            return
        }
        
        print("🧪 StreakTestView: Creating streak of \(days) days for userId: \(userId)")
        
        StreakTestHelper.createTestStreak(
            streakDays: days,
            includeToday: true,
            userId: userId,
            modelContext: modelContext
        )
        
        successMessage = "✅ Created \(days) days streak!\n\nOpen the calendar popup to see the effect."
        showSuccessAlert = true
    }
    
    private func clearStreak() {
        guard let userId = userId else { return }
        
        StreakTestHelper.clearTestStreak(
            userId: userId,
            modelContext: modelContext
        )
        
        selectedFlame = nil
        successMessage = "Cleared all test streak data."
        showSuccessAlert = true
    }
}

// MARK: - Preview
#Preview {
    StreakTestView()
        .modelContainer(for: DailyCompletion.self, inMemory: true)
}

