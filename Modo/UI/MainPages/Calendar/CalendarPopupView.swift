import SwiftUI
import SwiftData
import FirebaseAuth
import Combine

struct CalendarPopupView: View {
    @Binding var showCalendar: Bool
    @Binding var selectedDate: Date
    let dateRange: (min: Date, max: Date)
    let tasksByDate: [Date: [TaskItem]]
    @Environment(\.modelContext) private var modelContext

    @State private var currentMonth: Date = Date()
    @State private var selectedDay: Int? = nil

    private let weekSymbols = ["Su","Mo","Tu","We","Th","Fr","Sa"]
    
    init(showCalendar: Binding<Bool>, selectedDate: Binding<Date>, dateRange: (min: Date, max: Date), tasksByDate: [Date: [TaskItem]] = [:]) {
        self._showCalendar = showCalendar
        self._selectedDate = selectedDate
        self.dateRange = dateRange
        self.tasksByDate = tasksByDate
        // Initialize currentMonth to selectedDate's month
        self._currentMonth = State(initialValue: selectedDate.wrappedValue)
    }

    var body: some View {
        VStack(spacing: 0) {
            HeaderView(
                tasksByDate: tasksByDate
            )

            MonthNavigationView(currentMonth: $currentMonth, dateRange: dateRange)

            WeekdaySymbolsView(weekSymbols: weekSymbols)

            DaysGridView(
                selectedDay: $selectedDay,
                currentMonth: $currentMonth,
                dateRange: dateRange,
                tasksByDate: tasksByDate
            )

            Spacer(minLength: 0)

            ActionButtonsView(
                showCalendar: $showCalendar,
                selectedDate: $selectedDate,
                selectedDay: $selectedDay,
                currentMonth: currentMonth,
                dateRange: dateRange
            )
        }
        .frame(width: 343, height: 536)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: Color.primary.opacity(0.25), radius: 50, x: 0, y: 25)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .zIndex(1)
        .onAppear {
            // Initialize selectedDay to match selectedDate's day if in current month
            let calendar = Calendar.current
            let monthComponents = calendar.dateComponents([.year, .month], from: currentMonth)
            let selectedComponents = calendar.dateComponents([.year, .month, .day], from: selectedDate)
            if monthComponents.year == selectedComponents.year &&
               monthComponents.month == selectedComponents.month {
                selectedDay = selectedComponents.day
            }
        }
    }
}

// MARK: - Header
private struct HeaderView: View {
    let tasksByDate: [Date: [TaskItem]]
    @Environment(\.modelContext) private var modelContext
    @StateObject private var streakViewModel = StreakViewModel()
    @State private var showMilestoneCelebration = false
    @State private var milestoneDays: Int? = nil
    
    private var userId: String? {
        Auth.auth().currentUser?.uid
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Daily Streak")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(.secondary)
                    StreakView(streakCount: streakViewModel.streakCount)
                }
                Spacer()
                // Duolingo-style flame icon with animation
                DuolingoFlameIcon(streakCount: streakViewModel.streakCount)
                    .scaleEffect(showMilestoneCelebration ? 1.2 : 1.0)
                    .animation(.spring(response: 0.4, dampingFraction: 0.6), value: showMilestoneCelebration)
            }
            .frame(height: 68)
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 21)
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color(.separator))
                .frame(height: 1)
        }
        .onAppear {
            updateStreak()
        }
        .onReceive(NotificationCenter.default.publisher(for: .dayCompletionDidChange)) { _ in
            updateStreak()
        }
        .id(tasksByDate.count) // Force update when tasks change
        .onChange(of: tasksByDate.count) { _, _ in
            // Update streak when tasks change (using count as proxy for dictionary changes)
            updateStreak()
        }
        .sheet(isPresented: $showMilestoneCelebration) {
            if let milestone = milestoneDays {
                MilestoneCelebrationView(milestoneDays: milestone)
            }
        }
    }
    
    private func updateStreak() {
        guard let userId = userId else { 
            streakViewModel.updateStreak(0)
            return 
        }
        
        let previousStreak = streakViewModel.streakCount
        let newStreak = StreakService.shared.calculateStreak(
            userId: userId,
            modelContext: modelContext,
            tasksByDate: tasksByDate
        )
        
        streakViewModel.updateStreak(newStreak)
        
        // Check for milestone
        if newStreak > previousStreak, let milestone = StreakService.shared.checkMilestone(streakCount: newStreak) {
            milestoneDays = milestone
            showMilestoneCelebration = true
        }
    }
}

// MARK: - Streak View Model
private class StreakViewModel: ObservableObject {
    @Published var streakCount: Int = 0
    
