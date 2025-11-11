import SwiftUI

/// Header view for tasks section with AI task generation button
struct TasksHeader: View {
    @Binding var navigationPath: NavigationPath
    let selectedDate: Date
    let onAITaskTap: () -> Void
    @Binding var isAITaskLoading: Bool
    
    private var headerText: String {
        return "Modo's Tasks"
    }

    var body: some View {
        ZStack {
            // Center title
            Text(headerText)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(Color(hexString: "101828"))
            
            // Left and right buttons
            HStack {
                // AI Tasks button (left side with gradient)
                Button(action: {
                    onAITaskTap()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                        Text(isAITaskLoading ? "..." : "AI")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                    }
                    .frame(width: 60, height: 36)
                    .background(
                        LinearGradient(
                            colors: [Color(hexString: AppColors.primaryPurple), Color(hexString: AppColors.secondaryIndigo)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .shadow(color: Color(hexString: AppColors.primaryPurple).opacity(0.3), radius: 8, x: 0, y: 4)
                }
                .disabled(isAITaskLoading)
                
                Spacer()
                
                // Add Task button (right side, minimalist)
                Button(action: {
                    navigationPath.append(AddTaskDestination.addTask)
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                        Text("Add")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                    }
                    .frame(width: 70, height: 36)
                    .background(Color.black)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
            }
        }
        .frame(height: 60)
        .background(Color.white)
    }
}

