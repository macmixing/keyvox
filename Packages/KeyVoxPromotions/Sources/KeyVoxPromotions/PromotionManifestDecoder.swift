import Foundation

public enum PromotionManifestError: Error, Equatable {
    case unsupportedSchemaVersion(Int)
    case emptyCampaignID
    case duplicateCampaignID(String)
    case missingTarget(String)
    case invalidMinimumAppVersion(String)
    case invalidIcon(String)
    case invalidCopy(String)
    case incompleteAction(String)
    case invalidURL(String)
    case invalidDateRange(String)
    case invalidRotationInterval
}

public enum PromotionManifestDecoder {
    public static func decode(_ data: Data) throws -> PromotionManifest {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let manifest = try decoder.decode(PromotionManifest.self, from: data)
        try validate(manifest)
        return manifest
    }

    public static func validate(_ manifest: PromotionManifest) throws {
        guard manifest.schemaVersion == PromotionManifest.supportedSchemaVersion else {
            throw PromotionManifestError.unsupportedSchemaVersion(manifest.schemaVersion)
        }

        if manifest.selection.mode == .rotating {
            guard let interval = manifest.selection.interval, interval > 0 else {
                throw PromotionManifestError.invalidRotationInterval
            }
        }

        var campaignIDs = Set<String>()
        for campaign in manifest.campaigns {
            let id = campaign.id.trimmingCharacters(in: .whitespacesAndNewlines)
            guard id.isEmpty == false else {
                throw PromotionManifestError.emptyCampaignID
            }
            guard campaignIDs.insert(id).inserted else {
                throw PromotionManifestError.duplicateCampaignID(id)
            }
            guard campaign.targets.isEmpty == false else {
                throw PromotionManifestError.missingTarget(id)
            }
            for target in campaign.targets {
                if let minimumAppVersion = target.minimumAppVersion,
                   PromotionVersion(minimumAppVersion) == nil {
                    throw PromotionManifestError.invalidMinimumAppVersion(id)
                }
            }

            switch campaign.icon.kind {
            case .systemImage, .asset:
                guard campaign.icon.name?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
                    throw PromotionManifestError.invalidIcon(id)
                }
            case .appBundleIcon:
                guard campaign.icon.name == nil else {
                    throw PromotionManifestError.invalidIcon(id)
                }
            }

            guard campaign.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false,
                  campaign.message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
                throw PromotionManifestError.invalidCopy(id)
            }
            guard (campaign.buttonTitle == nil) == (campaign.action == nil) else {
                throw PromotionManifestError.incompleteAction(id)
            }
            if let buttonTitle = campaign.buttonTitle,
               buttonTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                throw PromotionManifestError.invalidCopy(id)
            }
            if let action = campaign.action {
                try validateHTTPSURL(action.url, campaignID: id)
            }
            if let sharing = campaign.sharing {
                try validateHTTPSURL(sharing.url, campaignID: id)
            }
            if let startsAt = campaign.startsAt, let endsAt = campaign.endsAt, startsAt >= endsAt {
                throw PromotionManifestError.invalidDateRange(id)
            }
        }
    }

    private static func validateHTTPSURL(_ url: URL, campaignID: String) throws {
        guard url.scheme?.lowercased() == "https", url.host?.isEmpty == false else {
            throw PromotionManifestError.invalidURL(campaignID)
        }
    }
}
