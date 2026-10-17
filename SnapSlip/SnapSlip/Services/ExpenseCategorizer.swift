//
//  ExpenseCategorizer.swift
//  SnapSlip
//
//  Suggests a spending category from the merchant name and receipt text,
//  entirely on device. It tries, in order:
//
//   1. A Core ML text classifier (ReceiptCategoryClassifier.mlmodel), trained
//      with Create ML from MLTraining/receipt_categories.csv.
//   2. Merchant keyword rules for well-known Sri Lankan brands.
//   3. NaturalLanguage word-embedding similarity to category "anchor" words,
//      which generalises to merchants the app has never seen.
//
//  (The personal MerchantMemory layer runs before all of these; see ScanViewModel.)
//

import Foundation
import NaturalLanguage

struct ScoredCategory: Equatable, Sendable {
    let category: ExpenseCategory
    let score: Double
}

struct CategoryPrediction: Equatable, Sendable {
    var category: ExpenseCategory
    var confidence: Double
    var source: CategorySource
    var alternatives: [ScoredCategory] = []
}

protocol ExpenseCategorizing: Sendable {
    func categorize(merchant: String, text: String) -> CategoryPrediction
    var isCoreMLModelLoaded: Bool { get }
}

final class ExpenseCategorizer: ExpenseCategorizing, @unchecked Sendable {
    static let modelName = "ReceiptCategoryClassifier"

    private let textClassifier: NLModel?
    private let embedding: NLEmbedding?
    private let minimumModelConfidence: Double

    /// Production initialiser: loads the compiled model from the app bundle if present.
    convenience init(bundle: Bundle = .main) {
        let classifier = bundle.url(forResource: Self.modelName, withExtension: "mlmodelc")
            .flatMap { try? NLModel(contentsOf: $0) }
        self.init(textClassifier: classifier, embedding: NLEmbedding.wordEmbedding(for: .english))
    }

    /// Designated initialiser; tests pass nil for deterministic keyword-only behaviour.
    init(textClassifier: NLModel?, embedding: NLEmbedding?, minimumModelConfidence: Double = 0.45) {
        self.textClassifier = textClassifier
        self.embedding = embedding
        self.minimumModelConfidence = minimumModelConfidence
    }

    var isCoreMLModelLoaded: Bool { textClassifier != nil }

    func categorize(merchant: String, text: String) -> CategoryPrediction {
        let input = Self.normalize(merchant + " " + text)
        let merchantInput = Self.normalize(merchant)

        if let prediction = classifyWithModel(input), prediction.confidence >= minimumModelConfidence {
            return prediction
        }
        if let prediction = classifyWithKeywords(merchant: merchantInput, text: input) {
            return prediction
        }
        if let prediction = classifyWithEmbeddings(input) {
            return prediction
        }
        return CategoryPrediction(category: .other, confidence: 0.2, source: .keywords)
    }

    /// The same normalisation is applied to the Create ML training text, so the
    /// model sees identical input at training time and at run time.
    static func normalize(_ text: String) -> String {
        let folded = text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US"))
        let words = folded
            .components(separatedBy: CharacterSet.letters.inverted)
            .filter { $0.count > 1 }
        return words.prefix(60).joined(separator: " ")
    }

    // MARK: 1. Core ML

    private func classifyWithModel(_ input: String) -> CategoryPrediction? {
        guard let model = textClassifier, !input.isEmpty else { return nil }
        let hypotheses = model.predictedLabelHypotheses(for: input, maximumCount: 3)
        let scored = hypotheses
            .compactMap { label, score in ExpenseCategory(rawValue: label).map { ScoredCategory(category: $0, score: score) } }
            .sorted { $0.score > $1.score }
        guard let best = scored.first else { return nil }
        return CategoryPrediction(category: best.category,
                                  confidence: best.score,
                                  source: .coreML,
                                  alternatives: Array(scored.dropFirst()))
    }

    // MARK: 2. Keyword rules

