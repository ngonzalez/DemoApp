//
//  ContentView.swift
//  DemoApp
//
//  Created by Nicolas GONZALEZ on 10/5/24.
//

import SwiftUI

@MainActor
struct ContentView: View {
    @State var folders: Array<URL> = Array<URL>()

    @State private var isImporting = false

    var body: some View {
        VStack {
            Text("Import: \(folders)")

            Button(action: {
                isImporting = true
            }) {
                Image(systemName: "waveform.circle.fill")
                    .font(.system(size: 40))
            }
            .fileImporter(
                isPresented: $isImporting,
                allowedContentTypes: [.folder],
                allowsMultipleSelection: true
            ) { result in
                if case .success = result {
                    do {
                        let items = try result.get()

                        for url in items {
                            if url.startAccessingSecurityScopedResource() {
                                folders.append(url)
                            }
                        }
                    } catch {
                        let nsError = error as NSError
                        fatalError("File Import Error \(nsError), \(nsError.userInfo)")
                    }
                } else {
                    print("File Import Failed")
                }
            }
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
