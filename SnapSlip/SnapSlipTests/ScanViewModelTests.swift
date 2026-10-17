//
//  ScanViewModelTests.swift
//  SnapSlipTests
//
//  End-to-end tests of the scan pipeline with a fake OCR engine, plus the
//  row-assembly, CSV and image helpers it relies on.
//

import Testing
import Foundation
import SwiftData
import UIKit
@testable import SnapSlip

/// Returns canned rows instead of running Vision.
private struct FakeRecognizer: TextRecognizing {
    var rows: [String]
    var error: Error?

    func recognizeText(in image: CGImage) async throws -> TextRecognitionResult {
        if let error { throw error }
        let observations = rows.enumerated().map { index, text in
            RecognizedLine(text: text, confidence: 0.95,
                           boundingBox: CGRect(x: 0.1, y: 0.9 - Double(index) * 0.05, width: 0.8, height: 0.03))
        }
        return TextRecognitionResult(observations: observations, rows: rows)
    }
}

@MainActor
@Suite("Scan pipeline", .serialized)
struct ScanViewModelTests {
    let container: ModelContainer
    let context: ModelContext

    init() throws {
        container = try PersistenceController.makeContainer(inMemory: true)
        context = container.mainContext
    }

    private func makeViewModel(rows: [String], error: Error? = nil) -> ScanViewModel {
        ScanViewModel(recognizer: FakeRecognizer(rows: rows, error: error),
                      categorizer: ExpenseCategorizer(textClassifier: nil, embedding: nil),
                      parser: ReceiptParser())
    }

    private var tinyImage: CGImage {
        UIGraphicsImageRenderer(size: CGSize(width: 4, height: 4)).image { ctx in
            UIColor.white.setFill(); ctx.fill(CGRect(x: 0, y: 0, width: 4, height: 4))
        }.cgImage!
    }

    @Test("A recognised receipt becomes a filled-in draft")
    func producesDraft() async {
        let viewModel = makeViewModel(rows: ["KEELLS SUPER", "Fresh Milk 450.00", "TOTAL Rs. 450.00"])
        await viewModel.recognize(tinyImage, storedJPEG: nil, thumbnail: nil, currencyCode: "LKR", memory: nil)

        #expect(viewModel.phase == .review)
        #expect(viewModel.draft.merchant == "Keells Super")
        #expect(viewModel.draft.amount == 450)
        #expect(viewModel.draft.category == .groceries)
        #expect(viewModel.draft.isScanned)
        #expect(viewModel.draft.isValid)
        #expect(viewModel.observations.count == 3)
    }

    @Test("OCR errors move the flow to the failed state")
    func handlesErrors() async {
        let viewModel = makeViewModel(rows: [], error: TextRecognitionError.noTextFound)
        await viewModel.recognize(tinyImage, storedJPEG: nil, thumbnail: nil, currencyCode: "LKR", memory: nil)
        if case .failed = viewModel.phase {} else {
            Issue.record("Expected failed phase, got \(viewModel.phase)")
        }
    }

    @Test("A learned merchant rule beats the generic categoriser")
    func personalRuleWins() async {
        let memory = MerchantMemory(context: context)
        memory.remember(.entertainment, for: "Keells Super")
        let viewModel = makeViewModel(rows: ["KEELLS SUPER", "TOTAL 1,000.00"])
        await viewModel.recognize(tinyImage, storedJPEG: nil, thumbnail: nil, currencyCode: "LKR", memory: memory)

        #expect(viewModel.draft.category == .entertainment)
        #expect(viewModel.prediction?.source == .personal)
    }

    @Test("Correcting the category on save teaches merchant memory")
    func savingCorrectionLearns() async throws {
        let viewModel = makeViewModel(rows: ["KEELLS SUPER", "TOTAL 1,000.00"])
        await viewModel.recognize(tinyImage, storedJPEG: nil, thumbnail: nil, currencyCode: "LKR", memory: nil)
        viewModel.draft.category = .health
        #expect(viewModel.userChangedCategory)

        let expense = try viewModel.save(in: context, learnFromEdits: true)
        #expect(expense.categorySource == .manual)
        #expect(MerchantMemory(context: context).prediction(for: "Keells Super")?.category == .health)
    }

    @Test("Manual entry skips straight to review with an empty draft")
    func manualEntry() {
        let viewModel = makeViewModel(rows: [])
        viewModel.startManualEntry(currencyCode: "USD")
        #expect(viewModel.phase == .review)
        #expect(viewModel.draft.currencyCode == "USD")
        #expect(viewModel.draft.isValid == false)
    }

    @Test("The rendered sample receipt goes through the image pipeline")
    func sampleReceiptPreparation() throws {
        let data = try #require(SampleReceipt.supermarket.renderJPEG())
        let prepared = try #require(ImageProcessor.prepare(data))
        #expect(max(prepared.ocrImage.width, prepared.ocrImage.height) <= Int(ImageProcessor.ocrMaxPixelSize))
        let thumbnail = try #require(prepared.thumbnailJPEG.flatMap(UIImage.init(data:)))
        #expect(max(thumbnail.size.width, thumbnail.size.height) <= ImageProcessor.thumbnailMaxPixelSize)
    }
}

@Suite("Helpers")
struct HelperTests {
    @Test("Observations on the same printed row are merged left to right")
    func rowAssembly() {
        let lines = [
            RecognizedLine(text: "450.00", confidence: 1, boundingBox: CGRect(x: 0.7, y: 0.80, width: 0.2, height: 0.04)),
            RecognizedLine(text: "Fresh Milk", confidence: 1, boundingBox: CGRect(x: 0.1, y: 0.81, width: 0.3, height: 0.04)),
            RecognizedLine(text: "KEELLS", confidence: 1, boundingBox: CGRect(x: 0.3, y: 0.92, width: 0.4, height: 0.05))
        ]
        #expect(RowAssembler.assembleRows(lines) == ["KEELLS", "Fresh Milk 450.00"])
    }

    @Test("Vision boxes convert to a top-left origin")
    func boxConversion() {
        // Binary-exact fractions keep the comparison free of floating-point noise.
        let rect = RecognizedTextOverlay.convert(CGRect(x: 0.25, y: 0.5, width: 0.5, height: 0.25),
                                                 to: CGSize(width: 200, height: 100))
        #expect(rect == CGRect(x: 50, y: 25, width: 100, height: 25))
    }

    @Test("CSV export escapes commas and quotes")
    func csvEscaping() {
        // Noon UTC on 2 Jan 1970 is still 2 Jan in every time zone from UTC−11 to UTC+11.
        let row = ExportRow(date: Date(timeIntervalSince1970: 86_400 + 43_200), merchant: "Perera, \"Sons\"",
                            category: "dining", amount: 1250, currency: "LKR", note: "")
        let csv = CSVExporter.csv(for: [row])
        let lines = csv.split(separator: "\n")
        #expect(lines.first == Substring(CSVExporter.header))
        #expect(lines.last == "1970-01-02,\"Perera, \"\"Sons\"\"\",dining,1250.00,LKR,")
    }
}