    static let keywordLexicon: [ExpenseCategory: [String]] = [
        .groceries: ["keells", "cargills", "food city", "arpico", "glomark", "laugfs super", "spar",
                     "supermarket", "super market", "grocery", "groceries", "mart", "vegetables", "dairy"],
        .dining: ["restaurant", "cafe", "coffee", "bakery", "pizza", "burger", "kfc", "mcdonald", "domino",
                  "perera sons", "kottu", "hotel", "bistro", "kitchen", "dine", "eatery", "juice bar", "uber eats"],
        .transport: ["pickme", "uber", "taxi", "kangaroo cabs", "fuel", "petrol", "diesel", "ceypetco",
                     "lanka ioc", "sinopec", "parking", "railway", "bus", "highway", "toll", "tuk"],
        .utilities: ["dialog", "mobitel", "slt", "hutch", "airtel", "ceb", "electricity", "leco",
                     "water board", "nwsdb", "internet", "broadband", "reload", "bill payment"],
        .shopping: ["odel", "fashion bug", "cool planet", "nolimit", "daraz", "house of fashion",
                    "abans", "singer", "softlogic", "clothing", "apparel", "shoes", "electronics", "mall"],
        .health: ["pharmacy", "osu sala", "healthguard", "hospital", "clinic", "channel", "medical",
                  "lab", "laboratory", "asiri", "nawaloka", "hemas", "durdans", "dental", "optician"],
        .education: ["bookshop", "book shop", "sarasavi", "vijitha yapa", "stationery", "tuition",
                     "course", "exam", "university", "institute", "sliit", "school", "library"],
        .entertainment: ["cinema", "cinemas", "scope", "majestic", "movie", "netflix", "spotify",
                         "concert", "game", "playstation", "steam", "theatre", "bowling", "event"]
    ]

    private func classifyWithKeywords(merchant: String, text: String) -> CategoryPrediction? {
        let paddedMerchant = " " + merchant + " "
        let paddedText = " " + text + " "
        var scores: [ExpenseCategory: Double] = [:]

        for (category, keywords) in Self.keywordLexicon {
            for keyword in keywords {
                let needle = " " + keyword + " "
                if paddedMerchant.contains(needle) {
                    scores[category, default: 0] += 2      // merchant name is the strongest signal
                } else if paddedText.contains(needle) {
                    scores[category, default: 0] += 1
                }
            }
        }

        let ranked = scores.sorted { $0.value > $1.value }
        guard let best = ranked.first else { return nil }
        let runnerUp = ranked.dropFirst().first?.value ?? 0
        // Confidence grows with evidence and with the margin over the runner-up.
        let margin = (best.value - runnerUp) / best.value
        let confidence = min(0.95, 0.5 + 0.1 * best.value) * (0.6 + 0.4 * margin)
        return CategoryPrediction(category: best.key,
                                  confidence: confidence,
                                  source: .keywords,
                                  alternatives: ranked.dropFirst().prefix(2).map { ScoredCategory(category: $0.key, score: $0.value) })
    }

    // MARK: 3. Word embeddings

    static let anchorWords: [ExpenseCategory: [String]] = [
        .groceries: ["grocery", "supermarket", "vegetables", "milk", "rice"],
        .dining: ["restaurant", "cafe", "pizza", "burger", "lunch"],
        .transport: ["taxi", "fuel", "bus", "train", "parking"],
        .utilities: ["electricity", "water", "internet", "telephone", "utility"],
        .shopping: ["clothing", "shoes", "fashion", "electronics", "store"],
        .health: ["pharmacy", "medicine", "hospital", "doctor", "clinic"],
        .education: ["books", "tuition", "course", "school", "university"],
        .entertainment: ["cinema", "movie", "music", "game", "concert"]
    ]

    private func classifyWithEmbeddings(_ input: String) -> CategoryPrediction? {
        guard let embedding else { return nil }
        let tokens = Array(Set(input.split(separator: " ").map(String.init)))
            .filter { $0.count >= 3 && embedding.contains($0) }
            .prefix(30)
        guard !tokens.isEmpty else { return nil }

        var bestDistance: [ExpenseCategory: Double] = [:]
        for token in tokens {
            for (category, anchors) in Self.anchorWords {
                for anchor in anchors {
                    let distance = embedding.distance(between: token, and: anchor, distanceType: .cosine)
                    if distance < bestDistance[category, default: .greatestFiniteMagnitude] {
                        bestDistance[category] = distance
                    }
                }
            }
        }

        let ranked = bestDistance.sorted { $0.value < $1.value }
        guard let best = ranked.first, best.value < 1.0 else { return nil }
        return CategoryPrediction(category: best.key,
                                  confidence: max(0.3, min(0.85, 1 - best.value)),
                                  source: .embedding,
                                  alternatives: ranked.dropFirst().prefix(2).map { ScoredCategory(category: $0.key, score: 1 - $0.value) })
    }
}
