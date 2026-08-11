import AppKit
import ImageIO
import Testing
@testable import RightSight

struct ImageConverterTests {
    @MainActor
    @Test func convertsWithoutOverwritingSource() throws {
        let testDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("RightSightImageConverterTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: testDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: testDirectory) }

        let sourceURL = testDirectory.appendingPathComponent("sample.png")
        let bitmap = try #require(NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: 2,
            pixelsHigh: 2,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ))
        bitmap.setColor(NSColor(deviceRed: 0.1, green: 0.4, blue: 0.9, alpha: 1), atX: 0, y: 0)
        let pngData = try #require(bitmap.representation(using: .png, properties: [:]))
        try pngData.write(to: sourceURL)

        let jpegURL = try ImageConverter.convert(sourceURL, to: .jpeg)
        #expect(FileManager.default.fileExists(atPath: sourceURL.path))
        #expect(FileManager.default.fileExists(atPath: jpegURL.path))
        #expect(jpegURL.lastPathComponent == "sample-converted.jpg")

        let secondJPEGURL = try ImageConverter.convert(sourceURL, to: .jpeg)
        #expect(secondJPEGURL.lastPathComponent == "sample-converted-2.jpg")
    }

    @MainActor
    @Test func createsAReadableWebP() throws {
        let testDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("RightSightWebPTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: testDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: testDirectory) }

        let sourceURL = testDirectory.appendingPathComponent("sample.png")
        let bitmap = try #require(NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: 2,
            pixelsHigh: 2,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ))
        bitmap.setColor(NSColor(deviceRed: 0.1, green: 0.8, blue: 0.3, alpha: 1), atX: 0, y: 0)
        let pngData = try #require(bitmap.representation(using: .png, properties: [:]))
        try pngData.write(to: sourceURL)

        let webPURL = try ImageConverter.convert(sourceURL, to: .webP)
        let source = try #require(CGImageSourceCreateWithURL(webPURL as CFURL, nil))
        let typeIdentifier = try #require(CGImageSourceGetType(source) as String?)

        #expect(typeIdentifier == "org.webmproject.webp")
    }
}
