import SwiftUI

struct MessagesView: View {
    @StateObject private var viewModel = MessagingViewModel()
    @State private var showingNewChatOptions = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search bar
                if !viewModel.messagingManager.chats.isEmpty {
                    SharedSearchBar(text: $viewModel.searchText, placeholder: "Search conversations...")
                        .padding(.horizontal)
                        .padding(.top, 8)
                }
                
                // Chat list
                if viewModel.messagingManager.isLoading {
                    loadingView
                } else if viewModel.filteredChats.isEmpty {
                    emptyChatsView
                } else {
                    chatsList
                }
            }
            .navigationTitle("Messages")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingNewChatOptions = true
                    }) {
                        Image(systemName: "square.and.pencil")
                    }
                }
            }
            .actionSheet(isPresented: $showingNewChatOptions) {
                ActionSheet(
                    title: Text("New Message"),
                    buttons: [
                        .default(Text("New Direct Message")) {
                            viewModel.showingNewChatSheet = true
                        },
                        .default(Text("New Group Chat")) {
                            viewModel.showingGroupChatSheet = true
                        },
                        .cancel()
                    ]
                )
            }
            .sheet(isPresented: $viewModel.showingNewChatSheet) {
                NewDirectMessageView(viewModel: viewModel)
            }
            .sheet(isPresented: $viewModel.showingGroupChatSheet) {
                NewGroupChatView(viewModel: viewModel)
            }
            .toast(viewModel.toastManager)
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 20) {
            Spacer()
            ProgressView()
                .scaleEffect(1.2)
            Text("Loading conversations...")
                .font(.headline)
                .foregroundColor(.secondary)
            Spacer()
        }
    }
    
    private var emptyChatsView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "message.circle")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No Messages Yet")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            Text("Start a conversation with your friends or create a group chat.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button(action: {
                showingNewChatOptions = true
            }) {
                HStack {
                    Image(systemName: "plus")
                    Text("Start Messaging")
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 30)
                .padding(.vertical, 12)
                .background(Color.blue)
                .cornerRadius(25)
            }
            .padding(.top, 10)
            
            Spacer()
        }
    }
    
    private var chatsList: some View {
        List {
            ForEach(viewModel.filteredChats) { chat in
                Button(action: {
                    // Use button action instead of NavigationLink to avoid issues
                    viewModel.selectedChat = chat
                    viewModel.showingChatView = true
                }) {
                    ChatRowView(chat: chat, viewModel: viewModel)
                }
                .buttonStyle(PlainButtonStyle())
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        viewModel.deleteChat(chat)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
        .listStyle(PlainListStyle())
        .fullScreenCover(isPresented: $viewModel.showingChatView) {
            if let selectedChat = viewModel.selectedChat {
                NavigationView {
                    ChatView(chat: selectedChat, messagingManager: viewModel.messagingManager, toastManager: viewModel.toastManager)
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarLeading) {
                                Button("Close") {
                                    viewModel.showingChatView = false
                                    viewModel.selectedChat = nil
                                }
                            }
                        }
                }
            }
        }
    }
}

struct ChatRowView: View {
    let chat: Chat
    let viewModel: MessagingViewModel
    
    var body: some View {
        HStack(spacing: 12) {
            // Chat image
            AsyncImage(url: URL(string: viewModel.getChatDisplayImage(for: chat))) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Circle()
                    .fill(chat.type == .group ? Color.blue.opacity(0.3) : Color.gray.opacity(0.3))
                    .overlay(
                        Image(systemName: chat.type == .group ? "person.2.fill" : "person.fill")
                            .foregroundColor(chat.type == .group ? .blue : .gray)
                    )
            }
            .frame(width: 50, height: 50)
            .clipShape(Circle())
            
            // Chat info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(viewModel.getChatDisplayName(for: chat))
                        .font(.headline)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    Text(viewModel.formatLastMessageTime(for: chat))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text(viewModel.getLastMessagePreview(for: chat))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                    
                    Spacer()
                    
                    // Unread count badge
                    let unreadCount = viewModel.getUnreadCount(for: chat)
                    if unreadCount > 0 {
                        Text("\(unreadCount)")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue)
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .padding(.vertical, 8)
    }
}

