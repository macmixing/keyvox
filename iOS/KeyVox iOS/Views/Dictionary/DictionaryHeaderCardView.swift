import SwiftUI

struct DictionaryHeaderCardView: View {
    var body: some View {
        Text("Add custom words, email addresses, and short phrases to improve transcription accuracy.")
            .font(.appFont(12))
            .foregroundStyle(.yellow)
            .padding(.horizontal, 10)
            .frame(maxWidth: 340)
            .frame(maxWidth: .infinity, alignment: .center)
            .multilineTextAlignment(.center)
    }
}
