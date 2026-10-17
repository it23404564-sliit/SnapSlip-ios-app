//
//  ScanViewModel.swift
//  SnapSlip
//
//  Drives the scan pipeline:
//
//    image → downsample (ImageIO) → OCR (Vision) → parse (ReceiptParser)
//          → categorise (MerchantMemory → Core ML → keywords → embeddings)
//          → editable draft → save (SwiftData)
//
//  Services are injected through protocols so the whole flow can be unit-tested
//  with a fake recogniser (see ScanViewModelTests).
//

import Foundation
import SwiftData
import UIKit
import Observation

@MainActor
@Observable
final class ScanViewModel {
    enum Step: String {
        case preparing = "Optimising image…"
        case reading = "Reading text with Vision…"
        case understanding = "Categorising on device…"
    }

    enum Phase: Equatable {
        case choosingSource
        case processing(Step)
        case review
        case failed(String)
    }

    private(set) var phase: Phase = .choosingSource
    var draft = ExpenseDraft()
    private(set) var previewImage: UIImage?
    private(set) var observations: [RecognizedLine] = []
    private(set) var prediction: CategoryPrediction?
    private(set) var processingDuration: Duration?

    private let recognizer: any TextRecognizing
    private let categorizer: any ExpenseCategorizing
    private let parser: ReceiptParser
    private let clock = ContinuousClock()

    init(recognizer: any TextRecognizing, categorizer: any ExpenseCategorizing, parser: ReceiptParser) {
        self.recognizer = recognizer
        self.categorizer = categorizer
        self.parser = parser
    }

    convenience init(services: AppServices) {
        self.init(recognizer: services.textRecognizer, categorizer: services.categorizer, parser: services.parser)
    }

    /// True when the user has picked a different category than the one suggested.
    var userChangedCategory: Bool {
        guard let prediction else { return false }
        return draft.category != prediction.category
    }

    // MARK: Pipeline

    func process(imageData: Data, currencyCode: String, memory: MerchantMemory?) async {
        phase = .processing(.preparing)
        let start = clock.now

        let prepared = await Task.detached(priority: .userInitiated) {
            ImageProcessor.prepare(imageData)
        }.value

        guard let prepared else {
            phase = .failed(String(localized: "That image couldn't be opened. Please try another photo."))
            return
        }
        previewImage = UIImage(cgImage: prepared.ocrImage)
        await recognize(prepared.ocrImage,
                        storedJPEG: prepared.storedJPEG,
                        thumbnail: prepared.thumbnailJPEG,
                        currencyCode: currencyCode,
                        memory: memory)
        processingDuration = clock.now - start
    }

    func recognize(_ image: CGImage,
                   storedJPEG: Data?,
                   thumbnail: Data?,
                   currencyCode: String,
                   memory: MerchantMemory?) async {
        phase = .processing(.reading)
        do {
            let result = try await recognizer.recognizeText(in: image)
            observations = result.observations

            phase = .processing(.understanding)
            let parsed = parser.parse(lines: result.rows)
            let merchant = parsed.merchant ?? ""

            // Personal corrections win over the generic model.
            let suggestion = memory?.prediction(for: merchant)
                ?? categorizer.categorize(merchant: merchant, text: parsed.rawText)
            prediction = suggestion

            draft = ExpenseDraft(parsed: parsed,
                                 prediction: suggestion,
                                 fallbackCurrency: currencyCode,
                                 imageData: storedJPEG,
                                 thumbnailData: thumbnail)
            phase = .review
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    /// Lets the user skip scanning and type everything in.
    func startManualEntry(currencyCode: String) {
        draft = ExpenseDraft()
        draft.currencyCode = currencyCode
        prediction = nil
        observations = []
        previewImage = nil
        phase = .review
    }

    // MARK: Save

    @discardableResult
    func save(in context: ModelContext, learnFromEdits: Bool) throws -> Expense {
        if userChangedCategory {
            draft.source = .manual
            draft.confidence = 1
            if learnFromEdits {
                MerchantMemory(context: context).remember(draft.category, for: draft.trimmedMerchant)
            }
        }
        return try ExpenseRepository(context: context).add(draft)
    }

    func reset() {
        phase = .choosingSource
        draft = ExpenseDraft()
        previewImage = nil
        observations = []
        prediction = nil
        processingDuration = nil
    }
}
