import SwiftUI

struct MainPageView: View {
    @State private var selectedTab: Tab = .todos

    var body: some View {
        ZStack {
            Color.white
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Top bar with date and menu/avatar aligned to match clean style
                TopHeaderView()
                    .padding(.horizontal, 24)
                    .padding(.top, 12)

                VStack(spacing: 16) {

                    // Stats
                    CombinedStatsCard()
                        .padding(.horizontal, 24)

                    // Tasks header
                    TasksHeader()
                        .padding(.horizontal, 24)

                    // Tasks list (scrollable only)
                    ScrollView {
                        VStack(spacing: 12) {
                            TaskRowCard(
                                emoji: "🥗",
                                title: "Healthy Breakfast",
                                subtitle: "Oatmeal with berries and nuts",
                                time: "08:00",
                                meta: "350 cal",
                                isDone: true,
                                emphasis: Color(hexString: "16A34A")
                            )
                            TaskRowCard(
                                emoji: "🏃",
                                title: "Morning Run",
                                subtitle: "5km jog in the park",
                                time: "07:00",
                                meta: "30 min",
                                isDone: false,
                                emphasis: Color(hexString: "3B82F6")
                            )
                            TaskRowCard(
                                emoji: "🥗",
                                title: "Lunch Prep",
                                subtitle: "Grilled chicken salad with quinoa",
                                time: "12:30",
                                meta: "420 cal",
                                isDone: false,
                                emphasis: Color(hexString: "3B82F6")
                            )
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 12)
                    }
                }
                .padding(.top, 12)

                // Bottom navigation
                BottomBar(selectedTab: $selectedTab)
                    .background(Color.white)
            }
        }
    }
}

private enum Tab: String, CaseIterable {
    case todos = "TODOs"
    case insights = "Insights"
}

private struct TopHeaderView: View {
    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            Button {} label: {
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

            Spacer()

            // Centered date look
            Text(Self.formattedDate)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(Color(hexString: "101828"))

            Spacer()

            // Menu button
            Button {} label: {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.black)
                    .frame(width: 40, height: 40)
                    .overlay(
                        VStack(spacing: 5) {
                            Capsule().fill(Color.white).frame(width: 18, height: 2)
                            Capsule().fill(Color.white).frame(width: 18, height: 2)
                            Capsule().fill(Color.white).frame(width: 18, height: 2)
                        }
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
                HStack(spacing: 0) {
                    StatItem(value: "1/3", label: "Completed", tint: Color(hexString: "101828"))
                    StatItem(value: "1", label: "Diet", tint: Color(hexString: "16A34A"))
                    StatItem(value: "0", label: "Fitness", tint: Color(hexString: "3B82F6"))
                }
                .frame(maxWidth: .infinity)
                .padding(12)
            )
            .frame(width: 327, height: 92)
    }



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
    var body: some View {
        HStack {
            Text("Today's Tasks")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(Color(hexString: "101828"))
            Spacer()
            Button(action: {}) {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                    Text("Add Task")
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
                .frame(height: 40)
                .padding(.horizontal, 16)
                .background(Color.black)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
    }
}

private struct TaskRowCard: View {
    let emoji: String
    let title: String
    let subtitle: String
    let time: String
    let meta: String
    let isDone: Bool
    let emphasis: Color

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
    }
}

private struct BottomBar: View {
    @Binding var selectedTab: Tab

    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color(hexString: "E5E7EB"))
                .frame(height: 1)
            HStack(spacing: 24) {
                BottomBarItem(icon: "doc.text", label: Tab.todos.rawValue, isSelected: selectedTab == .todos) {
                    selectedTab = .todos
                }
                BottomBarItem(icon: "message", label: Tab.insights.rawValue, isSelected: selectedTab == .insights) {
                    selectedTab = .insights
                }
            }
            .padding(.vertical, 12)
        }
        .background(Color.white)
    }
}

private struct BottomBarItem: View {
    let icon: String
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                Text(label)
                    .font(.system(size: 10, weight: .medium))
            }
            .frame(minWidth: 64)
            .foregroundColor(isSelected ? Color(hexString: "7C3AED") : Color(hexString: "101828"))
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected ? Color(hexString: "F5F3FF") : Color.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isSelected ? Color(hexString: "E9D5FF") : Color.clear, lineWidth: 1)
            )
        }
    }
}

#Preview {
    MainPageView()
}
