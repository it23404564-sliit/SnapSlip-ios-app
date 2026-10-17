//
//  CSVExporter.swift
//  SnapSlip
//
//  Exports expenses as RFC 4180 CSV. The same file can be imported by the
//  SnapSlip Spatial visionOS companion (Part B).
//

import Foundation
import CoreTransferable
import UniformTypeIdentifiers

struct ExportRow: Sendable, Equatable {
    let date: Date
    let merchant: String
    let category: String
    let amount: Double
    let currency: String
    let note: String
}

enum CSVExporter {
    static let header = "date,merchant,category,amount,currency,note"

    static func csv(for rows: [ExportRow]) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        formatter.timeZone = .current   // the user's calendar day, not GMT
        let body = rows.map { row in
            [formatter.string(from: row.date),
             escape(row.merchant),
             row.category,
             String(format: "%.2f", row.amount),
             row.currency,
             escape(row.note)].joined(separator: ",")
        }
        return ([header] + body).joined(separator: "\n") + "\n"
    }

    /// Quotes a field if it contains a comma, quote or newline; doubles inner quotes.
    static func escape(_ field: String) -> String {
        guard field.contains(where: { $0 == "," || $0 == "\"" || $0.isNewline }) else { return field }
        return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}

extension ExportRow {
    init(_ expense: Expense) {
        self.init(date: expense.date,
                  merchant: expense.merchant,
                  category: expense.categoryRawValue,
                  amount: expense.amount,
                  currency: expense.currencyCode,
                  note: expense.note)
    }
}

/// Lets ShareLink hand the CSV to Files, Mail, AirDrop, etc.
struct ExpenseCSVDocument: Transferable {
    let rows: [ExportRow]

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .commaSeparatedText) { document in
            Data(CSVExporter.csv(for: document.rows).utf8)
        }
        .suggestedFileName("SnapSlip-Expenses.csv")
    }
}
