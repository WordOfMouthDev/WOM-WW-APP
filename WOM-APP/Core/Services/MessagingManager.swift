import Foundation
import FirebaseFirestore
import FirebaseAuth
import FirebaseStorage
import FirebaseCore
import Combine

class MessagingManager: ObservableObject {
    private let db = Firestore.firestore()
    
    @Published var chats: [Chat] = []
    @Published var messages: [Message] = []
    @Published var isLoading = false
    @Published var isSendingMessage = false
    @Published var isUploadingAttachment = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    @Published var isLoadingInitial = false
    @Published var isLoadingOlder = false
    @Published var hasMoreOlder = true
    @Published var typingUsernames: [String] = []
    @Published var unreadCount: Int = 0
    @Published var firstUnreadMessageId: String?
    
    let pageSize = 30
    private let newMessageDebounceInterval: TimeInterval = 0.1
    
    // Real-time listeners
    private var chatsListener: ListenerRegistration?
    private var messagesListener: ListenerRegistration?
    private var typingListener: ListenerRegistration?
    private var currentChatId: String?
    
    private var cancellables = Set<AnyCancellable>()
    private var oldestSnapshot: DocumentSnapshot?
    private var latestSnapshot: DocumentSnapshot?
    private var messageIndex: [String: Message] = [:]
    private var pendingRealtimePayloads: [(Message, DocumentChangeType)] = []
    private var coalesceWorkItem: DispatchWorkItem?
    private var lastKnownReadTimestamp: TimeInterval?
    
    init() {
        loadUserChats()
    }
    
    deinit {
        chatsListener?.remove()
        messagesListener?.remove()
        typingListener?.remove()
        coalesceWorkItem?.cancel()
    }
    
    // MARK: - Chat Management
    
    func loadUserChats() {
        guard let currentUser = Auth.auth().currentUser else { return }
        
        // Remove existing listener
        chatsListener?.remove()
        
        // Listen for chats where current user is a participant
        // We'll store participant UIDs in a separate array for easier querying
        chatsListener = db.collection("chats")
            .whereField("participantUIDs", arrayContains: currentUser.uid)
            .order(by: "lastActivity", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                if let error = error {
                    DispatchQueue.main.async {
                        self?.errorMessage = "Failed to load chats: \(error.localizedDescription)"
                    }
                    return
                }
                
                let allChats: [Chat] = snapshot?.documents.compactMap { document in
                    var data = document.data()
                    data["id"] = document.documentID
                    return Chat.fromDictionary(data)
                } ?? []
                
                // Remove duplicates based on chat ID and sort by last activity
                let uniqueChats = Array(Set(allChats.map { $0.id })).compactMap { chatId in
                    allChats.first { $0.id == chatId }
                }.sorted { $0.lastActivity > $1.lastActivity }
                
                // Debug: Log duplicate removal
                if allChats.count != uniqueChats.count {
                    print("🔍 Removed \(allChats.count - uniqueChats.count) duplicate chats")
                }
                
                DispatchQueue.main.async {
                    self?.objectWillChange.send()
                    self?.chats = uniqueChats
                }

                Task { [weak self] in
                    guard let self else { return }
                    let enrichedChats = await self.enrichChats(uniqueChats)
                    await MainActor.run {
                        let currentIds = Set(self.chats.map { $0.id })
                        let expectedIds = Set(uniqueChats.map { $0.id })
                        guard currentIds == expectedIds else { return }
                        self.objectWillChange.send()
                        self.chats = enrichedChats.sorted { $0.lastActivity > $1.lastActivity }
                    }
                }
            }
    }
    
