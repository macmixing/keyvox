import Foundation

nonisolated struct AppStoreRelease: Equatable {
    let version: AppVersion
    let storeURL: URL
}

nonisolated struct AppUpdatePolicy: Equatable {
    let minimumSupportedVersion: AppVersion
}

nonisolated enum AppUpdateUrgency: Equatable {
    case optional
    case forced

    init?(rawValue: String) {
        switch rawValue {
        case "optional":
            self = .optional
        case "forced":
            self = .forced
        default:
            return nil
        }
    }

    var rawValue: String {
        switch self {
        case .optional:
            return "optional"
        case .forced:
            return "forced"
        }
    }
}

nonisolated struct AppUpdateDecision: Equatable {
    let release: AppStoreRelease
    let urgency: AppUpdateUrgency
}

nonisolated enum AppUpdatePolicyEvaluator {
    static func decision(
        currentVersion: AppVersion,
        release: AppStoreRelease,
        policy: AppUpdatePolicy?
    ) -> AppUpdateDecision? {
        guard currentVersion < release.version else { return nil }

        if let policy, currentVersion < policy.minimumSupportedVersion {
            return AppUpdateDecision(release: release, urgency: .forced)
        }

        return AppUpdateDecision(release: release, urgency: .optional)
    }
}
