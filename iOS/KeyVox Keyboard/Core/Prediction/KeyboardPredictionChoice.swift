import Foundation

struct KeyboardPredictionChoice: Equatable {
    enum Kind: Equatable {
        case literal
        case correction
        case completion
        case nextWord
        case accent
    }

    let text: String
    let kind: Kind
}
