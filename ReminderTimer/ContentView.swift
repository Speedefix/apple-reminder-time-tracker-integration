//
//  ContentView.swift
//  ReminderTimer
//
//  Created by Leonard Schulte on 07.11.25.
//

import SwiftUI
import EventKit

struct ContentView: View {
    @StateObject private var reminderManager = ReminderManager()
    @State private var searchText: String = ""
    @State private var selectedReminderID: String? = nil
    @FocusState private var searchFocused: Bool

    var filteredReminders: [EKReminder] {
        if searchText.isEmpty {
            return reminderManager.reminders
        }
        return reminderManager.reminders.filter { reminder in
            let title = reminder.title?.lowercased() ?? ""
            return title.contains(searchText.lowercased())
        }
    }

    var body: some View {
        NavigationView {
            // LEFT SIDE
            VStack {
                TextField("Suchen ...", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .padding()
                    .focused($searchFocused)

                List(selection: $selectedReminderID) {
                    ForEach(filteredReminders, id: \.calendarItemIdentifier) { reminder in
                        Text(reminder.title ?? "Ohne Titel")
                            .tag(reminder.calendarItemIdentifier as String?)
                    }
                }
            }
            .frame(minWidth: 250)

            // RIGHT SIDE
            if let id = selectedReminderID,
               let reminder = reminderManager.reminders.first(where: { $0.calendarItemIdentifier == id }) {
                ReminderDetailView(reminder: reminder, reminderManager: reminderManager)
            } else {
                Text("Wähle eine Erinnerung aus")
                    .foregroundStyle(.secondary)
            }
        }
        .task {
            if await reminderManager.requestAccess() {
                await reminderManager.loadReminders()
            }
        }
    }
}


struct YourView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
