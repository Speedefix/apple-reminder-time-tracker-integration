//
//  ReminderManager.swift
//  ReminderTimer
//
//  Created by Leonard Schulte on 11.11.25.
//

import Foundation
import EventKit
import Combine

@MainActor
class ReminderManager: ObservableObject {
    // MARK: - Time Spent Format Constants
    private let timeSpentTag = "time_spent:"
    private let timeSpentRegex =
        #"time_spent:\s*(\d+)h\s*(\d+)m\s*(\d+)s"#
    
    private let eventStore = EKEventStore()
    private var fetchTimer: Timer?
    
    @Published var reminders: [EKReminder] = []
    @Published var calendars: [EKCalendar] = []
    @Published var runningTimers: [String: Date] = [:]   // [ReminderID : startDate]
    @Published var elapsedTimes: [String: TimeInterval] = [:]  // For UI updates
    
    private var timer: Timer?

    init() {
        startTickTimer()
    }

    // MARK: - EventKit Access
    func requestAccess() async -> Bool {
        await withCheckedContinuation { continuation in
            eventStore.requestFullAccessToReminders { granted, error in
                if let error = error {
                    print("Zugriffsfehler: \(error.localizedDescription)")
                }
                continuation.resume(returning: granted)
            }
        }
    }
    
    func loadReminders() async {
        let predicate = eventStore.predicateForReminders(in: nil)
        eventStore.fetchReminders(matching: predicate) { reminders in
            DispatchQueue.main.async {
                let allReminders = (reminders ?? []).filter { !$0.isCompleted }
                self.reminders = allReminders.sorted { ($0.title ?? "") < ($1.title ?? "") }

                // Kalender sammeln
                let cals = Set(allReminders.compactMap { $0.calendar })
                self.calendars = Array(cals).sorted { $0.title < $1.title }
            }
        }
    }

    // MARK: - Timer Logic
    func startTimer(for reminder: EKReminder) {
        let id = reminder.calendarItemIdentifier
        runningTimers[id] = Date()
    }

    func stopTimer(for reminder: EKReminder) -> TimeInterval {
        let id = reminder.calendarItemIdentifier

        guard let start = runningTimers[id] else { return 0 }
        let elapsed = Date().timeIntervalSince(start)

        runningTimers[id] = nil
        elapsedTimes[id] = elapsed

        return elapsed
    }
    
    func formatElapsed(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded())
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60

        return "\(h)h \(m)m \(s)s"
    }
    
    func formatPretty(h: Int, m: Int, s: Int) -> String {
        var parts: [String] = []

        if h > 0 { parts.append("\(h)h") }
        if m > 0 { parts.append("\(m)m") }
        if s > 0 { parts.append("\(s)s") }

        // Wenn alles 0 ist
        if parts.isEmpty { return "0s" }

        return parts.joined(separator: " ")
    }
    
    func prettyTimeSpent(for reminder: EKReminder) -> String {
        guard let notes = reminder.notes,
              let ts = parseExistingTimeSpent(in: notes) else {
            return "Untracked"
        }
        
        if ts.h == 0 && ts.m == 0 && ts.s == 0 {
            return "Untracked"
        }
        
        return formatPretty(h: ts.h, m: ts.m, s: ts.s)
    }
    
    func parseExistingTimeSpent(in notes: String) -> (h: Int, m: Int, s: Int)? {
        guard let range = notes.range(of: timeSpentTag) else { return nil }

        let substring = notes[range.upperBound...]  // alles nach "time_spent:"

        // Suche nach h/m/s separat
        let hourMatch = substring.range(of: #"(\d+)\s*h"#, options: .regularExpression)
        let minuteMatch = substring.range(of: #"(\d+)\s*m"#, options: .regularExpression)
        let secondMatch = substring.range(of: #"(\d+)\s*s"#, options: .regularExpression)

        func extractNumber(_ r: Range<String.Index>?) -> Int {
            guard let r = r else { return 0 }
            let match = substring[r]
            let num = match.replacingOccurrences(of: #"[^0-9]"#, with: "", options: .regularExpression)
            return Int(num) ?? 0
        }

        let h = extractNumber(hourMatch)
        let m = extractNumber(minuteMatch)
        let s = extractNumber(secondMatch)

        if h == 0 && m == 0 && s == 0 {
            // Format existiert, aber keine Zahlen → ungültig
            return nil
        }

        return (h, m, s)
    }
    
    func addTimeToReminder(_ reminder: EKReminder, elapsed: TimeInterval) {
        let addedSeconds = Int(elapsed.rounded())
        var existingSeconds = 0

        let existingNotes = reminder.notes ?? ""

        if let parsed = parseExistingTimeSpent(in: existingNotes) {
            existingSeconds = parsed.h * 3600 + parsed.m * 60 + parsed.s
        }

        let combinedSeconds = existingSeconds + addedSeconds
        let combinedString = formatElapsed(TimeInterval(combinedSeconds))

        // neuen time_spent String bauen
        let newTimeString = "\(timeSpentTag) \(combinedString)"

        var updatedNotes = existingNotes

        if existingNotes.contains(timeSpentTag) {
            // ersetzen mit Regex → robust
            updatedNotes = existingNotes.replacingOccurrences(
                of: timeSpentRegex,
                with: newTimeString,
                options: .regularExpression
            )
        } else {
            // neu hinzufügen
            if !updatedNotes.isEmpty { updatedNotes += "\n" }
            updatedNotes += newTimeString
        }

        reminder.notes = updatedNotes

        do {
            try eventStore.save(reminder, commit: true)
            print("Gespeichert: \(updatedNotes)")
        } catch {
            print("Fehler beim Speichern: \(error)")
        }
    }

    private func startTickTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            Task { @MainActor in
                self.updateElapsedTimes()
            }
        }
    }

    private func updateElapsedTimes() {
        for (id, startDate) in runningTimers {
            elapsedTimes[id] = Date().timeIntervalSince(startDate)
        }
    }
}
