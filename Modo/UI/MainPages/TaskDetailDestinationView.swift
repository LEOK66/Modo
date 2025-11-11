import SwiftUI

/// Helper view for task detail navigation
struct TaskDetailDestinationView: View {
    let destination: TaskDetailDestination
    let getTask: (UUID) -> TaskItem?
    let onUpdateTask: (TaskItem, TaskItem) -> Void
    
    var body: some View {
        Group {
            if let taskId = destination.taskId,
               let task = getTask(taskId) {
                DetailPageView(
                    taskId: taskId,
                    getTask: getTask,
                    onUpdateTask: onUpdateTask
                )
            } else {
                // Fallback view if task not found
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 48))
                        .foregroundColor(Color(hexString: "9CA3AF"))
                    Text("Task not found")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(Color(hexString: "6A7282"))
                    Text("The task may have been deleted")
                        .font(.system(size: 14))
                        .foregroundColor(Color(hexString: "9CA3AF"))
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(hexString: "F9FAFB"))
            }
        }
    }
}

