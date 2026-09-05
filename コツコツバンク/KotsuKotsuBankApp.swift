//
//  KotsuKotsuBankApp.swift
//  コツコツバンク
//
//  Created by Kaito Seto on 2026/08/24.
//

import SwiftUI
import SwiftData

@main
struct KotsuKotsuBankApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            FamilyAccount.self,
            ChildProfile.self,
            Goal.self,
            Mission.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    @State private var session = SessionStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(session)
        }
        .modelContainer(sharedModelContainer)
    }
}
