//
//  SampleReceiptRenderer.swift
//  SnapSlip
//
//  Draws a realistic-looking receipt image so the full OCR → parse → categorise
//  pipeline can be demonstrated in the Simulator, which has no camera.
//  All shop names are fictional.
//

import UIKit

enum SampleReceipt: CaseIterable, Identifiable {
    case supermarket, cafe, pharmacy, taxi

    var id: Self { self }

    var title: String {
        switch self {
        case .supermarket: "Supermarket"
        case .cafe: "Café"
        case .pharmacy: "Pharmacy"
        case .taxi: "Taxi ride"
        }
    }

    func lines(on date: Date) -> [(left: String, right: String)] {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "dd/MM/yyyy"
        let dateText = formatter.string(from: date)

        switch self {
        case .supermarket:
            return [("GREEN BASKET SUPERMARKET", ""), ("No. 42, Galle Road, Colombo 03", ""),
                    ("Tel: 011 234 5678", ""), ("Date: \(dateText)", "18:42"), ("-", ""),
                    ("Fresh Milk 1L", "450.00"), ("Basmati Rice 5kg", "2,350.00"),
                    ("2 x Bananas", "360.00"), ("Brown Bread", "220.00"), ("Eggs (10)", "650.00"),
                    ("-", ""), ("Sub Total", "4,030.00"), ("Discount", "-80.00"),
                    ("GRAND TOTAL Rs.", "3,950.00"), ("Cash", "5,000.00"), ("Change", "1,050.00"),
                    ("Thank you! Come again", "")]
        case .cafe:
            return [("LOTUS LEAF CAFE", ""), ("Restaurant & Bakery", ""), ("Date: \(dateText)", "Table 4"),
                    ("-", ""), ("Chicken Kottu", "1,450.00"), ("Iced Coffee", "650.00"),
                    ("Watalappan", "480.00"), ("-", ""), ("Sub Total", "2,580.00"),
                    ("Service Charge 10%", "258.00"), ("Total LKR", "2,838.00"), ("Card", "2,838.00"),
                    ("Thank you for dining with us", "")]
        case .pharmacy:
            return [("WELLNESS PHARMACY", ""), ("Kandy Road, Kiribathgoda", ""), ("Date: \(dateText)", ""),
                    ("-", ""), ("Paracetamol 500mg", "120.00"), ("Vitamin C 1000mg", "1,250.00"),
                    ("Hand Sanitiser", "540.00"), ("-", ""), ("Net Total Rs.", "1,910.00"),
                    ("Get well soon", "")]
        case .taxi:
            return [("CITYRIDE TAXI", ""), ("Trip receipt", ""), ("Date: \(dateText)", "08:15"),
                    ("-", ""), ("Base fare", "150.00"), ("Distance 7.4 km", "740.00"),
                    ("Waiting time", "60.00"), ("-", ""), ("Total Rs.", "950.00"),
                    ("Thanks for riding", "")]
        }
    }

    /// Renders the receipt as a JPEG, as if it had been photographed.
    func renderJPEG(date: Date = .now) -> Data? {
        let width: CGFloat = 900
        let lineHeight: CGFloat = 54
        let rows = lines(on: date)
        let height = CGFloat(rows.count) * lineHeight + 160
        let size = CGSize(width: width, height: height)

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: size, format: format)

        let image = renderer.image { context in
            UIColor(white: 0.98, alpha: 1).setFill()
            context.fill(CGRect(origin: .zero, size: size))

            let font = UIFont.monospacedSystemFont(ofSize: 30, weight: .medium)
            let bold = UIFont.monospacedSystemFont(ofSize: 34, weight: .bold)
            let ink = UIColor(white: 0.12, alpha: 1)
            var y: CGFloat = 80

            for (index, row) in rows.enumerated() {
                if row.left == "-" {
                    let dash = String(repeating: "-", count: 44)
                    (dash as NSString).draw(at: CGPoint(x: 60, y: y), withAttributes: [.font: font, .foregroundColor: ink])
                } else {
                    let isHeader = index == 0 || row.left.uppercased().contains("TOTAL") && !row.left.contains("Sub")
                    let attributes: [NSAttributedString.Key: Any] = [.font: isHeader ? bold : font, .foregroundColor: ink]
                    (row.left as NSString).draw(at: CGPoint(x: 60, y: y), withAttributes: attributes)
                    if !row.right.isEmpty {
                        let rightSize = (row.right as NSString).size(withAttributes: attributes)
                        (row.right as NSString).draw(at: CGPoint(x: width - 60 - rightSize.width, y: y), withAttributes: attributes)
                    }
                }
                y += lineHeight
            }
        }
        return image.jpegData(compressionQuality: 0.9)
    }
}
