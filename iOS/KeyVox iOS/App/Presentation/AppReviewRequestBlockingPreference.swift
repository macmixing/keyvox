import SwiftUI

private struct AppReviewRequestBlockingPreferenceKey: PreferenceKey {
    static var defaultValue = false

    static func reduce(value: inout Bool, nextValue: () -> Bool) {
        value = value || nextValue()
    }
}

extension View {
    func blocksAppReviewRequest(_ isBlocked: Bool) -> some View {
        preference(key: AppReviewRequestBlockingPreferenceKey.self, value: isBlocked)
    }

    func onAppReviewRequestBlockingChange(
        perform action: @escaping (Bool) -> Void
    ) -> some View {
        onPreferenceChange(AppReviewRequestBlockingPreferenceKey.self, perform: action)
    }
}
