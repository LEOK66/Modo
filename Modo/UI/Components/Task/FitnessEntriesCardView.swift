import SwiftUI

/// Fitness entries card component for task form
struct FitnessEntriesCardView: View {
    @Binding var fitnessEntries: [FitnessEntry]
    @Binding var editingFitnessEntryIndex: Int?
    @Binding var titleText: String
    @FocusState.Binding var fitnessNameFocusIndex: Int?
    @Binding var pendingScrollId: String?
    @Binding var durationHoursInt: Int
    @Binding var durationMinutesInt: Int
    @Binding var isDurationSheetPresented: Bool
    
    let onAddExercise: () -> Void
    let onEditExercise: (Int) -> Void
    let onDeleteExercise: (Int) -> Void
    let onClearAll: () -> Void
    let onTriggerHaptic: () -> Void
    let onDismissKeyboard: () -> Void
    let formattedDuration: (Int, Int) -> String
    
    var body: some View {
        card {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    label("Exercises")
                    Spacer()
                    if !fitnessEntries.isEmpty {
                        Button("Clear all") {
                            onClearAll()
                        }
                        .font(.system(size: 12))
                    }
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(fitnessEntries.indices, id: \.self) { idx in
                        fitnessEntryRow(at: idx)
                            .id("fit-\(idx)")
                    }
                    
                    Button(action: onAddExercise) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(Color(hexString: "364153"))
                            Text("Add Exercise")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Color(hexString: "364153"))
                            Spacer()
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 16)
                        .background(Color(hexString: "F3F4F6"))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color(hexString: "364153"), lineWidth: 1)
                                .opacity(0.2)
                        )
                    }
                    .buttonStyle(.plain)
                }
                
                if !fitnessEntries.isEmpty {
                    VStack(spacing: 8) {
                        Divider()
                        HStack {
                            Text("Total Calories")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(Color(hexString: "0A0A0A"))
                            Spacer()
                            Text("\(totalFitnessCalories) cal")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(Color(hexString: "364153"))
                        }
                    }
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "figure.run.circle")
                            .font(.system(size: 32))
                            .foregroundColor(Color(hexString: "D1D5DB"))
                        Text("No exercise added yet")
                            .font(.system(size: 14))
                            .foregroundColor(Color(hexString: "6B7280"))
                        Text("Tap 'Add Exercise' to get started")
                            .font(.system(size: 12))
                            .foregroundColor(Color(hexString: "9CA3AF"))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                }
            }
        }
    }
    
    private var totalFitnessCalories: Int {
        fitnessEntries.map { Int($0.caloriesText) ?? 0 }.reduce(0, +)
    }
    
    private func fitnessEntryRow(at index: Int) -> some View {
        let entry = fitnessEntries[index]
        
        return VStack(spacing: 12) {
            HStack(spacing: 12) {
                Button(action: {
                    onEditExercise(index)
                }) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(Color(hexString: "6B7280"))
                        Text(entry.exercise?.name ?? (entry.customName.isEmpty ? "Choose Exercise" : entry.customName))
                            .foregroundColor(entry.exercise != nil ? Color(hexString: "0A0A0A") : Color(hexString: "6B7280"))
                            .lineLimit(1)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(Color(hexString: "9CA3AF"))
                            .font(.system(size: 12))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color(hexString: "F9FAFB"))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
                
                Button(action: {
                    onDeleteExercise(index)
                }) {
                    Image(systemName: "trash")
                        .foregroundColor(Color(hexString: "EF4444"))
                        .font(.system(size: 14))
                }
                .buttonStyle(.plain)
            }
            
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Duration")
                        .font(.system(size: 12))
                        .foregroundColor(Color(hexString: "6B7280"))
                    Button(action: {
                        let total = max(0, entry.minutesInt)
                        durationHoursInt = total / 60
                        durationMinutesInt = total % 60
                        // Clear focus immediately when opening duration sheet
                        onDismissKeyboard()
                        isDurationSheetPresented = true
                        // tie the wheel to this entry index via editingFitnessEntryIndex
                        editingFitnessEntryIndex = index
                    }) {
                        HStack {
                            Text(entry.minutesInt > 0 ? formattedDuration(entry.minutesInt / 60, entry.minutesInt % 60) : "-")
                                .foregroundColor(Color(hexString: "0A0A0A"))
                            Spacer()
                            Image(systemName: "timer")
                                .foregroundColor(Color(hexString: "6A7282"))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 8)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Calories")
                        .font(.system(size: 12))
                        .foregroundColor(Color(hexString: "6B7280"))
                    HStack(spacing: 4) {
                        TextField("0", text: Binding(
                            get: { fitnessEntries[index].caloriesText },
                            set: { newValue in
                                fitnessEntries[index].caloriesText = newValue.filter { $0.isNumber }
                            }
                        ))
                        .keyboardType(.numberPad)
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 8)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        Text("cal")
                            .font(.system(size: 12))
                            .foregroundColor(Color(hexString: "6B7280"))
                    }
                }
            }
            
            if entry.exercise == nil {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Customize Exercise")
                        .font(.system(size: 12))
                        .foregroundColor(Color(hexString: "6B7280"))
                    TextField("e.g., Stretching", text: Binding(
                        get: { fitnessEntries[index].customName },
                        set: { newValue in fitnessEntries[index].customName = newValue }
                    ))
                    .focused($fitnessNameFocusIndex, equals: index)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 8)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
            }
        }
        .contextMenu {
            Button("Duplicate") {
                let copy = entry
                fitnessEntries.insert(copy, at: min(index + 1, fitnessEntries.count))
                pendingScrollId = "fit-\(min(index + 1, fitnessEntries.count - 1))"
                onTriggerHaptic()
            }
        }
        .padding(12)
        .background(Color(hexString: "F9FAFB"))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
    
    private func label(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 14))
            .foregroundColor(Color(hexString: "4A5565"))
    }
    
    @ViewBuilder
    private func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(16)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var fitnessEntries: [FitnessEntry] = [
            FitnessEntry()
        ]
        @State private var editingFitnessEntryIndex: Int? = nil
        @State private var titleText = ""
        @FocusState private var fitnessNameFocusIndex: Int?
        @State private var pendingScrollId: String? = nil
        @State private var durationHoursInt: Int = 0
        @State private var durationMinutesInt: Int = 0
        @State private var isDurationSheetPresented: Bool = false
        
        var body: some View {
            FitnessEntriesCardView(
                fitnessEntries: $fitnessEntries,
                editingFitnessEntryIndex: $editingFitnessEntryIndex,
                titleText: $titleText,
                fitnessNameFocusIndex: $fitnessNameFocusIndex,
                pendingScrollId: $pendingScrollId,
                durationHoursInt: $durationHoursInt,
                durationMinutesInt: $durationMinutesInt,
                isDurationSheetPresented: $isDurationSheetPresented,
                onAddExercise: {
                    fitnessEntries.append(FitnessEntry())
                },
                onEditExercise: { index in
                    editingFitnessEntryIndex = index
                },
                onDeleteExercise: { index in
                    fitnessEntries.remove(at: index)
                },
                onClearAll: {
                    fitnessEntries.removeAll()
                },
                onTriggerHaptic: {},
                onDismissKeyboard: {},
                formattedDuration: { h, m in
                    if h > 0 {
                        return "\(h)h \(m)m"
                    } else {
                        return "\(m)m"
                    }
                }
            )
            .padding()
        }
    }
    
    return PreviewWrapper()
}

