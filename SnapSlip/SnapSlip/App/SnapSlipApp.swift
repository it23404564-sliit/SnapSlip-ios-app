//
//  SnapSlipApp.swift
//  SnapSlip
//
//  App entry point. Builds the SwiftData container, the shared services
//  (Vision OCR, Core ML categoriser, receipt parser) and the navigation router,
//  then injects them into the SwiftUI environment.
//

import SwiftUI
import SwiftData

@main
struct SnapSlipApp: App {
    private let modelContainer: ModelContainer
    @State private var services: AppServices
    @State private var router = AppRouter()

    init() {
        let arguments = ProcessInfo.processInfo.arguments
        let isUITesting = arguments.contains(LaunchArgument.uiTesting)

        do {
            // UI tests run against a throw-away in-memory store so every run starts clean.
            modelContainer = try PersistenceController.makeContainer(inMemory: isUITesting)
        } catch {
            // A corrupt store is unrecoverable at launch; fail loudly in development.
            fatalError("SnapSlip could not create its SwiftData container: \(error)")
        }

        _services = State(initialValue: AppServices.live())

        if isUITesting {
            AppSettings.prepareForUITesting(skipOnboarding: !arguments.contains(LaunchArgument.showOnboarding))
            if arguments.contains(LaunchArgument.seedSampleData) {
                PersistenceController.seedSampleData(into: modelContainer.mainContext)
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(services)
                .environment(router)
        }
        .modelContainer(modelContainer)
    }
}
