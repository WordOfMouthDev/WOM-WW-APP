import Foundation
import FirebaseFirestore

actor BusinessResolver {
    static let shared = BusinessResolver()

    private let db = Firestore.firestore()
    private var googleCache: [String: String] = [:]

    func resolve(_ businesses: [Business]) async -> [Business] {
        guard !businesses.isEmpty else { return businesses }

        var placeToWomId: [String: String] = [:]
        let uniquePlaceIds = Set(businesses.compactMap { $0.googlePlaceId })

        for placeId in uniquePlaceIds {
            if let cached = googleCache[placeId] {
                placeToWomId[placeId] = cached
                continue
            }

            do {
                let docRef = db.collection("businessResolvers").document(Self.googleResolverId(for: placeId))
                let snapshot = try await docRef.getDocument()
                if let data = snapshot.data(), let womId = data["womId"] as? String, !womId.isEmpty {
                    placeToWomId[placeId] = womId
                    googleCache[placeId] = womId
                }
            } catch {
                // Resolver lookup failures should not block search results; log and continue.
                print("BusinessResolver.resolve lookup failed for \(placeId): \(error)")
            }
        }

        return businesses.map { business in
            guard let placeId = business.googlePlaceId,
                  let womId = placeToWomId[placeId],
                  womId != business.womId else {
                return business
            }

            return business.updating(womId: womId)
        }
    }

    func persist(_ businesses: [Business]) async throws -> [Business] {
        guard !businesses.isEmpty else { return businesses }

        var persistedBusinesses: [Business] = []
        persistedBusinesses.reserveCapacity(businesses.count)

        for business in businesses {
            var canonicalBusiness = business

            if let placeId = business.googlePlaceId {
                if let cached = googleCache[placeId], cached != business.womId {
                    canonicalBusiness = business.updating(womId: cached)
                } else {
                    let docRef = db.collection("businessResolvers").document(Self.googleResolverId(for: placeId))
                    let snapshot = try await docRef.getDocument()
                    if let data = snapshot.data(), let womId = data["womId"] as? String, !womId.isEmpty, womId != business.womId {
                        canonicalBusiness = business.updating(womId: womId)
                        googleCache[placeId] = womId
                    }
                }
            }

            let businessRef = db.collection("businesses").document(canonicalBusiness.womId)

            do {
                let existingSnapshot = try await businessRef.getDocument()
                if let data = existingSnapshot.data(),
                   let existingBusiness = Business.fromDictionary(data) {
                    if !canonicalBusiness.isVerified && existingBusiness.isVerified {
                        canonicalBusiness = canonicalBusiness.updating(isVerified: true)
                    }
                    canonicalBusiness = canonicalBusiness.updatingFeedbackCounts(
                        likeCount: existingBusiness.likeCount,
                        dislikeCount: existingBusiness.dislikeCount
                    )
                }
            } catch {
                print("BusinessResolver.persist verification check failed: \(error)")
            }

            var payload = canonicalBusiness.toDictionary()

            try await businessRef.setData(payload, merge: true)

            for placeId in canonicalBusiness.externalIds.googlePlaceIds {
                try await storeResolver(
                    id: Self.googleResolverId(for: placeId),
                    payload: [
                        "womId": canonicalBusiness.womId,
                        "source": "google",
                        "placeId": placeId,
                        "name": canonicalBusiness.name,
                        "updatedAt": FieldValue.serverTimestamp()
                    ]
                )
                googleCache[placeId] = canonicalBusiness.womId
            }

            if let phoneNumber = normalizedPhoneNumber(from: canonicalBusiness.phoneNumber) {
                try await storeResolver(
                    id: "phone:\(phoneNumber)",
                    payload: [
                        "womId": canonicalBusiness.womId,
                        "type": "phone",
                        "value": phoneNumber,
                        "updatedAt": FieldValue.serverTimestamp()
                    ]
                )
            }

            if let host = websiteHost(from: canonicalBusiness.website) {
                try await storeResolver(
                    id: "website:\(host)",
                    payload: [
                        "womId": canonicalBusiness.womId,
                        "type": "website",
                        "value": host,
                        "updatedAt": FieldValue.serverTimestamp()
                    ]
                )
            }

            persistedBusinesses.append(canonicalBusiness)
        }

        return persistedBusinesses
    }

    private func storeResolver(id: String, payload: [String: Any]) async throws {
        guard !id.isEmpty else { return }
        try await db.collection("businessResolvers").document(id).setData(payload, merge: true)
    }

    private static func googleResolverId(for placeId: String) -> String {
        "place:google:\(placeId)"
    }

    private func normalizedPhoneNumber(from value: String?) -> String? {
        guard let value = value else { return nil }
        let digits = value.filter { $0.isNumber }
        guard digits.count >= 7 else { return nil }
        return digits
    }

    private func websiteHost(from value: String?) -> String? {
        guard let value = value, let url = URL(string: value.lowercased()) else { return nil }
        return url.host?.replacingOccurrences(of: "www.", with: "")
    }
}
