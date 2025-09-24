import Foundation
import FirebaseFirestore
import FirebaseAuth

class FriendsManager: ObservableObject {
    private let db = Firestore.firestore()
    
    @Published var friends: [Friend] = []
    @Published var incomingFriendRequests: [FriendRequest] = []
    @Published var outgoingFriendRequests: [FriendRequest] = []
    @Published var searchResults: [UserProfile] = []
    @Published var isLoading = false
    @Published var isSearching = false
    @Published var isSendingRequest = false
    @Published var isAcceptingRequest = false
    @Published var isDecliningRequest = false
    @Published var isRemovingFriend = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    
    // Track loading states for specific actions
    @Published var loadingStates: [String: Bool] = [:]
    
    init() {
        loadFriends()
        loadFriendRequests()
    }
    
    // MARK: - User Search
    func searchUsers(query: String) async {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            await MainActor.run {
                self.searchResults = []
            }
            return
        }
        
        await MainActor.run {
            self.objectWillChange.send()
            self.isSearching = true
            self.errorMessage = nil
        }
        
        do {
            // Search by username (case-insensitive)
            let usernameQuery = db.collection("users")
                .whereField("username", isGreaterThanOrEqualTo: query.lowercased())
                .whereField("username", isLessThan: query.lowercased() + "\u{f8ff}")
                .limit(to: 20)
            
            let usernameSnapshot = try await usernameQuery.getDocuments()
            
            // Search by display name (case-insensitive)
            let displayNameQuery = db.collection("users")
                .whereField("displayName", isGreaterThanOrEqualTo: query.lowercased())
                .whereField("displayName", isLessThan: query.lowercased() + "\u{f8ff}")
                .limit(to: 20)
            
            let displayNameSnapshot = try await displayNameQuery.getDocuments()
            
            let currentUserUID = Auth.auth().currentUser?.uid ?? ""
            
            // Process username results
            var usernameResults: [UserProfile] = []
            for document in usernameSnapshot.documents {
                let user = UserProfile.fromDictionary(document.data(), uid: document.documentID)
                if user.uid != currentUserUID {
                    usernameResults.append(user)
                }
            }
            
            // Process display name results (avoid duplicates)
            var displayNameResults: [UserProfile] = []
            for document in displayNameSnapshot.documents {
                let user = UserProfile.fromDictionary(document.data(), uid: document.documentID)
                if user.uid != currentUserUID,
                   !usernameResults.contains(where: { $0.uid == user.uid }) {
                    displayNameResults.append(user)
                }
            }
            
            let results = usernameResults + displayNameResults
            
            await MainActor.run {
                self.objectWillChange.send()
                self.searchResults = results
                self.isSearching = false
            }
            
        } catch {
            await MainActor.run {
                self.objectWillChange.send()
                self.errorMessage = "Failed to search users: \(error.localizedDescription)"
                self.isSearching = false
            }
        }
    }
    
    // MARK: - Friend Requests
    func sendFriendRequest(to user: UserProfile) async {
        guard let currentUser = Auth.auth().currentUser else {
            await MainActor.run {
                self.errorMessage = "You must be logged in to send friend requests"
            }
            return
        }
        
        await MainActor.run {
            self.objectWillChange.send()
            self.isSendingRequest = true
            self.loadingStates[user.uid] = true
            self.errorMessage = nil
            self.successMessage = nil
        }
        
        do {
            // Get current user's profile
            let currentUserDoc = try await db.collection("users").document(currentUser.uid).getDocument()
            guard let currentUserData = currentUserDoc.data() else {
                throw NSError(domain: "FriendsManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not load your profile"])
            }
            let currentUserProfile = UserProfile.fromDictionary(currentUserData, uid: currentUser.uid)
            
            let friendRequest = FriendRequest(
                fromUID: currentUser.uid,
                toUID: user.uid,
                fromUsername: currentUserProfile.username,
                fromDisplayName: currentUserProfile.displayName,
                fromEmail: currentUserProfile.email,
                fromProfileImageURL: currentUserProfile.profileImageURL
            )
            
            // Add to friend requests collection
            try await db.collection("friendRequests")
                .document(friendRequest.id)
                .setData(friendRequest.toDictionary())
            
            await MainActor.run {
                self.objectWillChange.send()
                self.outgoingFriendRequests.append(friendRequest)
                self.isSendingRequest = false
                self.loadingStates[user.uid] = false
                self.successMessage = "Friend request sent to \(user.displayName)!"
            }
            
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to send friend request: \(error.localizedDescription)"
                self.isSendingRequest = false
                self.loadingStates[user.uid] = false
            }
        }
    }
    
    func acceptFriendRequest(_ request: FriendRequest) async {
        guard let currentUser = Auth.auth().currentUser else { return }
        
        await MainActor.run {
            self.objectWillChange.send()
            self.isAcceptingRequest = true
            self.loadingStates[request.id] = true
            self.errorMessage = nil
            self.successMessage = nil
        }
        
        do {
            // Update friend request status
            try await db.collection("friendRequests")
                .document(request.id)
                .updateData([
                    "status": FriendRequestStatus.accepted.rawValue,
                    "updatedAt": Date().timeIntervalSince1970
                ])
            
            // Add to both users' friends collections
            let friend = Friend(
                uid: request.fromUID,
                username: request.fromUsername,
                displayName: request.fromDisplayName,
                email: request.fromEmail,
                profileImageURL: request.fromProfileImageURL
            )
            
            // Add friend to current user's friends
            try await db.collection("users")
                .document(currentUser.uid)
                .collection("friends")
                .document(request.fromUID)
                .setData(friend.toDictionary())
            
            // Get current user's profile to add to the other user's friends
            let currentUserDoc = try await db.collection("users").document(currentUser.uid).getDocument()
            guard let currentUserData = currentUserDoc.data() else {
                throw NSError(domain: "FriendsManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not load your profile"])
            }
            let currentUserProfile = UserProfile.fromDictionary(currentUserData, uid: currentUser.uid)
            
            let currentUserAsFriend = Friend.fromUserProfile(currentUserProfile)
            
            // Add current user to the other user's friends
            try await db.collection("users")
                .document(request.fromUID)
                .collection("friends")
                .document(currentUser.uid)
                .setData(currentUserAsFriend.toDictionary())
            
            await MainActor.run {
                self.objectWillChange.send()
                // Remove from incoming requests and add to friends
                self.incomingFriendRequests.removeAll { $0.id == request.id }
                if !self.friends.contains(where: { $0.uid == friend.uid }) {
                    self.friends.append(friend)
                }
                self.isAcceptingRequest = false
                self.loadingStates[request.id] = false
                self.successMessage = "You are now friends with \(request.fromDisplayName)!"
            }
            
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to accept friend request: \(error.localizedDescription)"
                self.isAcceptingRequest = false
                self.loadingStates[request.id] = false
            }
        }
    }
    
    func declineFriendRequest(_ request: FriendRequest) async {
        await MainActor.run {
            self.objectWillChange.send()
            self.isDecliningRequest = true
            self.loadingStates[request.id] = true
            self.errorMessage = nil
            self.successMessage = nil
        }
        
        do {
            try await db.collection("friendRequests")
                .document(request.id)
                .updateData([
                    "status": FriendRequestStatus.declined.rawValue,
                    "updatedAt": Date().timeIntervalSince1970
                ])
            
            await MainActor.run {
                self.objectWillChange.send()
                self.incomingFriendRequests.removeAll { $0.id == request.id }
                self.isDecliningRequest = false
                self.loadingStates[request.id] = false
                self.successMessage = "Friend request declined"
            }
            
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to decline friend request: \(error.localizedDescription)"
                self.isDecliningRequest = false
                self.loadingStates[request.id] = false
            }
        }
    }
    
    // MARK: - Load Data
    func loadFriends() {
        guard let currentUser = Auth.auth().currentUser else { return }
        
        db.collection("users")
            .document(currentUser.uid)
            .collection("friends")
            .addSnapshotListener { [weak self] snapshot, error in
                if let error = error {
                    DispatchQueue.main.async {
                        self?.errorMessage = "Failed to load friends: \(error.localizedDescription)"
                    }
                    return
                }
                
                let friends = snapshot?.documents.compactMap { document in
                    Friend.fromDictionary(document.data())
                } ?? []
                
                // Remove duplicates based on uid
                let uniqueFriends = Array(Set(friends.map { $0.uid })).compactMap { uid in
                    friends.first { $0.uid == uid }
                }
                
                DispatchQueue.main.async {
                    self?.objectWillChange.send()
                    self?.friends = uniqueFriends.sorted { $0.displayName < $1.displayName }
                }

                Task { [weak self] in
                    guard let strongSelf = self else { return }
                    let enriched = await strongSelf.enrichFriends(uniqueFriends)
                    await MainActor.run {
                        let currentIds = Set(strongSelf.friends.map { $0.uid })
                        let expectedIds = Set(uniqueFriends.map { $0.uid })
                        guard currentIds == expectedIds else { return }
                        strongSelf.objectWillChange.send()
                        strongSelf.friends = enriched.sorted { $0.displayName < $1.displayName }
                    }
                }
            }
    }
    
    func loadFriendRequests() {
        guard let currentUser = Auth.auth().currentUser else { return }
        
        // Load incoming friend requests
        db.collection("friendRequests")
            .whereField("toUID", isEqualTo: currentUser.uid)
            .whereField("status", isEqualTo: FriendRequestStatus.pending.rawValue)
            .addSnapshotListener { [weak self] snapshot, error in
                if let error = error {
                    DispatchQueue.main.async {
                        self?.errorMessage = "Failed to load incoming friend requests: \(error.localizedDescription)"
                    }
                    return
                }
                
                let requests = snapshot?.documents.compactMap { document in
                    FriendRequest.fromDictionary(document.data())
                } ?? []
                
                DispatchQueue.main.async {
                    self?.objectWillChange.send()
                    self?.incomingFriendRequests = requests
                }
            }
        
        // Load outgoing friend requests
        db.collection("friendRequests")
            .whereField("fromUID", isEqualTo: currentUser.uid)
            .whereField("status", isEqualTo: FriendRequestStatus.pending.rawValue)
            .addSnapshotListener { [weak self] snapshot, error in
                if let error = error {
                    DispatchQueue.main.async {
                        self?.errorMessage = "Failed to load outgoing friend requests: \(error.localizedDescription)"
                    }
                    return
                }
                
                let requests = snapshot?.documents.compactMap { document in
                    FriendRequest.fromDictionary(document.data())
                } ?? []
                
                DispatchQueue.main.async {
                    self?.objectWillChange.send()
                    self?.outgoingFriendRequests = requests
                }
            }
    }
    
    // MARK: - Helper Methods
    func isFriend(userUID: String) -> Bool {
        return friends.contains { $0.uid == userUID }
    }
    
    func hasPendingRequest(to userUID: String) -> Bool {
        return outgoingFriendRequests.contains { $0.toUID == userUID }
    }
    
    func hasPendingRequest(from userUID: String) -> Bool {
        return incomingFriendRequests.contains { $0.fromUID == userUID }
    }
    
    func removeFriend(_ friend: Friend) async {
        guard let currentUser = Auth.auth().currentUser else { return }
        
        await MainActor.run {
            self.objectWillChange.send()
            self.isRemovingFriend = true
            self.loadingStates[friend.uid] = true
            self.errorMessage = nil
            self.successMessage = nil
        }
        
        do {
            // Remove from current user's friends
            try await db.collection("users")
                .document(currentUser.uid)
                .collection("friends")
                .document(friend.uid)
                .delete()
            
            // Remove from the other user's friends
            try await db.collection("users")
                .document(friend.uid)
                .collection("friends")
                .document(currentUser.uid)
                .delete()
            
            await MainActor.run {
                self.objectWillChange.send()
                self.friends.removeAll { $0.uid == friend.uid }
                self.isRemovingFriend = false
                self.loadingStates[friend.uid] = false
                self.successMessage = "Removed \(friend.displayName) from friends"
            }
            
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to remove friend: \(error.localizedDescription)"
                self.isRemovingFriend = false
                self.loadingStates[friend.uid] = false
            }
        }
    }
}

