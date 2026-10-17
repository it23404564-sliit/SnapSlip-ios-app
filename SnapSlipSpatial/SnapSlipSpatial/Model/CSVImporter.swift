//
//  CSVImporter.swift
//  SnapSlip Spatial
//
//  Reads the CSV written by the iOS app's CSVExporter:
//      date,merchant,category,amount,currency,note
//  Handles RFC 4180 quoting ("Perera, ""Sons""").
//

import Foundation

enum CSVImportError: LocalizedError, Equatable {
    case missingHeader
    case noRows

    var errorDescription: String? {
        switch self {
        case .missingHeader: "This doesn't look like a SnapSlip export (the header row is missing)."
        case .noRows: "The file has no expenses in it."
        }
    }
}

enum CSVImporter {
    static func parse(_ text: String) throws -> [SpatialExpense] {
        let rows = splitRows(text).filter { !$0.allSatisfy(\.isEmpty) }
        guard let header = rows.first?.map({ $0.lowercased() }),
              let dateIndex = header.firstIndex(of: "date"),
              let merchantIndex = header.firstIndex(of: "merchant"),
              let categoryIndex = header.firstIndex(of: "category"),
              let amountIndex = header.firstIndex(of: "amount") else {
            throw CSVImportError.missingHeader
        }

        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withFullDate]
        dateFormatter.timeZone = .current

        let expenses: [SpatialExpense] = rows.dropFirst().compactMap { fields in
            guard fields.count > max(dateIndex, merchantIndex, categoryIndex, amountIndex),
                  let date = dateFormatter.date(from: fields[dateIndex]),
                  let amount = Double(fields[amountIndex]) else { return nil }
            let category = SpatialCategory(rawValue: fields[categoryIndex]) ?? .other
            return SpatialExpense(merchant: fields[merchantIndex], amount: amount, date: date, category: category)
        }
        guard !expenses.isEmpty else { throw CSVImportError.noRows }
        return expenses
    }

    /// Splits CSV text into rows of fields, honouring quotes and escaped quotes.
    static func splitRows(_ text: String) -> [[String]] {
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var inQuotes = false
        var iterator = Array(text).makeIterator()
        var pending: Character? = nil

        func nextChar() -> Character? {
            if let p = pending { pending = nil; return p }
            return iterator.next()
        }

        while let char = nextChar() {
            if inQuotes {
                if char == "\"" {
                    if let following = nextChar() {
                        if following == "\"" {
                            field.append("\"")
                        } else {
                            inQuotes = false
                            pending = following
                        }
                    } else {
                        inQuotes = false
                    }
                } else {
                    field.append(char)
                }
            } else {
                switch char {
                case "\"":
                    inQuotes = true
                case ",":
                    row.append(field)
                    field = ""
                case "\n", "\r\n":
                    row.append(field)
                    rows.append(row)
                    row = []
                    field = ""
                case "\r":
                    break
                default:
                    field.append(char)
                }
            }
        }
        if !field.isEmpty || !row.isEmpty {
            row.append(field)
            rows.append(row)
        }
        return rows
    }
}
