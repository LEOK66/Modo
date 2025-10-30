import SwiftUI

// MARK: - Coming Soon View
struct ComingSoonView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack(alignment: .top) {
            Color(hexString: "F9FAFB").ignoresSafeArea()
            
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
                        .foregroundColor(Color(hexString: "0A0A0A"))
                        .tracking(-0.3125)
                    
                    Spacer().frame(height: 24)
                    
                    // Description
                    VStack(spacing: 12) {
                        Text("This feature is currently under development")
                            .font(.system(size: 16, weight: .regular))
                            .foregroundColor(Color(hexString: "4A5565"))
                            .multilineTextAlignment(.center)
                            .tracking(-0.3125)
                            .lineSpacing(10)
                            .frame(maxWidth: 266)
                        
                        Text("We're working hard to bring you this feature. Check back soon!")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(Color(hexString: "99A1AF"))
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
                        .foregroundColor(.white)
                        .tracking(-0.3125)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.black)
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

