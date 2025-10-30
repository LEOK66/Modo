import SwiftUI

struct MainPageView: View {
    @Binding var selectedTab: Tab
    @State private var isShowingCalendar = false
    @State private var navigationPath = NavigationPath()
    
    // Can refactor this to different file to reuse struct
    struct TaskItem: Identifiable {
        let id = UUID()
        let emoji: String
        let title: String
        let subtitle: String
        let time: String
        let meta: String
        var isDone: Bool
        let emphasisHex: String
    }
    
    // Empty tasks for first-time users
    @State private var tasks: [TaskItem] = []
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                Color.white.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    TopHeaderView(isShowingCalendar: $isShowingCalendar)
                        .padding(.horizontal, 24)
                        .padding(.top, 12)
                    
                    VStack(spacing: 16) {
                        CombinedStatsCard()
                            .padding(.horizontal, 24)
                        
                        TasksHeader(navigationPath: $navigationPath)
                            .padding(.horizontal, 24)
                        
                        TaskListView(tasks: $tasks)
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
        }
    }
}

// MARK: - Navigation Destination Type
private enum AddTaskDestination: Hashable {
    case addTask
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
    var body: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Color.white)
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color(hexString: "E5E7EB"), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.04), radius: 2, x: 0, y: 1)
            .overlay(
                // Initial state with no tasks - all zeros
                HStack(spacing: 0) {
                    StatItem(value: "0/0", label: "Completed", tint: Color(hexString: "101828"))
                    StatItem(value: "0", label: "Diet", tint: Color(hexString: "00A63E"))
                    StatItem(value: "0", label: "Fitness", tint: Color(hexString: "155DFC"))
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
    let emoji: String
    let title: String
    let subtitle: String
    let time: String
    let meta: String
    @Binding var isDone: Bool
    let emphasis: Color

    init(emoji: String, title: String, subtitle: String, time: String, meta: String, isDone: Binding<Bool>, emphasis: Color) {
        self.emoji = emoji
        self.title = title
        self.subtitle = subtitle
        self.time = time
        self.meta = meta
        self._isDone = isDone
        self.emphasis = emphasis
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(isDone ? emphasis : Color.white)
                    .frame(width: 22, height: 22)
                    .overlay(
                        Circle().stroke(Color(hexString: "E5E7EB"), lineWidth: isDone ? 0 : 1)
                    )
                if isDone {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(emoji)
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(isDone ? emphasis : Color(hexString: "101828"))
                }
                Text(subtitle)
                    .font(.system(size: 14))
                    .foregroundColor(Color(hexString: "6A7282"))
                HStack(spacing: 12) {
                    Label(time, systemImage: "clock")
                        .font(.system(size: 12))
                        .foregroundColor(Color(hexString: "364153"))
                    Text(meta)
                        .font(.system(size: 12))
                        .foregroundColor(Color(hexString: "364153"))
                }
            }
            Spacer(minLength: 0)
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
        .onTapGesture {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                isDone.toggle()
            }
        }
    }
}

private struct TaskListView: View {
    @Binding var tasks: [MainPageView.TaskItem]

    var body: some View {
        ScrollView {
            if tasks.isEmpty {
                EmptyTasksView()
            } else {
                VStack(spacing: 12) {
                    ForEach($tasks) { $task in
                        TaskRowCard(
                            emoji: task.emoji,
                            title: task.title,
                            subtitle: task.subtitle,
                            time: task.time,
                            meta: task.meta,
                            isDone: $task.isDone,
                            emphasis: Color(hexString: task.emphasisHex)
                        )
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 12)
            }
        }
    }
}

#Preview {
    NavigationStack {
        StatefulPreviewWrapper(Tab.todos) { selection in
            MainPageView(selectedTab: selection)
        }
    }
}
