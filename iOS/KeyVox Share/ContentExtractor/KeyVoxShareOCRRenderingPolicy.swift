import CoreGraphics

enum KeyVoxShareOCRRenderingPolicy {
    static let maximumRecognitionWidth: CGFloat = 2_048
    static let tileHeight: CGFloat = 1_536
    static let tileOverlap: CGFloat = 96

    static func tileRects(for imageSize: CGSize) -> [CGRect] {
        let imageRect = CGRect(origin: .zero, size: imageSize)
        guard imageRect.height > tileHeight else {
            return [imageRect]
        }

        var rects: [CGRect] = []
        let stride = max(tileHeight - tileOverlap, 1)
        var originY: CGFloat = 0

        while originY < imageRect.height {
            let height = min(tileHeight, imageRect.height - originY)
            rects.append(CGRect(x: 0, y: originY, width: imageRect.width, height: height))

            if originY + height >= imageRect.height {
                break
            }

            originY += stride
        }

        return rects
    }
}

struct KeyVoxShareOCRTile {
    let image: CGImage
    let rect: CGRect
}
