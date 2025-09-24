import SwiftUI
import Combine

final class ImageCache {
    static let shared = ImageCache()
    private let cache = NSCache<NSURL, UIImage>()

    private init() {
        cache.countLimit = 200
        cache.totalCostLimit = 1024 * 1024 * 200 // 200 MB
    }

    func image(for url: NSURL) -> UIImage? {
        cache.object(forKey: url)
    }

    func insert(_ image: UIImage, for url: NSURL) {
        cache.setObject(image, forKey: url)
    }
}

final class ImageLoader: ObservableObject {
    @Published var image: UIImage?

    private var cancellable: AnyCancellable?
    private var currentURL: URL?

    func load(url: URL?) {
        guard currentURL != url else { return }
        currentURL = url
        image = nil
        cancellable?.cancel()

        guard let url else { return }

        if let cached = ImageCache.shared.image(for: url as NSURL) {
            image = cached
            return
        }

        cancellable = URLSession.shared.dataTaskPublisher(for: url)
            .map { UIImage(data: $0.data) }
            .replaceError(with: nil)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] downloaded in
                guard let self else { return }
                if let downloaded {
                    ImageCache.shared.insert(downloaded, for: url as NSURL)
                    self.image = downloaded
                }
            }
    }

    func cancel() {
        cancellable?.cancel()
        cancellable = nil
    }
}

struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    @StateObject private var loader = ImageLoader()
    private let url: URL?
    private let content: (Image) -> Content
    private let placeholder: () -> Placeholder

    init(
        url: URL?,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.url = url
        self.content = content
        self.placeholder = placeholder
    }

    var body: some View {
        Group {
            if let image = loader.image {
                content(Image(uiImage: image))
            } else {
                placeholder()
            }
        }
        .onAppear { loader.load(url: url) }
        .onChange(of: url) { _, newValue in
            loader.load(url: newValue)
        }
        .onDisappear {
            loader.cancel()
        }
    }
}
