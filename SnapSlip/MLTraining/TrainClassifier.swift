#!/usr/bin/env swift
//
//  TrainClassifier.swift
//  SnapSlip — Core ML model training
//
//  Trains the ReceiptCategoryClassifier text classifier with Create ML.
//  Run on a Mac (Create ML is macOS-only):
//
//      cd MLTraining
//      swift TrainClassifier.swift
//
//  Then drag the generated ReceiptCategoryClassifier.mlmodel into the
//  SnapSlip/ML folder in Xcode (any folder inside SnapSlip/ works). Xcode compiles
//  it to ReceiptCategoryClassifier.mlmodelc, which ExpenseCategorizer loads at launch.
//
//  You can also train it with no code: open the Create ML app → New Document →
//  Text Classifier → drop receipt_categories.csv in as training data.
//

import CreateML
import Foundation
import NaturalLanguage

let here = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let csvURL = here.appendingPathComponent("receipt_categories.csv")
let outputURL = here.appendingPathComponent("ReceiptCategoryClassifier.mlmodel")

do {
    let table = try MLDataTable(contentsOf: csvURL)
    let (training, testing) = table.randomSplit(by: 0.8, seed: 42)
    print("Training rows: \(training.rows.count), test rows: \(testing.rows.count)")

    // Maximum-entropy model: small (tens of KB), fast, and runs on every iOS 17 device.
    // Try .transferLearning(.dynamicEmbedding, revision: 1) to compare accuracy
    // against a larger embedding-based model (discussed in the report).
    let parameters = MLTextClassifier.ModelParameters(
        validation: .split(strategy: .automatic),
        algorithm: .maxEnt(revision: 1),
        language: .english
    )

    let classifier = try MLTextClassifier(trainingData: training,
                                          textColumn: "text",
                                          labelColumn: "label",
                                          parameters: parameters)

    let trainingAccuracy = (1.0 - classifier.trainingMetrics.classificationError) * 100
    let validationAccuracy = (1.0 - classifier.validationMetrics.classificationError) * 100
    let evaluation = classifier.evaluation(on: testing, textColumn: "text", labelColumn: "label")
    let testAccuracy = (1.0 - evaluation.classificationError) * 100

    print(String(format: "Training accuracy:   %.1f%%", trainingAccuracy))
    print(String(format: "Validation accuracy: %.1f%%", validationAccuracy))
    print(String(format: "Test accuracy:       %.1f%%", testAccuracy))
    print("Confusion matrix:\n\(evaluation.confusion)")

    let metadata = MLModelMetadata(author: "SnapSlip",
                                   shortDescription: "Predicts a spending category from receipt text.",
                                   license: "For SE4041 coursework",
                                   version: "1.0")
    try classifier.write(to: outputURL, metadata: metadata)
    print("Saved \(outputURL.path)")
} catch {
    print("Training failed: \(error)")
    exit(1)
}
