import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .top) {
            Color(hexString: "F9FAFB").ignoresSafeArea() // main background
            
            VStack(spacing: 0) {
                // Header
                PageHeader(title: "Settings")
                    .padding(.top, 12)
                    .padding(.horizontal, 24)
                
                Spacer().frame(height: 12)
                
                // Full-height gray scrollable container
                ScrollView {
                    // Place components here
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top) // fill available space
                .background(Color(hexString: "F3F4F6"))
            }
        }
        .navigationBarBackButtonHidden(true)
    }
}

// MARK: - Preview
#Preview {
    SettingsView()
}
