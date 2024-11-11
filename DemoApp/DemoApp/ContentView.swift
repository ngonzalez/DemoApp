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

/* GzipSwift */
import Gzip

/* Logger */
import OSLog

var logger = Logger()

class NetworkDelegateClass: NSObject, URLSessionDelegate, URLSessionDataDelegate {
    // URLSessionDataDelegate method to handle response data
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        // Process the received data
        logger.info("Successfully completed request")
    }

    // URLSessionDataDelegate method to handle completion
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            // Handle error
            logger.info("Task completed with error: \(error)")
        } else {
            // Task completed successfully
            logger.error("Task completed successfully")
        }
    }
}

@MainActor
struct ContentView: View {

    /* Uploads */
    @State private var uploadsResponses: Array<UploadResponse> = Array<UploadResponse>()

    @State private var uploadsWithFiles: Array<UploadWithFiles> = Array<UploadWithFiles>()

    /* Attachments */
    @State private var uploadImageFiles:Array<ImageFile> = Array<ImageFile>()

    @State private var uploadPdfFiles:Array<PdfFile> = Array<PdfFile>()

    @State private var uploadAudioFiles:Array<AudioFile> = Array<AudioFile>()

    @State private var uploadTextFiles:Array<TextFile> = Array<TextFile>()

    /* Folders  */
    @State private var folders: Array<URL> = Array<URL>()

    @State private var progress:Float = Float(0)

    /* Tables  */
    @State private var imageFileSortOrder = [KeyPathComparator(\ImageFile.fileName)]

    @State private var imageFileSelection = Set<ImageFile.ID>()

    @State private var pdfFileSortOrder = [KeyPathComparator(\PdfFile.fileName)]

    @State private var pdfFileSelection = Set<PdfFile.ID>()

    @State private var audioFileSortOrder = [KeyPathComparator(\AudioFile.fileName)]

    @State private var audioFileSelection = Set<AudioFile.ID>()

    @State private var textFileSortOrder = [KeyPathComparator(\TextFile.fileName)]

    @State private var textFileSelection = Set<TextFile.ID>()

    @State private var selectedImageFiles:Array<ImageFile> = Array<ImageFile>()

    @State private var selectedPdfFiles:Array<PdfFile> = Array<PdfFile>()

    @State private var selectedAudioFiles:Array<AudioFile> = Array<AudioFile>()

    @State private var selectedTextFiles:Array<TextFile> = Array<TextFile>()

    /* Upload Request  */
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

