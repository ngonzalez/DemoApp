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
    func clearFolders() {
        folders = []
    }
    
    func uploadItem(uploadData: Data) {
        let url = URL(string: "http://127.0.0.1:3002/")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let task = URLSession.shared.uploadTask(with: request, from: uploadData) { data, response, error in
            print(response as Any)
////            if let error = error {
////                print ("error: \(error)")
////                return
////            }
////            guard let response = response as? HTTPURLResponse,
////                (200...299).contains(response.statusCode) else {
////                print ("server error")
////                return
////            }
////            if let mimeType = response.mimeType,
////                mimeType == "application/json",
////                let data = data,
////                let dataString = String(data: data, encoding: .utf8) {
////                print ("got data: \(dataString)")
////            }
        }
        task.resume()
    }
    
    func browseFolder(folder: URL) {
        let fm = FileManager.default

        do {
            let items = try fm.contentsOfDirectory(atPath: folder.path)

            for item in items {
                print("--")
                let itemPath = folder.path + "/" + item
                print(itemPath)
                let attributes = try fm.attributesOfItem(
                    atPath: itemPath
                )
//                let fsattributes = try fm.attributesOfFileSystem(
//                    forPath: itemPath
//                )
                let fsFileType:String = attributes[FileAttributeKey.type] as! String
                print("fsFileType: \(fsFileType)")
                if (fsFileType == "NSFileTypeRegular") {
                    print(item)
                    do {
                        let fileData = try Data(contentsOf: URL(fileURLWithPath: itemPath))
                        print(fileData)
                        uploadItem(uploadData: fileData)
                    } catch {
                        print ("loading file error")
                    }
                } else if (fsFileType == "NSFileTypeDirectory") {
                    print("--")
                    let itemsSubfolder = try fm.contentsOfDirectory(atPath: itemPath)
                    for itemSubfolder in itemsSubfolder {
                        let itemSubfolderPath = itemPath + "/" + itemSubfolder
                        print(itemSubfolderPath)
                        let attributesItemSubfolder = try fm.attributesOfItem(
                            atPath: itemSubfolderPath
                        )
                        let fsFileTypeSubfolder:String = attributesItemSubfolder[FileAttributeKey.type] as! String
                        print("fsFileTypeSubfolder: \(fsFileTypeSubfolder)")
                        if (fsFileTypeSubfolder == "NSFileTypeRegular") {
                            do {
                                let fileDataSubfolder = try Data(contentsOf: URL(fileURLWithPath: itemSubfolderPath))
                                print(fileDataSubfolder)
                                uploadItem(uploadData: fileDataSubfolder)
                            } catch {
                                print ("loading file error")
                            }
                        }
                    }
                }
            }
        } catch {
            // failed to read directory – bad permissions, perhaps?
        }
    }
    func syncFolders() {
        for folder in folders {
            let fm = FileManager.default

            do {
                let attributes = try fm.attributesOfItem(
                    atPath: folder.path
                )
//                let fsattributes = try fm.attributesOfFileSystem(
//                    forPath: folder.path
//                )
                print("----")
                print(folder.path)
                let fsItemType:String = attributes[FileAttributeKey.type] as! String
                print("fsItemType: \(fsItemType)")
                print("\n")
//                print(attributes)
//                print(fsattributes)
//                print("\n")
                if (fsItemType == "NSFileTypeDirectory") {
                    browseFolder(folder: folder)
                }
            } catch {
                // failed to read directory – bad permissions, perhaps?
            }
        }
    }

    var body: some View {
        VStack {
            Button(action: syncFolders) {
                Text("Import \(folders)")
            }

            Button(action: clearFolders) {
                Text("clear")
            }

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
