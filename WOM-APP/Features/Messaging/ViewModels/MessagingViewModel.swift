import Foundation
import FirebaseAuth
import Combine

@MainActor
class MessagingViewModel: ObservableObject {
    let messagingManager = MessagingManager()
    @Published var toastManager = ToastManager()
    @Published var searchText = ""
    @Published var showingNewChatSheet = false
    @Published var showingGroupChatSheet = false
    @Published var showingChatView = false
    @Published var selectedChat: Chat?
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        setupMessageObservers()
        setupMessagingManagerObservation()
    }
    
    private func setupMessagingManagerObservation() {
        // Forward all MessagingManager published changes to trigger UI updates
        messagingManager.objectWillChange
            .sink { [weak self] in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }
    
    private func setupMessageObservers() {
        // Listen for success messages
        messagingManager.$successMessage
            .compactMap { $0 }
            .sink { [weak self] message in
                self?.toastManager.showSuccess(message)
                // Clear the message after showing toast
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self?.messagingManager.successMessage = nil
                }
            }
            .store(in: &cancellables)
        
        // Listen for error messages
        messagingManager.$errorMessage
            .compactMap { $0 }
            .sink { [weak self] message in
                self?.toastManager.showError(message)
                // Clear the message after showing toast
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self?.messagingManager.errorMessage = nil
                }
            }
            .store(in: &cancellables)
    }
    
    var filteredChats: [Chat] {
        if searchText.isEmpty {
            return messagingManager.chats
        }
        
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            return []
        }
        
        return messagingManager.chats.filter { chat in
            let displayName = messagingManager.getChatDisplayName(for: chat, currentUserId: currentUserId)
            return displayName.localizedCaseInsensitiveContains(searchText) ||
                   chat.participants.contains { participant in
                       participant.displayName.localizedCaseInsensitiveContains(searchText) ||
                       participant.username.localizedCaseInsensitiveContains(searchText)
                   }
        }
    }
    
    func createDirectChat(with friend: Friend) {
        // First check if chat already exists
        if let existingChat = messagingManager.chats.first(where: { chat in
            chat.type == .direct && chat.isParticipant(userId: friend.uid)
        }) {
            // Chat already exists, open it
            selectedChat = existingChat
            showingChatView = true
            toastManager.showInfo("Opening existing chat with \(friend.displayName)")
            return
        }
        
        // Create new chat
        Task {
            if let newChat = await messagingManager.createDirectChat(with: friend) {
                await MainActor.run {
                    selectedChat = newChat
                    showingChatView = true
                }
            } else {
                await MainActor.run {
                    toastManager.showError("Failed to create chat with \(friend.displayName)")
                }
            }
        }
    }
    
    func createGroupChat(name: String, participants: [Friend], description: String? = nil) {
        Task {
            if await messagingManager.createGroupChat(name: name, participants: participants, description: description) != nil {
                showingGroupChatSheet = false
            }
        }
    }
    
    func deleteChat(_ chat: Chat) {
        Task {
            await messagingManager.leaveChat(chat.id)
        }
    }
    
    func getChatDisplayName(for chat: Chat) -> String {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            return chat.displayName
        }
        return messagingManager.getChatDisplayName(for: chat, currentUserId: currentUserId)
    }
    
    func getChatDisplayImage(for chat: Chat) -> String {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            return chat.displayImage
        }
        return messagingManager.getChatDisplayImage(for: chat, currentUserId: currentUserId)
    }
    
    func getLastMessagePreview(for chat: Chat) -> String {
        guard let lastMessage = chat.lastMessage else {
            return "No messages yet"
        }
        
        switch lastMessage.type {
        case .text:
            return lastMessage.content
        case .image:
            return "📷 Image"
        case .system:
            return lastMessage.content
        }
    }
    
    func getUnreadCount(for chat: Chat) -> Int {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            return 0
        }
        return chat.getUnreadCount(for: currentUserId)
    }
    
    func formatLastMessageTime(for chat: Chat) -> String {
        guard let lastMessage = chat.lastMessage else {
            return ""
        }
        
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: lastMessage.timestamp, relativeTo: Date())
    }
}
