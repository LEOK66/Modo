import SwiftUI

// MARK: - Help & Support View
struct HelpSupportView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .top) {
            Color(.systemBackground).ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                PageHeader(title: "Help & Support")
                    .padding(.top, 12)
                    .padding(.horizontal, 24)
                
                Spacer().frame(height: 12)
                
                // Content
                ScrollView {
                    VStack(spacing: 24) {
                        // How can we assist you card
                        InfoCard(
                            icon: "questionmark.circle",
                            title: "How can we assist you?",
                            description: "Thank you for reaching out! Our support team is dedicated to providing you with the best assistance. Whether you have questions about your account, need help with features, or want to share feedback, we're here to ensure you have a smooth experience with our app."
                        )
                        
                        // Contact Us Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Contact Us")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)
                                .padding(.leading, 4)
                            
                            // Email Support
                            ContactCard(
                                icon: "envelope.fill",
                                title: "Email Support",
                                subtitle: "support@example.com"
                            ) {
                                if let url = URL(string: "mailto:support@example.com") {
                                    UIApplication.shared.open(url)
                                }
                            }
                            
                            // Response time info
                            InfoBox(text: "We typically respond within 24 hours on business days")
                        }
                    }
                    .padding(24)
                    .padding(.bottom, 24)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .background(Color(.secondarySystemBackground))
            }
        }
        .navigationBarBackButtonHidden(true)
    }
}

// MARK: - Preview
#Preview {
    HelpSupportView()
}
