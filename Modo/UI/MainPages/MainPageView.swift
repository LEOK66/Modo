import SwiftUI

struct MainPageView: View {
    @Binding var selectedTab: Tab
    @State private var isShowingCalendar = false
    @State private var navigationPath = NavigationPath()
    
    // Can refactor this to different file to reuse struct
    struct TaskItem: Identifiable {
        let id: UUID
        let title: String
        let subtitle: String
        let time: String
        let timeDate: Date // For sorting tasks by time
        let endTime: String? // For fitness tasks with duration
        let meta: String
        var isDone: Bool
        let emphasisHex: String
        let category: AddTaskView.Category // diet, fitness, others
        var dietEntries: [AddTaskView.DietEntry]
        var fitnessEntries: [AddTaskView.FitnessEntry]
        
        init(id: UUID = UUID(), title: String, subtitle: String, time: String, timeDate: Date, endTime: String? = nil, meta: String, isDone: Bool = false, emphasisHex: String, category: AddTaskView.Category, dietEntries: [AddTaskView.DietEntry], fitnessEntries: [AddTaskView.FitnessEntry]) {
            self.id = id
            self.title = title
            self.subtitle = subtitle
            self.time = time
            self.timeDate = timeDate
            self.endTime = endTime
            self.meta = meta
            self.isDone = isDone
            self.emphasisHex = emphasisHex
            self.category = category
            self.dietEntries = dietEntries
            self.fitnessEntries = fitnessEntries
        }
        
        // Calculate total calories for this task
        // Diet tasks add calories, fitness tasks subtract calories, others don't affect calories
        var totalCalories: Int {
            switch category {
            case .diet:
                return dietEntries.map { Int($0.caloriesText) ?? 0 }.reduce(0, +)
            case .fitness:
                return -fitnessEntries.map { Int($0.caloriesText) ?? 0 }.reduce(0, +)
            case .others:
                return 0
            }
        }
    }
    
    // Empty tasks for first-time users
    @State private var tasks: [TaskItem] = []
    
    // Computed property to return tasks sorted by time
    private var sortedTasks: [TaskItem] {
        tasks.sorted { $0.timeDate < $1.timeDate }
    }
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                Color.white.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    TopHeaderView(isShowingCalendar: $isShowingCalendar)
                        .padding(.horizontal, 24)
                        .padding(.top, 12)
                    
                    VStack(spacing: 16) {
                        CombinedStatsCard(tasks: sortedTasks)
                            .padding(.horizontal, 24)
                        
                        TasksHeader(navigationPath: $navigationPath)
                            .padding(.horizontal, 24)
                        
                        TaskListView(tasks: $tasks, navigationPath: $navigationPath)
                    }
                    .padding(.top, 12)
                    
                    // MARK: - Bottom Bar with navigation
                    BottomBar(selectedTab: $selectedTab)
                        .background(Color.white)
                }
                
                if isShowingCalendar {
                    // Dimming background that dismisses on tap
                    Color.black.opacity(0.25)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.easeInOut) { isShowingCalendar = false }
                        }
                    // Popup content centered
                    CalendarPopupView(showCalendar: $isShowingCalendar)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .navigationDestination(for: AddTaskDestination.self) { _ in
                AddTaskView(tasks: $tasks)
            }
            .navigationDestination(for: TaskDetailDestination.self) { destination in
                TaskDetailDestinationView(destination: destination, tasks: $tasks)
            }
        }
    }
}

// MARK: - Navigation Destination Type
private enum AddTaskDestination: Hashable {
    case addTask
}

private enum TaskDetailDestination: Hashable {
    case detail(taskId: UUID)
    
    var taskId: UUID? {
        if case .detail(let id) = self { return id }
        return nil
    }
}

private struct TopHeaderView: View {
    @Binding var isShowingCalendar: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            NavigationLink(destination: ProfilePageView()) {
                ZStack {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 40, height: 40)
                        .overlay(
                            Circle().stroke(Color(hexString: "E5E7EB"), lineWidth: 1)
                        )
                    Text("A")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color(hexString: "101828"))
                }
            }
            .buttonStyle(PlainButtonStyle())

            Spacer()

            // Centered date look
            Text(Self.formattedDate)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(Color(hexString: "101828"))

            Spacer()

            // Calendar
            Button {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                    isShowingCalendar = true
                }
            } label: {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.black)
                    .frame(width: 40, height: 40)
                    .overlay(
                        CalendarIcon(strokeColor: .white, size: 20)
                    )
            }
        }
    }

    private static var formattedDate: String {
        let df = DateFormatter()
        df.setLocalizedDateFormatFromTemplate("MMMM d")
        return df.string(from: Date())
    }
}

