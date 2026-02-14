import Foundation

struct UpdateFeedConfig: Equatable {
    let owner: String
    let repo: String
    let allowedHosts: [String]

    var latestReleaseURL: URL {
        URL(string: "https://api.github.com/repos/\(owner)/\(repo)/releases/latest")!
    }

    static let trackedDefault = UpdateFeedConfig(
        owner: "macmixing",
        repo: "keyvox",
        allowedHosts: ["api.github.com", "github.com"]
    )
}

struct UpdateFeedOverride: Codable {
    let owner: String
    let repo: String
}

enum UpdateFeedResolver {
    static func resolve(
        fileManager: FileManager = .default,
        overrideFileURL: URL = defaultOverrideFileURL
    ) -> UpdateFeedConfig {
        guard let override = loadOverride(fileManager: fileManager, overrideFileURL: overrideFileURL) else {
            return .trackedDefault
        }

        return UpdateFeedConfig(
            owner: override.owner,
            repo: override.repo,
            allowedHosts: UpdateFeedConfig.trackedDefault.allowedHosts
        )
    }

    static var defaultOverrideFileURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport
            .appendingPathComponent("KeyVox", isDirectory: true)
            .appendingPathComponent("update-feed.override.json")
    }

    private static func loadOverride(
        fileManager: FileManager,
        overrideFileURL: URL
    ) -> UpdateFeedOverride? {
        let overrideURL = overrideFileURL
        guard fileManager.fileExists(atPath: overrideURL.path) else { return nil }

        do {
            let data = try Data(contentsOf: overrideURL)
            let decoded = try JSONDecoder().decode(UpdateFeedOverride.self, from: data)

            let owner = decoded.owner.trimmingCharacters(in: .whitespacesAndNewlines)
            let repo = decoded.repo.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !owner.isEmpty, !repo.isEmpty else {
                #if DEBUG
                print("[UpdateFeedResolver] Ignoring override with empty owner/repo.")
                #endif
                return nil
            }

            return UpdateFeedOverride(owner: owner, repo: repo)
        } catch {
            #if DEBUG
            print("[UpdateFeedResolver] Failed to load override file: \(error)")
            #endif
            return nil
        }
    }
}
