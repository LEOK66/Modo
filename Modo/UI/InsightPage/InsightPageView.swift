import SwiftUI
import SwiftData
import FirebaseAuth

struct InsightsPageView: View {
    @Binding var selectedTab: Tab
    @EnvironmentObject var userProfileService: UserProfileService
    @EnvironmentObject var authService: AuthService
    @Environment(\.modelContext) private var modelContext
    
    // ViewModel - manages all business logic and state
    @StateObject private var viewModel = InsightsPageViewModel()
    
    // Focus state (must be in View, not ViewModel)
    @FocusState private var isInputFocused: Bool
    
    // Local UI state for drag gesture
    @State private var dragStartLocation: CGPoint? = nil

    var body: some View {
        VStack(spacing: 0) {
            headerView
            Divider().background(Color(.separator))
            FirebaseChatMessagesView
            inputFieldView
            if viewModel.keyboardHeight == 0 {
                BottomBar(selectedTab: $selectedTab)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeOut(duration: 0.3), value: viewModel.keyboardHeight)
        .background(Color(.systemBackground).ignoresSafeArea())
        .onTapGesture {
            // Dismiss keyboard when tapping outside input field
            if isInputFocused {
                isInputFocused = false
                viewModel.isInputFocused = false
            }
            // Dismiss attachment menu
            if viewModel.showAttachmentMenu {
                withAnimation {
                    viewModel.showAttachmentMenu = false
                }
            }
        }
        .onAppear {
            // Setup ViewModel with dependencies
            viewModel.setup(
                modelContext: modelContext,
                userProfileService: userProfileService,
                authService: authService
            )
            viewModel.onAppear()
        }
        .onDisappear {
            viewModel.onDisappear()
        }
        .onChange(of: authService.currentUser?.uid) { oldValue, newValue in
            // Reload chat history when user changes
            if oldValue != newValue {
                viewModel.handleUserChange()
            }
        }
        .sheet(isPresented: $viewModel.showPhotoPicker) {
            PhotoPicker(selectedImage: $viewModel.selectedImage)
        }
        .onChange(of: viewModel.selectedImage) { _, newImage in
            if let image = newImage {
                viewModel.handleImageSelection(image)
                viewModel.selectedImage = nil
            }
        }
        .alert("Clear Chat History", isPresented: $viewModel.showClearConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Clear", role: .destructive) {
                viewModel.clearChatHistory()
            }
        } message: {
            Text("Are you sure you want to clear all chat history? This action cannot be undone.")
        }
        .gesture(
            DragGesture(minimumDistance: 10)
                .onChanged { value in
                    // Track the start location when drag begins
                    if dragStartLocation == nil {
                        dragStartLocation = value.startLocation
                    }
                }
                .onEnded { value in
                    defer {
                        // Reset drag start location
                        dragStartLocation = nil
                    }
                    
                    let horizontalAmount = value.translation.width
                    let verticalAmount = value.translation.height
                    let startX = dragStartLocation?.x ?? value.startLocation.x
                    
                    // Only handle horizontal swipes (ignore vertical)
                    // Check if swipe starts from left edge (within 20 points) to avoid conflicts with ScrollView
                    if abs(horizontalAmount) > abs(verticalAmount) && startX < 20 {
                        if horizontalAmount > 50 {
                            // Swipe from left to right: go back to main page
                            withAnimation {
                                selectedTab = .todos
                            }
                        }
                    }
                }
        )
    }
    
    // MARK: - Helper Methods
    
    /// Send message
    private func sendMessage() {
        viewModel.sendMessage()
    }
    
