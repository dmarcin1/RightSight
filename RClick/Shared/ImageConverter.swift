import AppKit
import ImageIO
import SDWebImage
import SDWebImageWebPCoder

enum ImageOutputFormat: String, CaseIterable, Identifiable, Sendable {
    case jpeg
    case png
    case webP

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .jpeg: "JPG"
        case .png: "PNG"
        case .webP: "WebP"
        }
    }

    var fileExtension: String {
        switch self {
        case .jpeg: "jpg"
        case .png: "png"
        case .webP: "webp"
        }
    }

    fileprivate var typeIdentifier: CFString? {
        switch self {
        case .jpeg: "public.jpeg" as CFString
        case .png: "public.png" as CFString
        case .webP: nil
        }
    }
}

enum ImageConversionError: LocalizedError {
    case unreadableImage
    case cannotCreateDestination
    case cannotFinalize
    case webPEncodingFailed

    var errorDescription: String? {
        switch self {
        case .unreadableImage:
            AppLocalization.localized("Unable to read image")
        case .cannotCreateDestination:
            AppLocalization.localized("Cannot create destination image")
        case .cannotFinalize:
            AppLocalization.localized("Failed to write image data")
        case .webPEncodingFailed:
            AppLocalization.localized("WebP encoding failed")
        }
    }
}

enum ImageConverter {
    static func canRead(_ sourceURL: URL) -> Bool {
        guard let source = CGImageSourceCreateWithURL(sourceURL as CFURL, nil) else {
            return false
        }
        return CGImageSourceGetCount(source) > 0
    }

    @discardableResult
    static func convert(_ sourceURL: URL, to format: ImageOutputFormat) throws -> URL {
        let destinationURL = uniqueDestinationURL(for: sourceURL, format: format)

        switch format {
        case .jpeg, .png:
            try convertWithImageIO(sourceURL, to: destinationURL, format: format)
        case .webP:
            try convertToWebP(sourceURL, destinationURL: destinationURL)
        }

        return destinationURL
    }

    static func uniqueDestinationURL(for sourceURL: URL, format: ImageOutputFormat) -> URL {
        let directory = sourceURL.deletingLastPathComponent()
        let baseName = sourceURL.deletingPathExtension().lastPathComponent + "-converted"
        var candidate = directory.appendingPathComponent(baseName).appendingPathExtension(format.fileExtension)
        var suffix = 2

        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = directory
                .appendingPathComponent("\(baseName)-\(suffix)")
                .appendingPathExtension(format.fileExtension)
            suffix += 1
        }

        return candidate
    }

    private static func convertWithImageIO(
        _ sourceURL: URL,
        to destinationURL: URL,
        format: ImageOutputFormat
    ) throws {
        guard let source = CGImageSourceCreateWithURL(sourceURL as CFURL, nil),
              CGImageSourceGetCount(source) > 0
        else {
            throw ImageConversionError.unreadableImage
        }

        guard let typeIdentifier = format.typeIdentifier,
              let destination = CGImageDestinationCreateWithURL(
                destinationURL as CFURL,
                typeIdentifier,
                1,
                nil
              )
        else {
            throw ImageConversionError.cannotCreateDestination
        }

        let options: CFDictionary? = format == .jpeg
            ? [kCGImageDestinationLossyCompressionQuality: 0.9] as CFDictionary
            : nil
        CGImageDestinationAddImageFromSource(destination, source, 0, options)

        guard CGImageDestinationFinalize(destination) else {
            throw ImageConversionError.cannotFinalize
        }
    }

    private static func convertToWebP(_ sourceURL: URL, destinationURL: URL) throws {
        guard let image = NSImage(contentsOf: sourceURL) else {
            throw ImageConversionError.unreadableImage
        }

        let options: [SDImageCoderOption: Any] = [.encodeCompressionQuality: 0.9]
        guard let data = SDImageWebPCoder.shared.encodedData(
            with: image,
            format: .webP,
            options: options
        ) else {
            throw ImageConversionError.webPEncodingFailed
        }

        try data.write(to: destinationURL, options: .atomic)
    }
}
