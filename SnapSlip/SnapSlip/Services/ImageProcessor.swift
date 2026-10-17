//
//  ImageProcessor.swift
//  SnapSlip
//
//  Memory-friendly image handling with ImageIO. Camera photos can be 12–48 MP;
//  decoding them at full size just to read text or show a thumbnail wastes
//  hundreds of MB. Downsampling at decode time keeps peak memory low.
//

import Foundation
import ImageIO
import UIKit

struct PreparedReceiptImage: @unchecked Sendable {
    /// Upright image sized for OCR (long edge ≤ 2048 px).
    let ocrImage: CGImage
    /// JPEG stored with the expense (long edge ≤ 1600 px).
    let storedJPEG: Data?
    /// Small JPEG for list rows (long edge ≤ 240 px).
    let thumbnailJPEG: Data?
}

enum ImageProcessor {
    static let ocrMaxPixelSize: CGFloat = 2048
    static let storedMaxPixelSize: CGFloat = 1600
    static let thumbnailMaxPixelSize: CGFloat = 240

    /// Decodes straight to a smaller size and applies EXIF orientation, so the
    /// result is upright (Vision bounding boxes then match what's on screen).
    static func downsample(_ data: Data, maxPixelSize: CGFloat) -> CGImage? {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions) else { return nil }
        let options = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ] as CFDictionary
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options)
    }

    static func jpegData(from image: CGImage, quality: CGFloat = 0.72) -> Data? {
        UIImage(cgImage: image).jpegData(compressionQuality: quality)
    }

    /// Produces everything the scan flow needs from one original file.
    static func prepare(_ data: Data) -> PreparedReceiptImage? {
        guard let ocr = downsample(data, maxPixelSize: ocrMaxPixelSize) else { return nil }
        let stored = downsample(data, maxPixelSize: storedMaxPixelSize).flatMap { jpegData(from: $0) }
        let thumbnail = downsample(data, maxPixelSize: thumbnailMaxPixelSize).flatMap { jpegData(from: $0, quality: 0.6) }
        return PreparedReceiptImage(ocrImage: ocr, storedJPEG: stored, thumbnailJPEG: thumbnail)
    }
}

/// Small in-memory cache so scrolling a long list doesn't re-decode thumbnails.
/// NSCache drops entries automatically under memory pressure.
final class ThumbnailCache: @unchecked Sendable {
    static let shared = ThumbnailCache()
    private let cache = NSCache<NSString, UIImage>()

    private init() {
        cache.countLimit = 300
    }

    func image(for id: UUID, data: Data?) -> UIImage? {
        let key = id.uuidString as NSString
        if let cached = cache.object(forKey: key) { return cached }
        guard let data, let image = UIImage(data: data) else { return nil }
        cache.setObject(image, forKey: key)
        return image
    }

    func removeAll() { cache.removeAllObjects() }
}
