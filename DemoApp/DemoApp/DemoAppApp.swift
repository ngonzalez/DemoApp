//
//  DemoAppApp.swift
//  DemoApp
//
//  Created by Nicolas GONZALEZ on 10/5/24.
//

import SwiftUI

struct VisualEffect: NSViewRepresentable {
    func makeNSView(context: Self.Context) -> NSView {
        let view = NSVisualEffectView()
        view.material = .sidebar
        return view
    }
    func updateNSView(_ nsView: NSView, context: Context) { }
}

@main
struct DemoAppApp: App {
    /// The status page's ongoing events, for the banner
    @StateObject private var statusMonitor = StatusMonitor()

    var body: some Scene {
        WindowGroup {
            VStack(spacing: 0) {
                StatusBanner(monitor: statusMonitor)
                ContentView()
            }
            .background(VisualEffect())
            .task { await statusMonitor.start() }
        }
    }
}
