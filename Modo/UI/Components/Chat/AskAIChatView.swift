import SwiftUI
import SwiftData

/// A simple Ask AI view with chat history
struct AskAIChatView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @Binding var messages: [SimpleMessage] // Use binding to persist messages
    @State private var inputText: String = ""
    @State private var isLoading: Bool = false
    @FocusState private var isInputFocused: Bool
    
    private let openAIService = OpenAIService.shared
    
    // ✅ Use AIPromptBuilder for unified prompt construction
    private let promptBuilder = AIPromptBuilder()
    
    struct SimpleMessage: Identifiable, Codable {
        let id: UUID
        let content: String
        let isFromUser: Bool
        
        init(id: UUID = UUID(), content: String, isFromUser: Bool) {
            self.id = id
            self.content = content
            self.isFromUser = isFromUser
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // MARK: - Chat History
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            // Show chat history
                            ForEach(messages) { message in
                                if message.isFromUser {
                                    // User message
                                    Text(message.content)
                                        .font(.system(size: 16))
                                        .foregroundColor(Color(hexString: "1F2937"))
                                        .padding(16)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(Color(hexString: "DDD6FE"))
                                        .cornerRadius(12)
                                        .id(message.id)
                                } else {
                                    // AI response
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Modo Assistant")
                                            .font(.system(size: 16, weight: .bold))
                                            .foregroundColor(Color(hexString: "8B5CF6"))
                                        
                                        Text(message.content)
                                            .font(.system(size: 16))
                                            .foregroundColor(Color(hexString: "1F2937"))
                                    }
                                    .padding(16)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color(hexString: "F3F4F6"))
                                    .cornerRadius(12)
                                    .id(message.id)
                                }
                            }
                            
                            // Loading indicator
                            if isLoading {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Modo Assistant")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(Color(hexString: "8B5CF6"))
                                    
                                    Text("...")
                                        .font(.system(size: 16))
                                        .foregroundColor(Color(hexString: "6B7280"))
                                }
                                .padding(16)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(hexString: "F3F4F6"))
                                .cornerRadius(12)
                                .id("loading")
                            }
                            
                            // Empty state
                            if messages.isEmpty && !isLoading {
                                VStack(alignment: .center, spacing: 12) {
                                    Image(systemName: "brain.head.profile")
                                        .font(.system(size: 48))
                                        .foregroundColor(Color(hexString: "8B5CF6").opacity(0.3))
                                    
                                    Text("Ask me anything about fitness, nutrition, or healthy living!")
                                        .font(.system(size: 16))
                                        .foregroundColor(Color(hexString: "6B7280"))
                                        .multilineTextAlignment(.center)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.top, 60)
                            }
                        }
                        .padding(24)
                    }
                    .background(Color.white)
                    .onChange(of: messages.count) { _, _ in
                        if let lastMessage = messages.last {
                            withAnimation {
                                proxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                    .onChange(of: isLoading) { _, loading in
                        if loading {
                            withAnimation {
                                proxy.scrollTo("loading", anchor: .bottom)
                            }
                        }
                    }
                }
                .background(Color.white)
                
                // MARK: - Input Area
                VStack(spacing: 0) {
                    Divider()
                        .background(Color(hexString: "E5E7EB"))
                    
                    HStack(spacing: 12) {
                        TextField("Ask about fitness, nutrition, tasks...", text: $inputText, axis: .vertical)
                            .lineLimit(1...4)
                            .font(.system(size: 16))
                            .padding(12)
                            .background(Color(hexString: "F3F4F6"))
                            .cornerRadius(20)
                            .focused($isInputFocused)
                        
                        Button(action: sendMessage) {
                            Image(systemName: "paperplane.fill")
                                .foregroundColor(.white)
                                .frame(width: 40, height: 40)
                                .background(
                                    inputText.isEmpty || isLoading ? Color.gray.opacity(0.5) : Color(hexString: "8B5CF6")
                                )
                                .clipShape(Circle())
                        }
                        .disabled(inputText.isEmpty || isLoading)
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                    .background(Color.white)
                }
            }
            .navigationTitle("Ask AI")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(Color(hexString: "9CA3AF"))
                    }
                }
            }
        }
    }
    
    // MARK: - Send Message
    private func sendMessage() {
        let trimmedText = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }
        
        let questionText = trimmedText
        inputText = ""
        isInputFocused = false
        
        // Add user message to history
        let userMessage = SimpleMessage(content: questionText, isFromUser: true)
        messages.append(userMessage)
        isLoading = true
        
        Task {
            do {
                // ✅ Get user profile for personalization
                let userProfile: UserProfile? = {
                    let fetchDescriptor = FetchDescriptor<UserProfile>()
                    return try? modelContext.fetch(fetchDescriptor).first
                }()
                
                // ✅ Use AIPromptBuilder for unified prompt construction
                let systemPrompt = promptBuilder.buildSystemPrompt(userProfile: userProfile)
                
                // Build conversation history
                var apiMessages: [ChatCompletionRequest.Message] = [
                    ChatCompletionRequest.Message(role: "system", content: systemPrompt)
                ]
                
                // Add recent chat history (last 8 messages)
                let recentMessages = messages.suffix(9).dropLast() // Exclude current message
                for msg in recentMessages {
                    apiMessages.append(ChatCompletionRequest.Message(
                        role: msg.isFromUser ? "user" : "assistant",
                        content: msg.content
                    ))
                }
                
                // Add current user message
                apiMessages.append(ChatCompletionRequest.Message(
                    role: "user",
                    content: questionText
                ))
                
                let response = try await openAIService.sendChatRequest(
                    messages: apiMessages,
                    functions: nil,
                    functionCall: nil
                )
                
                await MainActor.run {
                    isLoading = false
                    if let content = response.choices.first?.message.content {
                        let aiMessage = SimpleMessage(content: content, isFromUser: false)
                        messages.append(aiMessage)
                    } else {
                        let errorMessage = SimpleMessage(content: "Sorry, I couldn't generate a response. Please try again.", isFromUser: false)
                        messages.append(errorMessage)
                    }
                }
                
            } catch {
                await MainActor.run {
                    isLoading = false
                    let errorMessage = SimpleMessage(content: "Sorry, I encountered an error. Please try again.", isFromUser: false)
                    messages.append(errorMessage)
                }
            }
        }
    }
    
    // ✅ buildSystemPrompt() and getUserProfile() removed - now using AIPromptBuilder.buildSystemPrompt()
}

// MARK: - Preview
#Preview {
    struct PreviewWrapper: View {
        @State private var messages: [AskAIChatView.SimpleMessage] = []
        
        var body: some View {
            AskAIChatView(messages: $messages)
        }
    }
    
    return PreviewWrapper()
}

