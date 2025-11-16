//
//  ReminderTimerApp.swift
//  ReminderTimer
//
//  Created by Leonard Schulte on 07.11.25.
//

import SwiftUI

@main
struct ReminderTimerApp: App {
    @StateObject var reminderManager = ReminderManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(reminderManager)
        }
    }
}
