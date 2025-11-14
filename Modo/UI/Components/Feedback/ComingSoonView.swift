import SwiftUI

// MARK: - Coming Soon View
struct ComingSoonView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack(alignment: .top) {
            Color(.systemBackground).ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Back Button
                HStack {
                    BackButton {
                        dismiss()
                    }
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, 12)
                
                Spacer()
                
                // Content
                VStack(spacing: 0) {
                    // Icon
                    ComingSoonIcon()
                    
                    Spacer().frame(height: 40)
                    
                    // Heading
                    Text("Coming Soon")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(.primary)
                        .tracking(-0.3125)
                    
                    Spacer().frame(height: 24)
                    
                    // Description
                    VStack(spacing: 12) {
                        Text("This feature is currently under development")
                            .font(.system(size: 16, weight: .regular))
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.center)
                            .tracking(-0.3125)
                            .lineSpacing(10)
                            .frame(maxWidth: 266)
                        
                        Text("We're working hard to bring you this feature. Check back soon!")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .tracking(-0.150391)
                            .lineSpacing(9)
                            .frame(maxWidth: 300)
                    }
                }
                .frame(maxWidth: .infinity)
                
                Spacer()
                
                // Go Back Button
                Button {
                    dismiss()
                } label: {
                    Text("Go Back")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(Color(.systemBackground))
                        .tracking(-0.3125)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.primary)
                        .cornerRadius(16)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
        .navigationBarBackButtonHidden(true)
    }
}

// MARK: - Preview
#Preview {
    ComingSoonView()
}

