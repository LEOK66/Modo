import SwiftUI

/// Task list view component that displays tasks for a selected date
/// Handles task display, animations, and user interactions
struct TaskListView: View {
    let tasks: [TaskItem]
    let selectedDate: Date
    @Binding var navigationPath: NavigationPath
    @Binding var newlyAddedTaskId: UUID?
    @Binding var replacingAITaskIds: Set<UUID>
    @Binding var isShowingChallengeDetail: Bool
    let onDeleteTask: (TaskItem) -> Void
    let onUpdateTask: (TaskItem) -> Void
    @State private var deletingTaskIds: Set<UUID> = []
    
    // MARK: - Animation Constants
    private enum AnimationTiming {
        static let scrollDelay: TimeInterval = 0.5
        static let highlightDuration: TimeInterval = 1.5
        static let deleteAnimationDuration: TimeInterval = 0.25
        static let fadeOutDuration: TimeInterval = 0.3
        static let springResponse: Double = 0.5
        static let springDamping: Double = 0.75
    }
    
    // MARK: - Screen Width
    private var screenWidth: CGFloat {
        #if canImport(UIKit)
        return UIScreen.main.bounds.width
        #else
        return 400 // Fallback for other platforms
        #endif
    }
    
    // Check if selected date is in the future
    private var isFutureDate: Bool {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let selected = calendar.startOfDay(for: selectedDate)
        return selected > today
    }

    var body: some View {
        Group {
            if tasks.isEmpty {
                ScrollView {
                    EmptyTasksView()
                }
            } else {
                ScrollViewReader { proxy in
                    List {
                        ForEach(tasks, id: \.id) { task in
                            taskRowView(for: task, proxy: proxy)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .onChange(of: newlyAddedTaskId) { oldId, newId in
                        handleNewTaskAdded(oldId: oldId, newId: newId, proxy: proxy)
                    }
                }
            }
        }
    }
    
    // MARK: - Task Row View
    @ViewBuilder
    private func taskRowView(for task: TaskItem, proxy: ScrollViewProxy) -> some View {
        let isNewlyAdded = newlyAddedTaskId == task.id
        let isDeleting = deletingTaskIds.contains(task.id)
        let isReplacing = replacingAITaskIds.contains(task.id)
        
        TaskRowCard(
            title: task.title,
            subtitle: task.subtitle,
            time: task.time,
            endTime: task.endTime,
            meta: task.meta,
            isDone: Binding(
                get: { task.isDone },
                set: { newValue in
                    guard !isFutureDate else { return }
                    onUpdateTask(task.with(isDone: newValue))
                }
            ),
            emphasis: Color(hexString: task.emphasisHex),
            category: task.category,
            isAIGenerated: task.isAIGenerated,
            isDailyChallenge: task.isDailyChallenge,
            isFutureDate: isFutureDate
        )
        .id(task.id)
        .modifier(TaskRowAnimationModifier(
            isNewlyAdded: isNewlyAdded,
            isDeleting: isDeleting,
            isReplacing: isReplacing,
            emphasisColor: Color(hexString: task.emphasisHex),
            screenWidth: screenWidth
        ))
        .listRowInsets(EdgeInsets(top: 0, leading: 24, bottom: 12, trailing: 24))
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                deleteTask(task)
            } label: {
                Label("Delete", systemImage: "trash.fill")
            }
            
            Button {
                if task.isDailyChallenge {
                    isShowingChallengeDetail = true
                } else {
                    navigateToTaskDetail(taskId: task.id)
                }
            } label: {
                Label("Detail", systemImage: "info.circle.fill")
            }
            .tint(Color.gray)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            handleTaskTap(task)
        }
    }
    
    // MARK: - Animation Handling
    private func handleNewTaskAdded(oldId: UUID?, newId: UUID?, proxy: ScrollViewProxy) {
        guard let taskId = newId, newId != oldId else { return }
        
        // Scroll to new task after a short delay
        Task {
            try? await Task.sleep(nanoseconds: UInt64(AnimationTiming.scrollDelay * 1_000_000_000))
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.6)) {
                    proxy.scrollTo(taskId, anchor: .center)
                }
            }
            
            // Clear highlight after total duration
            try? await Task.sleep(nanoseconds: UInt64((AnimationTiming.highlightDuration - AnimationTiming.scrollDelay) * 1_000_000_000))
            await MainActor.run {
                withAnimation(.easeOut(duration: AnimationTiming.fadeOutDuration)) {
                    newlyAddedTaskId = nil
                }
            }
        }
    }
    
    // MARK: - Navigation
    private func navigateToTaskDetail(taskId: UUID) {
        navigationPath.append(TaskDetailDestination.detail(taskId: taskId))
    }
    
    private func handleTaskTap(_ task: TaskItem) {
        if task.isDailyChallenge {
            isShowingChallengeDetail = true
        } else {
            navigateToTaskDetail(taskId: task.id)
        }
    }
    
    // MARK: - Task Actions
    private func deleteTask(_ task: TaskItem) {
        triggerDeleteHaptic()
        deletingTaskIds.insert(task.id)
        
        Task {
            try? await Task.sleep(nanoseconds: UInt64(AnimationTiming.deleteAnimationDuration * 1_000_000_000))
            await MainActor.run {
                onDeleteTask(task)
                deletingTaskIds.remove(task.id)
            }
        }
    }
    
    private func triggerDeleteHaptic() {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        #endif
    }
}

// MARK: - Task Row Animation Modifier
private struct TaskRowAnimationModifier: ViewModifier {
    let isNewlyAdded: Bool
    let isDeleting: Bool
    let isReplacing: Bool
    let emphasisColor: Color
    let screenWidth: CGFloat
    
    private var opacity: Double {
        if isDeleting || isReplacing { return 0 }
        if isNewlyAdded { return 0 }
        return 1
    }
    
    private var scale: CGFloat {
        if isReplacing { return 0.8 }
        if isNewlyAdded { return 0.9 }
        return 1.0
    }
    
    private var xOffset: CGFloat {
        isDeleting ? screenWidth : 0
    }
    
    private var yOffset: CGFloat {
        isNewlyAdded ? 30 : 0
    }
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isNewlyAdded ? 1.05 : 1.0)
            .shadow(
                color: isNewlyAdded ? emphasisColor.opacity(0.3) : Color.clear,
                radius: isNewlyAdded ? 12 : 0
            )
            .offset(x: xOffset, y: yOffset)
            .opacity(opacity)
            .scaleEffect(scale)
            .animation(.spring(response: 0.5, dampingFraction: 0.75), value: isNewlyAdded)
            .animation(.easeInOut(duration: 0.4), value: isReplacing)
    }
}

