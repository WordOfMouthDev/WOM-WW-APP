import Foundation

@MainActor
final class BusinessDetailViewModel: ObservableObject {
    @Published private(set) var business: Business
    @Published private(set) var userFeedback: BusinessFeedbackValue?
    @Published private(set) var isSaving = false
    @Published var errorMessage: String?

    private let repository: BusinessFeedbackRepository
    private let userId: String

    init(
        business: Business,
        userId: String,
        repository: BusinessFeedbackRepository = FirestoreBusinessFeedbackRepository()
    ) {
        self.business = business
        self.userId = userId
        self.repository = repository

        Task {
            await loadFeedback()
        }
    }

    var isVerified: Bool {
        business.isVerified
    }

    func toggleFeedback(_ value: BusinessFeedbackValue) {
        guard !isSaving else { return }
        let newValue: BusinessFeedbackValue? = (userFeedback == value) ? nil : value
        Task { await setFeedback(newValue) }
    }

    private func loadFeedback() async {
        do {
            let current = try await repository.currentFeedback(for: userId, businessId: business.womId)
            self.errorMessage = nil
            self.userFeedback = current
        } catch {
            self.errorMessage = "Unable to load your feedback."
        }
    }

    private func setFeedback(_ value: BusinessFeedbackValue?) async {
        isSaving = true
        errorMessage = nil

        do {
            let counts = try await repository.setFeedback(for: userId, businessId: business.womId, newValue: value)
            self.userFeedback = value
            self.business = self.business.updatingFeedbackCounts(likeCount: counts.likeCount, dislikeCount: counts.dislikeCount)
        } catch {
            self.errorMessage = "Failed to save feedback. Please try again."
        }

        isSaving = false
    }
}
