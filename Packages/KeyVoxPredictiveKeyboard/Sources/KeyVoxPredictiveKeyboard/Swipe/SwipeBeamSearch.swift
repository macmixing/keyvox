import Foundation
// Android's C library supplies the `Float` math functions Foundation brings in elsewhere.
#if canImport(Android)
import Android
#endif

/// Lexicon-constrained CTC beam search over a swipe lexicon's key-path trie, as
/// `Tools/KeyVoxSwipeModel/beam_search.c` runs it.
///
/// Each beam entry is a trie node (a key-path prefix) with the log-probability of every
/// alignment so far that spells exactly that prefix, split by whether the last frame was a blank
/// or the prefix's last key. After each frame the beam keeps the prefixes with the highest
/// pruning score, `log p / max(depth, 1)^gamma + beta * depth`, which keeps short prefixes from
/// crowding out longer ones. After the last frame, every surviving prefix that ends a word is a
/// candidate, with the exact CTC log-probability of its full key path.
enum SwipeBeamSearch {
    /// A trie node that ends at least one form, and the log-probability of its key path.
    struct Ending {
        let node: Int
        let logProbability: Float
    }

    private struct Entry {
        var node: Int32
        var blank: Float
        var key: Float
        var score: Float
    }

    /// - Parameter emissions: Frame-major log-probabilities, `symbols` per frame, the blank first
    ///   and then each key in the lexicon's key order.
    static func endings(
        emissions: [Float],
        symbols: Int,
        lexicon: SwipeLexicon.Tables,
        pruning: SwipeModelSettings.Pruning
    ) -> [Ending] {
        let frames = emissions.count / symbols
        var slot = [Int32](repeating: -1, count: lexicon.nodeCount)
        var current = [Entry(node: 0, blank: 0, key: -.infinity, score: 0)]
        var next: [Entry] = []
        let gamma = Float(pruning.gamma)
        let beta = Float(pruning.beta)
        for frame in 0..<frames {
            let emission = frame * symbols
            next.removeAll(keepingCapacity: true)
            func accumulate(_ node: Int, blank: Float, key: Float) {
                let index = Int(slot[node])
                if index < 0 {
                    slot[node] = Int32(next.count)
                    next.append(Entry(node: Int32(node), blank: blank, key: key, score: 0))
                    return
                }
                next[index].blank = addLog(next[index].blank, blank)
                next[index].key = addLog(next[index].key, key)
            }
            for entry in current {
                let node = Int(entry.node)
                let total = addLog(entry.blank, entry.key)
                let stayKey = node > 0 ? entry.key + emissions[emission + Int(lexicon.nodeKey[node]) + 1] : -.infinity
                accumulate(node, blank: total + emissions[emission], key: stayKey)
                for childIndex in Int(lexicon.childStart[node])..<Int(lexicon.childStart[node + 1]) {
                    let child = Int(lexicon.childNode[childIndex])
                    let key = Int(lexicon.nodeKey[child])
                    let before = node > 0 && Int(lexicon.nodeKey[node]) == key ? entry.blank : total
                    accumulate(child, blank: -.infinity, key: before + emissions[emission + key + 1])
                }
            }
            for index in next.indices {
                let node = Int(next[index].node)
                slot[node] = -1
                let depth = Int(lexicon.nodeDepth[node])
                let length: Float = depth > 1 ? Float(depth) : 1
                next[index].score = addLog(next[index].blank, next[index].key) / pow(length, gamma) + beta * Float(depth)
            }
            if next.count > pruning.beam {
                next.sort { $0.score > $1.score }
                next.removeLast(next.count - pruning.beam)
            }
            swap(&current, &next)
        }
        return current.compactMap { entry in
            let node = Int(entry.node)
            guard lexicon.formStart[node + 1] > lexicon.formStart[node] else { return nil }
            return Ending(node: node, logProbability: addLog(entry.blank, entry.key))
        }
    }

    private static func addLog(_ a: Float, _ b: Float) -> Float {
        if a == -.infinity { return b }
        if b == -.infinity { return a }
        let high = max(a, b)
        return high + log1p(exp(-abs(a - b)))
    }
}
