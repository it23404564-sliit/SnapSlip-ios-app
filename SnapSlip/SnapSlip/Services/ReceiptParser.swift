//
//  ReceiptParser.swift
//  SnapSlip
//
//  Turns the raw lines that Vision reads from a receipt into structured data:
//  merchant, total, date, currency and line items. It is pure Foundation code
//  (no Vision, no UI) so it is fully covered by unit tests.
//
//  Sri Lankan receipts use day-first dates (dd/MM/yyyy), "Rs." / "LKR" and
//  thousands separators (1,250.00); those conventions are the defaults here.
//

import Foundation

struct ParsedLineItem: Equatable, Sendable {
    var name: String
    var price: Double
    var quantity: Int
}

struct ParsedReceipt: Equatable, Sendable {
    var merchant: String?
    var total: Double?
    var date: Date?
    var currencyCode: String?
    var lineItems: [ParsedLineItem]
    var rawText: String
}

struct ReceiptParser: Sendable {
    /// Dates after this (plus one day) are rejected as OCR noise. Injected for tests.
    var referenceDate: Date?
    var calendar = Calendar(identifier: .gregorian)

    init(referenceDate: Date? = nil) {
        self.referenceDate = referenceDate
    }

    func parse(text: String) -> ParsedReceipt {
        parse(lines: text.components(separatedBy: .newlines))
    }

    func parse(lines rawLines: [String]) -> ParsedReceipt {
        let lines = rawLines
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return ParsedReceipt(merchant: extractMerchant(from: lines),
                             total: extractTotal(from: lines),
                             date: extractDate(from: lines),
                             currencyCode: detectCurrency(in: lines),
                             lineItems: extractLineItems(from: lines),
                             rawText: lines.joined(separator: "\n"))
    }

    // MARK: - Amounts

    /// Matches 1,250.00 · 1250.00 · 450 — but not digits glued to other digits.
    private static let amountRegex = try! NSRegularExpression(
        pattern: #"(?<![\d.,])(\d{1,3}(?:,\d{3})+(?:\.\d{1,2})?|\d+(?:\.\d{1,2})?)(?![\d,]|\.\d)"#
    )

    /// Same, but a decimal part is required (used for line-item prices).
    private static let priceAtEndRegex = try! NSRegularExpression(
        pattern: #"^(.+?)[\s:]+(?:rs\.?|lkr)?\s*(-?\d{1,3}(?:,\d{3})*\.\d{2}|-?\d+\.\d{2})$"#,
        options: [.caseInsensitive]
    )

    func amounts(in line: String) -> [Double] {
        let range = NSRange(line.startIndex..., in: line)
        return Self.amountRegex.matches(in: line, range: range).compactMap { match in
            guard let r = Range(match.range(at: 1), in: line) else { return nil }
            return Double(line[r].replacingOccurrences(of: ",", with: ""))
        }
    }

    // MARK: - Total

    /// Ordered by how strongly each phrase signals the final amount paid.
    private static let totalKeywords = [
        "grand total", "net total", "total due", "amount due", "balance due",
        "total amount", "amount payable", "net amount", "total payable", "to pay", "total"
    ]
    private static let notTotalKeywords = [
        "subtotal", "sub total", "sub-total", "total items", "total item", "total qty",
        "total quantity", "total savings", "total discount", "you saved", "no of items"
    ]
    private static let notAmountLineKeywords = [
        "cash", "change", "tendered", "tel", "phone", "fax", "invoice no", "bill no",
        "receipt no", "card no", "vat reg", "reg no", "points"
    ]