// Displays Completed Diet and Fitness Tasks (Should factor out to Components.swift)
private struct CombinedStatsCard: View {
    let tasks: [MainPageView.TaskItem]
    
    private var completedCount: Int {
        tasks.filter { $0.isDone }.count
    }
    
    private var totalCount: Int {
        tasks.count
    }
    
    private var dietCount: Int {
        tasks.filter { $0.category == .diet && !$0.isDone }.count
    }
    
    private var fitnessCount: Int {
        tasks.filter { $0.category == .fitness && !$0.isDone }.count
    }
    
    private var totalCalories: Int {
        tasks.filter { $0.isDone }.reduce(0) { total, task in
            total + task.totalCalories
        }
    }
    
    var body: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Color.white)
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color(hexString: "E5E7EB"), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.04), radius: 2, x: 0, y: 1)
            .overlay(
                HStack(spacing: 0) {
                    StatItem(value: "\(completedCount)/\(totalCount)", label: "Completed", tint: Color(hexString: "101828"))
                    StatItem(value: "\(dietCount)", label: "Diet", tint: Color(hexString: "00A63E"))
                    StatItem(value: "\(fitnessCount)", label: "Fitness", tint: Color(hexString: "155DFC"))
                    StatItem(value: "\(totalCalories)", label: "Calories", tint: Color(hexString: "4ECDC4"))
                }
                .frame(maxWidth: .infinity)
                .padding(12)
            )
            .frame(width: 327, height: 92)
    }


   // Formats the Text for statistics
    private struct StatItem: View {
        let value: String
        let label: String
        let tint: Color

        var body: some View {
            VStack(spacing: 4) {
                Text(value)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(tint)
                Text(label)
                    .font(.system(size: 12))
                    .foregroundColor(Color(hexString: "6A7282"))
            }
            .frame(maxWidth: .infinity)
        }
    }
}

private struct TasksHeader: View {
    @Binding var navigationPath: NavigationPath

    var body: some View {
        HStack {
            Text("Today's Tasks")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(Color(hexString: "101828"))
            Spacer()
            HStack(spacing: 8) {
                // AI Tasks button (purple)
                Button(action: {
                    print("AI Task here!")
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 16, height: 16)
                        Text("AI Tasks")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white)
                            .lineLimit(1)
                    }
                    .frame(width: 96, height: 36)
                    .background(Color(hexString: "9810FA"))
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }

                // Add Task button (black)
                Button(action: {
                    navigationPath.append(AddTaskDestination.addTask)
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                            .foregroundColor(.white)
                        Text("Add Task")
                            .foregroundColor(.white)
                            .lineLimit(1)
                    }
                    .font(.system(size: 14, weight: .medium))
                    .frame(width: 108, height: 36)
                    .background(Color.black)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
            }
        }
        .frame(height: 60)
        .background(Color.white)
    }
}

private struct TaskRowCard: View {
    let title: String
    let subtitle: String
    let time: String
    let endTime: String?
    let meta: String
    @Binding var isDone: Bool
    let emphasis: Color
    let category: AddTaskView.Category
    @State private var checkboxScale: CGFloat = 1.0
    @State private var strikethroughProgress: CGFloat = 0.0