extension FriendsManager {
    private func enrichFriends(_ friends: [Friend]) async -> [Friend] {
        let uids = Array(Set(friends.map { $0.uid })).filter { !$0.isEmpty }
        guard !uids.isEmpty else { return friends }
        var profiles: [String: UserProfile] = [:]
        let batchSize = 10
        var startIndex = 0
        do {
            while startIndex < uids.count {
                let endIndex = min(startIndex + batchSize, uids.count)
                let batch = Array(uids[startIndex..<endIndex])
                let snapshot = try await db.collection("users")
                    .whereField(FieldPath.documentID(), in: batch)
                    .getDocuments()
                for document in snapshot.documents {
                    profiles[document.documentID] = UserProfile.fromDictionary(document.data(), uid: document.documentID)
                }
                startIndex = endIndex
            }
        } catch {
            print("⚠️ Failed to enrich friend profiles: \(error.localizedDescription)")
            return friends
        }

        guard !profiles.isEmpty else { return friends }

        return friends.map { friend in
            guard let profile = profiles[friend.uid] else { return friend }
            return Friend(
                uid: profile.uid,
                username: profile.username.isEmpty ? friend.username : profile.username,
                displayName: profile.displayName.isEmpty ? friend.displayName : profile.displayName,
                email: profile.email.isEmpty ? friend.email : profile.email,
                profileImageURL: profile.profileImageURL.isEmpty ? friend.profileImageURL : profile.profileImageURL,
                dateAdded: friend.dateAdded
            )
        }
    }
}