    /// Scroll to bottom
    private func scrollToBottom(proxy: ScrollViewProxy) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if let lastMessage = viewModel.messages.last {
                withAnimation(.easeOut(duration: 0.3)) {
                    proxy.scrollTo(lastMessage.id, anchor: .bottom)
                }
            } else if viewModel.isProcessing {
                withAnimation(.easeOut(duration: 0.3)) {
                    proxy.scrollTo("loading", anchor: .bottom)
                }
            }
        }
    }
    
    // MARK: - Sub Views
    
    private var headerView: some View {
        ZStack {
            // Center content
            VStack(spacing: 2) {
                Text("Modor")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.primary)
                Text("Your wellness assistant")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            
            // Clear History Button (positioned on right)
            HStack {
                Spacer()
                Button(action: {
                    viewModel.showClearConfirmation = true
                }) {
                    Image(systemName: "trash")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                        .frame(width: 36, height: 36)
                }
                .padding(.trailing, 16)
            }
        }
        .frame(height: 60)
        .padding(.top, 12)
        .background(Color(.systemBackground))
    }
    
    private var FirebaseChatMessagesView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(viewModel.messages, id: \.id) { message in
                        ChatBubble(
                            message: message,
                            onAccept: { msg in
                                viewModel.handleAcceptTask(for: msg)
                            },
                            onReject: { msg in
                                viewModel.handleRejectTask(for: msg)
                            }
                        )
                        .id(message.id)
                    }
                    
                    if viewModel.isProcessing {
                        loadingIndicator
                    }
                }
                .padding(.vertical, 16)
                .padding(.bottom, viewModel.keyboardHeight > 0 ? max(0, viewModel.keyboardHeight - 80) : 0)  // Adjust for keyboard, subtract input field (~80) height (BottomBar is hidden when keyboard is shown)
            }
            .onChange(of: viewModel.messages.count) { _, _ in
                // Scroll to latest message when new message arrives
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: viewModel.isProcessing) { _, isProcessing in
                if isProcessing {
                    withAnimation {
                        proxy.scrollTo("loading", anchor: .bottom)
                    }
                }
            }
            .onChange(of: viewModel.keyboardHeight) { _, _ in
                // Scroll to bottom when keyboard appears
                if viewModel.keyboardHeight > 0 {
                    scrollToBottom(proxy: proxy)
                }
            }
            .simultaneousGesture(
                TapGesture()
                    .onEnded { _ in
                        // Dismiss keyboard when tapping on message area
                        if isInputFocused {
                            isInputFocused = false
                            viewModel.isInputFocused = false
                        }
                    }
            )
        }
        .background(Color(.systemBackground))
    }
    
    private var loadingIndicator: some View {
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
                        .fill(.secondary)
                        .frame(width: 8, height: 8)
                        .scaleEffect(viewModel.isProcessing ? 1 : 0.5)
                        .animation(
                            Animation.easeInOut(duration: 0.6)
                                .repeatForever()
                                .delay(Double(index) * 0.2),
                            value: viewModel.isProcessing
                        )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(20)
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .id("loading")
    }
    
    private var inputFieldView: some View {
        ZStack(alignment: .bottomLeading) {
            VStack(spacing: 0) {
                Divider()
                    .background(Color(.separator))
                
                HStack(spacing: 12) {
                    // Placeholder for plus button space
                    Color.clear
                        .frame(width: 40, height: 40)

                    CustomInputField(
                        placeholder: "Ask questions or add photos...",
                        text: $viewModel.inputText
                    )
                    .focused($isInputFocused)
                    .onChange(of: isInputFocused) { _, isFocused in
                        viewModel.isInputFocused = isFocused
                    }

                    Button(action: sendMessage) {
                        Image(systemName: "paperplane.fill")
                            .foregroundColor(.white)
                            .frame(width: 40, height: 40)
                            .background(
                                viewModel.inputText.isEmpty ? Color(.tertiarySystemBackground) : Color(hexString: "8B5CF6").opacity(0.7)
                            )
                            .clipShape(Circle())
                    }
                    .disabled(viewModel.inputText.isEmpty || viewModel.isProcessing)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
                .background(Color(.systemBackground))
            }
            
            plusButtonMenu
        }
    }
    
    private var plusButtonMenu: some View {
        ZStack {
            VStack(spacing: 0) {
                if viewModel.showAttachmentMenu {
                    Color.clear
                        .frame(width: 40, height: 40)
                        .overlay(
                            Image(systemName: "photo")
                                .font(.system(size: 18))
                                .foregroundColor(Color(hexString: "8B5CF6"))
                        )
                        .onTapGesture {
                            withAnimation(.spring(response: 0.3)) {
                                viewModel.showAttachmentMenu = false
                            }
                            viewModel.showPhotoPicker = true
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
                                viewModel.showAttachmentMenu = false
                            }
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
                            .foregroundColor(.primary)
                            .rotationEffect(.degrees(viewModel.showAttachmentMenu ? 45 : 0))
                    )
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3)) {
                            viewModel.showAttachmentMenu.toggle()
                        }
                    }
            }
        }
        .background(Color(.systemBackground))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Color(.separator), lineWidth: 1))
        .padding(.leading, 24)
        .padding(.bottom, 16)
    }
}

// MARK: - Preview
#Preview {
    StatefulPreviewWrapper(Tab.insights) { selection in
        InsightsPageView(selectedTab: selection)
    }
}
