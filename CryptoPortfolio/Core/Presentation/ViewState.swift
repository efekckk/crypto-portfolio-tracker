import Foundation

/// Generic state for an async screen: loading, loaded data, empty, or an error message.
enum ViewState<T: Equatable>: Equatable {
    case loading
    case loaded(T)
    case empty
    case error(String)
}