    func updateStreak(_ count: Int) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            streakCount = count
        }
    }
}

// MARK: - Duolingo-style Flame Icon
private struct DuolingoFlameIcon: View {
    let streakCount: Int
    @State private var isAnimating = false
    
    // Flame color based on streak count (Duolingo style)
    private var flameColor: Color {
        if streakCount >= 30 {
            return Color(red: 1.0, green: 0.4, blue: 0.0) // Bright orange
        } else if streakCount >= 7 {
            return Color(red: 1.0, green: 0.6, blue: 0.0) // Orange
        } else if streakCount >= 3 {
            return Color(red: 1.0, green: 0.7, blue: 0.2) // Light orange
        } else {
            return .secondary // Gray for 0-2 days
        }
    }
    
    // Flame size based on streak count
    private var flameSize: CGFloat {
        if streakCount >= 100 {
            return 40
        } else if streakCount >= 30 {
            return 36
        } else if streakCount >= 7 {
            return 32
        } else if streakCount >= 3 {
            return 28
        } else {
            return 28 // Same size for gray
        }
    }
    
    var body: some View {
        ZStack {
            // Main flame
            Image(systemName: "flame.fill")
                .font(.system(size: flameSize, weight: .medium))
                .foregroundColor(flameColor)
                .scaleEffect(isAnimating ? 1.1 : 1.0)
                .animation(
                    Animation.easeInOut(duration: 1.5)
                        .repeatForever(autoreverses: true),
                    value: isAnimating
                )
            
            // Subtle glow effect for higher streaks (only when streak is active)
            if streakCount >= 3 {
                Image(systemName: "flame.fill")
                    .font(.system(size: flameSize * 1.3, weight: .light))
                    .foregroundColor(flameColor.opacity(0.3))
                    .blur(radius: 2)
            }
        }
        .onAppear {
            if streakCount >= 3 {
                isAnimating = true
            }
        }
        .onChange(of: streakCount) { oldValue, newValue in
            if newValue >= 3 && oldValue < 3 {
                // Start animating when reaching 3 days
                isAnimating = true
            } else if newValue > oldValue && newValue >= 3 {
                // Pulse animation when streak increases (only if already animating)
                withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                    isAnimating = false
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    if newValue >= 3 {
                        isAnimating = true
                    }
                }
            } else if newValue < 3 {
                // Stop animating if streak drops below 3
                isAnimating = false
            }
        }
    }
}

// MARK: - Streak Count Display
private struct StreakView: View {
    let streakCount: Int
    
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text("\(streakCount)")
                .font(.system(size: 48, weight: .bold))
                .foregroundColor(.primary)
                .contentTransition(.numericText())
            Text("days")
                .font(.system(size: 16, weight: .regular))
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Milestone Celebration View
private struct MilestoneCelebrationView: View {
    let milestoneDays: Int
    @Environment(\.dismiss) private var dismiss
    @State private var animate = false
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.9)
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                // Animated flame
                Image(systemName: "flame.fill")
                    .font(.system(size: 80, weight: .medium))
                    .foregroundColor(Color(red: 1.0, green: 0.5, blue: 0.0))
                    .scaleEffect(animate ? 1.2 : 1.0)
                    .rotationEffect(.degrees(animate ? 5 : -5))
                    .animation(
                        Animation.easeInOut(duration: 0.5)
                            .repeatForever(autoreverses: true),
                        value: animate
                    )
                
                VStack(spacing: 8) {
                    Text("🔥 Streak Milestone! 🔥")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("\(milestoneDays) days!")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(Color(red: 1.0, green: 0.6, blue: 0.0))
                    
                    Text("Keep up the amazing work!")
                        .font(.system(size: 18, weight: .regular))
                        .foregroundColor(.white.opacity(0.8))
                }
                
                Button(action: {
                    dismiss()
                }) {
                    Text("Awesome!")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color(red: 1.0, green: 0.6, blue: 0.0))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 40)
                .padding(.top, 20)
            }
        }
        .onAppear {
            animate = true
        }
    }
}

// MARK: - Month Navigation
private struct MonthNavigationView: View {
    @Binding var currentMonth: Date
    let dateRange: (min: Date, max: Date)

