import SwiftUI

struct CalendarPopupView: View {
    @Binding var showCalendar: Bool

    @State private var currentMonth: Date = Date()
    @State private var selectedDay: Int? = nil

    private let weekSymbols = ["Su","Mo","Tu","We","Th","Fr","Sa"]

    var body: some View {
        VStack(spacing: 0) {
            HeaderView()

            MonthNavigationView(currentMonth: $currentMonth)

            WeekdaySymbolsView(weekSymbols: weekSymbols)

            DaysGridView(selectedDay: $selectedDay, currentMonth: $currentMonth)

            Spacer(minLength: 0)

            ActionButtonsView(showCalendar: $showCalendar)
        }
        .frame(width: 343, height: 536)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: Color.black.opacity(0.25), radius: 50, x: 0, y: 25)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .zIndex(1)
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
                        .foregroundColor(Color(hex: 0x0A0A0A))
                        .frame(width: 32, height: 32)
                        .background(Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                Button(action: { shiftMonth(by: 1) }) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color(hex: 0x0A0A0A))
                        .frame(width: 32, height: 32)
                        .background(Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
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

    private func shiftMonth(by offset: Int) {
        if let newDate = Calendar.current.date(byAdding: .month, value: offset, to: currentMonth) {
            currentMonth = newDate
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
                    DayCell(
                        number: day,
                        isSelected: day == selectedDay,
                        isFilledGray: currentMonthComponents.year == todayComponents.year &&
                                      currentMonthComponents.month == todayComponents.month &&
                                      day == todayComponents.day,
                        isFilledBlack: day == selectedDay
                    )
                    .onTapGesture {
                        selectedDay = day
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
}

// MARK: - Day Cell
private struct DayCell: View {
    let number: Int
    let isSelected: Bool
    let isFilledGray: Bool
    let isFilledBlack: Bool

    private var bgColor: Color {
        if isFilledBlack { return .black }
        if isFilledGray { return Color(hex: 0xE5E7EB) }
        return .clear
    }

    private var fgColor: Color {
        isFilledBlack ? .white : Color(hex: 0x364153)
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
    }
}


// MARK: - Action Buttons
private struct ActionButtonsView: View {
    @Binding var showCalendar: Bool

    var body: some View {
        HStack(spacing: 12) {
            Button(action: { withAnimation { showCalendar = false } }) {
                Text("Cancel")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(Color(hex: 0x101828))
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(Color(hex: 0xF3F4F6))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }

            Button(action: { withAnimation { showCalendar = false } }) {
                Text("Confirm")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(Color.black)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .padding(.bottom, 8)
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

    static var previews: some View {
        ZStack {
            Color.gray.opacity(0.4)
                .edgesIgnoringSafeArea(.all)

            CalendarPopupView(showCalendar: $showCalendar)
        }
    }
}
