//
//  IOSWatchControllerApp.swift
//  IOSWatchController WatchKit Extension
//
//  Created by Tejas Krishnan on 30.01.22.
//

import SwiftUI

@main
struct IOSWatchControllerApp: App {
    @SceneBuilder var body: some Scene {
        WindowGroup {
            NavigationView {
                ContentView()
            }
        }

        WKNotificationScene(controller: NotificationController.self, category: "myCategory")
    }
}