    var body: some View {
        HStack {
            Text(monthTitle(for: currentMonth))
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.primary)
            Spacer()
            HStack(spacing: 4) {
                Button(action: { shiftMonth(by: -1) }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(canGoPrevious ? .primary : .secondary)
                        .frame(width: 32, height: 32)
                        .background(Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .disabled(!canGoPrevious)
                
                Button(action: { shiftMonth(by: 1) }) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(canGoNext ? .primary : .secondary)
                        .frame(width: 32, height: 32)
                        .background(Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .disabled(!canGoNext)
            }
        }
        .frame(height: 32)
        .padding(.horizontal, 24)
        .padding(.top, 16)
    }

    private func monthTitle(for date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "LLLL yyyy"
        return f.string(from: date)
    }

    private var canGoPrevious: Bool {
        let calendar = Calendar.current
        if let prevMonth = calendar.date(byAdding: .month, value: -1, to: currentMonth) {
            let minMonth = calendar.dateComponents([.year, .month], from: dateRange.min)
            let prevMonthComponents = calendar.dateComponents([.year, .month], from: prevMonth)
            return prevMonthComponents.year! > minMonth.year! ||
                   (prevMonthComponents.year == minMonth.year && prevMonthComponents.month! >= minMonth.month!)
        }
        return false
    }

    private var canGoNext: Bool {
        let calendar = Calendar.current
        if let nextMonth = calendar.date(byAdding: .month, value: 1, to: currentMonth) {
            let maxMonth = calendar.dateComponents([.year, .month], from: dateRange.max)
            let nextMonthComponents = calendar.dateComponents([.year, .month], from: nextMonth)
            return nextMonthComponents.year! < maxMonth.year! ||
                   (nextMonthComponents.year == maxMonth.year && nextMonthComponents.month! <= maxMonth.month!)
        }
        return false
    }

    private func shiftMonth(by offset: Int) {
        let calendar = Calendar.current
        if let newDate = calendar.date(byAdding: .month, value: offset, to: currentMonth) {
            // Check if new date is within range
            let minMonth = calendar.dateComponents([.year, .month], from: dateRange.min)
            let maxMonth = calendar.dateComponents([.year, .month], from: dateRange.max)
            let newMonthComponents = calendar.dateComponents([.year, .month], from: newDate)
            
            let isInRange = (newMonthComponents.year! > minMonth.year! ||
                            (newMonthComponents.year == minMonth.year && newMonthComponents.month! >= minMonth.month!)) &&
                           (newMonthComponents.year! < maxMonth.year! ||
                            (newMonthComponents.year == maxMonth.year && newMonthComponents.month! <= maxMonth.month!))
            
            if isInRange {
                currentMonth = newDate
            }
        }
    }
}

// MARK: - Weekday Symbols
private struct WeekdaySymbolsView: View {
    let weekSymbols: [String]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(weekSymbols, id: \.self) { sym in
                Text(sym)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 32)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
    }
}

// MARK: - Days Grid
private struct DaysGridView: View {
    @Binding var selectedDay: Int?
    @Binding var currentMonth: Date
    let dateRange: (min: Date, max: Date)
    let tasksByDate: [Date: [TaskItem]]

    private let columns = Array(repeating: GridItem(.fixed(36.57), spacing: 6), count: 7)
    private let calendar = Calendar.current
    private let today = Date()

    var body: some View {
        let days = generateDays(for: currentMonth)
        let currentMonthComponents = calendar.dateComponents([.year, .month], from: currentMonth)
        let todayComponents = calendar.dateComponents([.year, .month, .day], from: today)

        LazyVGrid(columns: columns, alignment: .leading, spacing: 6) {
            ForEach(days.indices, id: \.self) { index in
                if let day = days[index] {
                    let dayDate = CalendarHelper.buildDate(day: day, month: currentMonth)
                    let isSelectable = isDateSelectable(day: day, in: currentMonth)
                    let normalizedDate = calendar.startOfDay(for: dayDate)
                    let hasUncompletedTasks = hasUncompletedTasks(for: normalizedDate)
                    
                    DayCell(
                        number: day,
                        isSelected: day == selectedDay,
                        isFilledGray: currentMonthComponents.year == todayComponents.year &&
                                      currentMonthComponents.month == todayComponents.month &&
                                      day == todayComponents.day,
                        isFilledBlack: day == selectedDay,
                        isDisabled: !isSelectable,
                        hasUncompletedTasks: hasUncompletedTasks
                    )
                    .onTapGesture {
                        if isSelectable {
                            selectedDay = day
                        }
                    }
                } else {
                    Color.clear
                        .frame(width: 36.57, height: 36.57)
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
        // Reset selection when month changes
        .onChange(of: currentMonth) { _, _ in
            selectedDay = nil
        }
    }

    // Generate array of days with optional nil placeholders
    private func generateDays(for date: Date) -> [Int?] {
        let range = calendar.range(of: .day, in: .month, for: date) ?? 1..<31
        let firstOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: date))!
        let firstWeekday = calendar.component(.weekday, from: firstOfMonth) // 1...7

        var days: [Int?] = Array(repeating: nil, count: firstWeekday - 1)
        days.append(contentsOf: range.map { $0 })
        return days
    }
    
    // Check if a date is within the selectable range
    private func isDateSelectable(day: Int, in month: Date) -> Bool {
        let dayDate = CalendarHelper.buildDate(day: day, month: month)
        let normalizedDate = calendar.startOfDay(for: dayDate)
        return normalizedDate >= dateRange.min && normalizedDate <= dateRange.max
    }
    
    // Check if a date has uncompleted tasks
    private func hasUncompletedTasks(for date: Date) -> Bool {
        let normalizedDate = calendar.startOfDay(for: date)
        guard let tasks = tasksByDate[normalizedDate] else { return false }
        return tasks.contains { !$0.isDone }
    }
}

// MARK: - Day Cell
private struct DayCell: View {
    let number: Int
    let isSelected: Bool
    let isFilledGray: Bool
    let isFilledBlack: Bool
    let isDisabled: Bool
    let hasUncompletedTasks: Bool

