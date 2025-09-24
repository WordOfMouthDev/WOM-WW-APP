import Foundation
import SwiftUI
import FirebaseAuth
import FirebaseCore
import FirebaseFirestore
import FirebaseStorage
import GoogleSignIn

class AuthViewModel: ObservableObject {
    @Published var isAuthenticated: Bool = false
    @Published var email: String = ""
    @Published var password: String = ""
    @Published var displayName: String = ""
    @Published var username: String = ""
    @Published var profileImageURL: String = ""
    @Published var errorMessage: String? = nil
    @Published var isLoading: Bool = false
    @Published var currentUserProfile: UserProfile? = nil
    // Used to force image reload in UI after updates
    @Published var imageCacheBuster: Int = 0

    private var authStateHandle: AuthStateDidChangeListenerHandle?

    init() {
        // Ensure Firebase is configured (helps with SwiftUI previews/tests)
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        // Keep local auth state in sync with Firebase
        authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            self?.isAuthenticated = (user != nil)
            if let uid = user?.uid {
                self?.loadUserProfile(uid: uid)
            } else {
                self?.currentUserProfile = nil
            }
        }
        isAuthenticated = Auth.auth().currentUser != nil
        if let uid = Auth.auth().currentUser?.uid { loadUserProfile(uid: uid) }
    }

    deinit {
        if let handle = authStateHandle { Auth.auth().removeStateDidChangeListener(handle) }
    }

    func signIn() {
        let email = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let password = password
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "Email and password are required."
            return
        }
        errorMessage = nil
        isLoading = true
        Auth.auth().signIn(withEmail: email, password: password) { [weak self] _, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                if let error = error {
                    self?.errorMessage = Self.mapAuthError(error)
                }
            }
        }
    }

    func register() {
        let email = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let password = password
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "Email and password are required."
            return
        }
        errorMessage = nil
        isLoading = true
        Auth.auth().createUser(withEmail: email, password: password) { [weak self] result, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                if let error = error {
                    self?.errorMessage = Self.mapAuthError(error)
                    return
                }
                guard let self = self, let user = result?.user else { return }

                // Create user document in Firestore with empty display/username
                self.createUserDocument(uid: user.uid, email: email, displayName: "", username: "", profileImageURL: self.profileImageURL)
            }
        }
    }

    private func createUserDocument(uid: String, email: String, displayName: String, username: String, profileImageURL: String) {
        let db = Firestore.firestore()
        let userProfile = UserProfile(
            email: email,
            displayName: displayName,
            username: username,
            profileImageURL: profileImageURL,
            uid: uid,
            dateOfBirth: nil,
            phoneNumber: nil,
            selectedServices: nil,
            location: nil,
            onboardingProgress: OnboardingProgress()
        )
        
        db.collection("users").document(uid).setData(userProfile.toDictionary()) { [weak self] error in
            if let error = error {
                DispatchQueue.main.async {
                    self?.errorMessage = "Failed to save profile: \(error.localizedDescription)"
                }
            } else {
                DispatchQueue.main.async {
                    self?.currentUserProfile = userProfile
                }
            }
        }
    }

    func loadUserProfile(uid: String) {
        let db = Firestore.firestore()
        db.collection("users").document(uid).getDocument { [weak self] snapshot, error in
            guard let data = snapshot?.data(), error == nil else { return }
            DispatchQueue.main.async {
                self?.currentUserProfile = UserProfile.fromDictionary(data, uid: uid)
            }
        }
    }

    func updateProfile(newDisplayName: String, imageData: Data?) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        var updates: [String: Any] = ["displayName": newDisplayName]

        func commitUpdates(with imageURL: String?) {
            if let imageURL { updates["profileImageURL"] = imageURL }
            Firestore.firestore().collection("users").document(uid).setData(updates, merge: true) { [weak self] error in
                if let error = error {
                    DispatchQueue.main.async { self?.errorMessage = "Failed to update profile: \(error.localizedDescription)" }
                } else {
                    // Reflect in Firebase Auth profile
                    if let change = Auth.auth().currentUser?.createProfileChangeRequest() {
                        change.displayName = newDisplayName
                        if let imageURL, let photoURL = URL(string: imageURL) {
                            change.photoURL = photoURL
                        }
                        change.commitChanges(completion: nil)
                    }
                    // Refresh cached profile
                    self?.loadUserProfile(uid: uid)
                    Task { [weak self] in
                        guard let self else { return }
                        await self.syncProfileReferences(uid: uid, displayName: newDisplayName, profileImageURL: imageURL)
                    }
                    // Bump cache buster so UI reloads image
                    DispatchQueue.main.async { self?.imageCacheBuster = Int(Date().timeIntervalSince1970) }
                }
            }
        }

        // If no image to upload, just update display name
        guard let imageData else { commitUpdates(with: nil); return }

        // Use the exact bucket from GoogleService-Info.plist to avoid domain mismatches
        let storage: Storage
        if let bucket = FirebaseApp.app()?.options.storageBucket, !bucket.isEmpty {
            storage = Storage.storage(url: "gs://\(bucket)")
        } else {
            storage = Storage.storage()
        }
        //firebase rule must send params correctly so it works uid must go seperately
        let storageRef = storage.reference().child("profile_images/\(uid)/\(uid).jpg")
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        let uploadData = ImageProcessor.prepareUploadData(imageData)
        storageRef.putData(uploadData, metadata: metadata) { _, error in
            if let error = error {
                DispatchQueue.main.async { self.errorMessage = "Image upload failed: \(error.localizedDescription)" }
                return
            }
            storageRef.downloadURL { url, _ in
                commitUpdates(with: url?.absoluteString)
            }
        }
    }

    func sendPasswordReset(to email: String) {
        let email = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !email.isEmpty else {
            errorMessage = "Enter your email to reset password."
            return
        }
        errorMessage = nil
        Auth.auth().sendPasswordReset(withEmail: email) { [weak self] error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.errorMessage = Self.mapAuthError(error)
                }
            }
        }
    }
    
    func signInWithGoogle() {
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            errorMessage = "Firebase client ID not found."
            return
        }
        
        // Create Google Sign In configuration object
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config
        
        // Get the root view controller
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let rootViewController = window.rootViewController else {
            errorMessage = "Unable to get root view controller."
            return
        }
        
        errorMessage = nil
        isLoading = true
        
        // Start the sign-in flow
        GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController) { [weak self] result, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    self?.errorMessage = "Google Sign-In failed: \(error.localizedDescription)"
                    return
                }
                
                guard let user = result?.user,
                      let idToken = user.idToken?.tokenString else {
                    self?.errorMessage = "Failed to get Google credentials."
                    return
                }
                
                let credential = GoogleAuthProvider.credential(
                    withIDToken: idToken,
                    accessToken: user.accessToken.tokenString
                )
                
                // Sign in with Firebase using Google credentials
                Auth.auth().signIn(with: credential) { [weak self] authResult, error in
                    DispatchQueue.main.async {
                        if let error = error {
                            self?.errorMessage = Self.mapAuthError(error)
                            return
                        }
                        
                        guard let self = self, let user = authResult?.user else { return }
                        
                        // Check if user document exists, if not create one
                        let db = Firestore.firestore()
                        db.collection("users").document(user.uid).getDocument { snapshot, error in
                            if snapshot?.exists == false {
                                // Create new user document with Google account info
                                let displayName = user.displayName ?? ""
                                let email = user.email ?? ""
                                let profileImageURL = user.photoURL?.absoluteString ?? ""
                                
                                DispatchQueue.main.async {
                                    self.createUserDocument(
                                        uid: user.uid,
                                        email: email,
                                        displayName: displayName,
                                        username: "", // Can be set later by user
                                        profileImageURL: profileImageURL
                                    )
                                }
                            } else {
                                // User exists, load their profile
                                DispatchQueue.main.async {
                                    self.loadUserProfile(uid: user.uid)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    func logout() {
        do {
            try Auth.auth().signOut()
        } catch {
            errorMessage = Self.mapAuthError(error)
        }
    }

    private func syncProfileReferences(uid: String, displayName: String, profileImageURL: String?) async {
        let db = Firestore.firestore()
        do {
            // Update any pending friend requests sent by this user
            let outgoingRequests = try await db.collection("friendRequests")
                .whereField("fromUID", isEqualTo: uid)
                .getDocuments()
            for document in outgoingRequests.documents {
                var updates: [String: Any] = [
                    "fromDisplayName": displayName
                ]
                if let profileImageURL = profileImageURL {
                    updates["fromProfileImageURL"] = profileImageURL
                }
                try await document.reference.updateData(updates)
            }

            // Update friend references stored in other users' collections
            let friendEntries = try await db.collectionGroup("friends")
                .whereField("uid", isEqualTo: uid)
                .getDocuments()
            for document in friendEntries.documents {
                var updates: [String: Any] = [
                    "displayName": displayName
                ]
                if let profileImageURL = profileImageURL {
                    updates["profileImageURL"] = profileImageURL
                }
                try await document.reference.updateData(updates)
            }

            // Update chat participant metadata so conversations show the latest profile info
            let chats = try await db.collection("chats")
                .whereField("participantUIDs", arrayContains: uid)
                .getDocuments()
            for document in chats.documents {
                var updates: [String: Any] = [
                    "participants.\(uid).displayName": displayName
                ]
                if let profileImageURL = profileImageURL {
                    updates["participants.\(uid).profileImageURL"] = profileImageURL
                }
                try await document.reference.updateData(updates)
            }
        } catch {
            print("⚠️ Failed to sync profile references for user \(uid): \(error.localizedDescription)")
        }
    }

    private static func mapAuthError(_ error: Error) -> String {
        let nsError = error as NSError
        // Provide user-friendly messages for common cases
        if nsError.domain == AuthErrorDomain, let code = AuthErrorCode(rawValue: nsError.code) {
            switch code {
            case .networkError: return "Network error. Check your connection."
            case .userNotFound, .wrongPassword: return "Invalid email or password."
            case .emailAlreadyInUse: return "Email already in use."
            case .weakPassword: return "Password is too weak."
            case .invalidEmail: return "Invalid email address."
            default: break
            }
        }
        return nsError.localizedDescription
    }
}
