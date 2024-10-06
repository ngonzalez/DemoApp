//
//  ContentView.swift
//  DemoApp
//
//  Created by Nicolas GONZALEZ on 10/5/24.
//

import SwiftUI

class NetworkDelegateClass: NSObject, URLSessionDelegate, URLSessionDataDelegate {

    // URLSessionDataDelegate method to handle response data
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        // Process the received data
        print("Received data: \(data)")
    }

    // URLSessionDataDelegate method to handle completion
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            // Handle error
            print("Task completed with error: \(error)")
        } else {
            // Task completed successfully
            print("Task completed successfully")
        }
    }
}

@MainActor
struct ContentView: View {
    @State var folders: Array<URL> = Array<URL>()

    @State private var backendURL = "http://127.0.0.1:3002/upload"

    @State private var mimeTypes = [
        "md": "text/markdown",
        "txt": "text/plain"
    ]

    @State private var isImporting = false

    func clearFolders() {
        folders = []
    }
    
    struct UploadItem: Codable {
        var id = UUID()
        var filePath: String
        var mimeType: String
        var itemData: Data
    }
    
    func newRequest(url: URL, data: Data) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = data
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        return request
    }

    func uploadItem(path: String, mimeType: String, uploadData: Data) {
        do {
            let item = UploadItem(filePath: path, mimeType: mimeType, itemData: uploadData)
            let data = try JSONEncoder().encode(item)
            let url = URL(string: backendURL)!
            let delegateClass = NetworkDelegateClass()
            let delegateSession = URLSession(configuration: .default, delegate: delegateClass, delegateQueue: nil)
            let request = newRequest(url: url, data: data)
            let task = delegateSession.dataTask(with: request)

            task.resume()
        } catch {
            //
        }
    }
    
    func browseFolder(folder: URL) {
        let fm = FileManager.default

        do {
            // Folder
            let items = try fm.contentsOfDirectory(atPath: folder.path).filter { $0 != ".DS_Store" }

            for item in items {

                // File
                let itemPath = folder.path + "/" + item
                let attributes = try fm.attributesOfItem(atPath: itemPath)
                let fsFileType:String = attributes[FileAttributeKey.type] as! String

                if (fsFileType == "NSFileTypeRegular") {
                    do {
                        let fileData = try Data(contentsOf: URL(fileURLWithPath: itemPath))
                        let fileExt = URL(fileURLWithPath: itemPath).pathExtension
                        let mimeType = String(mimeTypes[fileExt]!)

                        uploadItem(
                            path: itemPath,
                            mimeType: mimeType,
                            uploadData: fileData
                        )
                    } catch {
                        print ("loading file error")
                    }

                } else if (fsFileType == "NSFileTypeDirectory") {
                    
                    // Subfolder
                    let subfolderItems = try fm.contentsOfDirectory(atPath: itemPath).filter { $0 != ".DS_Store" }

                    for subfolderItem in subfolderItems {
                        
                        // File
                        let subfolderItemPath = itemPath + "/" + subfolderItem
                        let subfolderItemAttributes = try fm.attributesOfItem(atPath: subfolderItemPath)
                        let subfolderFsFileType:String = subfolderItemAttributes[FileAttributeKey.type] as! String

                        if (subfolderFsFileType == "NSFileTypeRegular") {
                            do {
                                let subfolderFileData = try Data(contentsOf: URL(fileURLWithPath: subfolderItemPath))
                                let subfolderFileExt = URL(fileURLWithPath: subfolderItemPath).pathExtension
                                let subfolderMimeType = String(mimeTypes[subfolderFileExt]!)

                                uploadItem(
                                    path: subfolderItemPath,
                                    mimeType: subfolderMimeType,
                                    uploadData: subfolderFileData
                                )
                            } catch {
                                print ("loading file error")
                            }
                        }
                    }
                }
            }
        } catch {
            //
        }
    }
    func syncFolders() {
        for folder in folders {
            let fm = FileManager.default

            do {
                let attributes = try fm.attributesOfItem(
                    atPath: folder.path
                )
                let fsItemType:String = attributes[FileAttributeKey.type] as! String
                if (fsItemType == "NSFileTypeDirectory") {
                    browseFolder(folder: folder)
                    do {
                        folder.stopAccessingSecurityScopedResource()
                    }
                }
            } catch {
                //
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
