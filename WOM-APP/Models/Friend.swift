import Foundation

struct Friend: Codable, Identifiable {
    let id: String
    let uid: String
    let username: String
    let displayName: String
    let email: String
    let profileImageURL: String
    let dateAdded: Date
    
    init(uid: String, username: String, displayName: String, email: String, profileImageURL: String = "", dateAdded: Date = Date()) {
        self.id = uid
        self.uid = uid
        self.username = username
        self.displayName = displayName
        self.email = email
        self.profileImageURL = profileImageURL
        self.dateAdded = dateAdded
    }
    
    func toDictionary() -> [String: Any] {
        return [
            "uid": uid,
            "username": username,
            "displayName": displayName,
            "email": email,
            "profileImageURL": profileImageURL,
            "dateAdded": dateAdded.timeIntervalSince1970
        ]
    }
    
    static func fromDictionary(_ dict: [String: Any]) -> Friend? {
        guard let uid = dict["uid"] as? String,
              let username = dict["username"] as? String,
              let displayName = dict["displayName"] as? String,
              let email = dict["email"] as? String else {
            return nil
        }
        
        let profileImageURL = dict["profileImageURL"] as? String ?? ""
        let dateAddedTimestamp = dict["dateAdded"] as? TimeInterval ?? Date().timeIntervalSince1970
        let dateAdded = Date(timeIntervalSince1970: dateAddedTimestamp)
        
        return Friend(
            uid: uid,
            username: username,
            displayName: displayName,
            email: email,
            profileImageURL: profileImageURL,
            dateAdded: dateAdded
        )
    }
    
    // Create Friend from UserProfile
    static func fromUserProfile(_ userProfile: UserProfile) -> Friend {
        return Friend(
            uid: userProfile.uid,
            username: userProfile.username,
            displayName: userProfile.displayName,
            email: userProfile.email,
            profileImageURL: userProfile.profileImageURL
        )
    }
}

enum FriendRequestStatus: String, Codable, CaseIterable {
    case pending = "pending"
    case accepted = "accepted"
    case declined = "declined"
}

struct FriendRequest: Codable, Identifiable {
    let id: String
    let fromUID: String
    let toUID: String
    let fromUsername: String
    let fromDisplayName: String
    let fromEmail: String
    let fromProfileImageURL: String
    let status: FriendRequestStatus
    let createdAt: Date
    let updatedAt: Date
    
    init(fromUID: String, toUID: String, fromUsername: String, fromDisplayName: String, fromEmail: String, fromProfileImageURL: String = "", status: FriendRequestStatus = .pending) {
        self.id = "\(fromUID)_\(toUID)"
        self.fromUID = fromUID
        self.toUID = toUID
        self.fromUsername = fromUsername
        self.fromDisplayName = fromDisplayName
        self.fromEmail = fromEmail
        self.fromProfileImageURL = fromProfileImageURL
        self.status = status
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    
    func toDictionary() -> [String: Any] {
        return [
            "fromUID": fromUID,
            "toUID": toUID,
            "fromUsername": fromUsername,
            "fromDisplayName": fromDisplayName,
            "fromEmail": fromEmail,
            "fromProfileImageURL": fromProfileImageURL,
            "status": status.rawValue,
            "createdAt": createdAt.timeIntervalSince1970,
            "updatedAt": updatedAt.timeIntervalSince1970
        ]
    }
    
    static func fromDictionary(_ dict: [String: Any]) -> FriendRequest? {
        guard let fromUID = dict["fromUID"] as? String,
              let toUID = dict["toUID"] as? String,
              let fromUsername = dict["fromUsername"] as? String,
              let fromDisplayName = dict["fromDisplayName"] as? String,
              let fromEmail = dict["fromEmail"] as? String,
              let statusString = dict["status"] as? String,
              let status = FriendRequestStatus(rawValue: statusString) else {
            return nil
        }
        
        let fromProfileImageURL = dict["fromProfileImageURL"] as? String ?? ""
        
        let request = FriendRequest(
            fromUID: fromUID,
            toUID: toUID,
            fromUsername: fromUsername,
            fromDisplayName: fromDisplayName,
            fromEmail: fromEmail,
            fromProfileImageURL: fromProfileImageURL,
            status: status
        )
        
        // Note: createdAt and updatedAt timestamps are handled in the init method
        
        return request
    }
}
