import SwiftUI
import SwiftData

struct InsightsPageView: View {
    @Binding var selectedTab: Tab
    @StateObject private var coachService = ModoCoachService()
    @State private var inputText: String = ""
    @State private var showClearConfirmation = false
    @State private var showAttachmentMenu = false
    @State private var showPhotoPicker = false
    @State private var selectedImage: UIImage?
    @Query private var userProfiles: [UserProfile]
    @Environment(\.modelContext) private var modelContext
    
    private var currentUserProfile: UserProfile? {
        userProfiles.first
    }

    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Header
            ZStack {
                // Center content
                VStack(spacing: 2) {
                    Text("Moder")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(Color(hexString: "101828"))
                    Text("Your wellness assistant")
                        .font(.system(size: 13))
                        .foregroundColor(Color(hexString: "6B7280"))
                }
                
                // Clear History Button (positioned on right)
                HStack {
                    Spacer()
                    Button(action: {
                        showClearConfirmation = true
                    }) {
                        Image(systemName: "trash")
                            .font(.system(size: 16))
                            .foregroundColor(Color(hexString: "6B7280"))
                            .frame(width: 36, height: 36)
                    }
                    .padding(.trailing, 16)
                }
            }
            .frame(height: 60)
            .padding(.top, 12)
            .background(Color.white)
            
            Divider()
                .background(Color(hexString: "E5E7EB"))
            
            // MARK: - Chat Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(coachService.messages, id: \.id) { message in
                            ChatBubble(
                                message: message,
                                onAccept: { msg in
                                    coachService.acceptWorkoutPlan(for: msg)
                                },
                                onReject: { msg in
                                    coachService.rejectWorkoutPlan(for: msg)
                                }
                            )
                            .id(message.id)
                        }
                        
                        // Loading indicator
                        if coachService.isProcessing {
                            HStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [Color(hexString: "8B5CF6"), Color(hexString: "6366F1")],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 36, height: 36)
                                    .overlay(
                                        Image(systemName: "figure.strengthtraining.traditional")
                                            .font(.system(size: 18, weight: .semibold))
                                            .foregroundColor(.white)
                                    )
                                
                                HStack(spacing: 8) {
                                    ForEach(0..<3) { index in
                                        Circle()
                                            .fill(Color(hexString: "9CA3AF"))
                                            .frame(width: 8, height: 8)
                                            .scaleEffect(coachService.isProcessing ? 1 : 0.5)
                                            .animation(
                                                Animation.easeInOut(duration: 0.6)
                                                    .repeatForever()
                                                    .delay(Double(index) * 0.2),
                                                value: coachService.isProcessing
                                            )
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(Color(hexString: "F3F4F6"))
                                .cornerRadius(20)
                                
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .id("loading")
                        }
                    }
                    .padding(.vertical, 16)
                }
                .onChange(of: coachService.messages.count) { _, _ in
                    if let lastMessage = coachService.messages.last {
                        withAnimation {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
                .onChange(of: coachService.isProcessing) { _, isProcessing in
                    if isProcessing {
                        withAnimation {
                            proxy.scrollTo("loading", anchor: .bottom)
                        }
                    }
                }
            }
            .background(Color.white)

            // MARK: - Input Field + Buttons
            ZStack(alignment: .bottomLeading) {
                VStack(spacing: 0) {
                    Divider()
                        .background(Color(hexString: "E5E7EB"))
                    
                    HStack(spacing: 12) {
                        // Placeholder for plus button space
                        Color.clear
                            .frame(width: 40, height: 40)

                        CustomInputField(
                            placeholder: "Ask questions or add photos...",
                            text: $inputText
                        )

                        Button(action: sendMessage) {
                            Image(systemName: "paperplane.fill")
                                .foregroundColor(.white)
                                .frame(width: 40, height: 40)
                                .background(
                                    inputText.isEmpty ? Color.gray.opacity(0.5) : Color.purple.opacity(0.7)
                                )
                                .clipShape(Circle())
                        }
                        .disabled(inputText.isEmpty || coachService.isProcessing)
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                    .background(Color.white)
                }
                
                // Floating Plus Button with Expandable Menu
                ZStack {
                    VStack(spacing: 0) {
                        if showAttachmentMenu {
                            Color.clear
                                .frame(width: 40, height: 40)
                                .overlay(
                                    Image(systemName: "photo")
                                        .font(.system(size: 18))
                                        .foregroundColor(Color(hexString: "8B5CF6"))
                                )
                                .onTapGesture {
                                    withAnimation(.spring(response: 0.3)) {
                                        showAttachmentMenu = false
                                    }
                                    showPhotoPicker = true
                                }
                            
                            Divider()
                                .frame(width: 30)
                            
                            Color.clear
                                .frame(width: 40, height: 40)
                                .overlay(
                                    Image(systemName: "doc")
                                        .font(.system(size: 18))
                                        .foregroundColor(Color(hexString: "8B5CF6"))
                                )
                                .onTapGesture {
                                    withAnimation(.spring(response: 0.3)) {
                                        showAttachmentMenu = false
                                    }
                                    // TODO: Handle file selection
                                    print("File selected")
                                }
                            
                            Divider()
                                .frame(width: 30)
                        }
                        
                        Color.clear
                            .frame(width: 40, height: 40)
                            .overlay(
                                Image(systemName: "plus")
                                    .font(.system(size: 18))
                                    .foregroundColor(.black)
                                    .rotationEffect(.degrees(showAttachmentMenu ? 45 : 0))
                            )
                            .onTapGesture {
                                withAnimation(.spring(response: 0.3)) {
                                    showAttachmentMenu.toggle()
                                }
                            }
                    }
                }
                .background(Color.white)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Color(hexString: "E5E7EB"), lineWidth: 1))
                .padding(.leading, 24)
                .padding(.bottom, 16)
            }

            // MARK: - Bottom Navigation Bar
            BottomBar(selectedTab: $selectedTab)
        }
        .background(Color(hexString: "F9FAFB").ignoresSafeArea())
        .onTapGesture {
            if showAttachmentMenu {
                withAnimation {
                    showAttachmentMenu = false
                }
            }
        }
        .onAppear {
            coachService.loadHistory(from: modelContext)
        }
        .sheet(isPresented: $showPhotoPicker) {
            PhotoPicker(selectedImage: $selectedImage)
        }
        .onChange(of: selectedImage) { _, newImage in
            if let image = newImage {
                handleImageSelection(image)
                selectedImage = nil
            }
        }
        .alert("Clear Chat History", isPresented: $showClearConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Clear", role: .destructive) {
                coachService.clearHistory()
            }
        } message: {
            Text("Are you sure you want to clear all chat history? This action cannot be undone.")
        }
    }
    
    // MARK: - Handle Image Selection
    private func handleImageSelection(_ image: UIImage) {
        // Show user message
        let userMessage = "📷 [Food photo uploaded]"
        coachService.sendUserMessage(userMessage)
        
        // Convert image to base64 for API
        guard let imageData = image.jpegData(compressionQuality: 0.7) else { return }
        let base64String = imageData.base64EncodedString()
        
        // Send to OpenAI Vision API for food analysis
        Task {
            await coachService.analyzeFoodImage(base64Image: base64String, userProfile: currentUserProfile)
        }
    }
    
    // MARK: - Send Message
    private func sendMessage() {
        guard !inputText.isEmpty else { return }
        
        coachService.sendMessage(inputText, userProfile: currentUserProfile)
        inputText = ""
    }
}

// MARK: - Preview
#Preview {
    StatefulPreviewWrapper(Tab.insights) { selection in
        InsightsPageView(selectedTab: selection)
    }
}
