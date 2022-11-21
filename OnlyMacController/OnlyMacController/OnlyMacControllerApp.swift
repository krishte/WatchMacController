//
//  OnlyMacControllerApp.swift
//  OnlyMacController
//
//  Created by Tejas Krishnan on 23.01.22.
//

import SwiftUI

@main
struct OnlyMacControllerApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
