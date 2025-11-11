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
    @State private var animatingInTaskIds: Set<UUID> = []
    
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
                GeometryReader { geometry in
                    ScrollViewReader { proxy in
                        List {
                            ForEach(tasks, id: \.id) { task in
                                let isNewlyAdded = newlyAddedTaskId == task.id
                                let isAnimatingIn = animatingInTaskIds.contains(task.id)
                                
                                TaskRowCard(
                                    title: task.title,
                                    subtitle: task.subtitle,
                                    time: task.time,
                                    endTime: task.endTime,
                                    meta: task.meta,
                                    isDone: Binding(
                                        get: { task.isDone },
                                        set: { newValue in
                                            // Disable check for future dates
                                            guard !isFutureDate else { return }
                                            
                                            // Create a new TaskItem with updated isDone
                                            let updatedTask = TaskItem(
                                                id: task.id,
                                                title: task.title,
                                                subtitle: task.subtitle,
                                                time: task.time,
                                                timeDate: task.timeDate,
                                                endTime: task.endTime,
                                                meta: task.meta,
                                                isDone: newValue,
                                                emphasisHex: task.emphasisHex,
                                                category: task.category,
                                                dietEntries: task.dietEntries,
                                                fitnessEntries: task.fitnessEntries,
                                                isAIGenerated: task.isAIGenerated,
                                                isDailyChallenge: task.isDailyChallenge
                                            )
                                            onUpdateTask(updatedTask)
                                        }
                                    ),
                                    emphasis: Color(hexString: task.emphasisHex),
                                    category: task.category,
                                    isAIGenerated: task.isAIGenerated,
                                    isDailyChallenge: task.isDailyChallenge,
                                    isFutureDate: isFutureDate
                                )
                                .scaleEffect(isNewlyAdded ? 1.05 : 1.0)
                                .shadow(
                                    color: isNewlyAdded ? Color(hexString: task.emphasisHex).opacity(0.3) : Color.clear,
                                    radius: isNewlyAdded ? 12 : 0,
                                    x: 0,
                                    y: 0
                                )
                                .id(task.id)
                                .offset(x: deletingTaskIds.contains(task.id) ? geometry.size.width : 0)
                                .offset(y: isAnimatingIn ? 0 : (isNewlyAdded ? 30 : 0))
                                .opacity(deletingTaskIds.contains(task.id) ? 0 : (replacingAITaskIds.contains(task.id) ? 0 : (isAnimatingIn ? 1 : (isNewlyAdded ? 0 : 1))))
                                .scaleEffect(replacingAITaskIds.contains(task.id) ? 0.8 : (isAnimatingIn ? 1.0 : (isNewlyAdded ? 0.9 : 1.0)))
                                .animation(.spring(response: 0.5, dampingFraction: 0.75), value: isNewlyAdded)
                                .animation(.easeInOut(duration: 0.4), value: replacingAITaskIds.contains(task.id))
                                .onAppear {
                                    if isNewlyAdded && !isAnimatingIn {
                                        // Start animation in
                                        animatingInTaskIds.insert(task.id)
                                        // Animate in with fade and slide up
                                        withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
                                            // Animation triggered by state change
                                        }
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                            if newlyAddedTaskId == task.id {
                                                withAnimation(.easeOut(duration: 0.3)) {
                                                    newlyAddedTaskId = nil
                                                }
                                            }
                                            animatingInTaskIds.remove(task.id)
                                        }
                                    }
                                }
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
                                        navigationPath.append(TaskDetailDestination.detail(taskId: task.id))
                                    } label: {
                                        Label("Detail", systemImage: "info.circle.fill")
                                    }
                                    .tint(Color.gray)
                                }
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    if task.isDailyChallenge {
                                        isShowingChallengeDetail = true
                                    } else {
                                        navigationPath.append(TaskDetailDestination.detail(taskId: task.id))
                                    }
                                }
                            }
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                        // FIX #1 & #2: Better handling of new task animation
                        .onChange(of: newlyAddedTaskId) { oldId, newId in
                            // Only proceed if we have a new task (not clearing)
                            guard let taskId = newId, newId != oldId else { return }
                            
                            // FIX #2: Longer delay to ensure view hierarchy is ready
                            // This gives the navigation transition time to complete
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                withAnimation(.easeInOut(duration: 0.6)) {
                                    proxy.scrollTo(taskId, anchor: .center)
                                }
                            }
                            
                            // FIX #1: Always clear the highlight after 1.5 seconds
                            // Independent of other state changes
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                withAnimation(.easeOut(duration: 0.3)) {
                                    newlyAddedTaskId = nil
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func deleteTask(_ task: TaskItem) {
        triggerDeleteHaptic()
        
        // Add to deleting set for animation
        deletingTaskIds.insert(task.id)
        
        // Remove after animation completes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            onDeleteTask(task)
            deletingTaskIds.remove(task.id)
        }
    }
    
    private func triggerDeleteHaptic() {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        #endif
    }
}

