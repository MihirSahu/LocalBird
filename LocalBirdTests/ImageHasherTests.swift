import XCTest

final class ImageHasherTests: XCTestCase {
    func testAverageHashDetectsIdenticalImage() throws {
        let hasher = ImageHasher()
        let image = try testImage(color: .white)
        let hash = hasher.averageHash(for: image)

        XCTAssertTrue(hasher.isDuplicate(hash, hash))
    }

    func testHammingDistanceHandlesInvalidHash() {
        XCTAssertEqual(ImageHasher().hammingDistance("bad", "hash"), Int.max)
    }
}
