//
//  CategorizerTests.swift
//  SnapSlipTests
//
//  Tests the categoriser's deterministic layers (keyword rules and input
//  normalisation) and the merchant-memory key. The Core ML and embedding layers
//  are disabled here by injecting nil, so results don't depend on the device.
//

import Testing
import Foundation
@testable import SnapSlip

@Suite("Expense categoriser")
struct CategorizerTests {
    let categorizer = ExpenseCategorizer(textClassifier: nil, embedding: nil)

    @Test("Known Sri Lankan merchants map to the right category", arguments: [
        ("Keells Super", ExpenseCategory.groceries),
        ("Cargills Food City", .groceries),
        ("PickMe", .transport),
        ("Ceypetco Fuel Station", .transport),
        ("Dialog Axiata PLC", .utilities),
        ("Osu Sala", .health),
        ("Sarasavi Bookshop", .education),
        ("Scope Cinemas", .entertainment),
        ("Fashion Bug", .shopping),
        ("Perera & Sons", .dining)
    ])
    func knownMerchants(merchant: String, expected: ExpenseCategory) {
        let prediction = categorizer.categorize(merchant: merchant, text: "")
        #expect(prediction.category == expected)
        #expect(prediction.source == .keywords)
        #expect(prediction.confidence > 0.5)
    }

    @Test("Receipt body text is used when the merchant is unknown")
    func usesBodyText() {
        let prediction = categorizer.categorize(merchant: "Sunrise Stores",
                                                text: "Paracetamol 500mg\nPrescription\nPharmacy")
        #expect(prediction.category == .health)
    }

    @Test("Merchant evidence outweighs a stray word in the body")
    func merchantWeightedHigher() {
        let prediction = categorizer.categorize(merchant: "Lotus Leaf Cafe", text: "parking available")
        #expect(prediction.category == .dining)
    }

    @Test("Unknown input falls back to Other with low confidence")
    func unknownFallsBack() {
        let prediction = categorizer.categorize(merchant: "Zxqv Holdings", text: "ref 0042")
        #expect(prediction.category == .other)
        #expect(prediction.confidence < 0.5)
    }

    @Test("Normalisation matches the Create ML training format")
    func normalisation() {
        #expect(ExpenseCategorizer.normalize("LOTUS LEAF CAFÉ — Table #4, 2,838.00") == "lotus leaf cafe table")
        #expect(ExpenseCategorizer.normalize("Perera & Sons") == "perera sons")
    }

    @Test("Without a bundled model the Core ML layer reports unloaded")
    func modelFlag() {
        #expect(categorizer.isCoreMLModelLoaded == false)
    }

    @Test("Merchant memory keys ignore case, accents and branch names")
    func merchantKeys() {
        #expect(MerchantMemory.key(for: "KEELLS - Nugegoda") == "keells nugegoda")
        #expect(MerchantMemory.key(for: "Keells Nugegoda Branch") == "keells nugegoda")
        #expect(MerchantMemory.key(for: "Café Kumbuk") == "cafe kumbuk")
        #expect(MerchantMemory.key(for: "!!") == "")
    }
}
