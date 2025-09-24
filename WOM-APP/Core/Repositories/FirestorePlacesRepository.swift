import Foundation
import FirebaseFirestore

protocol PlacesRepository {
    func watchPlaces(for uid: String, limit: Int, onError: ((Error) -> Void)?) -> AsyncStream<[Business]>
}

final class FirestorePlacesRepository: PlacesRepository {
    private let db = Firestore.firestore()

    func watchPlaces(for uid: String, limit: Int = 100, onError: ((Error) -> Void)? = nil) -> AsyncStream<[Business]> {
        let database = db

        return AsyncStream { continuation in
            let query = database.collection("users")
                .document(uid)
                .collection("mySpots")
                .order(by: "addedAt", descending: true)
                .limit(to: limit)

            let listener = query.addSnapshotListener { snapshot, error in
                if let error = error {
                    onError?(error)
                    return
                }

                guard let documents = snapshot?.documents else {
                    continuation.yield([])
                    return
                }

                Task {
                    if documents.isEmpty {
                        do {
                            let userSnapshot = try await database.collection("users").document(uid).getDocument()
                            if let rawPlaces = userSnapshot.data()?["visitedBusinesses"] as? [[String: Any]] {
                                let fallback = rawPlaces.compactMap(Business.fromDictionary)
                                continuation.yield(fallback)
                            } else {
                                continuation.yield([])
                            }
                        } catch {
                            onError?(error)
                        }
                        return
                    }

                    var businesses: [Business] = []
                    businesses.reserveCapacity(documents.count)

                    for document in documents {
                        let data = document.data()
                        let womId = data["womId"] as? String ?? document.documentID
                        guard !womId.isEmpty else { continue }

                        do {
                            let businessSnapshot = try await database.collection("businesses").document(womId).getDocument()
                            guard let businessData = businessSnapshot.data(),
                                  let business = Business.fromDictionary(businessData) else {
                                continue
                            }
                            businesses.append(business)
                        } catch {
                            onError?(error)
                        }
                    }

                    continuation.yield(businesses)
                }
            }

            continuation.onTermination = { _ in
                listener.remove()
            }
        }
    }
}
