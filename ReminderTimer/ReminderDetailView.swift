//
//  ReminderDetailView.swift
//  ReminderTimer
//
//  Created by Leonard Schulte on 15.11.25.
//

import SwiftUI
import EventKit

struct ReminderDetailView: View {
    let reminder: EKReminder
    @ObservedObject var reminderManager: ReminderManager

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {

            Text(reminder.title ?? "Ohne Titel")
                .font(.largeTitle)
                .fontWeight(.bold)

            if let due = reminder.dueDateComponents?.date {
                Text("Fällig: \(due.formatted(date: .long, time: .shortened))")
                    .foregroundStyle(.secondary)
            }

            Divider()

            timerSection

            Spacer()
        }
        .padding()
    }

    @ViewBuilder
    var timerSection: some View {
        let id = reminder.calendarItemIdentifier
        let running = reminderManager.runningTimers[id] != nil
        let elapsed = reminderManager.elapsedTimes[id] ?? 0

        VStack(alignment: .leading, spacing: 10) {
            if running {
                Text("Läuft: \(formatTime(elapsed))")
                    .font(.title2)
                    .foregroundColor(.blue)
            }

            Button(running ? "Stop" : "Start") {
                if running {
                    let total = reminderManager.stopTimer(for: reminder)
                    reminderManager.addTimeToReminder(reminder, elapsed: total)
                } else {
                    reminderManager.startTimer(for: reminder)
                }
            }
            .buttonStyle(.borderedProminent)
            .frame(width: 120)
        }
    }

    func formatTime(_ seconds: TimeInterval) -> String {
        let s = Int(seconds) % 60
        let m = (Int(seconds) / 60) % 60
        let h = Int(seconds) / 3600

        if h > 0 { return String(format: "%02d:%02d:%02d", h, m, s) }
        else { return String(format: "%02d:%02d", m, s) }
    }
}
