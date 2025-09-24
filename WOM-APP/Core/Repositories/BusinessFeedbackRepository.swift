import Foundation
import FirebaseFirestore

enum BusinessFeedbackValue: String {
    case like
    case dislike
}

struct BusinessFeedbackCounts {
    let likeCount: Int
    let dislikeCount: Int
}

protocol BusinessFeedbackRepository {
    func currentFeedback(for userId: String, businessId: String) async throws -> BusinessFeedbackValue?
    func setFeedback(
        for userId: String,
        businessId: String,
        newValue: BusinessFeedbackValue?
    ) async throws -> BusinessFeedbackCounts
}

final class FirestoreBusinessFeedbackRepository: BusinessFeedbackRepository {
    private let db = Firestore.firestore()

    func currentFeedback(for userId: String, businessId: String) async throws -> BusinessFeedbackValue? {
        let doc = try await db.collection("users")
            .document(userId)
            .collection("businessFeedback")
            .document(businessId)
            .getDocument()

        guard let value = doc.data()? ["value"] as? String else {
            return nil
        }
        return BusinessFeedbackValue(rawValue: value)
    }

    func setFeedback(
        for userId: String,
        businessId: String,
        newValue: BusinessFeedbackValue?
    ) async throws -> BusinessFeedbackCounts {
        let userRef = db.collection("users")
            .document(userId)
            .collection("businessFeedback")
            .document(businessId)
        let businessRef = db.collection("businesses").document(businessId)

        let result = try await db.runTransaction { transaction, _ -> Any? in
            let userSnapshot = try? transaction.getDocument(userRef)
            let previousData = userSnapshot?.data()
            let previousValue = (previousData?["value"] as? String).flatMap(BusinessFeedbackValue.init(rawValue:))

            let businessSnapshot = try? transaction.getDocument(businessRef)
            let businessData = businessSnapshot?.data()
            let previousLikeCount = businessData?["likeCount"] as? Int ?? 0
            let previousDislikeCount = businessData?["dislikeCount"] as? Int ?? 0

            var likeIncrement = 0
            var dislikeIncrement = 0

            if previousValue == .like { likeIncrement -= 1 }
            if previousValue == .dislike { dislikeIncrement -= 1 }

            if newValue == .like { likeIncrement += 1 }
            if newValue == .dislike { dislikeIncrement += 1 }

            if let newValue {
                transaction.setData([
                    "value": newValue.rawValue,
                    "updatedAt": FieldValue.serverTimestamp()
                ], forDocument: userRef, merge: true)
            } else {
                transaction.deleteDocument(userRef)
            }

            if likeIncrement != 0 {
                transaction.updateData([
                    "likeCount": FieldValue.increment(Int64(likeIncrement))
                ], forDocument: businessRef)
            }

            if dislikeIncrement != 0 {
                transaction.updateData([
                    "dislikeCount": FieldValue.increment(Int64(dislikeIncrement))
                ], forDocument: businessRef)
            }

            let updatedLike = max(previousLikeCount + likeIncrement, 0)
            let updatedDislike = max(previousDislikeCount + dislikeIncrement, 0)

            return ["likeCount": updatedLike, "dislikeCount": updatedDislike]
        }

        if let counts = result as? [String: Int],
           let like = counts["likeCount"],
           let dislike = counts["dislikeCount"] {
            return BusinessFeedbackCounts(likeCount: like, dislikeCount: dislike)
        }

        return BusinessFeedbackCounts(likeCount: 0, dislikeCount: 0)
    }
}