    func createDirectChat(with friend: Friend) async -> Chat? {
        guard let currentUser = Auth.auth().currentUser else {
            await MainActor.run {
                self.errorMessage = "You must be logged in to create chats"
            }
            return nil
        }
        
        await MainActor.run {
            self.isLoading = true
            self.errorMessage = nil
        }
        
        // Check if a direct chat already exists between these users
        if let existingChat = await findExistingDirectChat(with: friend.uid) {
            await MainActor.run {
                self.isLoading = false
            }
            return existingChat
        }
        
        do {
            let currentUserProfile = try await loadUserProfile(for: currentUser.uid)
            
            // Create participants
            let participants = [
                ChatParticipant(
                    uid: currentUser.uid,
                    username: currentUserProfile.username,
                    displayName: currentUserProfile.displayName,
                    profileImageURL: currentUserProfile.profileImageURL
                ),
                ChatParticipant(
                    uid: friend.uid,
                    username: friend.username,
                    displayName: friend.displayName,
                    profileImageURL: friend.profileImageURL
                )
            ]
            
            let chat = Chat(
                type: .direct,
                participants: participants,
                createdBy: currentUser.uid
            )
            
            // Save to Firestore
            try await db.collection("chats").document(chat.id).setData(chat.toDictionary())
            
            await MainActor.run {
                self.isLoading = false
                self.successMessage = "Chat created successfully"
            }
            
            return chat
            
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to create chat: \(error.localizedDescription)"
                self.isLoading = false
            }
            return nil
        }
    }
    
    func createGroupChat(name: String, participants: [Friend], description: String? = nil) async -> Chat? {
        guard let currentUser = Auth.auth().currentUser else {
            await MainActor.run {
                self.errorMessage = "You must be logged in to create group chats"
            }
            return nil
        }
        
        await MainActor.run {
            self.isLoading = true
            self.errorMessage = nil
        }
        
        do {
            let currentUserProfile = try await loadUserProfile(for: currentUser.uid)
            
            // Create participants (including current user as admin)
            var chatParticipants = [
                ChatParticipant(
                    uid: currentUser.uid,
                    username: currentUserProfile.username,
                    displayName: currentUserProfile.displayName,
                    profileImageURL: currentUserProfile.profileImageURL,
                    isAdmin: true
                )
            ]
            
            // Add other participants
            for friend in participants {
                chatParticipants.append(
                    ChatParticipant(
                        uid: friend.uid,
                        username: friend.username,
                        displayName: friend.displayName,
                        profileImageURL: friend.profileImageURL
                    )
                )
            }
            
            let chat = Chat(
                type: .group,
                participants: chatParticipants,
                createdBy: currentUser.uid,
                name: name,
                description: description
            )
            
            // Save to Firestore
            try await db.collection("chats").document(chat.id).setData(chat.toDictionary())
            
            // Send system message about chat creation
            let systemMessage = Message(
                chatId: chat.id,
                senderId: "system",
                senderName: "System",
                senderUsername: "system",
                content: "\(currentUserProfile.displayName) created the group",
                type: .system,
                status: .sent
            )
            
            try await db.collection("chats").document(chat.id)
                .collection("messages").document(systemMessage.id)
                .setData(systemMessage.toDictionary())
            
            await MainActor.run {
                self.isLoading = false
                self.successMessage = "Group chat created successfully"
            }
            
            return chat
            
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to create group chat: \(error.localizedDescription)"
                self.isLoading = false
            }
            return nil
        }
    }
    
    private func findExistingDirectChat(with userId: String) async -> Chat? {
        guard let currentUser = Auth.auth().currentUser else { return nil }
        
        print("🔍 Looking for existing chat between \(currentUser.uid) and \(userId)")
        print("🔍 Current chats count: \(chats.count)")
        
        // First check in local chats array
        let localChat = chats.first { chat in
            let isDirectChat = chat.type == .direct
            let hasTwoParticipants = chat.participants.count == 2
            let hasCurrentUser = chat.participants.contains(where: { $0.uid == currentUser.uid })
            let hasOtherUser = chat.participants.contains(where: { $0.uid == userId })
            
            print("🔍 Checking chat \(chat.id): direct=\(isDirectChat), participants=\(chat.participants.count), hasCurrentUser=\(hasCurrentUser), hasOtherUser=\(hasOtherUser)")
            
            return isDirectChat && hasTwoParticipants && hasCurrentUser && hasOtherUser
        }
        
        if let localChat = localChat {
            print("✅ Found existing local chat: \(localChat.id)")
            return localChat
        }
        
        // If not found locally, query Firestore
        print("🔍 Querying Firestore for existing chat...")
        do {
            let snapshot = try await db.collection("chats")
                .whereField("type", isEqualTo: "direct")
                .whereField("participantUIDs", arrayContains: currentUser.uid)
                .getDocuments()
            
            print("🔍 Found \(snapshot.documents.count) direct chats in Firestore")
            
            for document in snapshot.documents {
                var data = document.data()
                data["id"] = document.documentID
                
                print("🔍 Checking Firestore chat \(document.documentID)")
                
                if let chat = Chat.fromDictionary(data),
                   chat.participants.count == 2,
                   chat.participants.contains(where: { $0.uid == userId }) {
                    
                    print("✅ Found existing Firestore chat: \(chat.id)")
                    
                    // Add to local chats to avoid future duplicate queries
                    await MainActor.run {
                        if !self.chats.contains(where: { $0.id == chat.id }) {
                            self.chats.append(chat)
                            print("📝 Added chat to local cache")
                        }
                    }
                    
                    return chat
                }
            }
            
            print("❌ No existing chat found in Firestore")
            return nil
        } catch {
            print("❌ Error finding existing chat: \(error)")
            return nil
        }
    }
    

    // MARK: - Message Management

    func loadInitialMessages(chatId: String) async {
        let alreadyLoading = await MainActor.run { self.isLoadingInitial && self.currentChatId == chatId }
        if alreadyLoading { return }

        await MainActor.run {
            self.detachActiveChatListeners()
            self.resetChatState()
            self.currentChatId = chatId
            self.isLoadingInitial = true
            self.errorMessage = nil
        }

        do {
            let messagesQuery = db.collection("chats").document(chatId)
                .collection("messages")
                .order(by: "createdAt", descending: true)
                .limit(to: pageSize)

            let snapshot = try await messagesQuery.getDocuments()
            let documents = snapshot.documents

            var parsedMessages: [Message] = []
            parsedMessages.reserveCapacity(documents.count)

            for document in documents {
                let normalized = normalizeMessageData(document.data(), documentID: document.documentID)
                if let message = Message.fromDictionary(normalized) {
                    parsedMessages.append(message)
                }
            }

            parsedMessages.sort(by: messageSort)

            let enrichedMessages = await enrichMessages(parsedMessages)

            let chatSnapshot = try await db.collection("chats").document(chatId).getDocument()
            let (lastReadTimestamp, serverUnread) = extractReadState(from: chatSnapshot.data())

            let derivedUnreadMessages: [Message]
            if let lastReadTimestamp {
                let lastReadDate = Date(timeIntervalSince1970: lastReadTimestamp)
                derivedUnreadMessages = enrichedMessages.filter { $0.timestamp > lastReadDate }
            } else {
                derivedUnreadMessages = enrichedMessages
            }

            await MainActor.run {
                self.oldestSnapshot = documents.last
                self.latestSnapshot = documents.first
                self.messages = enrichedMessages
                self.messageIndex = Dictionary(uniqueKeysWithValues: enrichedMessages.map { ($0.id, $0) })
                self.hasMoreOlder = documents.count == self.pageSize
                self.lastKnownReadTimestamp = lastReadTimestamp
                self.unreadCount = max(serverUnread, derivedUnreadMessages.count)
                self.firstUnreadMessageId = derivedUnreadMessages.first?.id
                self.isLoadingInitial = false
                self.observeNewMessages(chatId: chatId)
                self.observeTyping(chatId: chatId)
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to load messages: \(error.localizedDescription)"
                self.isLoadingInitial = false
            }
        }
    }

    func loadOlderMessages(chatId: String) async {
        let context = await MainActor.run { (self.currentChatId == chatId, self.hasMoreOlder, self.isLoadingOlder, self.oldestSnapshot) }
        let (isCurrentChat, hasMore, isLoading, oldestSnapshot) = context
        guard isCurrentChat, hasMore, !isLoading else { return }
        guard let oldestSnapshot else {
            await MainActor.run { self.hasMoreOlder = false }
            return
        }

        await MainActor.run { self.isLoadingOlder = true }

        do {
            let query = db.collection("chats").document(chatId)
                .collection("messages")
                .order(by: "createdAt", descending: true)
                .start(afterDocument: oldestSnapshot)
                .limit(to: pageSize)

            let snapshot = try await query.getDocuments()
            let documents = snapshot.documents

            if documents.isEmpty {
                await MainActor.run {
                    self.hasMoreOlder = false
                    self.isLoadingOlder = false
                }
                return
            }

            var parsedMessages: [Message] = []
            parsedMessages.reserveCapacity(documents.count)

            for document in documents {
                let normalized = normalizeMessageData(document.data(), documentID: document.documentID)
                if let message = Message.fromDictionary(normalized) {
                    parsedMessages.append(message)
                }
            }

            parsedMessages.sort(by: messageSort)
            let enrichedMessages = await enrichMessages(parsedMessages)

            await MainActor.run {
                self.oldestSnapshot = documents.last
                if documents.count < self.pageSize {
                    self.hasMoreOlder = false
                }
                self.merge(messages: enrichedMessages)
                self.isLoadingOlder = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to load older messages: \(error.localizedDescription)"
                self.isLoadingOlder = false
            }
        }
    }

    func observeNewMessages(chatId: String) {
        messagesListener?.remove()

        let query = db.collection("chats").document(chatId)
            .collection("messages")
            .order(by: "createdAt", descending: false)
            .limit(toLast: pageSize * 2)

        messagesListener = query.addSnapshotListener { [weak self] snapshot, error in
            guard let self else { return }

            if let error {
                Task { @MainActor in
                    self.errorMessage = "Failed to observe messages: \(error.localizedDescription)"
                }
                return
            }

            guard let snapshot else { return }

            Task {
                let payloads: [(Message, DocumentChangeType)] = snapshot.documentChanges.compactMap { change in
                    guard change.type != .removed else { return nil }
                    let normalized = self.normalizeMessageData(change.document.data(), documentID: change.document.documentID)
                    guard let message = Message.fromDictionary(normalized) else { return nil }
                    return (message, change.type)
                }

                guard !payloads.isEmpty else { return }

                let originalMessages = payloads.map { $0.0 }
                let enriched = await self.enrichMessages(originalMessages)
                let lookup = Dictionary(uniqueKeysWithValues: zip(originalMessages.map { $0.id }, enriched))

                await MainActor.run {
                    if let lastDocument = snapshot.documents.last {
                        self.latestSnapshot = lastDocument
                    }
                    for (original, changeType) in payloads {
                        guard let enrichedMessage = lookup[original.id] else { continue }
                        self.enqueueRealtimeUpdate(message: enrichedMessage, changeType: changeType)
                    }
                }
            }
        }
    }

    func observeTyping(chatId: String) {
        typingListener?.remove()

        let chatRef = db.collection("chats").document(chatId)
        typingListener = chatRef.addSnapshotListener { [weak self] snapshot, _ in
            guard let self else { return }
            guard let data = snapshot?.data(),
                  let typingIds = data["typing"] as? [String] else {
                Task { @MainActor in
                    self.typingUsernames = []
                }
                return
            }

            let currentUserId = Auth.auth().currentUser?.uid
            let filtered = typingIds.filter { $0 != currentUserId }
            let names = self.resolveDisplayNames(for: filtered, chatId: chatId)

            Task { @MainActor in
                self.typingUsernames = names
            }
        }
    }

    func sendMessage(_ content: String, to chatId: String, type: MessageType = .text, replyToMessageId: String? = nil) async {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard let currentUser = Auth.auth().currentUser else {
            await MainActor.run {
                self.errorMessage = "You must be logged in to send messages"
            }
            return
        }

        await MainActor.run {
            self.isSendingMessage = true
            self.errorMessage = nil
        }

        var optimisticMessage: Message?

        do {
            let profile = try await loadUserProfile(for: currentUser.uid)
            let message = Message(
                chatId: chatId,
                senderId: currentUser.uid,
                senderName: profile.displayName,
                senderUsername: profile.username,
                senderProfileImageURL: profile.profileImageURL,
                content: trimmed,
                type: type,
                status: .sending,
                replyToMessageId: replyToMessageId
            )
            optimisticMessage = message

            await MainActor.run {
                self.insertOptimisticMessage(message)
            }

            let chatRef = db.collection("chats").document(chatId)
            let messageRef = chatRef.collection("messages").document(message.id)

            var payload = message.toDictionary()
            payload["status"] = MessageStatus.sent.rawValue
            payload["text"] = message.content
            payload["createdAt"] = Timestamp(date: message.timestamp)

            try await messageRef.setData(payload)

            try await chatRef.updateData([
                "lastMessage": payload,
                "lastActivity": Date().timeIntervalSince1970
            ])

            await MainActor.run {
                self.isSendingMessage = false
                self.setStatus(for: message.id, to: .sent)
            }
        } catch {
            let failedMessage = optimisticMessage
            await MainActor.run {
                self.errorMessage = "Failed to send message: \(error.localizedDescription)"
                self.isSendingMessage = false
                if let failedMessage {
                    self.setStatus(for: failedMessage.id, to: .failed)
                }
            }
        }
    }

    func sendImageMessage(_ imageData: Data, to chatId: String, replyToMessageId: String? = nil) async {
        guard let currentUser = Auth.auth().currentUser else {
            await MainActor.run {
                self.errorMessage = "You must be logged in to send images"
            }
            return
        }

        await MainActor.run {
            self.isUploadingAttachment = true
            self.errorMessage = nil
        }

        var optimisticMessage: Message?

        do {
            let profile = try await loadUserProfile(for: currentUser.uid)
            let uploadData = ImageProcessor.prepareUploadData(imageData, maxDimension: 1920, compressionQuality: 0.7)

            let storage: Storage
            if let bucket = FirebaseApp.app()?.options.storageBucket, !bucket.isEmpty {
                storage = Storage.storage(url: "gs://\(bucket)")
            } else {
                storage = Storage.storage()
            }

            let storageRef = storage.reference().child("chat_images/\(chatId)/\(UUID().uuidString).jpg")
            let metadata = StorageMetadata()
            metadata.contentType = "image/jpeg"
            _ = try await storageRef.putDataAsync(uploadData, metadata: metadata)
            let downloadURL = try await storageRef.downloadURL()

            let message = Message(
                chatId: chatId,
                senderId: currentUser.uid,
                senderName: profile.displayName,
                senderUsername: profile.username,
                senderProfileImageURL: profile.profileImageURL,
                content: "Image",
                type: .image,
                status: .sending,
                replyToMessageId: replyToMessageId,
                imageURL: downloadURL.absoluteString
            )
            optimisticMessage = message

            await MainActor.run {
                self.insertOptimisticMessage(message)
            }

            let chatRef = db.collection("chats").document(chatId)
            let messageRef = chatRef.collection("messages").document(message.id)

            var payload = message.toDictionary()
            payload["status"] = MessageStatus.sent.rawValue
            payload["text"] = message.content
            payload["createdAt"] = Timestamp(date: message.timestamp)
            payload["imageUrl"] = message.imageURL

            try await messageRef.setData(payload)

            try await chatRef.updateData([
                "lastMessage": payload,
                "lastActivity": Date().timeIntervalSince1970
            ])

            await MainActor.run {
                self.isUploadingAttachment = false
                self.setStatus(for: message.id, to: .sent)
            }
        } catch {
            let failedMessage = optimisticMessage
            await MainActor.run {
                self.errorMessage = "Failed to send image: \(error.localizedDescription)"
                self.isUploadingAttachment = false
                if let failedMessage {
                    self.setStatus(for: failedMessage.id, to: .failed)
                }
            }
        }
    }

    func markRead(chatId: String) async {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        let readDate = Date()
        let timestamp = readDate.timeIntervalSince1970

        await MainActor.run {
            self.unreadCount = 0
            self.firstUnreadMessageId = nil
            self.lastKnownReadTimestamp = timestamp
        }

        do {
            try await db.collection("chats").document(chatId).updateData([
                "participants.\(currentUserId).lastReadTimestamp": timestamp,
                "unreadCount.\(currentUserId)": 0
            ])
        } catch {
            print("Error marking messages as read: \(error.localizedDescription)")
        }
    }

    private func detachActiveChatListeners() {
        messagesListener?.remove()
        messagesListener = nil
        typingListener?.remove()
        typingListener = nil
    }

    @MainActor
    private func resetChatState() {
        coalesceWorkItem?.cancel()
        pendingRealtimePayloads.removeAll()
        messages = []
        messageIndex = [:]
        unreadCount = 0
        firstUnreadMessageId = nil
        isLoadingOlder = false
        hasMoreOlder = true
        oldestSnapshot = nil
        latestSnapshot = nil
        lastKnownReadTimestamp = nil
        typingUsernames = []
    }

    private func normalizeMessageData(_ data: [String: Any], documentID: String) -> [String: Any] {
        var normalized = data
        normalized["id"] = normalized["id"] ?? documentID

        if normalized["content"] == nil, let text = normalized["text"] as? String {
            normalized["content"] = text
        }

        if let timestamp = normalized["createdAt"] as? Timestamp {
            normalized["timestamp"] = timestamp.dateValue().timeIntervalSince1970
        } else if let date = normalized["createdAt"] as? Date {
            normalized["timestamp"] = date.timeIntervalSince1970
        } else if let timestamp = normalized["timestamp"] as? Timestamp {
            normalized["timestamp"] = timestamp.dateValue().timeIntervalSince1970
        }

        if let status = normalized["status"] as? String, status == "pending" {
            normalized["status"] = MessageStatus.sending.rawValue
        }

        if let imageUrl = normalized["imageUrl"] as? String, normalized["imageURL"] == nil {
            normalized["imageURL"] = imageUrl
        }

        return normalized
    }

    private func extractReadState(from data: [String: Any]?) -> (TimeInterval?, Int) {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            return (nil, 0)
        }

        guard let data else { return (nil, 0) }

        var lastRead: TimeInterval?
        if let participants = data["participants"] as? [String: Any],
           let participant = participants[currentUserId] as? [String: Any] {
            if let value = participant["lastReadTimestamp"] as? TimeInterval {
                lastRead = value
            } else if let timestamp = participant["lastReadTimestamp"] as? Timestamp {
                lastRead = timestamp.dateValue().timeIntervalSince1970
            }
        }

        var unread = 0
        if let unreadMap = data["unreadCount"] as? [String: Any],
           let raw = unreadMap[currentUserId] {
            if let intValue = raw as? Int {
                unread = intValue
            } else if let doubleValue = raw as? Double {
                unread = Int(doubleValue)
            }
        }

        return (lastRead, unread)
    }

    private func sortMessages(_ messages: [Message]) -> [Message] {
        messages.sorted(by: messageSort)
    }

    private func messageSort(_ lhs: Message, _ rhs: Message) -> Bool {
        if lhs.timestamp == rhs.timestamp {
            return lhs.id < rhs.id
        }
        return lhs.timestamp < rhs.timestamp
    }

    @MainActor
    private func merge(messages newMessages: [Message]) {
        guard !newMessages.isEmpty else { return }
        for message in newMessages {
            messageIndex[message.id] = message
        }
        messages = sortMessages(Array(messageIndex.values))
    }

    @MainActor
    private func enqueueRealtimeUpdate(message: Message, changeType: DocumentChangeType) {
        var resolvedType = changeType
        if changeType == .added, messageIndex[message.id] != nil {
            resolvedType = .modified
        }
        pendingRealtimePayloads.append((message, resolvedType))
        scheduleRealtimeFlush()
    }

    @MainActor
    private func scheduleRealtimeFlush() {
        coalesceWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.flushRealtimeBuffer()
        }
        coalesceWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + newMessageDebounceInterval, execute: workItem)
    }

    @MainActor
    private func flushRealtimeBuffer() {
        guard !pendingRealtimePayloads.isEmpty else { return }
        let payloads = pendingRealtimePayloads
        pendingRealtimePayloads.removeAll()

        var updatedIndex = messageIndex
        var updatedMessages = messages
        var updatedUnread = unreadCount
        var updatedFirstUnread = firstUnreadMessageId
        let currentUserId = Auth.auth().currentUser?.uid
        let readCutoff = lastKnownReadTimestamp ?? 0

        for (message, changeType) in payloads where changeType != .removed {
            let wasExisting = updatedIndex[message.id] != nil
            updatedIndex[message.id] = message

            if let idx = updatedMessages.firstIndex(where: { $0.id == message.id }) {
                updatedMessages[idx] = message
            } else {
                updatedMessages.append(message)
            }

            let isIncoming = message.senderId != currentUserId
            let timestamp = message.timestamp.timeIntervalSince1970

            if isIncoming && timestamp > readCutoff && !wasExisting {
                updatedUnread += 1
                if updatedFirstUnread == nil {
                    updatedFirstUnread = message.id
                }
            }
        }

        updatedMessages.sort(by: messageSort)
        messageIndex = updatedIndex
        messages = updatedMessages
        unreadCount = updatedUnread
        firstUnreadMessageId = updatedFirstUnread
    }

    private func resolveDisplayNames(for userIds: [String], chatId: String) -> [String] {
        guard let chat = chats.first(where: { $0.id == chatId }) else { return userIds }
        return userIds.compactMap { id in
            chat.participants.first(where: { $0.uid == id })?.displayName
        }
    }

    @MainActor
    private func insertOptimisticMessage(_ message: Message) {
        messageIndex[message.id] = message
        messages.append(message)
        messages.sort(by: messageSort)
    }

    @MainActor
    private func setStatus(for messageId: String, to status: MessageStatus) {
        guard var existing = messageIndex[messageId] else { return }
        existing.status = status
        messageIndex[messageId] = existing
        if let index = messages.firstIndex(where: { $0.id == messageId }) {
            messages[index] = existing
        }
    }
