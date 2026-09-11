import Foundation
import XCTest
@testable import KeyVoxLinguistics

final class WordNetLexicalDatabaseTests: XCTestCase {
    func testLoadsOnlySingleTokenLexicalMembership() throws {
        let noun = String(UnicodeScalar(0x03B1)!)
        let verb = String(UnicodeScalar(0x03B2)!)
        let adjective = String(UnicodeScalar(0x03B3)!)
        let adverb = String(UnicodeScalar(0x03B4)!)
        let directory = try makeDatabase(
            noun: noun + " 1 0 1 0 0\n" + noun + "_" + verb + " 1 0 1 0 0\n",
            verb: verb + " 1 0 1 0 0\n",
            adjective: adjective + " 1 0 1 0 0\n",
            adverb: adverb + " 1 0 1 0 0\n"
        )
        defer { try? FileManager.default.removeItem(at: directory) }

        let database = try WordNetLexicalDatabase(directory: directory)
        XCTAssertEqual(database.roles(for: noun.uppercased()), [.noun])
        XCTAssertEqual(database.roles(for: verb), [.verb])
        XCTAssertEqual(database.roles(for: adjective), [.adjective])
        XCTAssertEqual(database.roles(for: adverb), [.adverb])
        XCTAssertEqual(database.roles(for: noun + "_" + verb), [])
    }

    func testResolverUsesLexicalEvidenceOnlyForUnknownModelWords() throws {
        let noun = String(UnicodeScalar(0x03B1)!)
        let directory = try makeDatabase(noun: noun + " 1 0 1 0 0\n")
        defer { try? FileManager.default.removeItem(at: directory) }
        let database = try WordNetLexicalDatabase(directory: directory)

        XCTAssertEqual(
            WordNetLexicalRoleResolver.role(
                for: noun,
                predictedTag: "VB",
                at: 0,
                tags: ["VB"],
                allowsLexicalOverride: true,
                database: database
            ),
            .noun
        )
        XCTAssertEqual(
            WordNetLexicalRoleResolver.role(
                for: noun,
                predictedTag: "VB",
                at: 0,
                tags: ["VB"],
                allowsLexicalOverride: false,
                database: database
            ),
            .verb
        )
    }

    func testMissingIndexFailsClosed() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        XCTAssertThrowsError(try WordNetLexicalDatabase(directory: directory))
    }

    private func makeDatabase(
        noun: String = "",
        verb: String = "",
        adjective: String = "",
        adverb: String = ""
    ) throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try noun.write(to: directory.appendingPathComponent("index.noun"), atomically: true, encoding: .utf8)
        try verb.write(to: directory.appendingPathComponent("index.verb"), atomically: true, encoding: .utf8)
        try adjective.write(to: directory.appendingPathComponent("index.adj"), atomically: true, encoding: .utf8)
        try adverb.write(to: directory.appendingPathComponent("index.adv"), atomically: true, encoding: .utf8)
        return directory
    }
}
