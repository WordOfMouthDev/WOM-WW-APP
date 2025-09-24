import Foundation
import SwiftUI
import FirebaseAuth
import FirebaseFirestore

class OnboardingViewModel: ObservableObject {
    @Published var onboardingProgress = OnboardingProgress()
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var selectedDate = Date()
    @Published var selectedServices: [String]?
    @Published var userLocation: UserLocation?
    
    private let db = Firestore.firestore()
    
    init() {
        loadOnboardingProgress()
    }
    
    func loadOnboardingProgress() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        
        db.collection("users").document(uid).getDocument { [weak self] snapshot, error in
            guard let data = snapshot?.data(), error == nil else { return }
            
            DispatchQueue.main.async {
                // Load onboarding progress
                if let progressDict = data["onboardingProgress"] as? [String: Any] {
                    self?.onboardingProgress = OnboardingProgress.fromDictionary(progressDict)
                }
                
                // Load selected services for business selection
                if let servicesArray = data["selectedServices"] as? [String] {
                    self?.selectedServices = servicesArray
                }
                
                // Load user location for business search
                if let locationDict = data["location"] as? [String: Any] {
                    self?.userLocation = UserLocation.fromDictionary(locationDict)
                } else {
                    // If no saved location but location step is completed, try to get current location
                    self?.loadCurrentLocationIfNeeded()
                }
            }
        }
    }
    
    private func loadCurrentLocationIfNeeded() {
        // Check if location step is completed but we don't have location data
        let locationStepCompleted = onboardingProgress.steps.first { $0.id == "location_permission" }?.isCompleted ?? false
        
        if locationStepCompleted && userLocation == nil {
            // Try to get current location from LocationManager
            let locationManager = LocationManager.shared
            
            // Check if we have permission and location
            if locationManager.authorizationStatus == .authorizedWhenInUse || 
               locationManager.authorizationStatus == .authorizedAlways,
               let currentLocation = locationManager.location {
                
                // Create UserLocation from current location
                self.userLocation = UserLocation(
                    latitude: currentLocation.coordinate.latitude,
                    longitude: currentLocation.coordinate.longitude,
                    city: nil,
                    state: nil,
                    country: nil,
                    isPermissionGranted: true
                )
            }
        }
    }
    
    func saveOnboardingProgress() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        
        isLoading = true
        errorMessage = nil
        
        let updates = ["onboardingProgress": onboardingProgress.toDictionary()]
        
        db.collection("users").document(uid).setData(updates, merge: true) { [weak self] error in
            DispatchQueue.main.async {
                self?.isLoading = false
                if let error = error {
                    self?.errorMessage = "Failed to save progress: \(error.localizedDescription)"
                }
            }
        }
    }
    
    func completeBirthdayStep() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        
        isLoading = true
        errorMessage = nil
        
        // Complete the birthday step
        onboardingProgress.completeStep(stepId: "birthday")
        
        let updates: [String: Any] = [
            "dateOfBirth": selectedDate.timeIntervalSince1970,
            "onboardingProgress": onboardingProgress.toDictionary()
        ]
        
        db.collection("users").document(uid).setData(updates, merge: true) { [weak self] error in
            DispatchQueue.main.async {
                self?.isLoading = false
                if let error = error {
                    self?.errorMessage = "Failed to save birthday: \(error.localizedDescription)"
                }
            }
        }
    }
    
    func completeStep(stepId: String, additionalData: [String: Any] = [:]) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        
        isLoading = true
        errorMessage = nil
        
        // Complete the step
        onboardingProgress.completeStep(stepId: stepId)
        
        var updates = additionalData
        updates["onboardingProgress"] = onboardingProgress.toDictionary()
        
        db.collection("users").document(uid).setData(updates, merge: true) { [weak self] error in
            DispatchQueue.main.async {
                self?.isLoading = false
                if let error = error {
                    self?.errorMessage = "Failed to save progress: \(error.localizedDescription)"
                }
            }
        }
    }
    
    var currentStep: OnboardingStep? {
        return onboardingProgress.nextIncompleteStep
    }
    
    var isOnboardingComplete: Bool {
        return onboardingProgress.isCompleted
    }
    
    func resetOnboarding() {
        onboardingProgress = OnboardingProgress()
        saveOnboardingProgress()
    }
    
    func goBackToStep(_ stepId: String) {
        // Find the step index and set it as current
        if let stepIndex = onboardingProgress.steps.firstIndex(where: { $0.id == stepId }) {
            onboardingProgress.currentStepIndex = stepIndex
            
            // Mark steps after this one as incomplete
            for i in stepIndex..<onboardingProgress.steps.count {
                let step = onboardingProgress.steps[i]
                onboardingProgress.steps[i] = OnboardingStep(
                    id: step.id,
                    title: step.title,
                    isCompleted: false,
                    order: step.order
                )
            }
            
            onboardingProgress.isCompleted = false
            saveOnboardingProgress()
        }
    }
    
    // MARK: - Username Management
    
    func checkUsernameAvailability(_ username: String) async throws -> Bool {
        // Check in the usernames collection for fast lookup
        let usernameDoc = try await db.collection("usernames").document(username.lowercased()).getDocument()
        return !usernameDoc.exists
    }
    
    private func reserveUsername(_ username: String, for uid: String) async throws {
        // Reserve username in the usernames collection for indexing
        try await db.collection("usernames").document(username.lowercased()).setData([
            "uid": uid,
            "createdAt": FieldValue.serverTimestamp()
        ])
    }
    
    private func releaseUsername(_ username: String) async throws {
        // Remove username reservation
        try await db.collection("usernames").document(username.lowercased()).delete()
    }
    
    // MARK: - Profile Completion
    
    func completeProfileStep(phoneNumber: String, fullName: String, username: String) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                // Double-check username availability
                let isAvailable = try await checkUsernameAvailability(username)
                guard isAvailable else {
                    await MainActor.run {
                        self.errorMessage = "Username is no longer available"
                        self.isLoading = false
                    }
                    return
                }
                
                // Reserve the username first
                try await reserveUsername(username, for: uid)
                
                // Complete the profile step
                await MainActor.run {
                    self.onboardingProgress.completeStep(stepId: "name_username")
                }
                
                let updates: [String: Any] = [
                    "phoneNumber": phoneNumber,
                    "displayName": fullName,
                    "username": username.lowercased(),
                    "onboardingProgress": onboardingProgress.toDictionary()
                ]
                
                try await db.collection("users").document(uid).setData(updates, merge: true)
                
                await MainActor.run {
                    self.isLoading = false
                }
                
            } catch {
                // If anything fails, release username reservation
                try? await releaseUsername(username)
                
                await MainActor.run {
                    self.errorMessage = "Failed to save profile: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }
    
    // MARK: - Service Selection
    
    func completeServiceSelection(_ serviceIds: [String]) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        guard serviceIds.count >= 3 else {
            errorMessage = "Please select at least 3 services"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        // Store selected services for business category matching
        self.selectedServices = serviceIds
        
        Task {
            do {
                // Complete the service selection step
                await MainActor.run {
                    self.onboardingProgress.completeStep(stepId: "service_selection")
                }
                
                let updates: [String: Any] = [
                    "selectedServices": serviceIds,
                    "onboardingProgress": onboardingProgress.toDictionary()
                ]
                
                try await db.collection("users").document(uid).setData(updates, merge: true)
                
                await MainActor.run {
                    self.isLoading = false
                }
                
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to save service selection: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }
    
    // MARK: - Location Permission
    
    func completeLocationStep(_ userLocation: UserLocation) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        
        isLoading = true
        errorMessage = nil
        
        // Store user location for business search
        self.userLocation = userLocation
        
        Task {
            do {
                // Complete the location permission step
                await MainActor.run {
                    self.onboardingProgress.completeStep(stepId: "location_permission")
                }
                
                let updates: [String: Any] = [
                    "location": userLocation.toDictionary(),
                    "onboardingProgress": onboardingProgress.toDictionary()
                ]
                
                try await db.collection("users").document(uid).setData(updates, merge: true)
                
                await MainActor.run {
                    self.isLoading = false
                }
                
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to save location: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }
    
    // MARK: - Business Selection
    
    func completeBusinessSelection(_ businesses: [Business]) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                // Complete the business selection step
                await MainActor.run {
                    self.onboardingProgress.completeStep(stepId: "business_selection")
                }
                
                let canonicalBusinesses = try await persistBusinesses(businesses)
                try await syncMySpots(for: uid, businesses: canonicalBusinesses)
                let businessDictionaries = canonicalBusinesses.map { $0.toDictionary() }

                let updates: [String: Any] = [
                    "visitedBusinesses": businessDictionaries,
                    "onboardingProgress": onboardingProgress.toDictionary()
                ]

                try await db.collection("users").document(uid).setData(updates, merge: true)
                
                await MainActor.run {
                    self.isLoading = false
                }
                
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to save businesses: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }
}

extension OnboardingViewModel {
    private func persistBusinesses(_ businesses: [Business]) async throws -> [Business] {
        guard !businesses.isEmpty else { return [] }
        let canonicalBusinesses = try await BusinessResolver.shared.persist(businesses)
        return canonicalBusinesses
    }

    private func syncMySpots(for uid: String, businesses: [Business]) async throws {
        let collection = db.collection("users").document(uid).collection("mySpots")
        let existingSnapshot = try await collection.getDocuments()
        let selectedIds = Set(businesses.map(\.womId))
        let existingIds = Set(existingSnapshot.documents.map { $0.documentID })
        let batch = db.batch()
        var hasChanges = false

        for document in existingSnapshot.documents where !selectedIds.contains(document.documentID) {
            batch.deleteDocument(document.reference)
            hasChanges = true
        }

        for business in businesses where !existingIds.contains(business.womId) {
            let data: [String: Any] = [
                "womId": business.womId,
                "addedAt": FieldValue.serverTimestamp()
            ]
            batch.setData(data, forDocument: collection.document(business.womId), merge: true)
            hasChanges = true
        }

        if hasChanges {
            try await batch.commit()
        }
    }
}
