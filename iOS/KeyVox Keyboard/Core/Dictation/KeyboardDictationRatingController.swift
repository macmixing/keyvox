import Foundation

enum KeyboardDictationRatingButtonState {
    case inactive
    case unrated
    case rated
}

@MainActor
final class KeyboardDictationRatingController {
    private let store: PersonalDictationCaptureStore
    private var activeVariant: PersonalDictationCaptureVariantState?
    private var isActiveVariantAttachedToInsertion = false

    init(store: PersonalDictationCaptureStore = .shared) {
        self.store = store
    }

    var buttonState: KeyboardDictationRatingButtonState {
        guard let activeVariant else {
            return .inactive
        }

        switch activeVariant.rating {
        case .unrated:
            return .unrated
        case .good, .bad:
            return .rated
        }
    }

    func activate(_ context: PersonalDictationCaptureVariantContext) {
        activeVariant = store.upsertVariant(context)
        isActiveVariantAttachedToInsertion = true
    }

    func deactivate() {
        activeVariant = nil
        isActiveVariantAttachedToInsertion = false
    }

    func detachFromInsertionIfNeeded() {
        guard isActiveVariantAttachedToInsertion else { return }
        activeVariant = nil
        isActiveVariantAttachedToInsertion = false
    }

    func markGood() -> Bool {
        guard let activeVariant,
              let updated = store.rateVariant(variantID: activeVariant.variantID, rating: .good) else {
            return false
        }

        self.activeVariant = updated
        isActiveVariantAttachedToInsertion = false
        return true
    }

    func markBad() -> Bool {
        guard let activeVariant,
              let updated = store.rateVariant(variantID: activeVariant.variantID, rating: .bad) else {
            return false
        }

        self.activeVariant = updated
        isActiveVariantAttachedToInsertion = false
        return true
    }

    func undoOrRearmLatestUnrated() -> Bool {
        if let activeVariant, activeVariant.rating != .unrated {
            guard let updated = store.clearRating(variantID: activeVariant.variantID) else {
                return false
            }

            self.activeVariant = updated
            isActiveVariantAttachedToInsertion = false
            return true
        }

        guard let rearmed = store.latestUnratedVariant() else {
            return false
        }

        activeVariant = PersonalDictationCaptureVariantState(
            variantID: rearmed.variantID,
            rating: .unrated
        )
        isActiveVariantAttachedToInsertion = false
        return true
    }
}
