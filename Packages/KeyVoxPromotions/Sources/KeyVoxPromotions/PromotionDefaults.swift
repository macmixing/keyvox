import Foundation

public enum PromotionDefaults {
    public static let manifestURL = URL(
        string: "https://raw.githubusercontent.com/macmixing/keyvox/main/Packages/KeyVoxPromotions/Sources/KeyVoxPromotions/Resources/campaigns.json"
    )!
    public static let productionStateNamespace = "KeyVoxPromotions.Production"
    public static let previewStateNamespace = "KeyVoxPromotions.Preview"
}