    init(title: String, subtitle: String, time: String, endTime: String?, meta: String, isDone: Binding<Bool>, emphasis: Color, category: AddTaskView.Category) {
        self.title = title
        self.subtitle = subtitle
        self.time = time
        self.endTime = endTime
        self.meta = meta
        self._isDone = isDone
        self.emphasis = emphasis
        self.category = category
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Checkbox button
            Button {
                let willBeDone = !isDone
                
                withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                    isDone.toggle()
                    triggerCompletionHaptic()
                }
                // Checkbox bounce animation
                withAnimation(.easeOut(duration: 0.15)) {
                    checkboxScale = 1.3
                }
                withAnimation(.easeIn(duration: 0.15).delay(0.15)) {
                    checkboxScale = 1.0
                }
                // Strikethrough animation
                if willBeDone {
                    withAnimation(.easeInOut(duration: 0.4).delay(0.1)) {
                        strikethroughProgress = 1.0
                    }
                } else {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        strikethroughProgress = 0.0
                    }
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(isDone ? emphasis : Color.white)
                        .frame(width: 22, height: 22)
                        .overlay(
                            Circle().stroke(Color(hexString: "E5E7EB"), lineWidth: isDone ? 0 : 1)
                        )
                        .scaleEffect(checkboxScale)
                    if isDone {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .scaleEffect(checkboxScale)
                    }
                }
            }
            .buttonStyle(.plain)
            
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Text(title)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(isDone ? emphasis : Color(hexString: "101828"))
                            
                            // Animated strikethrough line
                            if strikethroughProgress > 0 {
                                Path { path in
                                    let y = geometry.size.height / 2
                                    let startX: CGFloat = 0
                                    let endX = geometry.size.width * strikethroughProgress
                                    path.move(to: CGPoint(x: startX, y: y))
                                    path.addLine(to: CGPoint(x: endX, y: y))
                                }
                                .stroke(
                                    emphasis,
                                    style: StrokeStyle(
                                        lineWidth: 2,
                                        lineCap: .round
                                    )
                                )
                                .animation(.none, value: strikethroughProgress)
                            }
                        }
                    }
                    .frame(height: 20) // Fixed height for GeometryReader
                }
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 14))
                        .foregroundColor(Color(hexString: "6A7282"))
                        .lineLimit(1)
                }
                if let endTime = endTime {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 12))
                        Text("\(time) - \(endTime)")
                            .font(.system(size: 12))
                    }
                    .foregroundColor(Color(hexString: "364153"))
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 12))
                        Text(time)
                            .font(.system(size: 12))
                    }
                    .foregroundColor(Color(hexString: "364153"))
                }
            }
            Spacer(minLength: 0)
            
            // Meta information (calories)
            if !meta.isEmpty {
                Text(meta)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(emphasis)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(isDone ? emphasis.opacity(0.25) : Color(hexString: "E5E7EB"), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 2, x: 0, y: 1)
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
    
    private func triggerCompletionHaptic() {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        #endif
    }
}


// Helper view for task detail navigation
private struct TaskDetailDestinationView: View {
    let destination: TaskDetailDestination
    @Binding var tasks: [MainPageView.TaskItem]
    
    var body: some View {
        Group {
            if let taskId = destination.taskId,
               let taskIndex = tasks.firstIndex(where: { $0.id == taskId }) {
                DetailPageView(tasks: $tasks, taskIndex: taskIndex)
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

private struct TaskListView: View {
    @Binding var tasks: [MainPageView.TaskItem]
    @Binding var navigationPath: NavigationPath
    @State private var deletingTaskIds: Set<UUID> = []
    
    // Use original tasks array for sorting display
    private var sortedTasks: [MainPageView.TaskItem] {
        tasks.sorted { $0.timeDate < $1.timeDate }
    }

    var body: some View {
        Group {
            if tasks.isEmpty {
                ScrollView {
                    EmptyTasksView()
                }
            } else {
                GeometryReader { geometry in
                    List {
                        ForEach(Array(sortedTasks.enumerated()), id: \.element.id) { _, task in
                            // Find the actual index in the original tasks array
                            let actualIndex = tasks.firstIndex(where: { $0.id == task.id }) ?? 0
                            
                            TaskRowCard(
                                title: task.title,
                                subtitle: task.subtitle,
                                time: task.time,
                                endTime: task.endTime,
                                meta: task.meta,
                                isDone: Binding(
                                    get: { task.isDone },
                                    set: { newValue in
                                        tasks[actualIndex].isDone = newValue
                                    }
                                ),
                                emphasis: Color(hexString: task.emphasisHex),
                                category: task.category
                            )
                            .offset(x: deletingTaskIds.contains(task.id) ? geometry.size.width : 0)
                            .opacity(deletingTaskIds.contains(task.id) ? 0 : 1)
                            .listRowInsets(EdgeInsets(top: 0, leading: 24, bottom: 12, trailing: 24))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    deleteTask(task.id)
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
                                navigationPath.append(TaskDetailDestination.detail(taskId: task.id))
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
        }
    }
    
    private func deleteTask(_ taskId: UUID) {
        triggerDeleteHaptic()
        
        
        // Remove after animation completes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            tasks.removeAll { $0.id == taskId }
            deletingTaskIds.remove(taskId)
        }
    }
    
    private func triggerDeleteHaptic() {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        #endif
    }
}

#Preview {
    NavigationStack {
        StatefulPreviewWrapper(Tab.todos) { selection in
            MainPageView(selectedTab: selection)
        }
    }
}
