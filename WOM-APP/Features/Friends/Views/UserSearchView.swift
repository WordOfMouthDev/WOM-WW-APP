import SwiftUI

struct UserSearchView: View {
    @ObservedObject var viewModel: FriendsViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search bar
                SharedSearchBar(text: $searchText, placeholder: "Search by username or name...")
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .onChange(of: searchText) { _, newValue in
                        if !newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Task {
                                // Small delay to avoid too many searches while typing
                                try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
                                if searchText == newValue { // Only search if text hasn't changed
                                    await viewModel.friendsManager.searchUsers(query: newValue)
                                }
                            }
                        } else {
                            viewModel.friendsManager.searchResults = []
                        }
                    }
                
                // Search results
                if viewModel.friendsManager.isSearching {
                    loadingView
                } else if searchText.isEmpty {
                    emptySearchView
                } else if viewModel.friendsManager.searchResults.isEmpty {
                    noResultsView
                } else {
                    searchResultsList
                }
            }
            .navigationTitle("Find Friends")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .toast(viewModel.toastManager)
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 20) {
            Spacer()
            ProgressView()
                .scaleEffect(1.2)
            Text("Searching...")
                .font(.headline)
                .foregroundColor(.secondary)
            Spacer()
        }
    }
    
    private var emptySearchView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "magnifyingglass.circle")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("Search for Friends")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            Text("Enter a username or display name to find people you know.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Spacer()
        }
    }
    
    private var noResultsView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "person.crop.circle.badge.questionmark")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No Results")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            Text("No users found matching '\(searchText)'. Try a different search term.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Spacer()
        }
    }
    
    private var searchResultsList: some View {
        List {
            ForEach(viewModel.friendsManager.searchResults, id: \.uid) { user in
                UserSearchRowView(
                    user: user,
                    friendsManager: viewModel.friendsManager,
                    onSendRequest: {
                        viewModel.sendFriendRequest(to: user)
                    },
                    toastManager: viewModel.toastManager
                )
            }
        }
        .listStyle(PlainListStyle())
    }
}

struct UserSearchRowView: View {
    let user: UserProfile
    let friendsManager: FriendsManager
    let onSendRequest: () -> Void
    @ObservedObject var toastManager: ToastManager
    
    private var isLoading: Bool {
        friendsManager.loadingStates[user.uid] == true
    }
    
    private var relationshipStatus: RelationshipStatus {
        if friendsManager.isFriend(userUID: user.uid) {
            return .friend
        } else if friendsManager.hasPendingRequest(to: user.uid) {
            return .requestSent
        } else if friendsManager.hasPendingRequest(from: user.uid) {
            return .requestReceived
        } else {
            return .none
        }
    }
    
    var body: some View {
        Group {
            if relationshipStatus == .friend,
               let friend = friendsManager.friends.first(where: { $0.uid == user.uid }) {
                // If they're already friends, make it navigatable to their profile
                NavigationLink(destination: FriendProfileView(
                    friend: friend,
                    friendsManager: friendsManager,
                    toastManager: toastManager
                )) {
                    userRowContent
                }
                .buttonStyle(PlainButtonStyle())
            } else {
                // If not friends, just show the regular row
                userRowContent
            }
        }
    }
    
    private var userRowContent: some View {
        HStack(spacing: 12) {
            // Profile Image
            AsyncImage(url: URL(string: user.profileImageURL)) { image in
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
                Text(user.displayName)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text("@\(user.username)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                if !user.email.isEmpty {
                    Text(user.email)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Show chevron for friends to indicate they're tappable
            if relationshipStatus == .friend {
                Image(systemName: "chevron.right")
                    .foregroundColor(.gray.opacity(0.6))
                    .font(.caption)
                    .padding(.trailing, 8)
            }
            
            // Action button based on relationship status
            relationshipButton
        }
        .padding(.vertical, 8)
    }
    
    @ViewBuilder
    private var relationshipButton: some View {
        switch relationshipStatus {
        case .none:
            Button(action: onSendRequest) {
                HStack(spacing: 4) {
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                            .foregroundColor(.white)
                    } else {
                        Image(systemName: "person.badge.plus")
                        Text("Add")
                    }
                }
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isLoading ? Color.blue.opacity(0.6) : Color.blue)
                .cornerRadius(20)
            }
            .disabled(isLoading)
            
        case .friend:
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                Text("Friends")
            }
            .font(.subheadline)
            .fontWeight(.semibold)
            .foregroundColor(.green)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.green.opacity(0.1))
            .cornerRadius(20)
            
        case .requestSent:
            HStack(spacing: 4) {
                Image(systemName: "clock")
                Text("Sent")
            }
            .font(.subheadline)
            .fontWeight(.semibold)
            .foregroundColor(.orange)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.orange.opacity(0.1))
            .cornerRadius(20)
            
        case .requestReceived:
            HStack(spacing: 4) {
                Image(systemName: "person.crop.circle.badge.clock")
                Text("Pending")
            }
            .font(.subheadline)
            .fontWeight(.semibold)
            .foregroundColor(.purple)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.purple.opacity(0.1))
            .cornerRadius(20)
        }
    }
}

private enum RelationshipStatus {
    case none
    case friend
    case requestSent
    case requestReceived
}

#Preview {
    UserSearchView(viewModel: FriendsViewModel())
}
