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
    
<<<<<<< HEAD
    // Test values for now
    @State private var tasks: [TaskItem] = [
//        TaskItem(emoji: "🥗", title: "Healthy Breakfast", subtitle: "Oatmeal with berries and nuts", time: "08:00", meta: "350 cal", isDone: true, emphasisHex: "16A34A"),
//        TaskItem(emoji: "🏃", title: "Morning Run", subtitle: "5km jog in the park", time: "07:00", meta: "30 min", isDone: false, emphasisHex: "16A34A"),
//        TaskItem(emoji: "🥗", title: "Lunch Prep", subtitle: "Grilled chicken salad with quinoa", time: "12:30", meta: "420 cal", isDone: false, emphasisHex: "16A34A")
    ]
=======
    // Empty tasks for first-time users
    @State private var tasks: [TaskItem] = []
>>>>>>> develop
    
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

// Displays Completed Diet and Fitness Tasks
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
<<<<<<< HEAD
                    StatItem(value: "0", label: "Completed", tint: Color(hexString: "101828"))
                    StatItem(value: "0", label: "Diet", tint: Color(hexString: "16A34A"))
                    StatItem(value: "0", label: "Fitness", tint: Color(hexString: "3B82F6"))
=======
                    StatItem(value: "0/0", label: "Completed", tint: Color(hexString: "101828"))
                    StatItem(value: "0", label: "Diet", tint: Color(hexString: "00A63E"))
                    StatItem(value: "0", label: "Fitness", tint: Color(hexString: "155DFC"))
>>>>>>> develop
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

private struct TaskListView: View {
    @Binding var tasks: [MainPageView.TaskItem]

    var body: some View {
        if tasks.isEmpty {
            // Empty state when no tasks exist
            VStack {
                Spacer(minLength: 24)
                EmptyStateView()
                    .frame(maxWidth: .infinity)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 24)
            .padding(.bottom, 12)
        } else {
            ScrollView {
                VStack(spacing: 12) {
                    ForEach($tasks) { $task in
                        TaskCard(
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

private struct EmptyStateView: View {
    var body: some View {
<<<<<<< HEAD
        VStack(spacing: 24) {
            // Decorative circles group
            ZStack {
                // Outer ring 80x80 with 4pt border (#E5E7EB)
                Circle()
                    .stroke(Color(hexString: "E5E7EB"), lineWidth: 4)
                    .frame(width: 80, height: 80)
                    .overlay(
                        // Inner ring 40x40 with 2pt border (#D1D5DC) and 0.8 opacity
                        Circle()
                            .stroke(Color(hexString: "D1D5DC").opacity(0.8), lineWidth: 2)
                            .frame(width: 40, height: 40)
                    )
                    .overlay(
                        // Small light gray dot (10x10) at approx right-middle
                        Circle()
                            .fill(Color(hexString: "F3F4F6"))
                            .frame(width: 10, height: 10)
                            .offset(x: 28, y: 0)
                    )
                    .overlay(
                        // Small white outlined dot (14x14) at approx bottom-left
                        Circle()
                            .stroke(Color(hexString: "E5E7EB"), lineWidth: 2)
                            .background(Circle().fill(Color.white))
                            .frame(width: 14, height: 14)
                            .offset(x: -32, y: 32)
                    )
                    .overlay(
                        // Small white outlined dot (20x20) at approx top-right
                        Circle()
                            .stroke(Color(hexString: "D1D5DC"), lineWidth: 2)
                            .background(Circle().fill(Color.white))
                            .frame(width: 20, height: 20)
                            .offset(x: 20, y: -40)
                    )
            }
            .frame(width: 80, height: 80)

            // Text container (Heading + Paragraph) centered
            VStack(spacing: 8) {
                Text("Nothing here yet")
                    .font(.system(size: 18, weight: .regular))
                    .kerning(-0.439453)
                    .foregroundColor(Color(hexString: "0A0A0A"))
                    .frame(maxWidth: 240)
                    .multilineTextAlignment(.center)

                Text("Your task list is feeling a bit lonely. Let's add some goals to keep it company! ")
                    .font(.system(size: 14, weight: .regular))
                    .kerning(-0.150391)
                    .foregroundColor(Color(hexString: "6A7282"))
                    .frame(maxWidth: 240)
                    .multilineTextAlignment(.center)
            }
=======
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
>>>>>>> develop
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    NavigationStack {
        StatefulPreviewWrapper(Tab.todos) { selection in
            MainPageView(selectedTab: selection)
        }
    }
}

