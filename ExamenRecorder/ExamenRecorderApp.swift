//
//  ExamenRecorderApp.swift
//  ExamenRecorder
//
//  Created by admin on 21.11.24.
//

import SwiftUI

@main
struct ExamenRecorderApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            SplashScreenView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
