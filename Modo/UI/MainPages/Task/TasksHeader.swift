import SwiftUI

/// Header view for tasks section with AI task generation button
struct TasksHeader: View {
    let onAITaskTap: () -> Void
    let onAddTaskTap: () -> Void
    @Binding var isAITaskLoading: Bool
    
    private var headerText: String {
        return "Modor's Tasks"
    }

    var body: some View {
        ZStack {
            // Center title
            Text(headerText)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.primary)
            
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
                        if isAITaskLoading {
                            LoadingDotsView(
                                dotSize: 4,
                                dotColor: .white,
                                spacing: 3,
                                isAnimating: isAITaskLoading
                            )
                        } else {
                            Text("AI")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                        }
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
                Button(action: {
                    onAddTaskTap()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color(.systemBackground))
                        Text("Add")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color(.systemBackground))
                            .lineLimit(1)
                    }
                    .frame(width: 70, height: 36)
                    .background(Color.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
            }
        }
        .frame(height: 60)
        .background(Color(.systemBackground))
    }
}

