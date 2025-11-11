import SwiftUI

/// Time picker sheet component
struct TimePickerSheetView: View {
    @Binding var isPresented: Bool
    @Binding var timeDate: Date
    
    var body: some View {
        VStack(spacing: 12) {
            DatePicker("", selection: $timeDate, displayedComponents: .hourAndMinute)
                .datePickerStyle(.wheel)
                .labelsHidden()
                .frame(maxWidth: .infinity)
            Button("Done") { 
                isPresented = false 
            }
            .font(.system(size: 16, weight: .semibold))
            .frame(maxWidth: .infinity, minHeight: 44)
        }
        .padding(16)
        .presentationDetents([.fraction(0.35)])
        .presentationDragIndicator(.visible)
    }
}

