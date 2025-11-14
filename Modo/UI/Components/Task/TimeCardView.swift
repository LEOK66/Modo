import SwiftUI

/// Time card component for task form
struct TimeCardView: View {
    @Binding var timeDate: Date
    @Binding var isTimeSheetPresented: Bool
    let onDismissKeyboard: () -> Void
    
    var body: some View {
        card {
            VStack(alignment: .leading, spacing: 12) {
                label("Time")
                Button(action: {
                    onDismissKeyboard()
                    isTimeSheetPresented = true
                }) {
                    HStack {
                        Text(formattedTime)
                            .foregroundColor(.primary)
                        Spacer()
                        Image(systemName: "clock")
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 16)
                    .frame(height: 48)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color(.separator), lineWidth: 0.5)
                    )
                }
                .buttonStyle(.plain)
                .sheet(isPresented: $isTimeSheetPresented, onDismiss: {
                    onDismissKeyboard()
                }) {
                    VStack(spacing: 12) {
                        DatePicker("", selection: $timeDate, displayedComponents: .hourAndMinute)
                            .datePickerStyle(.wheel)
                            .labelsHidden()
                            .frame(maxWidth: .infinity)
                        Button("Done") {
                            isTimeSheetPresented = false
                        }
                            .font(.system(size: 16, weight: .semibold))
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .padding(16)
                    .presentationDetents([.fraction(0.35)])
                    .presentationDragIndicator(.visible)
                }
            }
        }
    }
    
    private var formattedTime: String {
        let df = DateFormatter()
        df.locale = .current
        df.timeStyle = .short
        df.dateStyle = .none
        return df.string(from: timeDate)
    }
    
    private func label(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 14))
            .foregroundColor(.secondary)
    }
    
    @ViewBuilder
    private func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(16)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: Color.primary.opacity(0.1), radius: 8, x: 0, y: 2)
    }
}

#Preview {
    TimeCardView(
        timeDate: .constant(Date()),
        isTimeSheetPresented: .constant(false),
        onDismissKeyboard: {}
    )
    .padding()
}



