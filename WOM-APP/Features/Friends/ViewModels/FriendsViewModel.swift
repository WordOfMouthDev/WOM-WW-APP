import Foundation
import FirebaseAuth
import Combine

@MainActor
class FriendsViewModel: ObservableObject {
    @Published var searchText = ""
    @Published var showingUserSearch = false
    @Published var selectedTab = 0 // 0: Friends, 1: Requests
    @Published var toastManager = ToastManager()
    
    // Make friendsManager ObservedObject to ensure proper reactivity
    let friendsManager = FriendsManager()
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        setupToastObservers()
        setupFriendsManagerObservation()
    }
    
    private func setupFriendsManagerObservation() {
        // Forward all FriendsManager published changes to trigger UI updates
        friendsManager.objectWillChange
            .sink { [weak self] in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }
    
    private func setupToastObservers() {
        // Listen for success messages
        friendsManager.$successMessage
            .compactMap { $0 }
            .sink { [weak self] message in
                self?.toastManager.showSuccess(message)
                // Clear the message after showing toast
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self?.friendsManager.successMessage = nil
                }
            }
            .store(in: &cancellables)
        
        // Listen for error messages
        friendsManager.$errorMessage
            .compactMap { $0 }
            .sink { [weak self] message in
                self?.toastManager.showError(message)
                // Clear the message after showing toast
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self?.friendsManager.errorMessage = nil
                }
            }
            .store(in: &cancellables)
    }
    
    var filteredFriends: [Friend] {
        if searchText.isEmpty {
            return friendsManager.friends
        }
        return friendsManager.friends.filter { friend in
            friend.username.localizedCaseInsensitiveContains(searchText) ||
            friend.displayName.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    func searchUsers() {
        Task {
            await friendsManager.searchUsers(query: searchText)
        }
    }
    
    func sendFriendRequest(to user: UserProfile) {
        // Immediately update loading state for instant UI feedback
        friendsManager.loadingStates[user.uid] = true
        friendsManager.isSendingRequest = true
        objectWillChange.send()
        
        Task {
            await friendsManager.sendFriendRequest(to: user)
            // Force UI update
            await MainActor.run {
                self.objectWillChange.send()
            }
        }
    }
    
    func acceptFriendRequest(_ request: FriendRequest) {
        // Immediately update loading state for instant UI feedback
        friendsManager.loadingStates[request.id] = true
        friendsManager.isAcceptingRequest = true
        objectWillChange.send()
        
        Task {
            await friendsManager.acceptFriendRequest(request)
            // Force UI update
            await MainActor.run {
                self.objectWillChange.send()
            }
        }
    }
    
    func declineFriendRequest(_ request: FriendRequest) {
        // Immediately update loading state for instant UI feedback
        friendsManager.loadingStates[request.id] = true
        friendsManager.isDecliningRequest = true
        objectWillChange.send()
        
        Task {
            await friendsManager.declineFriendRequest(request)
            // Force UI update
            await MainActor.run {
                self.objectWillChange.send()
            }
        }
    }
    
    func removeFriend(_ friend: Friend) {
        // Immediately update loading state for instant UI feedback
        friendsManager.loadingStates[friend.uid] = true
        friendsManager.isRemovingFriend = true
        objectWillChange.send()
        
        Task {
            await friendsManager.removeFriend(friend)
            // Force UI update
            await MainActor.run {
                self.objectWillChange.send()
            }
        }
    }
    
    func clearSearch() {
        searchText = ""
        friendsManager.searchResults = []
    }
}
