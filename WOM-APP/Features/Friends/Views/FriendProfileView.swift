import SwiftUI

struct FriendProfileView: View {
    let friend: Friend
    @ObservedObject var friendsManager: FriendsManager
    @ObservedObject var toastManager: ToastManager
    @Environment(\.dismiss) private var dismiss
    @State private var showingRemoveAlert = false
    @State private var showingChat = false
    @StateObject private var messagingManager = MessagingManager()
    
    private var isRemoving: Bool {
        friendsManager.loadingStates[friend.uid] == true
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Header with profile image and basic info
                headerSection
                
                // Profile details
                profileDetailsSection
                
                // Actions section
                actionsSection
                
                Spacer(minLength: 50)
            }
        }
        .navigationTitle(friend.displayName)
        .navigationBarTitleDisplayMode(.large)
        .toast(toastManager)
        .alert("Remove Friend", isPresented: $showingRemoveAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Remove", role: .destructive) {
                removeFriend()
            }
        } message: {
            Text("Are you sure you want to remove \(friend.displayName) from your friends? This action cannot be undone.")
        }
        .fullScreenCover(isPresented: $showingChat) {
            ChatDisplayView(
                friend: friend,
                messagingManager: messagingManager,
                toastManager: toastManager,
                onClose: {
                    showingChat = false
                }
            )
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            // Profile Image
            AsyncImage(url: URL(string: friend.profileImageURL)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.gray)
                    )
            }
            .frame(width: 120, height: 120)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(Color.white, lineWidth: 4)
                    .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
            )
            
            // Name and username
            VStack(spacing: 4) {
                Text(friend.displayName)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text("@\(friend.username)")
                    .font(.headline)
                    .foregroundColor(.secondary)
            }
            
            // Friends since
            HStack(spacing: 4) {
                Image(systemName: "calendar")
                    .foregroundColor(.secondary)
                    .font(.caption)
                
                Text("Friends since \(friend.dateAdded, style: .date)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 30)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [Color.blue.opacity(0.1), Color.clear]),
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
    
    private var profileDetailsSection: some View {
        VStack(spacing: 16) {
            // Contact Information
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "person.text.rectangle")
                        .foregroundColor(.blue)
                        .font(.title2)
                    
                    Text("Contact Information")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Spacer()
                }
                .padding(.horizontal, 20)
                
                VStack(spacing: 0) {
                    // Email
                    HStack(spacing: 12) {
                        Image(systemName: "envelope.fill")
                            .foregroundColor(.gray)
                            .frame(width: 20)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Email")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text(friend.email)
                                .font(.body)
                                .foregroundColor(.primary)
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            if let url = URL(string: "mailto:\(friend.email)") {
                                UIApplication.shared.open(url)
                            }
                        }) {
                            Image(systemName: "square.and.arrow.up")
                                .foregroundColor(.blue)
                                .font(.caption)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    
                    Divider()
                        .padding(.horizontal, 20)
                    
                    // Username
                    HStack(spacing: 12) {
                        Image(systemName: "at")
                            .foregroundColor(.gray)
                            .frame(width: 20)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Username")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text("@\(friend.username)")
                                .font(.body)
                                .foregroundColor(.primary)
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            UIPasteboard.general.string = friend.username
                            toastManager.showSuccess("Username copied!")
                            // Haptic feedback
                            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                            impactFeedback.impactOccurred()
                        }) {
                            Image(systemName: "doc.on.doc")
                                .foregroundColor(.blue)
                                .font(.caption)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
                .padding(.horizontal, 20)
            }
        }
        .padding(.bottom, 20)
    }
    
    private var actionsSection: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "gear")
                    .foregroundColor(.blue)
                    .font(.title2)
                
                Text("Actions")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
            }
            .padding(.horizontal, 20)
            
            VStack(spacing: 12) {
                // Message Button
                Button(action: {
                    startDirectMessage()
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: "message.fill")
                            .foregroundColor(.white)
                            .font(.system(size: 16))
                            .frame(width: 32, height: 32)
                            .background(Color.blue)
                            .clipShape(Circle())
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Send Message")
                                .font(.body)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                            
                            Text("Start a conversation")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .foregroundColor(.gray)
                            .font(.caption)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
                }
                .buttonStyle(PlainButtonStyle())
                
                // Remove Friend Button
                Button(action: {
                    showingRemoveAlert = true
                }) {
                    HStack(spacing: 12) {
                        if isRemoving {
                            ProgressView()
                                .scaleEffect(0.8)
                                .frame(width: 32, height: 32)
                        } else {
                            Image(systemName: "person.badge.minus")
                                .foregroundColor(.white)
                                .font(.system(size: 16))
                                .frame(width: 32, height: 32)
                                .background(Color.red)
                                .clipShape(Circle())
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Remove Friend")
                                .font(.body)
                                .fontWeight(.medium)
                                .foregroundColor(isRemoving ? .secondary : .primary)
                            
                            Text("End this friendship")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        if !isRemoving {
                            Image(systemName: "chevron.right")
                                .foregroundColor(.gray)
                                .font(.caption)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(isRemoving)
            }
            .padding(.horizontal, 20)
        }
        .padding(.bottom, 30)
    }
    
    private func startDirectMessage() {
        print("🚀 Starting direct message with \(friend.displayName) (UID: \(friend.uid))")
        
        Task {
            // Always try to find or create the chat first
            if let chat = await messagingManager.createDirectChat(with: friend) {
                print("✅ Chat ready: \(chat.id)")
                await MainActor.run {
                    showingChat = true
                }
            } else {
                print("❌ Failed to create/find chat")
                await MainActor.run {
                    toastManager.showError("Failed to open chat. Please try again.")
                }
            }
        }
    }
    
    private func checkForChatPeriodically() {
        var attempts = 0
        let maxAttempts = 10
        
        func checkForChat() {
            attempts += 1
            
            if messagingManager.chats.first(where: { chat in
                chat.type == .direct && chat.isParticipant(userId: friend.uid)
            }) != nil {
                // Chat found, the view will update automatically
                return
            }
            
            if attempts < maxAttempts {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    checkForChat()
                }
            } else {
                // Max attempts reached, show error
                showingChat = false
                toastManager.showError("Failed to load chat. Please try again.")
            }
        }
        
        checkForChat()
    }
    
    private func removeFriend() {
        // Haptic feedback for destructive action
        let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
        impactFeedback.impactOccurred()
        
        Task {
            await friendsManager.removeFriend(friend)
            // Navigate back after successful removal
            await MainActor.run {
                dismiss()
            }
        }
    }
}

#Preview {
    NavigationView {
        FriendProfileView(
            friend: Friend(
                uid: "123",
                username: "johndoe",
                displayName: "John Doe",
                email: "john@example.com",
                profileImageURL: ""
            ),
            friendsManager: FriendsManager(),
            toastManager: ToastManager()
        )
    }
}

