import SwiftUI
import FirebaseAuth

struct ChatDisplayView: View {
    let friend: Friend
    @ObservedObject var messagingManager: MessagingManager
    @ObservedObject var toastManager: ToastManager
    let onClose: () -> Void
    
    @State private var currentChat: Chat?
    @State private var isLoading = true
    @State private var loadingMessage = "Looking for existing chat..."
    
    private var currentUserId: String {
        Auth.auth().currentUser?.uid ?? ""
    }
    
    var body: some View {
        Group {
            if let chat = currentChat {
                NavigationView {
                    ChatView(chat: chat, messagingManager: messagingManager, toastManager: toastManager)
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarLeading) {
                                Button("Close") {
                                    onClose()
                                }
                            }
                        }
                }
            } else if isLoading {
                VStack(spacing: 20) {
                    ProgressView()
                        .scaleEffect(1.2)
                    
                    Text(loadingMessage)
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text("with \(friend.displayName)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .onAppear {
                    findOrCreateChat()
                }
            } else {
                VStack(spacing: 20) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 50))
                        .foregroundColor(.orange)
                    
                    Text("Failed to Load Chat")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Unable to open chat with \(friend.displayName)")
                        .font(.body)
                        .foregroundColor(.secondary)
                    
                    Button("Try Again") {
                        isLoading = true
                        findOrCreateChat()
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Close") {
                        onClose()
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
            }
        }
    }
    
    private func findOrCreateChat() {
        Task {
            // First check if chat already exists in local cache
            let existingLocalChat = messagingManager.chats.first { chat in
                chat.type == .direct && 
                chat.participants.count == 2 &&
                chat.participants.contains(where: { $0.uid == currentUserId }) &&
                chat.participants.contains(where: { $0.uid == friend.uid })
            }
            
            if let existingLocalChat = existingLocalChat {
                print("✅ Found existing local chat for \(friend.displayName)")
                await MainActor.run {
                    currentChat = existingLocalChat
                    isLoading = false
                }
                return
            }
            
            // Update loading message
            await MainActor.run {
                loadingMessage = "Creating chat..."
            }
            
            // Try to find or create chat
            if let chat = await messagingManager.createDirectChat(with: friend) {
                print("✅ Chat created/found for \(friend.displayName): \(chat.id)")
                await MainActor.run {
                    currentChat = chat
                    isLoading = false
                }
            } else {
                print("❌ Failed to create chat for \(friend.displayName)")
                await MainActor.run {
                    isLoading = false
                    toastManager.showError("Failed to create chat with \(friend.displayName)")
                }
            }
        }
    }
}

#Preview {
    ChatDisplayView(
        friend: Friend(
            uid: "123",
            username: "johndoe",
            displayName: "John Doe",
            email: "john@example.com"
        ),
        messagingManager: MessagingManager(),
        toastManager: ToastManager(),
        onClose: {}
    )
}
