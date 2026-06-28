import SwiftUI

struct CalendarWidgetView: View {
    @ObservedObject private var calendar = CalendarManager.shared

    var body: some View {
        VStack(spacing: 0) {
            // Calendar Header
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text(calendar.weekday.isEmpty ? "Today" : calendar.weekday)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.pink)
                    Text(calendar.monthDay)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                }

                Spacer()

                Text(calendar.statusText)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.4))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(6)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)

            Spacer()

            // Events list / empty states
            Group {
                switch calendar.access {
                case .denied:
                    emptyState(icon: "lock.fill",
                               title: "Calendar Access Off",
                               subtitle: "Enable in System Settings → Privacy → Calendars")
                case .unknown:
                    emptyState(icon: "calendar", title: "Loading…", subtitle: nil)
                case .granted where calendar.events.isEmpty:
                    emptyState(icon: "checkmark.circle.fill",
                               title: "Nothing on your calendar",
                               subtitle: "Enjoy the clear day")
                case .granted:
                    VStack(spacing: 8) {
                        ForEach(calendar.events.prefix(3)) { event in
                            EventRow(event: event)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
    }

    private func emptyState(icon: String, title: String, subtitle: String?) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(.white.opacity(0.35))
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white.opacity(0.6))
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.system(size: 9))
                    .foregroundColor(.white.opacity(0.35))
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
    }
}

struct EventRow: View {
    let event: CalendarManager.Item
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 8) {
            // Left color indicator bar
            RoundedRectangle(cornerRadius: 1.5)
                .fill(event.color)
                .frame(width: 3, height: 20)

            VStack(alignment: .leading, spacing: 1) {
                Text(event.title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)

                Text(event.time)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
            }

            Spacer()

            // Duration indicator
            Text(event.duration)
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(event.isActive ? event.color : .white.opacity(0.4))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(event.isActive ? event.color.opacity(0.15) : Color.white.opacity(0.05))
                .cornerRadius(4)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.white.opacity(isHovered ? 0.05 : 0.02))
        .cornerRadius(8)
        .onHover { hovering in
            withAnimation(.spring(response: 0.2, dampingFraction: 0.75)) {
                isHovered = hovering
            }
        }
    }
}
