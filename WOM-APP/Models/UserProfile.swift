import Foundation

struct UserProfile: Codable {
    let email: String
    let displayName: String
    let username: String
    let profileImageURL: String
    let uid: String
    let dateOfBirth: Date?
    let phoneNumber: String?
    let selectedServices: [String]? // Array of service IDs
    let location: UserLocation?
    let onboardingProgress: OnboardingProgress

    init(email: String, displayName: String, username: String, profileImageURL: String = "", uid: String, dateOfBirth: Date? = nil, phoneNumber: String? = nil, selectedServices: [String]? = nil, location: UserLocation? = nil, onboardingProgress: OnboardingProgress? = nil) {
        self.email = email
        self.displayName = displayName
        self.username = username
        self.profileImageURL = profileImageURL
        self.uid = uid
        self.dateOfBirth = dateOfBirth
        self.phoneNumber = phoneNumber
        self.selectedServices = selectedServices
        self.location = location
        self.onboardingProgress = onboardingProgress ?? OnboardingProgress()
    }

    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "email": email,
            "displayName": displayName,
            "username": username,
            "profileImageURL": profileImageURL,
            "uid": uid,
            "onboardingProgress": onboardingProgress.toDictionary()
        ]
        
        if let dateOfBirth = dateOfBirth {
            dict["dateOfBirth"] = dateOfBirth.timeIntervalSince1970
        }
        
        if let phoneNumber = phoneNumber {
            dict["phoneNumber"] = phoneNumber
        }
        
        if let selectedServices = selectedServices {
            dict["selectedServices"] = selectedServices
        }
        
        if let location = location {
            dict["location"] = location.toDictionary()
        }
        
        return dict
    }
    
    static func fromDictionary(_ dict: [String: Any], uid: String) -> UserProfile {
        let email = dict["email"] as? String ?? ""
        let displayName = dict["displayName"] as? String ?? ""
        let username = dict["username"] as? String ?? ""
        let profileImageURL = dict["profileImageURL"] as? String ?? ""
        let phoneNumber = dict["phoneNumber"] as? String
        let selectedServices = dict["selectedServices"] as? [String]
        
        var location: UserLocation?
        if let locationDict = dict["location"] as? [String: Any] {
            location = UserLocation.fromDictionary(locationDict)
        }
        
        var dateOfBirth: Date?
        if let timestamp = dict["dateOfBirth"] as? TimeInterval {
            dateOfBirth = Date(timeIntervalSince1970: timestamp)
        }
        
        var onboardingProgress = OnboardingProgress()
        if let progressDict = dict["onboardingProgress"] as? [String: Any] {
            onboardingProgress = OnboardingProgress.fromDictionary(progressDict)
        }
        
        return UserProfile(
            email: email,
            displayName: displayName,
            username: username,
            profileImageURL: profileImageURL,
            uid: uid,
            dateOfBirth: dateOfBirth,
            phoneNumber: phoneNumber,
            selectedServices: selectedServices,
            location: location,
            onboardingProgress: onboardingProgress
        )
    }
}
