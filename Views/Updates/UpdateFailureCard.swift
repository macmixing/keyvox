import SwiftUI

struct UpdateFailureCard: View {
    let message: String

    var body: some View {
        SettingsCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Update Failed")
                    .font(.custom("Kanit Medium", size: 15))
                    .foregroundColor(.white)

                Text(message)
                    .font(.custom("Kanit Medium", size: 12))
                    .foregroundColor(.orange)
                    .lineSpacing(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
