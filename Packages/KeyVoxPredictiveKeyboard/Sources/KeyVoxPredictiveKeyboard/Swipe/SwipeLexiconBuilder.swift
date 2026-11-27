import Foundation

/// Builds a swipe lexicon file (`SwipeLexiconFormat`) from a typing language's dictionary
/// words, for the swipe model whose `settings` it is built for.
///
/// Every word that may be offered and spells a form the model's keys can swipe is kept.
/// Spellings that share a form, such as case, accent, or apostrophe variants, are one form
/// whose frequency is its likeliest spelling's; its spellings are kept likeliest first, in
/// dictionary order between equals.
public enum SwipeLexiconBuilder {
    public struct Word: Sendable, Equatable {
        public let spelling: String
        /// The dictionary probability, 0 to 255 and already log-scaled.
        public let probability: Int
        /// False for entries marked as not a word or as blocked.
        public let isOfferable: Bool

        public init(spelling: String, probability: Int, isOfferable: Bool) {
            self.spelling = spelling
            self.probability = probability
            self.isOfferable = isOfferable
        }
    }

    private struct Spelling {
        let text: String
        let probability: Int
        let order: Int
    }

    public static func fileData(words: [Word], settings: SwipeModelSettings) throws -> Data {
        let keyIndex = settings.keyIndex
        var spellingsByForm: [String: [Spelling]] = [:]
        for (order, word) in words.enumerated() where word.isOfferable {
            let form = SwipeLetterForm.form(of: word.spelling)
            guard form.isEmpty == false else { continue }
            spellingsByForm[form, default: []].append(
                Spelling(text: word.spelling, probability: word.probability, order: order)
            )
        }
        var typeable: [(form: String, path: [Int])] = []
        for form in spellingsByForm.keys {
            guard let path = SwipeLetterForm.keyPath(
                of: form,
                keyIndex: keyIndex,
                keepsDoubleLetters: settings.keepsDoubleLetters
            ), path.isEmpty == false else { continue }
            typeable.append((form, path))
        }
        typeable.sort { $0.form.unicodeScalars.lexicographicallyPrecedes($1.form.unicodeScalars) }

        var children: [[Int: Int]] = [[:]]
        var nodeKey: [UInt8] = [SwipeLexiconFormat.rootKey]
        var nodeDepth: [UInt8] = [0]
        var formsAtNode: [[Int]] = [[]]
        for (number, entry) in typeable.enumerated() {
            guard entry.path.count <= Int(UInt8.max) else {
                throw PredictiveKeyboardError.invalidSwipeModel(SwipeLexiconFormat.fileName)
            }
            var node = 0
            for key in entry.path {
                if let child = children[node][key] {
                    node = child
                    continue
                }
                let child = children.count
                children[node][key] = child
                children.append([:])
                nodeKey.append(UInt8(key))
                nodeDepth.append(nodeDepth[node] + 1)
                formsAtNode.append([])
                node = child
            }
            formsAtNode[node].append(number)
        }

        var childStart: [UInt32] = [0]
        var childNode: [UInt32] = []
        var formStart: [UInt32] = [0]
        var formFrequency: [UInt8] = []
        var formPathLength: [UInt8] = []
        var formSpellingStart: [UInt32] = [0]
        var spellingFrequency: [UInt8] = []
        var spellingOffset: [UInt32] = [0]
        var spellingBytes: [UInt8] = []
        for node in children.indices {
            childNode.append(contentsOf: children[node].keys.sorted().map { UInt32(children[node][$0]!) })
            childStart.append(UInt32(childNode.count))
            for number in formsAtNode[node] {
                let entry = typeable[number]
                let spellings = spellingsByForm[entry.form]!.sorted {
                    $0.probability != $1.probability ? $0.probability > $1.probability : $0.order < $1.order
                }
                formFrequency.append(UInt8(clamping: spellings[0].probability))
                formPathLength.append(UInt8(entry.path.count))
                for spelling in spellings {
                    spellingFrequency.append(UInt8(clamping: spelling.probability))
                    spellingBytes.append(contentsOf: spelling.text.utf8)
                    spellingOffset.append(UInt32(spellingBytes.count))
                }
                formSpellingStart.append(UInt32(spellingFrequency.count))
            }
            formStart.append(UInt32(formFrequency.count))
        }

        var data = Data(SwipeLexiconFormat.magic)
        let letters = Array(settings.letters.utf8)
        append(SwipeLexiconFormat.version, to: &data)
        append(UInt32(letters.count), to: &data)
        data.append(contentsOf: letters)
        data.append(contentsOf: [UInt8](repeating: 0, count: (4 - letters.count % 4) % 4))
        for count in [
            settings.keepsDoubleLetters ? 1 : 0,
            children.count,
            formFrequency.count,
            spellingFrequency.count,
            spellingBytes.count,
        ] {
            append(UInt32(count), to: &data)
        }
        for table in [childStart, childNode, formStart, formSpellingStart, spellingOffset] {
            table.forEach { append($0, to: &data) }
        }
        for table in [nodeKey, nodeDepth, formFrequency, formPathLength, spellingFrequency, spellingBytes] {
            data.append(contentsOf: table)
        }
        return data
    }

    private static func append(_ value: UInt32, to data: inout Data) {
        withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) }
    }
}
