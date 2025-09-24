import SwiftUI

struct FriendsView: View {
    @StateObject private var viewModel = FriendsViewModel()
    @State private var showingUserSearch = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Tab Picker
                Picker("Friends Tab", selection: $viewModel.selectedTab) {
                    Text("Friends (\(viewModel.friendsManager.friends.count))")
                        .tag(0)
                    Text("Requests (\(viewModel.friendsManager.incomingFriendRequests.count))")
                        .tag(1)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)
                .padding(.top, 8)
                
                // Content based on selected tab
                if viewModel.selectedTab == 0 {
                    friendsListView
                } else {
                    friendRequestsView
                }
            }
            .navigationTitle("Friends")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingUserSearch = true
                    }) {
                        Image(systemName: "person.badge.plus")
                    }
                }
            }
            .sheet(isPresented: $showingUserSearch) {
                UserSearchView(viewModel: viewModel)
            }
            .toast(viewModel.toastManager)
        }
    }
    
    private var friendsListView: some View {
        VStack {
            // Search bar for existing friends
            if !viewModel.friendsManager.friends.isEmpty {
                SearchBar(text: $viewModel.searchText, placeholder: "Search friends...")
                    .padding(.horizontal)
                    .padding(.top, 8)
            }
            
            if viewModel.friendsManager.friends.isEmpty {
                emptyFriendsView
            } else {
                List {
                    ForEach(viewModel.filteredFriends) { friend in
                        FriendRowView(
                            friend: friend,
                            friendsManager: viewModel.friendsManager,
                            toastManager: viewModel.toastManager
                        )
                    }
                }
                .listStyle(PlainListStyle())
            }
        }
    }
    
    private var friendRequestsView: some View {
        VStack {
            if viewModel.friendsManager.incomingFriendRequests.isEmpty {
                emptyRequestsView
            } else {
                List {
                    ForEach(viewModel.friendsManager.incomingFriendRequests) { request in
                        FriendRequestRowView(
                            request: request,
                            onAccept: {
                                viewModel.acceptFriendRequest(request)
                            },
                            onDecline: {
                                viewModel.declineFriendRequest(request)
                            },
                            friendsManager: viewModel.friendsManager
                        )
                    }
                }
                .listStyle(PlainListStyle())
            }
        }
    }
    
    private var emptyFriendsView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "person.2.circle")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No Friends Yet")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            Text("Start connecting with people by searching for users to add as friends.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button(action: {
                showingUserSearch = true
            }) {
                HStack {
                    Image(systemName: "person.badge.plus")
                    Text("Find Friends")
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
    
    private var emptyRequestsView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "person.crop.circle.badge.clock")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No Friend Requests")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            Text("When someone sends you a friend request, it will appear here.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Spacer()
        }
    }
}

struct FriendRowView: View {
    let friend: Friend
    @ObservedObject var friendsManager: FriendsManager
    @ObservedObject var toastManager: ToastManager

    var body: some View {
        NavigationLink(destination: FriendProfileView(
            friend: friend,
            friendsManager: friendsManager,
            toastManager: toastManager
        )) {
            friendRowContent
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var friendRowContent: some View {
        HStack(spacing: 12) {
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
                            .foregroundColor(.gray)
                    )
            }
            .frame(width: 50, height: 50)
            .clipShape(Circle())
            
            // User Info
            VStack(alignment: .leading, spacing: 4) {
                Text(friend.displayName)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text("@\(friend.username)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text("Friends since \(friend.dateAdded, style: .date)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Navigation chevron
            Image(systemName: "chevron.right")
                .foregroundColor(.gray.opacity(0.6))
                .font(.caption)
                .padding(.trailing, 8)
        }
        .padding(.vertical, 8)
    }
}

struct FriendRequestRowView: View {
    let request: FriendRequest
    let onAccept: () -> Void
    let onDecline: () -> Void
    @ObservedObject var friendsManager: FriendsManager
    
    private var isProcessing: Bool {
        friendsManager.loadingStates[request.id] == true
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Profile Image
            AsyncImage(url: URL(string: request.fromProfileImageURL)) { image in
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
            .frame(width: 50, height: 50)
            .clipShape(Circle())
            
            // User Info
            VStack(alignment: .leading, spacing: 4) {
                Text(request.fromDisplayName)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text("@\(request.fromUsername)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text("Sent \(request.createdAt, style: .relative)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Action buttons
            if isProcessing {
                ProgressView()
                    .scaleEffect(0.8)
                    .frame(width: 32, height: 32)
            } else {
                HStack(spacing: 8) {
                    Button(action: onDecline) {
                        Image(systemName: "xmark")
                            .foregroundColor(.white)
                            .font(.system(size: 14, weight: .semibold))
                            .frame(width: 32, height: 32)
                            .background(Color.red)
                            .clipShape(Circle())
                    }
                    .disabled(isProcessing)
                    
                    Button(action: onAccept) {
                        Image(systemName: "checkmark")
                            .foregroundColor(.white)
                            .font(.system(size: 14, weight: .semibold))
                            .frame(width: 32, height: 32)
                            .background(Color.green)
                            .clipShape(Circle())
                    }
                    .disabled(isProcessing)
                }
            }
        }
        .padding(.vertical, 8)
    }
}

struct SearchBar: View {
    @Binding var text: String
    let placeholder: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            
            TextField(placeholder, text: $text)
                .textFieldStyle(PlainTextFieldStyle())
            
            if !text.isEmpty {
                Button(action: {
                    text = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

#Preview {
    FriendsView()
}
