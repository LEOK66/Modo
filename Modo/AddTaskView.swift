import SwiftUI

struct AddTaskView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var tasks: [MainPageView.TaskItem] // Binding to main page tasks

    var body: some View {
        ZStack(alignment: .top) {
            Color(hexString: "F9FAFB").ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                addTaskHeader
                    .padding(.top, 12)
                    .padding(.horizontal, 24)
                
                Spacer()
                
                bottomActionBar
            }
        }
        .navigationBarBackButtonHidden(true)
    }
}

// MARK: - Header
private extension AddTaskView {
    var addTaskHeader: some View {
        HStack {
            // Back button
            BackButton {
                dismiss()
            }
            
            Spacer()
            
            // Centered title
            Text("Add New Task")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(Color(hexString: "101828"))
            
            Spacer()
            
            // Empty space to balance back button
            Color.clear.frame(width: 36, height: 36)
        }
    }
}

// MARK: - Bottom Action Bar
private extension AddTaskView {
    var bottomActionBar: some View {
        VStack(spacing: 0) {
            Divider().background(Color(hexString: "E5E7EB"))
            
            HStack(spacing: 12) {
                Button(action: { dismiss() }) {
                    Text("Cancel")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color(hexString: "364153"))
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .background(Color(hexString: "F3F4F6"))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                
                Button(action: {
                    // Add empty task and dismiss
                    tasks.append(
                        MainPageView.TaskItem(
                            emoji: "📝",
                            title: "New Task",
                            subtitle: "",
                            time: "",
                            meta: "",
                            isDone: false,
                            emphasisHex: "16A34A"
                        )
                    )
                    dismiss()
                }) {
                    Text("Save Task")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .background(Color.black)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(Color.white)
        }
    }
}

// MARK: - Preview
#Preview {
    StatefulPreviewWrapper([MainPageView.TaskItem]()) { tasks in
        NavigationStack {
            AddTaskView(tasks: tasks)
        }
    }
}
