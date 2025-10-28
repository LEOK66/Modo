import SwiftUI

struct AddTaskView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var tasks: [MainPageView.TaskItem] // Binding to main page tasks
    
    // Form state
    @State private var selectedEmoji: String = "📝"
    @State private var titleText: String = ""
    @State private var descriptionText: String = ""
    @State private var timeText: String = ""
    @State private var selectedCategory: Category? = nil
    @State private var caloriesText: String = ""
    @State private var durationHoursText: String = ""
    @State private var durationMinutesText: String = ""
    
    enum Category: String, CaseIterable, Identifiable {
        case diet = "🥗 Diet"
        case fitness = "🏃 Fitness"
        var id: String { rawValue }
        var isPrimary: Bool { self == .diet }
        var color: Color {
            switch self {
            case .diet: return Color(hexString: "00C950")
            case .fitness: return Color(hexString: "F9FAFB")
            }
        }
        var textColor: Color {
            switch self {
            case .diet: return .white
            case .fitness: return Color(hexString: "364153")
            }
        }
    }
    
    var body: some View {
        ZStack(alignment: .top) {
            Color(hexString: "F9FAFB").ignoresSafeArea()
            VStack(spacing: 0) {
                // Header
                PageHeader(title: "Add New Task")
                    .padding(.top, 12)
                    .padding(.horizontal, 24)
                Spacer().frame(height: 12)
                // Scrollable container
                ScrollView {
                    VStack(spacing: 16) {
                        emojiPickerCard
                        titleCard
                        descriptionCard
                        timeCard
                        categoryCard
                        if selectedCategory == .diet {
                            caloriesCard
                        }
                        if selectedCategory == .fitness {
                            fitnessDurationCard
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                }
                .background(Color(hexString: "F3F4F6"))
                .padding(.top, 8)
                bottomActionBar
            }
        }
        .navigationBarBackButtonHidden(true)
    }
}

// MARK: - Bottom Action Bar
private extension AddTaskView {
    // MARK: - Cards
    var emojiPickerCard: some View {
        card {
            VStack(alignment: .leading, spacing: 12) {
                label("Task Icon")
                // Grid of emoji buttons, 3 columns x 4 rows (approx per spec)
                LazyVGrid(columns: Array(repeating: GridItem(.fixed(44), spacing: 8, alignment: .leading), count: 6), alignment: .leading, spacing: 12) {
                    ForEach(emojiOptions, id: \.self) { emoji in
                        Button {
                            selectedEmoji = emoji
                        } label: {
                            Text(emoji)
                                .font(.system(size: 24))
                                .frame(width: 44, height: 44)
                                .background(buttonBackground(for: emoji))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(borderColor(for: emoji), lineWidth: selectedEmoji == emoji ? 2 : 0)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .foregroundColor(Color(hexString: "0A0A0A"))
                        }
                    }
                }
            }
        }
    }

    var titleCard: some View {
        card {
            VStack(alignment: .leading, spacing: 12) {
                label("Task Title")
                TextField("e.g., Morning Run", text: $titleText)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 16)
                    .frame(height: 48)
                    .background(Color(hexString: "F9FAFB"))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
    }

    var descriptionCard: some View {
        card {
            VStack(alignment: .leading, spacing: 12) {
                label("Description")
                TextField("e.g., 5km jog in the park", text: $descriptionText, axis: .vertical)
                    .lineLimit(3...6)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color(hexString: "F9FAFB"))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
    }

    var timeCard: some View {
        card {
            VStack(alignment: .leading, spacing: 12) {
                label("Time")
                TextField("e.g., 7:30 AM", text: $timeText)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 16)
                    .frame(height: 48)
                    .background(Color(hexString: "F9FAFB"))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
    }

    var categoryCard: some View {
        card {
            VStack(alignment: .leading, spacing: 12) {
                label("Category")
                HStack(spacing: 12) {
                    categoryChip(.diet)
                    categoryChip(.fitness)
                    Spacer(minLength: 0)
                }
            }
        }
    }

    var caloriesCard: some View {
        card {
            VStack(alignment: .leading, spacing: 12) {
                label("Calories (e.g., 350 cal)")
                TextField("350 cal", text: $caloriesText)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 16)
                    .frame(height: 48)
                    .background(Color(hexString: "F9FAFB"))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
    }
    
    var fitnessDurationCard: some View {
        card {
            VStack(alignment: .leading, spacing: 12) {
                label("Duration (hours/minutes)")
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Hours")
                            .font(.system(size: 12))
                            .foregroundColor(Color(hexString: "4A5565"))
                        TextField("0", text: $durationHoursText)
                            .keyboardType(.numberPad)
                            .textFieldStyle(.plain)
                            .padding(.horizontal, 16)
                            .frame(height: 48)
                            .background(Color(hexString: "F9FAFB"))
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Minutes")
                            .font(.system(size: 12))
                            .foregroundColor(Color(hexString: "4A5565"))
                        TextField("0", text: $durationMinutesText)
                            .keyboardType(.numberPad)
                            .textFieldStyle(.plain)
                            .padding(.horizontal, 16)
                            .frame(height: 48)
                            .background(Color(hexString: "F9FAFB"))
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                }
            }
        }
    }

    // MARK: - Helpers
    func label(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 14))
            .foregroundColor(Color(hexString: "4A5565"))
    }

    var emojiOptions: [String] {
        ["🥗","🏃","🏋️","🧘","💧","🍎","🥑","🏊","🚴","⚽","🎯","🌟"]
    }

    func buttonBackground(for emoji: String) -> Color {
        if selectedEmoji == emoji {
            return Color(hexString: "F3E8FF")
        }
        return Color(hexString: "F9FAFB")
    }

    func borderColor(for emoji: String) -> Color {
        selectedEmoji == emoji ? Color(hexString: "C27AFF") : .clear
    }
    
    var metaText: String {
        switch selectedCategory {
        case .diet:
            return caloriesText.isEmpty ? "" : caloriesText
        case .fitness:
            let h = Int(durationHoursText) ?? 0
            let m = Int(durationMinutesText) ?? 0
            if h == 0 && m == 0 { return "" }
            if h > 0 && m > 0 { return "\(h)h \(m)m" }
            if h > 0 { return "\(h)h" }
            return "\(m)m"
        case .none:
            return ""
        }
    }

    func categoryChip(_ category: Category) -> some View {
        let isSelected = selectedCategory == category
        return Button {
            selectedCategory = category
        } label: {
            HStack(spacing: 8) {
                Text(category.rawValue)
                    .font(.system(size: 16))
                    .foregroundColor(Color(hexString: "0A0A0A"))
            }
            .frame(width: 147, height: 48)
            .background(isSelected ? Color(hexString: "F3E8FF") : Color(hexString: "F9FAFB"))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isSelected ? Color(hexString: "C27AFF") : Color.clear, lineWidth: isSelected ? 2 : 0)
            )
        }
    }

    func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            content()
                .padding(16)
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 1)
        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
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
                    tasks.append(
                        MainPageView.TaskItem(
                            emoji: selectedEmoji,
                            title: titleText.isEmpty ? "New Task" : titleText,
                            subtitle: descriptionText,
                            time: timeText,
                            meta: metaText,
                            isDone: false,
                            emphasisHex: (selectedCategory == .diet) ? "16A34A" : "364153"
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