func addMembers(_ newFriends: [Friend], to chatId: String) async -> Chat? {
        guard !newFriends.isEmpty else { return nil }
        guard let currentUser = Auth.auth().currentUser else {
            await MainActor.run {
                self.errorMessage = "You must be logged in to add members"
            }
            return nil
        }
        
        await MainActor.run {
            self.isLoading = true
            self.errorMessage = nil
        }
        
        do {
            // Fetch current user profile for system message context
            let currentUserDoc = try await db.collection("users").document(currentUser.uid).getDocument()
            guard let currentUserData = currentUserDoc.data() else {
                throw NSError(domain: "MessagingManager", code: 3, userInfo: [NSLocalizedDescriptionKey: "Could not load your profile"])
            }
            let currentUserProfile = UserProfile.fromDictionary(currentUserData, uid: currentUser.uid)
            
            let participants = newFriends.map { friend in
                ChatParticipant(
                    uid: friend.uid,
                    username: friend.username,
                    displayName: friend.displayName,
                    profileImageURL: friend.profileImageURL
                )
            }
            
            var updateData: [String: Any] = [
                "participantUIDs": FieldValue.arrayUnion(participants.map { $0.uid }),
                "lastActivity": Date().timeIntervalSince1970
            ]
            
            for participant in participants {
                updateData["participants.\(participant.uid)"] = participant.toDictionary()
                updateData["unreadCount.\(participant.uid)"] = 0
            }
            
            let chatRef = db.collection("chats").document(chatId)
            try await chatRef.updateData(updateData)
            
            // Create system message announcing new members
            let names = participants.map { $0.displayName }.joined(separator: ", ")
            let systemMessage = Message(
                chatId: chatId,
                senderId: "system",
                senderName: "System",
                senderUsername: "system",
                content: "\(currentUserProfile.displayName) added \(names)",
                type: .system,
                status: .sent
            )
            try await chatRef.collection("messages").document(systemMessage.id).setData(systemMessage.toDictionary())
            try await chatRef.updateData([
                "lastMessage": systemMessage.toDictionary(),
                "lastActivity": Date().timeIntervalSince1970
            ])
            
            let updatedChat = try await fetchChat(by: chatId)
            
            await MainActor.run {
                self.isLoading = false
                self.successMessage = "Added \(participants.count) member\(participants.count == 1 ? "" : "s")"
            }
            
            return updatedChat
        } catch {
            await MainActor.run {
                self.isLoading = false
                self.errorMessage = "Failed to add members: \(error.localizedDescription)"
            }
            return nil
        }
    }

    func updateGroupChatDetails(chatId: String, newName: String?, newDescription: String? = nil, imageData: Data?) async -> Chat? {
        await MainActor.run {
            self.isLoading = true
            self.errorMessage = nil
        }
        
        if newName == nil && newDescription == nil && imageData == nil {
            let chat = try? await fetchChat(by: chatId)
            await MainActor.run { self.isLoading = false }
            return chat
        }
        
        do {
            let chatRef = db.collection("chats").document(chatId)
            var updates: [String: Any] = [:]
            var systemMessages: [String] = []
            
            if let trimmedName = newName?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmedName.isEmpty {
                updates["name"] = trimmedName
                systemMessages.append("renamed the group to \(trimmedName)")
            }
            
            if let description = newDescription?.trimmingCharacters(in: .whitespacesAndNewlines) {
                updates["description"] = description.isEmpty ? FieldValue.delete() : description
                systemMessages.append(description.isEmpty ? "cleared the group description" : "updated the group description")
            }
            
            if let imageData {
                let imageURL = try await uploadGroupImage(chatId: chatId, imageData: imageData)
                updates["imageURL"] = imageURL
                systemMessages.append("updated the group photo")
            }
            
            if !updates.isEmpty {
                updates["lastActivity"] = Date().timeIntervalSince1970
                try await chatRef.updateData(updates)
            }
            
            if !systemMessages.isEmpty, let currentUser = Auth.auth().currentUser {
                let profileDoc = try await db.collection("users").document(currentUser.uid).getDocument()
                if let profileData = profileDoc.data() {
                    let profile = UserProfile.fromDictionary(profileData, uid: currentUser.uid)
                    let content = "\(profile.displayName) \(systemMessages.joined(separator: ", "))"
                    let message = Message(
                        chatId: chatId,
                        senderId: "system",
                        senderName: "System",
                        senderUsername: "system",
                        content: content,
                        type: .system,
                        status: .sent
                    )
                    try await chatRef.collection("messages").document(message.id).setData(message.toDictionary())
                    try await chatRef.updateData([
                        "lastMessage": message.toDictionary(),
                        "lastActivity": Date().timeIntervalSince1970
                    ])
                }
            }
            
            let updatedChat = try await fetchChat(by: chatId)
            let hasUpdates = !updates.isEmpty || !systemMessages.isEmpty
            await MainActor.run {
                self.isLoading = false
                if hasUpdates {
                    self.successMessage = "Group updated"
                }
            }
            return updatedChat
        } catch {
            await MainActor.run {
                self.isLoading = false
                self.errorMessage = "Failed to update group: \(error.localizedDescription)"
            }
            return nil
        }
    }

    private func markMessagesAsRead(chatId: String) async {
        guard let currentUser = Auth.auth().currentUser else { return }
        
        do {
            // Update user's last read timestamp in the chat
            try await db.collection("chats").document(chatId).updateData([
                "participants.\(currentUser.uid).lastReadTimestamp": Date().timeIntervalSince1970
            ])
            
            // Reset unread count for current user
            try await db.collection("chats").document(chatId).updateData([
                "unreadCount.\(currentUser.uid)": 0
            ])
            
        } catch {
            print("Error marking messages as read: \(error)")
        }
    }

    // MARK: - Helper Methods
    
    private func fetchChat(by chatId: String) async throws -> Chat? {
        let snapshot = try await db.collection("chats").document(chatId).getDocument()
        guard var data = snapshot.data() else { return nil }
        if data["id"] == nil {
            data["id"] = snapshot.documentID
        }
        return Chat.fromDictionary(data)
    }

    private func loadUserProfile(for uid: String) async throws -> UserProfile {
        let userDoc = try await db.collection("users").document(uid).getDocument()
        guard let userData = userDoc.data() else {
            throw NSError(
                domain: "MessagingManager",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Could not load user profile"]
            )
        }
        return UserProfile.fromDictionary(userData, uid: uid)
    }
    
    private func uploadGroupImage(chatId: String, imageData: Data) async throws -> String {
        let storage: Storage
        if let bucket = FirebaseApp.app()?.options.storageBucket, !bucket.isEmpty {
            storage = Storage.storage(url: "gs://\(bucket)")
        } else {
            storage = Storage.storage()
        }
        let storageRef = storage.reference().child("group_chat_images/\(chatId)/avatar.jpg")

        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        let uploadData = ImageProcessor.prepareUploadData(imageData)
        _ = try await storageRef.putDataAsync(uploadData, metadata: metadata)
        let downloadURL = try await storageRef.downloadURL()
        return downloadURL.absoluteString
    }

    func getChatDisplayName(for chat: Chat, currentUserId: String) -> String {
        if chat.type == .group {
            return chat.name ?? "Group Chat"
        }
        
        // For direct chats, show the other person's name
        if let otherParticipant = chat.getOtherParticipant(currentUserId: currentUserId) {
            return otherParticipant.displayName
        }
        
        return "Chat"
    }
    
    func getChatDisplayImage(for chat: Chat, currentUserId: String) -> String {
        if chat.type == .group {
            return chat.imageURL ?? ""
        }
        
        // For direct chats, show the other person's profile image
        if let otherParticipant = chat.getOtherParticipant(currentUserId: currentUserId) {
            return otherParticipant.profileImageURL
        }
        
        return ""
    }
    
    func deleteMessage(_ messageId: String, from chatId: String) async {
        do {
            try await db.collection("chats").document(chatId)
                .collection("messages").document(messageId).delete()
            
            await MainActor.run {
                self.successMessage = "Message deleted"
                self.messageIndex.removeValue(forKey: messageId)
                self.messages.removeAll { $0.id == messageId }
                if self.firstUnreadMessageId == messageId {
                    let cutoff = self.lastKnownReadTimestamp ?? 0
                    self.firstUnreadMessageId = self.messages.first(where: { $0.timestamp.timeIntervalSince1970 > cutoff })?.id
                }
            }
            
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to delete message: \(error.localizedDescription)"
            }
        }
    }
    
    func leaveChat(_ chatId: String) async {
        guard let currentUser = Auth.auth().currentUser else { return }
        
        do {
            // First get the current chat to find the user's participant data
            let chatDoc = try await db.collection("chats").document(chatId).getDocument()
            guard var chatData = chatDoc.data() else {
                throw NSError(domain: "MessagingManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not load chat data"])
            }
            if chatData["id"] == nil {
                chatData["id"] = chatDoc.documentID
            }
            guard let chat = Chat.fromDictionary(chatData) else {
                throw NSError(domain: "MessagingManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not load chat data"])
            }
            
            // Find the participant to remove
            guard let participantToRemove = chat.participants.first(where: { $0.uid == currentUser.uid }) else {
                throw NSError(domain: "MessagingManager", code: 2, userInfo: [NSLocalizedDescriptionKey: "User is not a participant in this chat"])
            }
            
            // Remove user from both participants and participantUIDs arrays
            try await db.collection("chats").document(chatId).updateData([
                "participants.\(participantToRemove.uid)": FieldValue.delete(),
                "participantUIDs": FieldValue.arrayRemove([currentUser.uid])
            ])
            
            await MainActor.run {
                self.successMessage = "Left chat successfully"
                // Remove from local array
                self.chats.removeAll { $0.id == chatId }
            }
            
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to leave chat: \(error.localizedDescription)"
            }
        }
    }
}

