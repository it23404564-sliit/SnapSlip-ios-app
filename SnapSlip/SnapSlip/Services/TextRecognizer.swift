//
//  TextRecognizer.swift
//  SnapSlip
//
//  On-device OCR with the Vision framework (VNRecognizeTextRequest).
//  Runs off the main thread and is measured with OSSignposter so it shows up
//  as an interval in Instruments (Points of Interest).
//

import Foundation
import CoreGraphics
import Vision
import os

/// One piece of text Vision found, with its normalised bounding box
/// (origin bottom-left, 0…1, as Vision reports it).
struct RecognizedLine: Identifiable, Equatable, Sendable {
    var id = UUID()
    let text: String
    let confidence: Float
    let boundingBox: CGRect
}

protocol TextRecognizing: Sendable {
    /// Returns individual text observations (for drawing boxes) and the same text
    /// regrouped into visual rows (for parsing), top to bottom.
    func recognizeText(in image: CGImage) async throws -> TextRecognitionResult
}

struct TextRecognitionResult: Sendable, Equatable {
    var observations: [RecognizedLine]
    var rows: [String]
}

enum TextRecognitionError: LocalizedError {
    case noTextFound

    var errorDescription: String? {
        switch self {
        case .noTextFound:
            String(localized: "No text was found. Try a sharper photo with the whole receipt in view.")
        }
    }
}

struct VisionTextRecognizer: TextRecognizing {
    var languages: [String] = ["en-US"]

    private static let signposter = OSSignposter(subsystem: "lk.sliit.snapslip", category: "OCR")

    func recognizeText(in image: CGImage) async throws -> TextRecognitionResult {
        let languages = languages
        return try await Task.detached(priority: .userInitiated) {
            let state = Self.signposter.beginInterval("RecognizeText")
            defer { Self.signposter.endInterval("RecognizeText", state) }

            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = languages
            request.minimumTextHeight = 0.008

            let handler = VNImageRequestHandler(cgImage: image, orientation: .up, options: [:])
            try handler.perform([request])

            let observations: [RecognizedLine] = (request.results ?? []).compactMap { observation in
                guard let candidate = observation.topCandidates(1).first else { return nil }
                return RecognizedLine(text: candidate.string,
                                      confidence: candidate.confidence,
                                      boundingBox: observation.boundingBox)
            }
            guard !observations.isEmpty else { throw TextRecognitionError.noTextFound }
            return TextRecognitionResult(observations: observations,
                                         rows: RowAssembler.assembleRows(observations))
        }.value
    }
}

/// Vision often returns "Fresh Milk" and "450.00" as two observations even though
/// they sit on the same printed row. This regroups observations into rows by
/// vertical overlap and joins them left-to-right.
enum RowAssembler {
    static func assembleRows(_ observations: [RecognizedLine]) -> [String] {
        let sorted = observations.sorted { $0.boundingBox.midY > $1.boundingBox.midY }
        var rows: [[RecognizedLine]] = []

        for item in sorted {
            if let anchor = rows.last?.first {
                let tolerance = max(anchor.boundingBox.height, item.boundingBox.height) * 0.5
                if abs(anchor.boundingBox.midY - item.boundingBox.midY) <= tolerance {
                    rows[rows.count - 1].append(item)
                    continue
                }
            }
            rows.append([item])
        }

        return rows.map { row in
            row.sorted { $0.boundingBox.minX < $1.boundingBox.minX }
                .map(\.text)
                .joined(separator: " ")
        }
    }
}
