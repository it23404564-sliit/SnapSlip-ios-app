//
//  AppServices.swift
//  SnapSlip
//
//  A small dependency container. Views read it from the environment and pass the
//  protocol-typed services into view models, which keeps the view models testable
//  with mocks (see ScanViewModelTests).
//

import Foundation
import Observation

@Observable
final class AppServices {
    let textRecognizer: any TextRecognizing
    let categorizer: any ExpenseCategorizing
    let parser: ReceiptParser

    init(textRecognizer: any TextRecognizing,
         categorizer: any ExpenseCategorizing,
         parser: ReceiptParser = ReceiptParser()) {
        self.textRecognizer = textRecognizer
        self.categorizer = categorizer
        self.parser = parser
    }

    /// Production services. The Core ML model is loaded once here and reused.
    static func live() -> AppServices {
        AppServices(textRecognizer: VisionTextRecognizer(),
                    categorizer: ExpenseCategorizer())
    }
}