    @State private var backendURL:String = "http://127.0.0.1:3002/uploads"

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
                    logger.error("[uploadItem] Error \(error)")
                }
            }

            task.resume()

        } catch let error {
            logger.error("[uploadItem] Error: \(error)")
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
            logger.error("[importItem] Error \(error)")
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
            logger.error("[importFolder] Error: \(error)")
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
            logger.error("[browseFolder] Error: \(error)")
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
                logger.error("[syncFolders] Error: \(error)")
            }
        }
    }

    func clearFolders() {
        self.folders = []
        progress = Float(0)
    }

    struct Folder: Decodable, Identifiable {
        let id: Int
        let name: String
        let folder: String?
        let subfolder: String?
    }

    struct ImageFile: Decodable, Identifiable {
        let id: Int
        let folder: Folder
        let fileName: String
        let fileUrl: String
        let thumbUrl: String
        let dataUrl: String?
        let mimeType: String?
        let width: Int?
        let height: Int?
    }

    struct PdfFile: Decodable, Identifiable {
        let id: Int
        let folder: Folder
        let fileName: String
        let fileUrl: String
        let dataUrl: String?
        let mimeType: String?
    }

    struct TextFile: Decodable, Identifiable {
        let id: Int
        let folder: Folder
        let fileName: String
        let fileUrl: String
        let dataUrl: String?
        let mimeType: String?
    }

    struct AudioFile: Decodable, Identifiable {
        let id: Int
        let folder: Folder
        let fileName: String
        let fileUrl: String
        let dataUrl: String?
        let mimeType: String?
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

    func setUploads(results: Array<UploadWithFiles>) {
        self.uploadsWithFiles = results
        logger.log("[setUpload] Results count=\(results.count)")

        /* Attachments */
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
                    let response = try JSONDecoder().decode([UploadWithFiles].self, from: data!)
                    setUploads(results: response)
                } catch let error {
                    logger.error("[getUpload] Request: \(error)")
                }
            }

            task.resume()

        } catch let error {
            logger.error("[getUploads] Error: \(error)")
        }
    }

    /* Users */
    struct User: Codable, Identifiable {
        let id = UUID()
        let firstName: String?
        let lastName: String?
        let emailAddress: String?
    }

    @State private var userName: String = String()

    @State private var password: String = String()

    @State private var firstName: String = String()

    @State private var lastName: String = String()

    @State private var registrationURL:String = "http://127.0.0.1:3002/registration"

    func submitForm() {
        do {
            let item = User(firstName: firstName, lastName: lastName, emailAddress: userName)
            let data = try JSONEncoder().encode(item)
            let url = URL(string: "\(registrationURL)")!
            let delegateClass = NetworkDelegateClass()
            let delegateSession = URLSession(configuration: .default, delegate: delegateClass, delegateQueue: nil)
            let optimizedData: Data = try! data.gzipped(level: .bestCompression)
            let postLength = String(format: "%lu", UInt(optimizedData.count))
            let request = newPostRequest(url: url, data: optimizedData, postLength: postLength)
            let task = delegateSession.dataTask(with: request) { data, response, error in
                do {
                    let response = try JSONDecoder().decode(User.self, from: data!)
                    print(response)
                } catch let error {
                    logger.error("[submitForm] Request: \(error)")
                }
            }

            task.resume()

        } catch let error {
            logger.error("[submitForm] Error: \(error)")
        }
    }

    /* Navigation */
    enum SideBarItem: String, Identifiable, CaseIterable {
        var id: String { rawValue }

        case login
        case upload
    }

    @State var selectedSideBarItem: SideBarItem = .upload

    var body: some View {
        NavigationSplitView {
            List(SideBarItem.allCases, selection: $selectedSideBarItem) { item in
                NavigationLink(
                    item.rawValue.localizedCapitalized,
                    value: item
                )
            }
        } content : {
            switch selectedSideBarItem {
            case .upload:
                TabView {
                    VStack {
                        Section {
                            /* ImageFiles */
                            Table(of: ImageFile.self,
                                  selection: $imageFileSelection,
                                  sortOrder: $imageFileSortOrder) {
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
                                    if imageFile.mimeType != nil {
                                        Text(imageFile.mimeType!)
                                    }
                                }
                            } rows: {
                                ForEach(uploadImageFiles) { imageFile in
                                    TableRow(imageFile)
                                }
                            }
                        } header: {
                            Text("Images")
                        }
                    }
                     .onChange(of: imageFileSelection) { selectedIds in
                         self.selectedImageFiles = []
                         for selectedId in selectedIds {
                             uploadImageFiles.map { imageFile in
                                 if imageFile.id == selectedId {
                                     self.selectedImageFiles.append(imageFile)
                                 }
                             }
                         }
                     }
                    .onChange(of: imageFileSortOrder) { order in
                        withAnimation {
                            uploadImageFiles.sort(using: order)
                        }
                    }
                    .tabItem {
                        Text("Images (\(uploadImageFiles.count))")
                    }

                    VStack {
                        Section {
                            /* PdfFiles */
                            Table(of: PdfFile.self,
                                  selection: $pdfFileSelection,
                                  sortOrder: $pdfFileSortOrder) {
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
                                    if pdfFile.mimeType != nil {
                                        Text(pdfFile.mimeType!)
                                    }
                                }
                            } rows: {
                                ForEach(uploadPdfFiles) { pdfFile in
                                    TableRow(pdfFile)
                                }
                            }
                        } header: {
                            Text("Pdfs")
                        }
                    }
                     .onChange(of: pdfFileSelection) { selectedIds in
                         self.selectedPdfFiles = []
                         for selectedId in selectedIds {
                             uploadPdfFiles.map { pdfFile in
                                 if pdfFile.id == selectedId {
                                     self.selectedPdfFiles.append(pdfFile)
                                 }
                             }
                         }
                     }
                    .onChange(of: pdfFileSortOrder) { order in
                        uploadPdfFiles.sort(using: order)
                    }
                    .tabItem {
                        Text("Pdfs (\(uploadPdfFiles.count))")
                    }

                    VStack {
                        Section {
                            /* AudioFiles */
                            Table(of: AudioFile.self,
                                  selection: $audioFileSelection,
                                  sortOrder: $audioFileSortOrder) {
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
                                TableColumn("mimeType") { audioFile in
                                    if audioFile.mimeType != nil {
                                        Text(audioFile.mimeType!)
                                    }
                                }
                            } rows: {
                                ForEach(uploadAudioFiles) { audioFile in
                                    TableRow(audioFile)
                                }
                            }
                        } header: {
                            Text("Media")
                        }
                    }
                     .onChange(of: audioFileSelection) { selectedIds in
                         self.selectedAudioFiles = []
                         for selectedId in selectedIds {
                             uploadAudioFiles.map { audioFile in
                                 if audioFile.id == selectedId {
                                     self.selectedAudioFiles.append(audioFile)
                                 }
                             }
                         }
                     }
                    .onChange(of: audioFileSortOrder) { order in
                        uploadAudioFiles.sort(using: order)
                    }
                    .tabItem {
                        Text("Media (\(uploadAudioFiles.count))")
                    }

                    VStack {
                        Section {
                            /* TextFiles */
                            Table(of: TextFile.self,
                                  selection: $textFileSelection,
                                  sortOrder: $textFileSortOrder) {
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
                                TableColumn("mimeType") { textFile in
                                    if textFile.mimeType != nil {
                                        Text(textFile.mimeType!)
                                    }
                                }
                            } rows: {
                                ForEach(uploadTextFiles) { textFile in
                                    TableRow(textFile)
                                }
                            }
                        } header: {
                            Text("Documents")
                        }
                    }
                     .onChange(of: textFileSelection) { selectedIds in
                         self.selectedTextFiles = []
                         for selectedId in selectedIds {
                             uploadTextFiles.map { textFile in
                                 if textFile.id == selectedId {
                                     self.selectedTextFiles.append(textFile)
                                 }
                             }
                         }
                     }
                    .onChange(of: textFileSortOrder) { order in
                        uploadTextFiles.sort(using: order)
                    }
                    .tabItem {
                        Text("Documents (\(uploadTextFiles.count))")
                    }

                }.padding(10)

                HStack {
                    VStack {
                        /* Browse Button */
                        Button(action: syncFolders) {
                            let folderNames = folders.map { String($0.path().split(separator: "/").last!) }
                            Image(systemName: "arrow.down.square")
                            Text("Import \(folderNames.joined(separator: ", "))")
                            ProgressView(value: progress)
                        }
                    }
                    VStack {
                        /* Clear Button */
                        Button(action: clearFolders) {
                            Text("Clear")
                                .foregroundStyle(.blue.gradient)
                        }.buttonStyle(PlainButtonStyle())
                    }
                    VStack {
                        /* Import Button */
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
                                    logger.error("[fileImporter] Error: \(error)")
                                }
                            }
                        }
                    }
                }
                .padding(20)
                .navigationTitle("Demo App")
                .toolbar {
                    Button(action: getUploads) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 20))
                    }
                }
            case .login:
                Form {
                    VStack {
                        TextField(text: $firstName, prompt: Text("John")) {
                            Text("First Name")
                        }
                        .disableAutocorrection(true)
                        TextField(text: $lastName, prompt: Text("Appleseed")) {
                            Text("Last Name")
                        }
                        .disableAutocorrection(true)
                        TextField(text: $userName, prompt: Text("johnatan@apple.com")) {
                            Text("Email")
                        }
                        .disableAutocorrection(true)
                        SecureField(text: $password, prompt: Text("Required")) {
                            Text("Password")
                        }
                        .disableAutocorrection(true)

                        Button(action: submitForm) {
                            Text("Submit")
                        }.buttonStyle(PlainButtonStyle())
                    }
                    .textFieldStyle(.roundedBorder)
                }.padding(20)
            }

        } detail: {
            Text("\(self.selectedImageFiles)")
            Text("\(self.selectedPdfFiles)")
            Text("\(self.selectedAudioFiles)")
            Text("\(self.selectedTextFiles)")
        }
    }
}

#Preview {
    ContentView()
}