    func extractTotal(from lines: [String]) -> Double? {
        let lowered = lines.map { $0.lowercased() }

        for keyword in Self.totalKeywords {
            for (index, line) in lowered.enumerated() where line.contains(keyword) {
                if Self.notTotalKeywords.contains(where: line.contains) { continue }
                if let value = amounts(in: lines[index]).last, value > 0 { return value }
                // Some receipts print the amount on the next line.
                if index + 1 < lines.count, let value = amounts(in: lines[index + 1]).first, value > 0 {
                    return value
                }
            }
        }

        // Fallback: the largest decimal amount that isn't cash given or change.
        let candidates = lines.enumerated()
            .filter { index, _ in !Self.notAmountLineKeywords.contains(where: lowered[index].contains) }
            .filter { _, line in line.contains(".") }
            .flatMap { _, line in amounts(in: line) }
        return candidates.max()
    }

    // MARK: - Merchant

    private static let notMerchantKeywords = [
        "receipt", "tax invoice", "invoice", "welcome", "thank", "cash bill", "tel", "phone",
        "vat", "date", "www", "http", "@", "reg no", "cashier", "order", "table", "branch:"
    ]

    func extractMerchant(from lines: [String]) -> String? {
        for line in lines.prefix(5) {
            let lower = line.lowercased()
            let letters = line.filter(\.isLetter).count
            guard letters >= 3, Double(letters) / Double(line.count) >= 0.5 else { continue }
            guard !Self.notMerchantKeywords.contains(where: lower.contains) else { continue }
            return Self.tidyName(line)
        }
        return nil
    }

    /// "GREEN BASKET SUPERMARKET" → "Green Basket Supermarket"; mixed case is kept.
    static func tidyName(_ text: String) -> String {
        let collapsed = text
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        let letters = collapsed.filter(\.isLetter)
        let isShouting = !letters.isEmpty && letters == letters.uppercased()
        return isShouting ? collapsed.capitalized : collapsed
    }

    // MARK: - Date

    private static let numericDateRegex = try! NSRegularExpression(
        pattern: #"\b(\d{4}[-/.]\d{1,2}[-/.]\d{1,2}|\d{1,2}[-/.]\d{1,2}[-/.]\d{2,4})\b"#
    )
    private static let namedMonthRegex = try! NSRegularExpression(
        pattern: #"\b(\d{1,2}[\s-]*(?:jan|feb|mar|apr|may|jun|jul|aug|sep|sept|oct|nov|dec)[a-z]*\.?[\s,-]*\d{2,4}|(?:jan|feb|mar|apr|may|jun|jul|aug|sep|sept|oct|nov|dec)[a-z]*\.?\s+\d{1,2},?\s+\d{4})\b"#,
        options: [.caseInsensitive]
    )

    private static let numericFormats = ["yyyy/M/d", "d/M/yyyy", "d/M/yy"]
    private static let namedFormats = ["d MMM yyyy", "d MMMM yyyy", "d MMM yy", "MMM d yyyy", "MMMM d yyyy"]

