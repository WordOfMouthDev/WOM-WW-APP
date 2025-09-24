import Foundation

enum MessageType: String, Codable, CaseIterable {
    case text = "text"
    case image = "image"
    case system = "system" // For system messages like "User joined chat"
}

enum MessageStatus: String, Codable, CaseIterable {
    case sending = "sending"
    case sent = "sent"
    case delivered = "delivered"
    case read = "read"
    case failed = "failed"
}

struct Message: Codable, Identifiable, Hashable {
    let id: String
    let chatId: String
    let senderId: String
    let senderName: String
    let senderUsername: String
    let senderProfileImageURL: String
    let content: String
    let type: MessageType
    let timestamp: Date
    var status: MessageStatus
    let replyToMessageId: String? // For message replies
    let imageURL: String? // For image messages
    
    init(
        chatId: String,
        senderId: String,
        senderName: String,
        senderUsername: String,
        senderProfileImageURL: String = "",
        content: String,
        type: MessageType = .text,
        status: MessageStatus = .sending,
        replyToMessageId: String? = nil,
        imageURL: String? = nil
    ) {
        self.id = UUID().uuidString
        self.chatId = chatId
        self.senderId = senderId
        self.senderName = senderName
        self.senderUsername = senderUsername
        self.senderProfileImageURL = senderProfileImageURL
        self.content = content
        self.type = type
        self.timestamp = Date()
        self.status = status
        self.replyToMessageId = replyToMessageId
        self.imageURL = imageURL
    }
    
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "id": id,
            "chatId": chatId,
            "senderId": senderId,
            "senderName": senderName,
            "senderUsername": senderUsername,
            "senderProfileImageURL": senderProfileImageURL,
            "content": content,
            "type": type.rawValue,
            "timestamp": timestamp.timeIntervalSince1970,
            "status": status.rawValue
        ]
        
        if let replyToMessageId = replyToMessageId {
            dict["replyToMessageId"] = replyToMessageId
        }
        
        if let imageURL = imageURL {
            dict["imageURL"] = imageURL
        }
        
        return dict
    }
    
    static func fromDictionary(_ dict: [String: Any]) -> Message? {
        guard let id = dict["id"] as? String,
              let chatId = dict["chatId"] as? String,
              let senderId = dict["senderId"] as? String,
              let senderName = dict["senderName"] as? String,
              let senderUsername = dict["senderUsername"] as? String,
              let content = dict["content"] as? String,
              let typeString = dict["type"] as? String,
              let type = MessageType(rawValue: typeString),
              let timestampInterval = dict["timestamp"] as? TimeInterval,
              let statusString = dict["status"] as? String,
              let status = MessageStatus(rawValue: statusString) else {
            return nil
        }
        
        let senderProfileImageURL = dict["senderProfileImageURL"] as? String ?? ""
        let timestamp = Date(timeIntervalSince1970: timestampInterval)
        let replyToMessageId = dict["replyToMessageId"] as? String
        let imageURL = dict["imageURL"] as? String
        
        var message = Message(
            chatId: chatId,
            senderId: senderId,
            senderName: senderName,
            senderUsername: senderUsername,
            senderProfileImageURL: senderProfileImageURL,
            content: content,
            type: type,
            replyToMessageId: replyToMessageId,
            imageURL: imageURL
        )
        
        // Override the generated values with the ones from the dictionary
        message = Message(
            id: id,
            chatId: chatId,
            senderId: senderId,
            senderName: senderName,
            senderUsername: senderUsername,
            senderProfileImageURL: senderProfileImageURL,
            content: content,
            type: type,
            timestamp: timestamp,
            status: status,
            replyToMessageId: replyToMessageId,
            imageURL: imageURL
        )
        
        return message
    }
    
    // Custom init for dictionary data
    private init(
        id: String,
        chatId: String,
        senderId: String,
        senderName: String,
        senderUsername: String,
        senderProfileImageURL: String,
        content: String,
        type: MessageType,
        timestamp: Date,
        status: MessageStatus,
        replyToMessageId: String?,
        imageURL: String?
    ) {
        self.id = id
        self.chatId = chatId
        self.senderId = senderId
        self.senderName = senderName
        self.senderUsername = senderUsername
        self.senderProfileImageURL = senderProfileImageURL
        self.content = content
        self.type = type
        self.timestamp = timestamp
        self.status = status
        self.replyToMessageId = replyToMessageId
        self.imageURL = imageURL
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: Message, rhs: Message) -> Bool {
        lhs.id == rhs.id
    }

    func updatingSender(
        name: String? = nil,
        username: String? = nil,
        profileImageURL: String? = nil
    ) -> Message {
        Message(
            id: id,
            chatId: chatId,
            senderId: senderId,
            senderName: name ?? senderName,
            senderUsername: username ?? senderUsername,
            senderProfileImageURL: profileImageURL ?? senderProfileImageURL,
            content: content,
            type: type,
            timestamp: timestamp,
            status: status,
            replyToMessageId: replyToMessageId,
            imageURL: imageURL
        )
    }
}
