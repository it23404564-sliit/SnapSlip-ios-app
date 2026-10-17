//
//  ReceiptParserTests.swift
//  SnapSlipTests
//
//  Unit tests for the receipt text parser (Swift Testing).
//

import Testing
import Foundation
@testable import SnapSlip

@Suite("Receipt parser")
struct ReceiptParserTests {
    /// Fixed "today" so date validation is deterministic.
    let reference = DateComponents(calendar: Calendar(identifier: .gregorian),
                                   timeZone: .current,
                                   year: 2026, month: 10, day: 9).date!
    var parser: ReceiptParser { ReceiptParser(referenceDate: reference) }

    let supermarket = """
    GREEN BASKET SUPERMARKET
    No. 42, Galle Road, Colombo 03
    Tel: 011 234 5678
    Date: 08/10/2026 18:42
    --------------------------------
    Fresh Milk 1L 450.00
    Basmati Rice 5kg 2,350.00
    2 x Bananas 360.00
    Brown Bread 220.00
    Eggs (10) 650.00
    --------------------------------
    Sub Total 4,030.00
    Discount -80.00
    GRAND TOTAL Rs. 3,950.00
    Cash 5,000.00
    Change 1,050.00
    Thank you! Come again
    """

    @Test("Full supermarket receipt")
    func parsesSupermarketReceipt() throws {
        let result = parser.parse(text: supermarket)

        #expect(result.merchant == "Green Basket Supermarket")
        #expect(result.total == 3_950)
        #expect(result.currencyCode == "LKR")
        #expect(result.lineItems.count == 5)
        #expect(result.lineItems.first == ParsedLineItem(name: "Fresh Milk 1L", price: 450, quantity: 1))
        #expect(result.lineItems.contains(ParsedLineItem(name: "Bananas", price: 360, quantity: 2)))
        #expect(result.lineItems.contains(ParsedLineItem(name: "Eggs (10)", price: 650, quantity: 1)))

        let components = Calendar(identifier: .gregorian).dateComponents([.year, .month, .day], from: try #require(result.date))
        #expect(components.year == 2026)
        #expect(components.month == 10)
        #expect(components.day == 8)
    }

    @Test("Grand total beats sub total and cash")
    func prefersGrandTotal() {
        let lines = ["Sub Total 1,000.00", "Total 1,150.00", "Cash 2,000.00", "Change 850.00"]
        #expect(parser.extractTotal(from: lines) == 1_150)
    }

    @Test("Sub total alone is never treated as the total")
    func ignoresSubtotal() {
        let lines = ["Item A 300.00", "Item B 200.00", "Subtotal 500.00", "Amount Due 540.00"]
        #expect(parser.extractTotal(from: lines) == 540)
    }

    @Test("Amount printed on the line after 'TOTAL'")
    func totalOnNextLine() {
        #expect(parser.extractTotal(from: ["TOTAL", "Rs. 2,450.00"]) == 2_450)
    }

    @Test("Falls back to the largest amount, ignoring cash given")
    func fallbackLargestAmount() {
        let lines = ["Kottu 1,200.00", "Juice 350.00", "Cash 5,000.00"]
        #expect(parser.extractTotal(from: lines) == 1_200)
    }

    @Test("Amount extraction handles separators and noise",
          arguments: [
            ("Rs. 1,250.00", [1_250.0]),
            ("Total LKR 12,345.50", [12_345.5]),
            ("450", [450.0]),
            ("Distance 7.4 km 740.00", [7.4, 740.0])
          ])
    func extractsAmounts(line: String, expected: [Double]) {
        #expect(parser.amounts(in: line) == expected)
    }

    @Test("Day-first and named-month dates",
          arguments: [
            ("Date: 08/10/2026", 8, 10),
            ("2026-09-30 14:05", 30, 9),
            ("12-03-26", 12, 3),
            ("Date 5 Sep 2026", 5, 9),
            ("Sept 21, 2026", 21, 9),
            ("21.07.2026", 21, 7)
          ])
    func parsesDates(line: String, day: Int, month: Int) throws {
        let date = try #require(parser.extractDate(from: [line]))
        let parts = Calendar(identifier: .gregorian).dateComponents([.day, .month], from: date)
        #expect(parts.day == day)
        #expect(parts.month == month)
    }

    @Test("Future dates and impossible dates are rejected")
    func rejectsImplausibleDates() {
        #expect(parser.extractDate(from: ["Date: 01/01/2031"]) == nil)
        #expect(parser.extractDate(from: ["Date: 45/13/2026"]) == nil)
    }

    @Test("Merchant skips headers like TAX INVOICE")
    func merchantSkipsHeaders() {
        let lines = ["TAX INVOICE", "*** WELCOME ***", "LOTUS LEAF CAFE", "Restaurant & Bakery"]
        #expect(parser.extractMerchant(from: lines) == "Lotus Leaf Cafe")
    }

    @Test("Mixed-case names are kept as printed")
    func keepsMixedCase() {
        #expect(ReceiptParser.tidyName("Perera & Sons") == "Perera & Sons")
        #expect(ReceiptParser.tidyName("KEELLS   SUPER") == "Keells Super")
    }

    @Test("Line items skip totals, tax and payment lines")
    func lineItemsSkipNonItems() {
        let lines = ["Ground Coffee 900.00", "VAT 18% 162.00", "Service Charge 90.00", "Card 1,152.00"]
        let items = parser.extractLineItems(from: lines)
        #expect(items == [ParsedLineItem(name: "Ground Coffee", price: 900, quantity: 1)])
    }

    @Test("Currency detection", arguments: [
        ("Total Rs. 100.00", "LKR"),
        ("Amount LKR 100.00", "LKR"),
        ("Total $12.00", "USD"),
        ("Total €12.00", "EUR"),
        ("Total 100.00", nil)
    ])
    func detectsCurrency(line: String, expected: String?) {
        #expect(parser.detectCurrency(in: [line]) == expected)
    }

    @Test("Empty input gives an empty result")
    func emptyInput() {
        let result = parser.parse(lines: ["", "   "])
        #expect(result.merchant == nil)
        #expect(result.total == nil)
        #expect(result.lineItems.isEmpty)
        #expect(result.rawText.isEmpty)
    }
}