// MARK: - Profile Enrichment Helpers

extension MessagingManager {
    private func enrichChats(_ chats: [Chat]) async -> [Chat] {
        let participantUIDs = Array(Set(chats.flatMap { $0.participants.map { $0.uid } })).filter { !$0.isEmpty && $0 != "system" }
        let profiles = await fetchProfiles(for: participantUIDs)
        guard !profiles.isEmpty else { return chats }

        return chats.map { chat in
            let updatedParticipants = chat.participants.map { participant -> ChatParticipant in
                guard let profile = profiles[participant.uid] else { return participant }
                return ChatParticipant(
                    uid: participant.uid,
                    username: profile.username.isEmpty ? participant.username : profile.username,
                    displayName: profile.displayName.isEmpty ? participant.displayName : profile.displayName,
                    profileImageURL: profile.profileImageURL.isEmpty ? participant.profileImageURL : profile.profileImageURL,
                    joinedAt: participant.joinedAt,
                    isAdmin: participant.isAdmin,
                    lastReadMessageId: participant.lastReadMessageId,
                    lastReadTimestamp: participant.lastReadTimestamp
                )
            }

            var updatedLastMessage = chat.lastMessage
            if let lastMessage = chat.lastMessage,
               lastMessage.senderId != "system",
               let profile = profiles[lastMessage.senderId] {
                updatedLastMessage = lastMessage.updatingSender(
                    name: profile.displayName.isEmpty ? lastMessage.senderName : profile.displayName,
                    username: profile.username.isEmpty ? lastMessage.senderUsername : profile.username,
                    profileImageURL: profile.profileImageURL.isEmpty ? lastMessage.senderProfileImageURL : profile.profileImageURL
                )
            }

            return chat.updating(participants: updatedParticipants, lastMessage: updatedLastMessage)
        }
    }

