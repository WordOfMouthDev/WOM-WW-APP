import Foundation

enum LoadableState<Value> {
    case idle
    case loading
    case loaded(Value)
    case failed(Error)
}

extension LoadableState {
    var value: Value? {
        if case .loaded(let value) = self { return value }
        return nil
    }

    var error: Error? {
        if case .failed(let error) = self { return error }
        return nil
    }

    var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }
}
