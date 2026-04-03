import Foundation

enum SentencePieceModelParser {
    struct Piece: Sendable {
        let token: String
        let score: Float
    }

    enum ParserError: Error {
        case invalidData
        case truncatedData
        case invalidUTF8
    }

    static func parse(_ data: Data) throws -> [Piece] {
        var cursor = 0
        let bytes = Array(data)
        var pieces: [Piece] = []

        while cursor < bytes.count {
            let tag = try readVarint(from: bytes, cursor: &cursor)
            let fieldNumber = Int(tag >> 3)
            let wireType = Int(tag & 0x07)

            switch wireType {
            case 0:
                _ = try readVarint(from: bytes, cursor: &cursor)
            case 1:
                cursor += 8
                guard cursor <= bytes.count else { throw ParserError.truncatedData }
            case 2:
                let length = Int(try readVarint(from: bytes, cursor: &cursor))
                let end = cursor + length
                guard end <= bytes.count else { throw ParserError.truncatedData }
                if fieldNumber == 1 {
                    pieces.append(try parsePiece(bytes, start: cursor, end: end))
                }
                cursor = end
            case 5:
                cursor += 4
                guard cursor <= bytes.count else { throw ParserError.truncatedData }
            default:
                throw ParserError.invalidData
            }
        }

        return pieces
    }

    private static func parsePiece(_ bytes: [UInt8], start: Int, end: Int) throws -> Piece {
        var cursor = start
        var token = ""
        var score: Float = 0

        while cursor < end {
            let tag = try readVarint(from: bytes, cursor: &cursor)
            let fieldNumber = Int(tag >> 3)
            let wireType = Int(tag & 0x07)

            switch wireType {
            case 0:
                _ = try readVarint(from: bytes, cursor: &cursor)
            case 1:
                cursor += 8
                guard cursor <= end else { throw ParserError.truncatedData }
            case 2:
                let length = Int(try readVarint(from: bytes, cursor: &cursor))
                let fieldEnd = cursor + length
                guard fieldEnd <= end else { throw ParserError.truncatedData }
                if fieldNumber == 1 {
                    guard let value = String(bytes: bytes[cursor..<fieldEnd], encoding: .utf8) else {
                        throw ParserError.invalidUTF8
                    }
                    token = value
                }
                cursor = fieldEnd
            case 5:
                guard cursor + 4 <= end else { throw ParserError.truncatedData }
                if fieldNumber == 2 {
                    score = readFloat32(bytes, offset: cursor)
                }
                cursor += 4
            default:
                throw ParserError.invalidData
            }
        }

        return Piece(token: token, score: score)
    }

    private static func readVarint(from bytes: [UInt8], cursor: inout Int) throws -> UInt64 {
        var shift: UInt64 = 0
        var value: UInt64 = 0

        while cursor < bytes.count {
            let byte = bytes[cursor]
            cursor += 1
            value |= UInt64(byte & 0x7F) << shift
            if byte & 0x80 == 0 {
                return value
            }
            shift += 7
            if shift >= 64 {
                throw ParserError.invalidData
            }
        }

        throw ParserError.truncatedData
    }

    private static func readFloat32(_ bytes: [UInt8], offset: Int) -> Float {
        var value: Float = 0
        withUnsafeMutableBytes(of: &value) { rawBuffer in
            rawBuffer[0] = bytes[offset]
            rawBuffer[1] = bytes[offset + 1]
            rawBuffer[2] = bytes[offset + 2]
            rawBuffer[3] = bytes[offset + 3]
        }
        return value
    }
}
