import Foundation

@MainActor
final class PlacesViewModel: ObservableObject {
    @Published var state: LoadableState<[Business]> = .idle

    private let repository: PlacesRepository
    private var watchTask: Task<Void, Never>?
    private var currentUid: String?
    private let limit: Int

    init(repository: PlacesRepository, limit: Int = 100) {
        self.repository = repository
        self.limit = limit
    }

    func watchPlaces(for uid: String) {
        guard !uid.isEmpty else { return }

        if currentUid == uid, watchTask != nil {
            return
        }

        currentUid = uid
        state = .loading
        subscribe(for: uid)
    }

    func retry() {
        guard let uid = currentUid else { return }
        state = .loading
        subscribe(for: uid)
    }

    func stop() {
        watchTask?.cancel()
        watchTask = nil
    }

    deinit {
        watchTask?.cancel()
    }

    private func subscribe(for uid: String) {
        watchTask?.cancel()

        let stream = repository.watchPlaces(for: uid, limit: limit) { [weak self] error in
            Task { @MainActor [weak self] in
                self?.state = .failed(error)
            }
        }

        watchTask = Task { [weak self] in
            guard let self else { return }
            for await businesses in stream {
                await MainActor.run {
                    self.state = .loaded(businesses)
                }
            }
        }
    }
}