    private func enrichMessages(_ messages: [Message]) async -> [Message] {
        let senderIds = Array(Set(messages.compactMap { message -> String? in
            let senderId = message.senderId
            return senderId == "system" || senderId.isEmpty ? nil : senderId
        }))
        let profiles = await fetchProfiles(for: senderIds)
        guard !profiles.isEmpty else { return messages }

        return messages.map { message in
            guard message.senderId != "system",
                  let profile = profiles[message.senderId] else {
                return message
            }
            return message.updatingSender(
                name: profile.displayName.isEmpty ? message.senderName : profile.displayName,
                username: profile.username.isEmpty ? message.senderUsername : profile.username,
                profileImageURL: profile.profileImageURL.isEmpty ? message.senderProfileImageURL : profile.profileImageURL
            )
        }
    }

    private func fetchProfiles(for uids: [String]) async -> [String: UserProfile] {
        let uniqueUIDs = Array(Set(uids)).filter { !$0.isEmpty }
        guard !uniqueUIDs.isEmpty else { return [:] }

        var profiles: [String: UserProfile] = [:]
        let batchSize = 10
        var index = 0

        do {
            while index < uniqueUIDs.count {
                let endIndex = min(index + batchSize, uniqueUIDs.count)
                let batch = Array(uniqueUIDs[index..<endIndex])
                let snapshot = try await db.collection("users")
                    .whereField(FieldPath.documentID(), in: batch)
                    .getDocuments()
                for document in snapshot.documents {
                    profiles[document.documentID] = UserProfile.fromDictionary(document.data(), uid: document.documentID)
                }
                index = endIndex
            }
        } catch {
            print("⚠️ Failed to fetch user profiles: \(error.localizedDescription)")
        }

        return profiles
    }
}