    func extractDate(from lines: [String]) -> Date? {
        for line in lines {
            let range = NSRange(line.startIndex..., in: line)

            if let match = Self.numericDateRegex.firstMatch(in: line, range: range),
               let r = Range(match.range(at: 1), in: line) {
                let normalised = line[r]
                    .replacingOccurrences(of: "-", with: "/")
                    .replacingOccurrences(of: ".", with: "/")
                if let date = parseDate(normalised, formats: Self.numericFormats) { return date }
            }

            if let match = Self.namedMonthRegex.firstMatch(in: line, range: range),
               let r = Range(match.range(at: 1), in: line) {
                let normalised = String(line[r])
                    .lowercased()
                    .replacingOccurrences(of: "sept", with: "sep")
                    .replacingOccurrences(of: ",", with: " ")
                    .replacingOccurrences(of: ".", with: " ")
                    .replacingOccurrences(of: "-", with: " ")
                    .replacingOccurrences(of: #"(\d)([a-z])"#, with: "$1 $2", options: .regularExpression)
                    .replacingOccurrences(of: #"([a-z])(\d)"#, with: "$1 $2", options: .regularExpression)
                    .components(separatedBy: .whitespaces)
                    .filter { !$0.isEmpty }
                    .joined(separator: " ")
                    .capitalized
                if let date = parseDate(normalised, formats: Self.namedFormats) { return date }
            }
        }
        return nil
    }

    private func parseDate(_ text: String, formats: [String]) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.isLenient = false

        let now = referenceDate ?? Date()
        let latest = now.addingTimeInterval(86_400)
        let earliest = calendar.date(from: DateComponents(year: 2000, month: 1, day: 1)) ?? .distantPast

        for format in formats {
            formatter.dateFormat = format
            if let date = formatter.date(from: text), date >= earliest, date <= latest {
                return date
            }
        }
        return nil
    }

    // MARK: - Line items

    private static let notItemKeywords = [
        "total", "subtotal", "tax", "vat", "cash", "change", "balance", "discount", "card",
        "visa", "master", "amex", "amount", "tendered", "paid", "due", "round", "service charge",
        "sscl", "items", "qty", "savings", "points", "tel", "date", "time"
    ]
    /// Whole-word match, so "Ground Coffee" isn't skipped because it contains "round".
    private static let notItemRegex = try! NSRegularExpression(
        pattern: "\\b(" + notItemKeywords.joined(separator: "|") + ")\\b",
        options: [.caseInsensitive]
    )
    private static let quantityRegex = try! NSRegularExpression(
        pattern: #"(?:^|\s)(\d{1,3})\s*[xX*@]\s*(?:\d+(?:\.\d{1,2})?)?"#
    )
    private static let itemCodeRegex = try! NSRegularExpression(pattern: #"^\d{4,}\s+"#)

    func extractLineItems(from lines: [String]) -> [ParsedLineItem] {
        var items: [ParsedLineItem] = []
        for line in lines {
            let range = NSRange(line.startIndex..., in: line)
            if Self.notItemRegex.firstMatch(in: line, range: range) != nil { continue }

            guard let match = Self.priceAtEndRegex.firstMatch(in: line, range: range),
                  let nameRange = Range(match.range(at: 1), in: line),
                  let priceRange = Range(match.range(at: 2), in: line),
                  let price = Double(line[priceRange].replacingOccurrences(of: ",", with: "")),
                  price > 0 else { continue }

            var name = String(line[nameRange])
            var quantity = 1

            let nameNSRange = NSRange(name.startIndex..., in: name)
            if let qMatch = Self.quantityRegex.firstMatch(in: name, range: nameNSRange),
               let qRange = Range(qMatch.range(at: 1), in: name),
               let whole = Range(qMatch.range, in: name) {
                quantity = Int(name[qRange]) ?? 1
                name.removeSubrange(whole)
            }
            name = Self.itemCodeRegex.stringByReplacingMatches(
                in: name, range: NSRange(name.startIndex..., in: name), withTemplate: "")
            name = name.trimmingCharacters(in: CharacterSet(charactersIn: " \t-:.*#"))

            guard name.filter(\.isLetter).count >= 2 else { continue }
            items.append(ParsedLineItem(name: Self.tidyName(name), price: price, quantity: max(1, quantity)))
        }
        return items
    }

    // MARK: - Currency

    func detectCurrency(in lines: [String]) -> String? {
        let text = lines.joined(separator: " ").lowercased()
        if text.contains("lkr") || text.range(of: #"\brs\.?\s*\d"#, options: .regularExpression) != nil
            || text.range(of: #"\brs\.?\b"#, options: .regularExpression) != nil { return "LKR" }
        if text.contains("₹") || text.contains("inr") { return "INR" }
        if text.contains("€") || text.contains("eur") { return "EUR" }
        if text.contains("£") || text.contains("gbp") { return "GBP" }
        if text.contains("aud") || text.contains("a$") { return "AUD" }
        if text.contains("$") || text.contains("usd") { return "USD" }
        return nil
    }
}
