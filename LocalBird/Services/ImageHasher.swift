import AppKit
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

struct ImageHasher: Sendable {
    let duplicateThreshold: Int

    init(duplicateThreshold: Int = 5) {
        self.duplicateThreshold = duplicateThreshold
    }

    func averageHash(for image: CGImage) -> String {
        let width = 8
        let height = 8
        var pixels = [UInt8](repeating: 0, count: width * height)
        let colorSpace = CGColorSpaceCreateDeviceGray()
        let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        )
        context?.interpolationQuality = .low
        context?.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        let average = pixels.map(Int.init).reduce(0, +) / pixels.count
        var value: UInt64 = 0
        for pixel in pixels {
            value <<= 1
            if Int(pixel) >= average {
                value |= 1
            }
        }
        return String(format: "%016llx", value)
    }

    func isDuplicate(_ lhs: String?, _ rhs: String?) -> Bool {
        guard let lhs, let rhs else { return false }
        return hammingDistance(lhs, rhs) <= duplicateThreshold
    }

    func hammingDistance(_ lhs: String, _ rhs: String) -> Int {
        guard let left = UInt64(lhs, radix: 16), let right = UInt64(rhs, radix: 16) else {
            return Int.max
        }
        return (left ^ right).nonzeroBitCount
    }
}

extension CGImage {
    func pngData() -> Data? {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil) else {
            return nil
        }
        CGImageDestinationAddImage(destination, self, nil)
        guard CGImageDestinationFinalize(destination) else {
            return nil
        }
        return data as Data
    }
}
