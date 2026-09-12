import Foundation
import KeyVoxTextComposition

enum AndroidTextComposition {
    struct Payload: Encodable {
        let text: String
        let deleteFollowingCodePoint: Bool
    }

    static func compose(
        transcript: String,
        precedingText: String?,
        precedingTextIsTruncated: Bool,
        followingText: String?,
        followingTextIsTruncated: Bool
    ) -> Payload {
        // Composition only consumes the prefix of following text. Retaining this
        // signal in the bridge contract prevents a capped read from masquerading
        // as complete editor context if future policies need the document end.
        _ = followingTextIsTruncated
        let cleanedText = transcript.replacingOccurrences(
            of: #"[\r\n]+$"#,
            with: "",
            options: .regularExpression
        )
        guard cleanedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
            return Payload(text: "", deleteFollowingCodePoint: false)
        }

        let context = precedingText.map {
            TextCompositionContext(
                precedingText: $0,
                isAtDocumentStart: precedingTextIsTruncated ? false : nil
            )
        }
        let result = TextCompositionPolicy.composeForInsertion(
            text: cleanedText,
            precedingContext: context,
            followingText: followingText,
            preserveLeadingCapitalization: AndroidDictionaryCasingStore.shared
                .shouldPreserveLeadingCapitalization(in: cleanedText)
        )
        return Payload(
            text: result.text,
            deleteFollowingCodePoint: result.shouldDeleteFollowingCodePoint
        )
    }
}
