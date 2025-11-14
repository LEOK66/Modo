import SwiftUI

/// Duration picker sheet component
struct DurationPickerSheetView: View {
    @Binding var isPresented: Bool
    @Binding var durationHours: Int
    @Binding var durationMinutes: Int
    let onDurationChanged: () -> Void
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                VStack {
                    Text("Hours")
                        .font(.system(size: 14))
                        .foregroundColor(Color(hexString: "6A7282"))
                    Picker("Hours", selection: $durationHours) {
                        ForEach(0...5, id: \.self) { Text("\($0)") }
                    }
                    .pickerStyle(.wheel)
                    .frame(maxWidth: .infinity)
                    .onChange(of: durationHours) { _, _ in
                        onDurationChanged()
                    }
                }
                VStack {
                    Text("Minutes")
                        .font(.system(size: 14))
                        .foregroundColor(Color(hexString: "6A7282"))
                    Picker("Minutes", selection: $durationMinutes) {
                        ForEach(0...59, id: \.self) { Text("\($0)") }
                    }
                    .pickerStyle(.wheel)
                    .frame(maxWidth: .infinity)
                    .onChange(of: durationMinutes) { _, _ in
                        onDurationChanged()
                    }
                }
            }
            Button("Done") {
                onDurationChanged()
                isPresented = false
            }
            .font(.system(size: 16, weight: .semibold))
            .frame(maxWidth: .infinity, minHeight: 44)
        }
        .padding(16)
        .presentationDetents([.fraction(0.45)])
        .presentationDragIndicator(.visible)
    }
}

