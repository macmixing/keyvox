import Foundation

/// One language a language list offers: its identifier and the name the list shows for it.
struct LanguageListOption: Identifiable, Hashable {
    let id: String
    let name: String
}
