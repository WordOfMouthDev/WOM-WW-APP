import Foundation
import FirebaseFirestore

enum ChatType: String, Codable, CaseIterable {
    case direct = "direct" // 1-on-1 chat
    case group = "group"   // Group chat
}

struct ChatParticipant: Codable, Identifiable, Hashable {
    let id: String
    let uid: String
    let username: String
    let displayName: String
    let profileImageURL: String
    let joinedAt: Date
    let isAdmin: Bool // For group chats
    let lastReadMessageId: String? // For read receipts
    let lastReadTimestamp: Date?
    
    init(
        uid: String,
        username: String,
        displayName: String,
        profileImageURL: String = "",
        joinedAt: Date = Date(),
        isAdmin: Bool = false,
        lastReadMessageId: String? = nil,
        lastReadTimestamp: Date? = nil
    ) {
        self.id = uid
        self.uid = uid
        self.username = username
        self.displayName = displayName
        self.profileImageURL = profileImageURL
        self.joinedAt = joinedAt
        self.isAdmin = isAdmin
        self.lastReadMessageId = lastReadMessageId
        self.lastReadTimestamp = lastReadTimestamp
    }
    
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "id": uid,
            "uid": uid,
            "username": username,
            "displayName": displayName,
            "profileImageURL": profileImageURL,
            "joinedAt": joinedAt.timeIntervalSince1970,
            "isAdmin": isAdmin
        ]
        
        if let lastReadMessageId = lastReadMessageId {
            dict["lastReadMessageId"] = lastReadMessageId
        }
        
        if let lastReadTimestamp = lastReadTimestamp {
            dict["lastReadTimestamp"] = lastReadTimestamp.timeIntervalSince1970
        }
        
        return dict
    }
    
    static func fromDictionary(_ dict: [String: Any]) -> ChatParticipant? {
        let identifier = dict["uid"] as? String ?? dict["id"] as? String
        guard let uid = identifier,
              let username = dict["username"] as? String,
              let displayName = dict["displayName"] as? String else {
            return nil
        }
        
        let profileImageURL = dict["profileImageURL"] as? String ?? ""
        let isAdmin = dict["isAdmin"] as? Bool ?? false
        let lastReadMessageId = dict["lastReadMessageId"] as? String
        let joinedAt: Date
        if let timestamp = dict["joinedAt"] as? TimeInterval {
            joinedAt = Date(timeIntervalSince1970: timestamp)
        } else if let timestamp = dict["joinedAt"] as? Timestamp {
            joinedAt = timestamp.dateValue()
        } else {
            joinedAt = Date()
        }
        var lastReadTimestamp: Date?
        if let interval = dict["lastReadTimestamp"] as? TimeInterval {
            lastReadTimestamp = Date(timeIntervalSince1970: interval)
        } else if let timestamp = dict["lastReadTimestamp"] as? Timestamp {
            lastReadTimestamp = timestamp.dateValue()
        }
        
        return ChatParticipant(
            uid: uid,
            username: username,
            displayName: displayName,
            profileImageURL: profileImageURL,
            joinedAt: joinedAt,
            isAdmin: isAdmin,
            lastReadMessageId: lastReadMessageId,
            lastReadTimestamp: lastReadTimestamp
        )
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(uid)
    }
    
    static func == (lhs: ChatParticipant, rhs: ChatParticipant) -> Bool {
        lhs.uid == rhs.uid
    }
}

struct Chat: Codable, Identifiable, Hashable {
    let id: String
    let type: ChatType
    let name: String? // For group chats
    let description: String? // For group chats
    let imageURL: String? // For group chat images
    let participants: [ChatParticipant]
    let createdBy: String
    let createdAt: Date
    let lastMessage: Message?
    let lastActivity: Date
    let isArchived: Bool
    let unreadCount: [String: Int] // userId -> unread count
    
    init(
        type: ChatType,
        participants: [ChatParticipant],
        createdBy: String,
        name: String? = nil,
        description: String? = nil,
        imageURL: String? = nil
    ) {
        self.id = UUID().uuidString
        self.type = type
        self.name = name
        self.description = description
        self.imageURL = imageURL
        self.participants = participants
        self.createdBy = createdBy
        self.createdAt = Date()
        self.lastMessage = nil
        self.lastActivity = Date()
        self.isArchived = false
        self.unreadCount = [:]
    }
    
    // Computed properties for UI
    var displayName: String {
        if let name = name {
            return name
        }
        
        // For direct chats, show the other person's name
        if type == .direct, participants.count == 2 {
            // Find the participant who is not the current user
            // This will be handled in the UI layer where we have access to current user
            return participants.map { $0.displayName }.joined(separator: ", ")
        }
        
        // For group chats without a name, show participant names
        return participants.map { $0.displayName }.joined(separator: ", ")
    }
    
    var displayImage: String {
        if let imageURL = imageURL {
            return imageURL
        }
        
        // For direct chats, use the other person's profile image
        if type == .direct, participants.count == 2 {
            return participants.first?.profileImageURL ?? ""
        }
        
        return ""
    }
    
