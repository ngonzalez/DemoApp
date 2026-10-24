/*
    Copyright (c) 2026 Nicolas GONZALEZ

    MIT License

    Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated
    documentation files (the “Software”), to deal in the Software without restriction, including without limitation
    the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software,
    and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

    The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
    OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLteDERS BE
    LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR
    IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

import SwiftUI

/// A system event of the status page (status.appshare.site), from the
/// backend's `GET /system_events`
struct SystemStatusEvent: Decodable, Identifiable, Equatable {
    let id: Int
    /// incident, maintenance, deploy or info
    let eventType: String
    /// website, api, streaming or registration; none for every service
    let service: String?
    let title: String?
    let description: String?
    /// ISO 8601
    let occurredAt: String
    let endedAt: String?
    let ongoing: Bool

    /// The kinds the banner shows, the most serious first: a deploy isn't
    /// worth telling the user
    static let shownTypes = ["incident", "maintenance", "info"]

    /// What identifies the event as the user saw it: hidden, it comes back
    /// once it changes (a new title, an end)
    var dismissKey: String { "\(id)|\(eventType)|\(title ?? "")|\(endedAt ?? "")" }
}

/// Watches the status page's ongoing events: on launch, then every five
/// minutes; remembers the ones the user hid
@MainActor
final class StatusMonitor: ObservableObject {
    static let statusURL = URL(string: "https://api.appshare.site/system_events")!
    static let pageURL = URL(string: "https://status.appshare.site")!
    static let interval: Duration = .seconds(5 * 60)
    private static let dismissedKey = "dismissedStatusEvents"

    @Published private(set) var events: [SystemStatusEvent] = []
    @Published private(set) var dismissed: Set<String> = Set(UserDefaults.standard.stringArray(forKey: dismissedKey) ?? [])

    /// The ongoing events the user hasn't hidden, the most serious first
    var shown: [SystemStatusEvent] {
        events
            .filter { $0.ongoing && SystemStatusEvent.shownTypes.contains($0.eventType) && !dismissed.contains($0.dismissKey) }
            .sorted { SystemStatusEvent.shownTypes.firstIndex(of: $0.eventType)! < SystemStatusEvent.shownTypes.firstIndex(of: $1.eventType)! }
    }

    /// Check now, then every `interval`, as long as the window is open
    func start() async {
        while !Task.isCancelled {
            await refresh()
            try? await Task.sleep(for: Self.interval)
        }
    }

    /// The status now; a failure keeps the last one (the banner isn't worth an error)
    func refresh() async {
        struct Status: Decodable { let events: [SystemStatusEvent] }
        var request = URLRequest(url: Self.statusURL)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let status = try? JSONDecoder().decode(Status.self, from: data) else { return }
        events = status.events
    }

    /// Hide the event until it changes
    func dismiss(_ event: SystemStatusEvent) {
        dismissed.insert(event.dismissKey)
        // only the events still listed: the set doesn't grow forever
        let listed = Set(events.map(\.dismissKey))
        UserDefaults.standard.set(Array(dismissed.intersection(listed)), forKey: Self.dismissedKey)
    }
}

/// A thin bar at the top of the window while an incident, a maintenance or
/// a note is ongoing: its title and since when, Details (the status page),
/// and ✕ to hide it
struct StatusBanner: View {
    @ObservedObject var monitor: StatusMonitor
    @Environment(\.openURL) private var openURL

    var body: some View {
        if let event = monitor.shown.first {
            HStack(spacing: 10) {
                Image(systemName: icon(event))
                Text(event.title ?? "")
                    .fontWeight(.medium)
                    .lineLimit(1)
                if let since = since(event) {
                    Text("Since \(since)")
                        .opacity(0.85)
                        .lineLimit(1)
                }
                if monitor.shown.count > 1 {
                    Text("+\(monitor.shown.count - 1) more")
                        .opacity(0.85)
                }
                Spacer()
                Button("Details") { openURL(StatusMonitor.pageURL) }
                    .buttonStyle(.plain)
                    .underline()
                Button {
                    monitor.dismiss(event)
                } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.plain)
                .help(Text("Hide"))
            }
            .font(.callout)
            .foregroundStyle(foreground(event))
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity)
            .background(background(event))
        }
    }

    func icon(_ event: SystemStatusEvent) -> String {
        switch event.eventType {
        case "incident": "exclamationmark.triangle.fill"
        case "maintenance": "wrench.and.screwdriver.fill"
        default: "info.circle.fill"
        }
    }

    /// Red for an incident, amber for a maintenance, blue for a note
    func background(_ event: SystemStatusEvent) -> Color {
        switch event.eventType {
        case "incident": Color(red: 0.91, green: 0.30, blue: 0.24)
        case "maintenance": Color(red: 0.97, green: 0.73, blue: 0.20)
        default: Color(red: 0.20, green: 0.52, blue: 0.86)
        }
    }

    func foreground(_ event: SystemStatusEvent) -> Color {
        event.eventType == "maintenance" ? Color.black.opacity(0.85) : .white
    }

    /// When the event began: its time today, or its date and time
    func since(_ event: SystemStatusEvent) -> String? {
        guard let date = ISO8601DateFormatter().date(from: event.occurredAt) else { return nil }
        return Calendar.current.isDateInToday(date)
            ? date.formatted(date: .omitted, time: .shortened)
            : date.formatted(date: .abbreviated, time: .shortened)
    }
}
