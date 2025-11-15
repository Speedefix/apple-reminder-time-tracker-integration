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
    private let eventStore = EKEventStore()
    @Published var reminders: [EKReminder] = []
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
                self.reminders = (reminders ?? [])
                    .filter { !$0.isCompleted }       // nur offene
                    .sorted { ($0.title ?? "") < ($1.title ?? "") }
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
        let totalSeconds = Int(seconds.rounded())
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let secs = totalSeconds % 60

        return "\(hours)h \(minutes)m \(secs)s"
    }
    
    func addTimeToReminder(_ reminder: EKReminder, elapsed: TimeInterval) {
        let newFormatted = formatElapsed(elapsed)

        var existingHours = 0
        var existingMinutes = 0
        var existingSeconds = 0

        if let notes = reminder.notes {
            if let matchRange = notes.range(of: #"time_spent:\s*(\d+)h\s*(\d+)m\s*(\d+)s"#, options: .regularExpression) {
                let match = String(notes[matchRange])

                let regex = try! NSRegularExpression(pattern: #"time_spent:\s*(\d+)h\s*(\d+)m\s*(\d+)s"#)
                if let result = regex.firstMatch(in: match, range: NSRange(match.startIndex..., in: match)) {
                    if let hRange = Range(result.range(at: 1), in: match),
                       let mRange = Range(result.range(at: 2), in: match),
                       let sRange = Range(result.range(at: 3), in: match) {

                        existingHours = Int(match[hRange]) ?? 0
                        existingMinutes = Int(match[mRange]) ?? 0
                        existingSeconds = Int(match[sRange]) ?? 0
                    }
                }
            }
        }

        let newTotalSeconds = Int(elapsed.rounded())
        let existingTotalSeconds = existingHours * 3600 + existingMinutes * 60 + existingSeconds
        let combinedSeconds = existingTotalSeconds + newTotalSeconds

        let combinedHours = combinedSeconds / 3600
        let combinedMinutes = (combinedSeconds % 3600) / 60
        let combinedSecs = combinedSeconds % 60

        let combinedFormatted = "\(combinedHours)h \(combinedMinutes)m \(combinedSecs)s"

        // Write back into notes
        var newNotes = reminder.notes ?? ""
        if newNotes.contains("time_spent:") {
            // replace existing entry
            newNotes = newNotes.replacingOccurrences(
                of: #"time_spent:\s*\d+h\s*\d+m\s*\d+s"#,
                with: "time_spent: \(combinedFormatted)",
                options: .regularExpression
            )
        } else {
            // append new entry
            if newNotes.isEmpty == false { newNotes += "\n" }
            newNotes += "time_spent: \(combinedFormatted)"
        }

        reminder.notes = newNotes

        do {
            try eventStore.save(reminder, commit: true)
            print("Gespeichert: \(newNotes)")
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