    func toDictionary() -> [String: Any] {
        let participantsDictionary = Dictionary(uniqueKeysWithValues: participants.map { participant in
            (participant.uid, participant.toDictionary())
        })
        
        var dict: [String: Any] = [
            "id": id,
            "type": type.rawValue,
            "participants": participantsDictionary,
            "participantUIDs": participants.map { $0.uid }, // Add this for easier querying
            "createdBy": createdBy,
            "createdAt": createdAt.timeIntervalSince1970,
            "lastActivity": lastActivity.timeIntervalSince1970,
            "isArchived": isArchived,
            "unreadCount": unreadCount
        ]
        
        if let name = name {
            dict["name"] = name
        }
        
        if let description = description {
            dict["description"] = description
        }
        
        if let imageURL = imageURL {
            dict["imageURL"] = imageURL
        }
        
        if let lastMessage = lastMessage {
            dict["lastMessage"] = lastMessage.toDictionary()
        }
        
        return dict
    }

    func updating(
        participants: [ChatParticipant]? = nil,
        lastMessage: Message? = nil
    ) -> Chat {
        Chat(
            id: id,
            type: type,
            name: name,
            description: description,
            imageURL: imageURL,
            participants: participants ?? self.participants,
            createdBy: createdBy,
            createdAt: createdAt,
            lastMessage: lastMessage ?? self.lastMessage,
            lastActivity: lastActivity,
            isArchived: isArchived,
            unreadCount: unreadCount
        )
    }

    static func fromDictionary(_ dict: [String: Any]) -> Chat? {
        guard let id = dict["id"] as? String,
              let typeString = dict["type"] as? String,
              let type = ChatType(rawValue: typeString),
              let createdBy = dict["createdBy"] as? String,
              let createdAt = parseDate(from: dict["createdAt"]),
              let lastActivity = parseDate(from: dict["lastActivity"]) else {
            return nil
        }

        // Handle participants data - it might be missing in some documents
        var participants: [ChatParticipant] = []
        if let participantsData = dict["participants"] as? [[String: Any]] {
            participants = participantsData.compactMap { ChatParticipant.fromDictionary($0) }
        } else if let participantsMap = dict["participants"] as? [String: Any] {
            participants = participantsMap.compactMap { key, value in
                guard var participantData = value as? [String: Any] else {
                    return nil
                }
                if participantData["uid"] == nil {
                    participantData["uid"] = key
                }
                if participantData["id"] == nil {
                    participantData["id"] = key
                }
                return ChatParticipant.fromDictionary(participantData)
            }
        }

        // Debug: Log if participants are empty
        if participants.isEmpty {
            print("⚠️ Chat \(id) has no participants loaded from data: \(dict["participants"] ?? "nil")")
        }
        participants.sort { $0.joinedAt < $1.joinedAt }

        let name = dict["name"] as? String
        let description = dict["description"] as? String
        let imageURL = dict["imageURL"] as? String
        let isArchived = dict["isArchived"] as? Bool ?? false
        let unreadCount = dict["unreadCount"] as? [String: Int] ?? [:]
        
        var lastMessage: Message?
        if let lastMessageData = dict["lastMessage"] as? [String: Any] {
            lastMessage = Message.fromDictionary(lastMessageData)
        }
        
        return Chat(
            id: id,
            type: type,
            name: name,
            description: description,
            imageURL: imageURL,
            participants: participants,
            createdBy: createdBy,
            createdAt: createdAt,
            lastMessage: lastMessage,
            lastActivity: lastActivity,
            isArchived: isArchived,
            unreadCount: unreadCount
        )
    }
    
    // Custom init for dictionary data
    private init(
        id: String,
        type: ChatType,
        name: String?,
        description: String?,
        imageURL: String?,
        participants: [ChatParticipant],
        createdBy: String,
        createdAt: Date,
        lastMessage: Message?,
        lastActivity: Date,
        isArchived: Bool,
        unreadCount: [String: Int]
    ) {
        self.id = id
        self.type = type
        self.name = name
        self.description = description
        self.imageURL = imageURL
        self.participants = participants
        self.createdBy = createdBy
        self.createdAt = createdAt
        self.lastMessage = lastMessage
        self.lastActivity = lastActivity
        self.isArchived = isArchived
        self.unreadCount = unreadCount
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: Chat, rhs: Chat) -> Bool {
        lhs.id == rhs.id
    }
    
    // Helper methods
    func getOtherParticipant(currentUserId: String) -> ChatParticipant? {
        return participants.first { $0.uid != currentUserId }
    }
    
    func isParticipant(userId: String) -> Bool {
        return participants.contains { $0.uid == userId }
    }
    
    func getUnreadCount(for userId: String) -> Int {
        let storedCount = unreadCount[userId] ?? 0
        guard let lastMessage = lastMessage else { return storedCount }
        guard lastMessage.senderId != userId else { return storedCount }

        let lastRead = participants.first(where: { $0.uid == userId })?.lastReadTimestamp

        if let lastRead, lastMessage.timestamp <= lastRead {
            return storedCount
        }

        return max(storedCount, 1)
    }

    private static func parseDate(from value: Any?) -> Date? {
        if let timeInterval = value as? TimeInterval {
            return Date(timeIntervalSince1970: timeInterval)
        }
        if let number = value as? NSNumber {
            return Date(timeIntervalSince1970: number.doubleValue)
        }
        if let timestamp = value as? Timestamp {
            return timestamp.dateValue()
        }
        return nil
    }
}