    private var bgColor: Color {
        if isFilledBlack { return Color.primary }
        if isFilledGray { return Color(.secondarySystemBackground) }
        return .clear
    }

    private var fgColor: Color {
        if isDisabled {
            return .secondary
        }
        return isFilledBlack ? Color(.systemBackground) : .primary
    }
    
    private var dotColor: Color {
        // Use secondary color that adapts to light/dark mode
        if isFilledBlack {
            return .secondary.opacity(0.7) // Lighter for dark background
        }
        return .secondary // Adapts automatically
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(bgColor)
            Text("\(number)")
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(fgColor)
        }
        .frame(width: 36.57, height: 36.57)
        .overlay(alignment: .bottom) {
            // Indicator dot for uncompleted tasks
            if hasUncompletedTasks {
                Circle()
                    .fill(dotColor)
                    .frame(width: 4, height: 4)
                    .offset(y: 8) // Position dot slightly below the cell with more spacing
            }
        }
    }
}


// MARK: - Action Buttons
private struct ActionButtonsView: View {
    @Binding var showCalendar: Bool
    @Binding var selectedDate: Date
    @Binding var selectedDay: Int?
    let currentMonth: Date
    let dateRange: (min: Date, max: Date)

    private let calendar = Calendar.current

    var body: some View {
        HStack(spacing: 12) {
            Button(action: {
                withAnimation { showCalendar = false }
            }) {
                Text("Cancel")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }

            Button(action: {
                confirmSelection()
            }) {
                Text("Confirm")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(hasValidSelection ? Color(.systemBackground) : .secondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(hasValidSelection ? Color.primary : Color(.tertiarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .disabled(!hasValidSelection)
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .padding(.bottom, 8)
    }
    
    private var hasValidSelection: Bool {
        guard let day = selectedDay else { return false }
        let dayDate = CalendarHelper.buildDate(day: day, month: currentMonth)
        let normalizedDate = calendar.startOfDay(for: dayDate)
        return normalizedDate >= dateRange.min && normalizedDate <= dateRange.max
    }
    
    private func confirmSelection() {
        guard let day = selectedDay else {
            withAnimation { showCalendar = false }
            return
        }
        
        let dayDate = CalendarHelper.buildDate(day: day, month: currentMonth)
        let normalizedDate = calendar.startOfDay(for: dayDate)
        
        // Double-check date is in range
        guard normalizedDate >= dateRange.min && normalizedDate <= dateRange.max else {
            withAnimation { showCalendar = false }
            return
        }
        
        // Update selectedDate with animation
        withAnimation(.easeInOut(duration: 0.3)) {
            selectedDate = normalizedDate
            selectedDay = nil
            showCalendar = false
        }
    }
}

// MARK: - Calendar Helper
private enum CalendarHelper {
    /// Build a Date from day number and month
    static func buildDate(day: Int, month: Date) -> Date {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month], from: month)
        components.day = day
        return calendar.date(from: components) ?? month
    }
}

// MARK: - Preview
struct CalendarPopupView_Previews: PreviewProvider {
    @State static var showCalendar = true
    @State static var selectedDate = Calendar.current.startOfDay(for: Date())
    
    static var dateRange: (min: Date, max: Date) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let minDate = calendar.date(byAdding: .month, value: -12, to: today) ?? today
        let maxDate = calendar.date(byAdding: .month, value: 3, to: today) ?? today
        return (min: minDate, max: maxDate)
    }

    static var previews: some View {
        ZStack {
            Color.gray.opacity(0.4)
                .edgesIgnoringSafeArea(.all)

            CalendarPopupView(
                showCalendar: $showCalendar,
                selectedDate: $selectedDate,
                dateRange: dateRange
            )
        }
    }
}
