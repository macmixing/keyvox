import CoreGraphics
import Foundation
import KeyVoxPredictiveKeyboard

/// swipe.futo.org recordings as the harness reads them: each swipe's word, the words before it
/// in its sentence, and its samples on a keyboard sized as it was recorded, with the letter keys
/// of the recording's layout file (`swipe-5/layouts/qwerty.json`).
struct FutoSwipes {
    struct Swipe {
        let word: String
        /// Newest first.
        let previousWords: [String]
        let canvas: CGSize
        /// Times in seconds, locations in canvas points.
        let samples: [SwipeTouchSample]
    }

    private struct Line: Decodable {
        let word: String
        let previous: [String]?
        let w: Double
        let h: Double
        let points: [[Double]]
    }

    private struct LayoutFile: Decodable {
        struct Key: Decodable {
            let letter: String
            let cx: Double
            let cy: Double
            let rx: Double
            let ry: Double
        }

        let keys: [Key]
    }

    let swipes: [Swipe]
    private let keys: [LayoutFile.Key]

    /// - Parameter path: JSON lines of `word`, `previous`, `w`, `h`, and `points` ([t ms, x, y]
    ///   with x and y normalized), or swipe.futo.org's own records, which have `canvas_width`,
    ///   `canvas_height`, and `data`.
    init(path: String, layoutPath: String, limit: Int?) throws {
        let decoder = JSONDecoder()
        keys = try decoder.decode(LayoutFile.self, from: Data(contentsOf: URL(fileURLWithPath: layoutPath))).keys
        guard let text = try? String(contentsOfFile: path, encoding: .utf8) else {
            throw HarnessError.unreadableCorpus(path)
        }
        var swipes: [Swipe] = []
        for line in text.split(separator: "\n") {
            if let limit, swipes.count >= limit { break }
            let data = Data(line.utf8)
            let parsed: Line
            if let line = try? decoder.decode(Line.self, from: data) {
                parsed = line
            } else if let record = try? decoder.decode(FutoRecord.self, from: data), let points = record.data {
                parsed = Line(
                    word: record.word, previous: nil, w: record.canvas_width, h: record.canvas_height,
                    points: points.map { [$0.t, $0.x, $0.y] }
                )
            } else {
                continue
            }
            guard parsed.points.isEmpty == false else { continue }
            swipes.append(Swipe(
                word: parsed.word,
                previousWords: parsed.previous ?? [],
                canvas: CGSize(width: parsed.w, height: parsed.h),
                samples: parsed.points.map {
                    SwipeTouchSample(location: CGPoint(x: $0[1] * parsed.w, y: $0[2] * parsed.h), timestamp: $0[0] / 1000)
                }
            ))
        }
        self.swipes = swipes
    }

    /// The layout's letter keys on a canvas of `size`.
    func keyGeometry(for size: CGSize) -> [PredictionKeyGeometry] {
        keys.compactMap { key in
            guard let letter = key.letter.first else { return nil }
            return PredictionKeyGeometry(
                character: letter,
                frame: CGRect(
                    x: (key.cx - key.rx) * size.width,
                    y: (key.cy - key.ry) * size.height,
                    width: 2 * key.rx * size.width,
                    height: 2 * key.ry * size.height
                )
            )
        }
    }

    private struct FutoRecord: Decodable {
        struct Point: Decodable {
            let t: Double
            let x: Double
            let y: Double
        }

        let word: String
        let canvas_width: Double
        let canvas_height: Double
        let data: [Point]?
    }
}
