/*
    Copyright 2024 Nicolas GONZALEZ

    MIT License

    Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated
    documentation files (the “Software”), to deal in the Software without restriction, including without limitation
    the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software,
    and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

    The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
    OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
    LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR
    IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

import SwiftUI
import Gzip

import OSLog

var logger = Logger()

class NetworkDelegateClass: NSObject, URLSessionDelegate, URLSessionDataDelegate {
    // URLSessionDataDelegate method to handle response data
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        // Process the received data
        do {
            print("Successfully completed request")
        } catch {
            print("Failed to parse response")
        }
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

    @State var uploadsResponses: Array<UploadResponse> = Array<UploadResponse>()

    @State var uploadsWithFiles: Array<UploadWithFiles> = Array<UploadWithFiles>()

    @State var uploadImageFiles:Array<ImageFile> = Array<ImageFile>()

    @State var uploadPdfFiles:Array<PdfFile> = Array<PdfFile>()

    @State var uploadAudioFiles:Array<AudioFile> = Array<AudioFile>()

    @State var uploadTextFiles:Array<TextFile> = Array<TextFile>()

    @State var folders: Array<URL> = Array<URL>()

    @State private var backendURL:String = "http://127.0.0.1:3002/uploads"

    @State private var progress:Float = Float(0)

    @State private var mimeTypes:[String:String] = [
        /* DOCUMENTS */
        "pdf": "application/pdf",
        "md": "text/markdown",
        "txt": "text/plain",

        /* JPEG */
        "jpg": "image/jpeg",
        "jpeg": "image/jpeg",

        /* FLAC */
        "flac": "audio/flac",

        /* MP3 */
        "mp3": "audio/mpeg",

        /* AAC MP4 ALAC  **/
        "aac": "audio/m4a",
        "m4a": "audio/x-m4a",
        "mp4": "audio/mp4",

        /* AIFF */
        "aff": "audio/x-aiff",
        "aif": "audio/x-aiff",
        "aiff": "audio/x-aiff",

        /* WAV */
        "wav": "audio/wav"
    ]

    @State private var isImporting:Bool = false

    struct UploadItem: Codable {
        var id = UUID()
        var filePath: String
        var mimeType: String
        var source: String
        var itemData: Data
        var createdAt: String
        var updatedAt: String
    }

    func newPostRequest(url: URL, data: Data, postLength: String) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = data
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(postLength, forHTTPHeaderField: "Content-Length")
        request.addValue("gzip, deflate", forHTTPHeaderField: "Content-Encoding")

        return request
    }

    struct UploadResponse: Decodable {
        let id: Int
        let uuid: UUID
    }

    func uploadItem(source: String, path: String, mimeType: String, uploadData: Data, createdAt: Date, updatedAt: Date) {

        do {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
            let createdAtFormatted = dateFormatter.string(from: createdAt)
            let updatedAtFormatted = dateFormatter.string(from: updatedAt)
            let item = UploadItem(
                filePath: path,
                mimeType: mimeType,
                source: source,
                itemData: uploadData,
                createdAt: createdAtFormatted,
                updatedAt: updatedAtFormatted
            )

            let data = try JSONEncoder().encode(item)
            let url = URL(string: backendURL)!
            let delegateClass = NetworkDelegateClass()
            let delegateSession = URLSession(configuration: .default, delegate: delegateClass, delegateQueue: nil)
            let optimizedData: Data = try! data.gzipped(level: .bestCompression)
            let postLength = String(format: "%lu", UInt(optimizedData.count))
            let request = newPostRequest(url: url, data: optimizedData, postLength: postLength)
            let task = delegateSession.dataTask(with: request) { data, response, error in
                do {
                    let upload = try JSONDecoder().decode(UploadResponse.self, from: data!)
                    logger.log("[uploadItem] Upload id=\(upload.id) uuid=\(upload.uuid)")
                    self.uploadsResponses.append(upload)
                } catch let error {
                    print(error)
                }
            }

            task.resume()

        } catch let error {
            print("[uploadItem] Error: \(error)")
        }

    }

    func importItem(itemPath: String, createdAt: Date, updatedAt: Date, source: String) {
        do {
            let fileData = try Data(contentsOf: URL(fileURLWithPath: itemPath))
            let fileExt = URL(fileURLWithPath: itemPath).pathExtension
            let allowedMimeTypes = mimeTypes.map { (key, value) in return key }

            if allowedMimeTypes.contains(fileExt) {
                let mimeType = String(mimeTypes[fileExt]!).lowercased()

                DispatchQueue.main.async {
                    uploadItem(
                        source: source,
                        path: itemPath,
                        mimeType: mimeType,
                        uploadData: fileData,
                        createdAt: createdAt,
                        updatedAt: updatedAt
                    )
                }
            }
        } catch let error {
            print ("[importItem] Error \(error)")
        }
    }

    func importFolder(folder: URL, item: String) {

        do {

          let fm = FileManager.default
          let folderAttributes = try fm.attributesOfItem(atPath: folder.path)
          let folderFsItemType:String = folderAttributes[FileAttributeKey.type] as! String

          if (folderFsItemType == "NSFileTypeDirectory") {

              // File
              let itemPath = folder.path + "/" + item
              let attributes = try fm.attributesOfItem(atPath: itemPath)
              let fsFileType:String = attributes[FileAttributeKey.type] as! String
              let itemCreatedAt:Date = attributes[FileAttributeKey.creationDate] as! Date
              let itemUpdatedAt:Date = attributes[FileAttributeKey.modificationDate] as! Date

              if (fsFileType == "NSFileTypeRegular") {

                  importItem(itemPath: itemPath, createdAt: itemCreatedAt, updatedAt: itemUpdatedAt, source: "root")

              } else if (fsFileType == "NSFileTypeDirectory") {

                  // Folder
                  let folderItems = try fm.contentsOfDirectory(atPath: itemPath).filter { $0 != ".DS_Store" }

                  for folderItem in folderItems {

                      // File
                      let folderItemPath = itemPath + "/" + folderItem
                      let folderItemAttributes = try fm.attributesOfItem(atPath: folderItemPath)
                      let folderFsFileType:String = folderItemAttributes[FileAttributeKey.type] as! String
                      let folderItemCreatedAt:Date = folderItemAttributes[FileAttributeKey.creationDate] as! Date
                      let folderItemUpdatedAt:Date = folderItemAttributes[FileAttributeKey.modificationDate] as! Date

                      if (folderFsFileType == "NSFileTypeRegular") {

                          importItem(itemPath: folderItemPath, createdAt: folderItemCreatedAt, updatedAt: folderItemUpdatedAt, source: "folder")

                      }

                      if (folderFsFileType == "NSFileTypeDirectory") {

                          // SubFolder
                          let subfolderItems = try fm.contentsOfDirectory(atPath: folderItemPath).filter { $0 != ".DS_Store" }

                          for subfolderItem in subfolderItems {

                              // File
                              let subfolderItemPath = folderItemPath + "/" + subfolderItem
                              let subfolderItemAttributes = try fm.attributesOfItem(atPath: subfolderItemPath)
                              let subfolderFsFileType:String = subfolderItemAttributes[FileAttributeKey.type] as! String
                              let subfolderItemCreatedAt:Date = subfolderItemAttributes[FileAttributeKey.creationDate] as! Date
                              let subfolderItemUpdatedAt:Date = subfolderItemAttributes[FileAttributeKey.modificationDate] as! Date

                              if (subfolderFsFileType == "NSFileTypeRegular") {

                                  importItem(itemPath: subfolderItemPath, createdAt: subfolderItemCreatedAt, updatedAt: subfolderItemUpdatedAt, source: "subfolder")

                              }
                          }
                      }
                  }
              }
          }

        } catch let error {
            print("[importFolder] Error: \(error)")
        }
    }

    func browseFolder(folder: URL) {
        let fm = FileManager.default

        do {
            let items = try fm.contentsOfDirectory(atPath: folder.path).filter { $0 != ".DS_Store" }

            for item in items {
                importFolder(folder: folder, item: item)
            }
        } catch let error {
            print("[browseFolder] Error: \(error)")
        }
    }

    func syncFolders() {
        var index = 0
        for folder in folders {

            // Set progress
            index += 1
            progress = Float(index / folders.count * 100)

            do {
                let attributes = try FileManager.default.attributesOfItem(atPath: folder.path)
                let fsItemType:String = attributes[FileAttributeKey.type] as! String
                if (fsItemType == "NSFileTypeDirectory") {

                    browseFolder(folder: folder)

                    do {
                        folder.stopAccessingSecurityScopedResource()
                    }
                }
            } catch {
                print("[syncFolders] Error: \(error)")
            }
        }
    }

    struct ImageFile: Decodable, Identifiable {
        let id: Int
        let dataUrl: String
        let fileName: String
        let fileUrl: String
        let thumbUrl: String
        let mimeType: String
    }

    struct PdfFile: Decodable, Identifiable {
        let id: Int
        let dataUrl: String
        let fileName: String
        let fileUrl: String
        let mimeType: String
    }

    struct TextFile: Decodable, Identifiable {
        let id: Int
        let dataUrl: String
        let fileName: String
        let fileUrl: String
        let mimeType: String
    }

    struct AudioFile: Decodable, Identifiable {
        let id: Int
        let dataUrl: String
        let fileName: String
        let fileUrl: String
        let mimeType: String
    }

    struct UploadWithFiles: Decodable, Identifiable {
        let id: Int
        let uuid: UUID
        let imageFiles: Array<ImageFile>
        let pdfFiles: Array<PdfFile>
        let textFiles: Array<TextFile>
        let audioFiles: Array<AudioFile>
    }

    struct UploadUuids: Codable {
        var uuids:Array<UUID> = Array<UUID>()
    }

    func setAttachments() {
        self.uploadImageFiles = []
        self.uploadPdfFiles = []
        self.uploadAudioFiles = []
        self.uploadTextFiles = []

        for upload in self.uploadsWithFiles {
            self.uploadImageFiles += upload.imageFiles
            self.uploadPdfFiles += upload.pdfFiles
            self.uploadAudioFiles += upload.audioFiles
            self.uploadTextFiles += upload.textFiles
        }
    }

    func getUploads() {
        do {
            let item = UploadUuids(uuids: uploadsResponses.map{ $0.uuid })
            let data = try JSONEncoder().encode(item)
            let url = URL(string: "\(backendURL)/list")!
            let delegateClass = NetworkDelegateClass()
            let delegateSession = URLSession(configuration: .default, delegate: delegateClass, delegateQueue: nil)
            let optimizedData: Data = try! data.gzipped(level: .bestCompression)
            let postLength = String(format: "%lu", UInt(optimizedData.count))
            let request = newPostRequest(url: url, data: optimizedData, postLength: postLength)
            let task = delegateSession.dataTask(with: request) { data, response, error in
                do {
                    let results = try JSONDecoder().decode([UploadWithFiles].self, from: data!)
                    logger.log("[getUploads] Results count=\(results.count)")
                    self.uploadsWithFiles = results
                    setAttachments()
                } catch let error {
                    print("[getUploads] Error: \(error)")
                }
            }

            task.resume()

        } catch let error {
            print("[getUploads] Error: \(error)")
        }
    }

    func refreshUploads() {
        getUploads()
    }

    func clearFolders() {
        self.folders = []
        progress = Float(0)
    }

    @Environment(\.openWindow) private var openWindow

    var body: some View {
        NavigationSplitView {
            //
            } content : {
            VStack {

                Button(action: refreshUploads) {
                     Image(systemName: "arrow.clockwise.square")
                         .font(.system(size: 20))
                 }

                Button(action: syncFolders) {
                    let folderNames = folders.map { String($0.path().split(separator: "/").last!) }
                    Text("Import \(folderNames.joined(separator: ", "))")
                    ProgressView(value: progress)
                }

                Button(action: clearFolders) {
                    Text("Clear folders")
                }

                Button(action: {
                    isImporting = true
                }) {
                    Image(systemName: "square.grid.3x1.folder.badge.plus")
                        .font(.system(size: 20))
                        .symbolEffect(.bounce, options: .repeat(1))
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
                        } catch let error {
                            print("[fileImporter] Error: \(error)")
                        }
                    }
                }

                /* ImageFiles */
                Table(of: ImageFile.self) {
                    TableColumn("id") { imageFile in
                        Text("\(imageFile.id)")
                    }
                    TableColumn("fileName", value: \.fileName)
                    TableColumn("fileUrl") { imageFile in
                        Link(destination: URL(string: imageFile.fileUrl)!, label: {
                            Image(systemName: "bubble.left")
                            Text("Web")
                        })
                    }
                    TableColumn("mimeType") { imageFile in
                        Text(imageFile.mimeType)
                    }
                    } rows: {
                    ForEach(uploadImageFiles) { imageFile in
                       TableRow(imageFile)
                    }
                }

                /* PdfFiles */
                Table(of: PdfFile.self) {
                    TableColumn("id") { pdfFile in
                        Text("\(pdfFile.id)")
                    }
                    TableColumn("fileName", value: \.fileName)
                    TableColumn("fileUrl") { pdfFile in
                        Link(destination: URL(string: pdfFile.fileUrl)!, label: {
                            Image(systemName: "bubble.left")
                            Text("Web")
                        })
                    }
                    TableColumn("mimeType") { pdfFile in
                        Text(pdfFile.mimeType)
                    }
                    } rows: {
                    ForEach(uploadPdfFiles) { pdfFile in
                       TableRow(pdfFile)
                    }
                }

                /* AudioFiles */
                Table(of: AudioFile.self) {
                    TableColumn("id") { audioFile in
                        Text("\(audioFile.id)")
                    }
                    TableColumn("fileName", value: \.fileName)
                    TableColumn("fileUrl") { audioFile in
                        Link(destination: URL(string: audioFile.fileUrl)!, label: {
                            Image(systemName: "bubble.left")
                            Text("Web")
                        })
                    }
                    TableColumn("mimeType") { pdfFile in
                        Text(pdfFile.mimeType)
                    }
                    } rows: {
                    ForEach(uploadAudioFiles) { audioFile in
                       TableRow(audioFile)
                    }
                }

                /* TextFiles */
                Table(of: TextFile.self) {
                    TableColumn("id") { textFile in
                        Text("\(textFile.id)")
                    }
                    TableColumn("fileName", value: \.fileName)
                    TableColumn("fileUrl") { textFile in
                        Link(destination: URL(string: textFile.fileUrl)!, label: {
                            Image(systemName: "bubble.left")
                            Text("Web")
                        })
                    }
                    TableColumn("mimeType") { pdfFile in
                        Text(pdfFile.mimeType)
                    }
                    } rows: {
                    ForEach(uploadTextFiles) { textFile in
                       TableRow(textFile)
                    }
                }

            }

        } detail: {
            ScrollView {
                VStack {
                    /* Details */
                    Text("uploadsResponses \(uploadsResponses.count)")
                    Text("uploadsWithFiles \(uploadsWithFiles.count)")
                    Text("uploadImageFiles \(uploadImageFiles.count)")
                    Text("uploadPdfFiles \(uploadPdfFiles.count)")
                    Text("uploadAudioFiles \(uploadAudioFiles.count)")
                    Text("uploadTextFiles \(uploadTextFiles.count)")
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
