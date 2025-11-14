import SwiftUI

struct CalendarPopupView: View {
    @Binding var showCalendar: Bool
    @Binding var selectedDate: Date
    let dateRange: (min: Date, max: Date)
    let tasksByDate: [Date: [MainPageView.TaskItem]]

    @State private var currentMonth: Date = Date()
    @State private var selectedDay: Int? = nil

    private let weekSymbols = ["Su","Mo","Tu","We","Th","Fr","Sa"]
    
    init(showCalendar: Binding<Bool>, selectedDate: Binding<Date>, dateRange: (min: Date, max: Date), tasksByDate: [Date: [MainPageView.TaskItem]] = [:]) {
        self._showCalendar = showCalendar
        self._selectedDate = selectedDate
        self.dateRange = dateRange
        self.tasksByDate = tasksByDate
        // Initialize currentMonth to selectedDate's month
        self._currentMonth = State(initialValue: selectedDate.wrappedValue)
    }

    var body: some View {
        VStack(spacing: 0) {
            HeaderView()

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
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: Color.black.opacity(0.25), radius: 50, x: 0, y: 25)
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
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Daily Streak")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(Color(hex: 0x6A7282))
                    StreakView()
                }
                Spacer()
                Text("🔥")
                    .font(.system(size: 48))
            }
            .frame(height: 68)
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 21)
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color(hex: 0xE5E7EB))
                .frame(height: 1)
        }
    }
}

private struct StreakView: View {
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text("7")
                .font(.system(size: 48, weight: .regular))
                .foregroundColor(Color(hex: 0x0A0A0A))
            Text("days")
                .font(.system(size: 16, weight: .regular))
                .foregroundColor(Color(hex: 0x4A5565))
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
                .foregroundColor(Color(hex: 0x0A0A0A))
            Spacer()
            HStack(spacing: 4) {
                Button(action: { shiftMonth(by: -1) }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(canGoPrevious ? Color(hex: 0x0A0A0A) : Color(hex: 0xD1D5DB))
                        .frame(width: 32, height: 32)
                        .background(Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .disabled(!canGoPrevious)
                
                Button(action: { shiftMonth(by: 1) }) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(canGoNext ? Color(hex: 0x0A0A0A) : Color(hex: 0xD1D5DB))
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
                    .foregroundColor(Color(hex: 0x99A1AF))
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
    let tasksByDate: [Date: [MainPageView.TaskItem]]

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
                    let dayDate = buildDate(day: day, month: currentMonth)
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
    
    // Build a Date from day number and month
    private func buildDate(day: Int, month: Date) -> Date {
        var components = calendar.dateComponents([.year, .month], from: month)
        components.day = day
        return calendar.date(from: components) ?? month
    }
    
    // Check if a date is within the selectable range
    private func isDateSelectable(day: Int, in month: Date) -> Bool {
        let dayDate = buildDate(day: day, month: month)
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
        if isFilledBlack { return .black }
        if isFilledGray { return Color(hex: 0xE5E7EB) }
        return .clear
    }

    private var fgColor: Color {
        if isDisabled {
            return Color(hex: 0xD1D5DB)
        }
        return isFilledBlack ? .white : Color(hex: 0x364153)
    }
    
    private var dotColor: Color {
        // Use gray color that works on both light and dark backgrounds
        if isFilledBlack {
            return Color(hex: 0x9CA3AF) // Lighter gray for black background
        }
        return Color(hex: 0x6B7280) // Darker gray for light background
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
                    .foregroundColor(Color(hex: 0x101828))
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(Color(hex: 0xF3F4F6))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }

            Button(action: {
                confirmSelection()
            }) {
                Text("Confirm")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(hasValidSelection ? Color.black : Color(hex: 0xD1D5DB))
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
        let dayDate = buildDate(day: day, month: currentMonth)
        let normalizedDate = calendar.startOfDay(for: dayDate)
        return normalizedDate >= dateRange.min && normalizedDate <= dateRange.max
    }
    
    private func buildDate(day: Int, month: Date) -> Date {
        var components = calendar.dateComponents([.year, .month], from: month)
        components.day = day
        return calendar.date(from: components) ?? month
    }
    
    private func confirmSelection() {
        guard let day = selectedDay else {
            withAnimation { showCalendar = false }
            return
        }
        
        let dayDate = buildDate(day: day, month: currentMonth)
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

// MARK: - Color Extension
private extension Color {
    init(hex: UInt, alpha: Double = 1.0) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
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
