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
    @State private var showCalendarFilter = false
    @State private var selectedCalendars: Set<String> = [] // Kalendertitel
    @FocusState private var searchFocused: Bool
    @Environment(\.scenePhase) private var scenePhase

    var filteredReminders: [EKReminder] {
        reminderManager.reminders.filter { reminder in
            // Filter nach Suche
            let matchesSearch = searchText.isEmpty || (reminder.title?.lowercased().contains(searchText.lowercased()) ?? false)
            // Filter nach ausgewählten Listen
            let matchesCalendar = selectedCalendars.isEmpty || selectedCalendars.contains(reminder.calendar.title)
            return matchesSearch && matchesCalendar
        }
    }
    
    // MARK: - View
    var body: some View {
        NavigationView {
            // LEFT SIDE
            VStack {
                TextField("Suchen ...", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .padding()
                    .focused($searchFocused)

                DisclosureGroup(
                        isExpanded: $showCalendarFilter,
                        content: {
                            VStack(alignment: .leading) {
                                ForEach(reminderManager.calendars, id: \.calendarIdentifier) { cal in
                                    Toggle(isOn: Binding(
                                        get: { selectedCalendars.contains(cal.title) },
                                        set: { selected in
                                            if selected { selectedCalendars.insert(cal.title) }
                                            else { selectedCalendars.remove(cal.title) }
                                        }
                                    )) {
                                        Text(cal.title)
                                    }
                                }
                            }
                            .padding(.horizontal)
                        },
                        label: {
                            // Label zeigt immer die ausgewählten Kalender an
                            let selected = reminderManager.calendars
                                .filter { selectedCalendars.contains($0.title) }
                                .map { $0.title }
                                .joined(separator: ", ")
                            Text(selected.isEmpty ? "Alle Listen anzeigen" : selected)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    )
                    .padding(.horizontal)
                
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
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            Task { await reminderManager.loadReminders() }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeMainNotification)) { _ in
            Task { await reminderManager.loadReminders() }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { _ in
            Task { await reminderManager.loadReminders() }
        }
    }
}


struct YourView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
