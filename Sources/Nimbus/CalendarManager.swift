import Foundation
import EventKit
import SwiftUI
import Combine

/// Real calendar integration via EventKit. Surfaces today's events from every
/// calendar the user has granted access to, with live "happening now" detection.
final class CalendarManager: ObservableObject {
    static let shared = CalendarManager()

    struct Item: Identifiable {
        let id: String
        let time: String
        let title: String
        let duration: String
        let color: Color
        let isActive: Bool
    }

    enum Access { case unknown, granted, denied }

    @Published var events: [Item] = []
    @Published var weekday: String = ""
    @Published var monthDay: String = ""
    @Published var access: Access = .unknown

    // An event starting within the next 15 minutes — drives the live-activity.
    @Published var imminentTitle: String? = nil
    @Published var imminentMinutes: Int = 0

    private let store = EKEventStore()
    private var refreshTimer: Timer?

    private let weekdayFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "EEEE"; return f
    }()
    private let monthDayFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "MMMM d"; return f
    }()
    private let timeFormatter: DateFormatter = {
        let f = DateFormatter(); f.timeStyle = .short; f.dateStyle = .none; return f
    }()

    var statusText: String {
        switch access {
        case .denied:  return "Access Needed"
        case .unknown: return "Loading…"
        case .granted: return events.isEmpty ? "No Events Today" : "\(events.count) Event\(events.count == 1 ? "" : "s") Today"
        }
    }

    private init() {}

    func start() {
        updateDate()
        requestAccess()

        // Recompute date + "active" state every minute; refresh when the store changes.
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.updateDate()
            self?.fetchEvents()
        }
        NotificationCenter.default.addObserver(
            self, selector: #selector(storeChanged),
            name: .EKEventStoreChanged, object: store)
    }

    @objc private func storeChanged() { fetchEvents() }

    private func updateDate() {
        let now = Date()
        let weekday = weekdayFormatter.string(from: now)
        let monthDay = monthDayFormatter.string(from: now)
        DispatchQueue.main.async {
            self.weekday = weekday
            self.monthDay = monthDay
        }
    }

    private func requestAccess() {
        let handler: (Bool, Error?) -> Void = { [weak self] granted, _ in
            DispatchQueue.main.async {
                self?.access = granted ? .granted : .denied
                if granted { self?.fetchEvents() }
            }
        }
        if #available(macOS 14.0, *) {
            store.requestFullAccessToEvents(completion: handler)
        } else {
            store.requestAccess(to: .event, completion: handler)
        }
    }

    private func fetchEvents() {
        let cal = Calendar.current
        let start = cal.startOfDay(for: Date())
        guard let end = cal.date(byAdding: .day, value: 1, to: start) else { return }

        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        let now = Date()
        let sorted = store.events(matching: predicate)
            .filter { !$0.isAllDay || $0.startDate >= start } // keep today's all-day + timed
            .sorted { $0.startDate < $1.startDate }

        // Soonest timed event starting within the next 15 minutes.
        let imminent = sorted.first { !$0.isAllDay && $0.startDate > now && $0.startDate.timeIntervalSince(now) <= 15 * 60 }
        let imTitle = imminent?.title
        let imMins = imminent != nil ? max(1, Int(imminent!.startDate.timeIntervalSince(now) / 60)) : 0

        let items = sorted
            .map { ev -> Item in
                let active = !ev.isAllDay && ev.startDate <= now && ev.endDate >= now
                let nsColor = ev.calendar.cgColor.flatMap { NSColor(cgColor: $0) } ?? .systemBlue
                return Item(
                    id: ev.eventIdentifier ?? UUID().uuidString,
                    time: ev.isAllDay ? "All day" : timeFormatter.string(from: ev.startDate),
                    title: ev.title ?? "Untitled",
                    duration: durationLabel(for: ev, active: active),
                    color: Color(nsColor),
                    isActive: active
                )
            }

        DispatchQueue.main.async {
            self.events = items
            self.imminentTitle = imTitle
            self.imminentMinutes = imMins
        }
    }

    private func durationLabel(for ev: EKEvent, active: Bool) -> String {
        if active { return "Now" }
        if ev.isAllDay { return "All day" }
        let minutes = Int(ev.endDate.timeIntervalSince(ev.startDate) / 60)
        guard minutes > 0 else { return "" }
        let h = minutes / 60, m = minutes % 60
        if h > 0 && m > 0 { return "\(h)h \(m)m" }
        if h > 0 { return "\(h)h" }
        return "\(m)m"
    }
}
