import SwiftUI

struct AddTaskView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var tasks: [MainPageView.TaskItem] // Binding to main page tasks
    var body: some View {
            ZStack(alignment: .top) {
                Color(hexString: "F9FAFB").ignoresSafeArea() // main background
                
                VStack(spacing: 0) {
                    // Header
                    PageHeader(title: "Add New Task")
                        .padding(.top, 12)
                        .padding(.horizontal, 24)
                    
                    Spacer().frame(height: 12)
                    
                    // Slight gray scrollable container
                    ScrollView {
                        // Place components to add task in here
                    }
                    .background(Color(hexString: "F3F4F6")) // container background
                    .cornerRadius(0) // optional if you want square edges
                    .padding(.top, 8)
                    
                    Spacer()
                    
                    bottomActionBar
                }
            }
            .navigationBarBackButtonHidden(true)
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
