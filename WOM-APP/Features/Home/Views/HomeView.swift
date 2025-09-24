import SwiftUI
import FirebaseAuth

struct HomeView: View {
    @State private var showingMessages = false
    @State private var showingNotifications = false
    @StateObject private var friendsManager = FriendsManager()
    @StateObject private var messagingViewModel = MessagingViewModel()

    private var unreadMessagesCount: Int {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return 0 }
        return messagingViewModel.messagingManager.chats.reduce(into: 0) { result, chat in
            result += chat.getUnreadCount(for: currentUserId)
        }
    }

    private var unreadMessagesBadgeText: String? {
        let count = unreadMessagesCount
        guard count > 0 else { return nil }
        return count > 99 ? "99+" : "\(count)"
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("Home")
                    .font(.largeTitle.bold())
                Text("This is the home tab")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Home")
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingNotifications = true
                    }) {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: "bell")
                                .font(.title2)
                            if friendsManager.incomingFriendRequests.count > 0 {
                                Text("\(friendsManager.incomingFriendRequests.count)")
                                    .font(.caption2.bold())
                                    .foregroundColor(.white)
                                    .padding(4)
                                    .background(Circle().fill(Color.red))
                                    .offset(x: 8, y: -6)
                            }
                        }
                    }
                    .accessibilityLabel("Notifications")

                    Button(action: {
                        showingMessages = true
                    }) {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: "paperplane")
                                .font(.title2)
                            if let badgeText = unreadMessagesBadgeText {
                                Text(badgeText)
                                    .font(.caption2.bold())
                                    .foregroundColor(.white)
                                    .padding(4)
                                    .background(Circle().fill(Color.red))
                                    .offset(x: 8, y: -6)
                            }
                        }
                    }
                    .accessibilityLabel("Messages")
                }
            }
            .sheet(isPresented: $showingMessages) {
                MessagesView()
            }
            .sheet(isPresented: $showingNotifications) {
                NotificationsView(friendsManager: friendsManager)
            }
        }
    }
}

struct NotificationsView: View {
    @ObservedObject var friendsManager: FriendsManager
    @Environment(\.dismiss) private var dismiss

    private var requests: [FriendRequest] {
        friendsManager.incomingFriendRequests
    }

    var body: some View {
        NavigationStack {
            Group {
                if requests.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "bell")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("You're all caught up!")
                            .font(.headline)
                        Text("Friend requests will appear here.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemGroupedBackground))
                } else {
                    List {
                        Section("Friend Requests") {
                            ForEach(requests) { request in
                                NotificationFriendRequestRow(
                                    request: request,
                                    friendsManager: friendsManager
                                )
                            }
                        }
                    }
                    .listStyle(InsetGroupedListStyle())
                }
            }
            .navigationTitle("Notifications")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .bold()
                }
            }
        }
    }
}

private struct NotificationFriendRequestRow: View {
    let request: FriendRequest
    @ObservedObject var friendsManager: FriendsManager

    private var isProcessing: Bool {
        friendsManager.loadingStates[request.id] == true
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                CachedAsyncImage(url: URL(string: request.fromProfileImageURL)) { image in
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
                .frame(width: 48, height: 48)
                .clipShape(Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text(request.fromDisplayName)
                        .font(.headline)
                    Text("@\(request.fromUsername)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("sent you a friend request")
                        .font(.subheadline)
                        .foregroundColor(.primary)
                }

                Spacer()
            }

            HStack(spacing: 12) {
                Button(role: .destructive) {
                    Task { await friendsManager.declineFriendRequest(request) }
                } label: {
                    Text("Decline")
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color(.systemGray5))
                        .foregroundColor(.red)
                        .cornerRadius(10)
                }
                .disabled(isProcessing)

                Button {
                    Task { await friendsManager.acceptFriendRequest(request) }
                } label: {
                    Text("Accept")
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .disabled(isProcessing)
            }
            if isProcessing {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                    .tint(.secondary)
            }
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    HomeView()
}