struct NewDirectMessageView: View {
    @ObservedObject var viewModel: MessagingViewModel
    @ObservedObject var friendsManager = FriendsManager()
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    
    var body: some View {
        NavigationView {
            VStack {
                // Search bar
                SharedSearchBar(text: $searchText, placeholder: "Search friends...")
                    .padding(.horizontal)
                    .padding(.top, 8)
                
                // Friends list
                List {
                    ForEach(filteredFriends) { friend in
                        Button(action: {
                            dismiss()
                            viewModel.createDirectChat(with: friend)
                        }) {
                            HStack(spacing: 12) {
                                AsyncImage(url: URL(string: friend.profileImageURL)) { image in
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                } placeholder: {
                                    Circle()
                                        .fill(Color.gray.opacity(0.3))
                                        .overlay(
                                            Image(systemName: "person.fill")
                                                .foregroundColor(.gray)
                                        )
                                }
                                .frame(width: 40, height: 40)
                                .clipShape(Circle())
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(friend.displayName)
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    
                                    Text("@\(friend.username)")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .listStyle(PlainListStyle())
            }
            .navigationTitle("New Message")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var filteredFriends: [Friend] {
        if searchText.isEmpty {
            return friendsManager.friends
        }
        return friendsManager.friends.filter { friend in
            friend.displayName.localizedCaseInsensitiveContains(searchText) ||
            friend.username.localizedCaseInsensitiveContains(searchText)
        }
    }
}

struct NewGroupChatView: View {
    @ObservedObject var viewModel: MessagingViewModel
    @ObservedObject var friendsManager = FriendsManager()
    @Environment(\.dismiss) private var dismiss
    
    @State private var groupName = ""
    @State private var groupDescription = ""
    @State private var selectedFriends: Set<String> = []
    @State private var searchText = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Group details form
                Form {
                    Section("Group Details") {
                        TextField("Group Name", text: $groupName)
                        TextField("Description (optional)", text: $groupDescription, axis: .vertical)
                            .lineLimit(3)
                    }
                    
                    Section("Add Friends") {
                        SharedSearchBar(text: $searchText, placeholder: "Search friends...")
                        
                        ForEach(filteredFriends) { friend in
                            HStack(spacing: 12) {
                                AsyncImage(url: URL(string: friend.profileImageURL)) { image in
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                } placeholder: {
                                    Circle()
                                        .fill(Color.gray.opacity(0.3))
                                        .overlay(
                                            Image(systemName: "person.fill")
                                                .foregroundColor(.gray)
                                        )
                                }
                                .frame(width: 35, height: 35)
                                .clipShape(Circle())
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(friend.displayName)
                                        .font(.body)
                                        .foregroundColor(.primary)
                                    
                                    Text("@\(friend.username)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                if selectedFriends.contains(friend.uid) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.blue)
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if selectedFriends.contains(friend.uid) {
                                    selectedFriends.remove(friend.uid)
                                } else {
                                    selectedFriends.insert(friend.uid)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("New Group")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        createGroup()
                    }
                    .disabled(groupName.isEmpty || selectedFriends.isEmpty)
                }
            }
        }
    }
    
    private var filteredFriends: [Friend] {
        if searchText.isEmpty {
            return friendsManager.friends
        }
        return friendsManager.friends.filter { friend in
            friend.displayName.localizedCaseInsensitiveContains(searchText) ||
            friend.username.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    private func createGroup() {
        let selectedFriendObjects = friendsManager.friends.filter { selectedFriends.contains($0.uid) }
        
        viewModel.createGroupChat(
            name: groupName,
            participants: selectedFriendObjects,
            description: groupDescription.isEmpty ? nil : groupDescription
        )
    }
}

#Preview {
    MessagesView()
}
