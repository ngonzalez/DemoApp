/*
    Copyright 2024,2025 Nicolas GONZALEZ

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

/* VideoPlayer */
import AVKit

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

    /* Media Player */
    @State private var player:AVPlayer = AVPlayer()

    @State private var isPlaying:Bool = false

    /* Uploads */
    @State private var uploadsWithFiles: Array<UploadWithFiles> = Array<UploadWithFiles>()

    /* Attachments */
    @State private var uploadImageFiles:Array<ImageFile> = Array<ImageFile>()

    @State private var uploadPdfFiles:Array<PdfFile> = Array<PdfFile>()

    @State private var uploadAudioFiles:Array<AudioFile> = Array<AudioFile>()

    @State private var uploadVideoFiles:Array<VideoFile> = Array<VideoFile>()

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

    @State private var videoFileSortOrder = [KeyPathComparator(\VideoFile.fileName)]

    @State private var videoFileSelection = Set<VideoFile.ID>()

    @State private var textFileSortOrder = [KeyPathComparator(\TextFile.fileName)]

    @State private var textFileSelection = Set<TextFile.ID>()

    @State private var folderSortOrder = [KeyPathComparator(\Folder.name)]

    @State private var folderSelection = Set<Folder.ID>()

    @State private var selectedImageFiles:Array<ImageFile> = Array<ImageFile>()

    @State private var selectedPdfFiles:Array<PdfFile> = Array<PdfFile>()

    @State private var selectedAudioFiles:Array<AudioFile> = Array<AudioFile>()

    @State private var selectedVideoFiles:Array<VideoFile> = Array<VideoFile>()

    @State private var selectedTextFiles:Array<TextFile> = Array<TextFile>()

    @State private var selectedFolders = Set<Folder.ID>()

    /* Upload Request  */
    @State private var backendURL:String = "https://link12.ddns.net:4040/upload"
//    @State private var backendURL:String = "http://127.0.0.1:3002/upload"

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
//        "mp4": "audio/mp4",

        /* AIFF */
        "aff": "audio/x-aiff",
        "aif": "audio/x-aiff",
        "aiff": "audio/x-aiff",

        /* WAV */
        "wav": "audio/wav",

        /* MKV */
        "mkv": "video/x-matroska",
        
        /* */
        "mp4": "video/mp4",
    ]

    @State private var isImporting:Bool = false

    struct UploadItem: Codable {
        var id: Int?
        var uuid:UUID = UUID()
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
            let task = delegateSession.uploadTask(withStreamedRequest: request)

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
        let dataUrl: String?
        let formattedName: String?
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

    struct VideoFile: Decodable, Identifiable {
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
        let videoFiles: Array<VideoFile>
    }

    @State var loadedFolders: Array<Folder> = Array<Folder>()

    func setUploads(results: Array<UploadWithFiles>) {
        self.uploadsWithFiles = results
        logger.log("[setUpload] Results count=\(results.count)")

        self.uploadImageFiles = []
        self.uploadPdfFiles = []
        self.uploadAudioFiles = []
        self.uploadVideoFiles = []
        self.uploadTextFiles = []
        self.loadedFolders = []

        for upload in self.uploadsWithFiles {
            self.uploadImageFiles += upload.imageFiles
            for imageFile in upload.imageFiles {
                if !self.loadedFolders.map { $0.id }.contains(imageFile.folder.id) {
                    self.loadedFolders.append(imageFile.folder)
                }
            }
            self.uploadPdfFiles += upload.pdfFiles
            for pdfFile in upload.pdfFiles {
                if !self.loadedFolders.map { $0.id }.contains(pdfFile.folder.id) {
                    self.loadedFolders.append(pdfFile.folder)
                }
            }
            self.uploadAudioFiles += upload.audioFiles
            for audioFile in upload.audioFiles {
                if !self.loadedFolders.map { $0.id }.contains(audioFile.folder.id) {
                    self.loadedFolders.append(audioFile.folder)
                }
            }
            self.uploadVideoFiles += upload.videoFiles
            for videoFile in upload.videoFiles {
                if !self.loadedFolders.map { $0.id }.contains(videoFile.folder.id) {
                    self.loadedFolders.append(videoFile.folder)
                }
            }
            self.uploadTextFiles += upload.textFiles
            for textFile in upload.textFiles {
                if !self.loadedFolders.map { $0.id }.contains(textFile.folder.id) {
                    self.loadedFolders.append(textFile.folder)
                }
            }
        }
    }

    func newGetRequest(url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        return request
    }
    
    func getUploadsRequest() -> URL {
        if (selectedFolders.count > 0) {
            var str:String = ""
            for folderId in selectedFolders {
                str += ",\(folderId)"
            }
            let strData:Data = str.data(using: .utf8)!
            let base64str:String = strData.base64EncodedString()
            return URL(string: "\(backendURL)" + "?folderIds=\(base64str)")!
        } else {
            return URL(string: "\(backendURL)")!
        }
    }

    func getUploads() {
        do {
            let delegateClass = NetworkDelegateClass()
            let delegateSession = URLSession(configuration: .default, delegate: delegateClass, delegateQueue: nil)
            let request = newGetRequest(url: getUploadsRequest())
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
        let id:Int?
        let uuid:UUID = UUID()
        let firstName: String?
        let lastName: String?
        let emailAddress: String?
        let password: String?
        let createdAt: String?
        let updatedAt: String?
        let errors: [String]?
    }

    @State var identified:Bool = Bool(false)

    @State private var signedInUser: User?

    @State private var userName: String = String()

    @State private var password: String = String()

    @State private var firstName: String = String()

    @State private var lastName: String = String()

    @State private var registrationURL:String = "https://link12.ddns.net:4040/registration"
//    @State private var registrationURL:String = "http://127.0.0.1:3002/registration"

    @State private var sessionURL:String = "https://link12.ddns.net:4040/session"
//    @State private var sessionURL:String = "http://127.0.0.1:3002/session"

    func submitRegistrationForm() {
        do {
            let item = User(
                id: nil,
                firstName: firstName,
                lastName: lastName,
                emailAddress: userName,
                password: password,
                createdAt: nil,
                updatedAt: nil,
                errors: nil
            )

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
                    self.signedInUser = response
                    self.identified = ((self.signedInUser?.createdAt) != nil)
                    getUploads()
                } catch let error {
                    logger.error("[submitRegistrationForm] Request: \(error)")
                }
            }

            task.resume()

        } catch let error {
            logger.error("[submitRegistrationForm] Error: \(error)")
        }
    }

    func submitSessionForm() {
        do {
            let item = User(
                id: nil,
                firstName: nil,
                lastName: nil,
                emailAddress: userName,
                password: password,
                createdAt: nil,
                updatedAt: nil,
                errors: nil
            )

            let data = try JSONEncoder().encode(item)
            let url = URL(string: "\(sessionURL)")!
            let delegateClass = NetworkDelegateClass()
            let delegateSession = URLSession(configuration: .default, delegate: delegateClass, delegateQueue: nil)
            let optimizedData: Data = try! data.gzipped(level: .bestCompression)
            let postLength = String(format: "%lu", UInt(optimizedData.count))
            let request = newPostRequest(url: url, data: optimizedData, postLength: postLength)
            let task = delegateSession.dataTask(with: request) { data, response, error in
                do {
                    let response = try JSONDecoder().decode(User.self, from: data!)
                    self.signedInUser = response
                    self.identified = ((self.signedInUser?.createdAt) != nil)
                    getUploads()
                } catch let error {
                    logger.error("[submitSessionForm] Request: \(error)")
                }
            }

            task.resume()

        } catch let error {
            logger.error("[submitSessionForm] Error: \(error)")
        }
    }

    struct Message: Codable {
        let message: String?
    }

    func newDeleteRequest(url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        return request
    }

    func submitDestroySessionForm() {
        do {
            let data = try JSONEncoder().encode("{}")
            let url = URL(string: "\(sessionURL)")!
            let delegateClass = NetworkDelegateClass()
            let delegateSession = URLSession(configuration: .default, delegate: delegateClass, delegateQueue: nil)
            let optimizedData: Data = try! data.gzipped(level: .bestCompression)
            let postLength = String(format: "%lu", UInt(optimizedData.count))
            let request = newDeleteRequest(url: url)
            let task = delegateSession.dataTask(with: request) { data, response, error in
                do {
                    let response = try JSONDecoder().decode(Message.self, from: data!)
                    self.signedInUser = nil
                    self.identified = false
                } catch let error {
                    logger.error("[submitDestroySessionForm] Request: \(error)")
                }
            }

            task.resume()

        } catch let error {
            logger.error("[submitDestroySessionForm] Error: \(error)")
        }
    }

    /* Navigation */
    enum SideBarItem: String, Identifiable, CaseIterable {
        var id: String { rawValue }

        case signin
        case signup
        case upload
    }

    @State var selectedSideBarItem: SideBarItem = .upload

    @State private var visibility: NavigationSplitViewVisibility = .detailOnly

    func clearSelectedFiles() {
        self.selectedImageFiles = []
        self.selectedPdfFiles = []
        self.selectedAudioFiles = []
        self.selectedVideoFiles = []
        self.selectedTextFiles = []
    }

    func clearSelection() {
        self.folderSelection = Set()
        self.audioFileSelection = Set()
        self.videoFileSelection = Set()
        self.imageFileSelection = Set()
        self.pdfFileSelection = Set()
        self.textFileSelection = Set()
    }

    func clearSelectedFolders() {
        clearSelectedFiles()
        clearSelection()
    }

    func getFolderName(folder: Folder) -> String {
        var folderNames:[String] = []
        folderNames += [folder.name]
        if folder.folder != nil && (folder.folder != folder.name) {
            folderNames += [folder.folder!]
        }
        if folder.subfolder != nil {
            folderNames += [folder.subfolder!]
        }
        return folderNames.joined(separator: ", ")
    }

    /* Media Player*/
    func initMediaPlayer(url: URL) {
        self.player = AVPlayer(url: url)
    }

    func pauseMediaPlayer() {
        do {
            if (self.player != nil) {
                self.player.pause()
            } else {
                self.player = AVPlayer()
            }
            print("pauseMediaPlayer")
        } catch {
            //
        }
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $visibility) {
            List(SideBarItem.allCases, selection: $selectedSideBarItem) { item in
                NavigationLink(
                    item.rawValue.localizedCapitalized,
                    value: item
                )
            }
        } content: {
            switch selectedSideBarItem {
            case .signin:
                if self.identified {
                    Text("\(self.signedInUser)")
                } else {
                    Form {
                        VStack {
                            TextField(text: $userName, prompt: Text("johnatan@apple.com")) {
                                Text("Email")
                            }
                            .disableAutocorrection(true)
                            SecureField(text: $password, prompt: Text("Required")) {
                                Text("Password")
                            }
                            .disableAutocorrection(true)
                            
                            Button(action: submitSessionForm) {
                                Text("Submit")
                            }.buttonStyle(PlainButtonStyle())
                        }
                        .textFieldStyle(.roundedBorder)
                    }.padding(20)
                }
            case .signup:
                if self.identified {
                    Text("\(self.signedInUser)")
                } else {
                    if self.signedInUser?.errors != nil {
                        Text("Errors \(self.signedInUser?.errors)")
                    }
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
                            
                            Button(action: submitRegistrationForm) {
                                Text("Submit")
                            }.buttonStyle(PlainButtonStyle())
                        }
                        .textFieldStyle(.roundedBorder)
                    }.padding(20)
                }
            case .upload:
                if !self.identified {
                    Text("You need to be identified. Please login.")
                } else {
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
                    .padding(5)
                    .navigationTitle("DemoApp (\(self.signedInUser?.emailAddress)")
                    .toolbar {
                        Button(action: getUploads) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 20))
                        }
                    }

                    Section {
                        Table(of: Folder.self,
                              selection: $folderSelection,
                              sortOrder: $folderSortOrder) {
                            TableColumn("name") { folder in
                                Label(folder.formattedName ?? "",
                                      systemImage: "folder")
                                .labelStyle(.titleAndIcon)
                                .font(.system(size: 11))
                            }
                        } rows: {
                            ForEach(loadedFolders) { folder in
                                TableRow(folder)
                            }
                        }
                        .onChange(of: folderSelection) { selectedIds in
                            self.selectedFolders = []
                            for selectedId in selectedIds {
                                loadedFolders.map { folder in
                                    if folder.id == selectedId {
                                        self.selectedFolders.insert(folder.id)
                                    }
                                }
                            }
                            pauseMediaPlayer()
                            clearSelectedFiles()
                            getUploads()
                        }.tableStyle(.inset(alternatesRowBackgrounds: false))
                            .frame(height: 250)
                    } header: {
                        Text("Folders")
                    }
                }
            }

            switch selectedSideBarItem {
            case .upload:
                if self.identified {
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
                                    TableColumn("fileName") { imageFile in
                                        Label(imageFile.fileName ?? "",
                                              systemImage: "document")
                                        .labelStyle(.titleAndIcon)
                                        .font(.system(size: 11))
                                    }
                                    TableColumn("fileUrl") { imageFile in
                                        Link(destination: URL(string: imageFile.fileUrl)!, label: {
                                            Image(systemName: "bubble.left")
                                            Text("Web")
                                                .font(.system(size: 11))
                                        })
                                    }
                                    TableColumn("mimeType") { imageFile in
                                        Label(imageFile.mimeType ?? "",
                                              systemImage: "document")
                                        .labelStyle(.titleAndIcon)
                                        .font(.system(size: 11))
                                    }
                                } rows: {
                                    ForEach(uploadImageFiles) { imageFile in
                                        TableRow(imageFile)
                                    }
                                }
                            } header: {
                                Text("Image")
                            }
                        }.tableStyle(.inset(alternatesRowBackgrounds: false))
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
                                Text("Image (\(uploadImageFiles.count))")
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
                                    TableColumn("fileName") { pdfFile in
                                        Label(pdfFile.fileName ?? "",
                                              systemImage: "document")
                                        .labelStyle(.titleAndIcon)
                                        .font(.system(size: 11))
                                    }
                                    TableColumn("fileUrl") { pdfFile in
                                        Link(destination: URL(string: pdfFile.fileUrl)!, label: {
                                            Image(systemName: "bubble.left")
                                            Text("Web")
                                                .font(.system(size: 11))
                                        })
                                    }
                                    TableColumn("mimeType") { pdfFile in
                                        Label(pdfFile.mimeType ?? "",
                                              systemImage: "document")
                                        .labelStyle(.titleAndIcon)
                                        .font(.system(size: 11))
                                    }
                                } rows: {
                                    ForEach(uploadPdfFiles) { pdfFile in
                                        TableRow(pdfFile)
                                    }
                                }
                            } header: {
                                Text("Pdf")
                            }
                        }.tableStyle(.inset(alternatesRowBackgrounds: false))
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
                                    TableColumn("fileName") { audioFile in
                                        Label(audioFile.fileName ?? "",
                                              systemImage: "document")
                                        .labelStyle(.titleAndIcon)
                                        .font(.system(size: 11))
                                    }
                                    TableColumn("fileUrl") { audioFile in
                                        Link(destination: URL(string: audioFile.fileUrl)!, label: {
                                            Image(systemName: "bubble.left")
                                            Text("Web")
                                                .font(.system(size: 11))
                                        })
                                    }
                                    TableColumn("mimeType") { audioFile in
                                        Label(audioFile.mimeType ?? "",
                                              systemImage: "document")
                                        .labelStyle(.titleAndIcon)
                                        .font(.system(size: 11))
                                    }
                                } rows: {
                                    ForEach(uploadAudioFiles) { audioFile in
                                        TableRow(audioFile)
                                    }
                                }
                            } header: {
                                Text("Audio")
                            }
                        }.tableStyle(.inset(alternatesRowBackgrounds: false))
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
                                Text("Audio (\(uploadAudioFiles.count))")
                            }
                        
                        VStack {
                            Section {
                                /* VideoFiles */
                                Table(of: VideoFile.self,
                                      selection: $videoFileSelection,
                                      sortOrder: $videoFileSortOrder) {
                                    TableColumn("id") { videoFile in
                                        Text("\(videoFile.id)")
                                    }
                                    TableColumn("fileName") { videoFile in
                                        Label(videoFile.fileName ?? "",
                                              systemImage: "document")
                                        .labelStyle(.titleAndIcon)
                                        .font(.system(size: 11))
                                    }
                                    TableColumn("fileUrl") { videoFile in
                                        Link(destination: URL(string: videoFile.fileUrl)!, label: {
                                            Image(systemName: "bubble.left")
                                            Text("Web")
                                                .font(.system(size: 11))
                                        })
                                    }
                                    TableColumn("mimeType") { videoFile in
                                        Label(videoFile.mimeType ?? "",
                                              systemImage: "document")
                                        .labelStyle(.titleAndIcon)
                                        .font(.system(size: 11))
                                    }
                                } rows: {
                                    ForEach(uploadVideoFiles) { videoFile in
                                        TableRow(videoFile)
                                    }
                                }
                            } header: {
                                Text("Video")
                            }
                        }.tableStyle(.inset(alternatesRowBackgrounds: false))
                            .onChange(of: videoFileSelection) { selectedIds in
                                self.selectedVideoFiles = []
                                for selectedId in selectedIds {
                                    uploadVideoFiles.map { videoFile in
                                        let url = URL(string: "https://link12.ddns.net:5050/hls/video-\(videoFile.id).m3u8")!
                                        pauseMediaPlayer()
                                        initMediaPlayer(url: url)
                                        if videoFile.id == selectedId {
                                            self.selectedVideoFiles.append(videoFile)
                                        }
                                    }
                                }
                            }
                            .onChange(of: videoFileSortOrder) { order in
                                uploadVideoFiles.sort(using: order)
                            }
                            .tabItem {
                                Text("Video (\(uploadVideoFiles.count))").colorMultiply(.cyan)
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
                                    TableColumn("fileName") { textFile in
                                        Label(textFile.fileName ?? "",
                                              systemImage: "document")
                                        .labelStyle(.titleAndIcon)
                                        .font(.system(size: 11))
                                    }
                                    TableColumn("fileUrl") { textFile in
                                        Link(destination: URL(string: textFile.fileUrl)!, label: {
                                            Image(systemName: "bubble.left")
                                            Text("Web")
                                                .font(.system(size: 11))
                                        })
                                    }
                                    TableColumn("mimeType") { textFile in
                                        Label(textFile.mimeType ?? "",
                                              systemImage: "document")
                                        .labelStyle(.titleAndIcon)
                                        .font(.system(size: 11))
                                    }
                                } rows: {
                                    ForEach(uploadTextFiles) { textFile in
                                        TableRow(textFile)
                                    }
                                }
                            } header: {
                                Text("Text")
                            }
                        }.tableStyle(.inset(alternatesRowBackgrounds: false))
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
                                Text("Text (\(uploadTextFiles.count))")
                            }
                    }
                    .padding(.horizontal, 5)
                }
            case .signin, .signup:
                if self.identified {
                    Text("\(self.signedInUser?.emailAddress)")
                    Divider()
                    Button(action: submitDestroySessionForm) {
                        Image(systemName: "xmark")
                            .font(.system(size: 15))
                    }
                }
            }
        } detail: {

            HStack {
                VStack {
                    List {
                       ForEach(self.selectedImageFiles) { imageFile in
                           Label(imageFile.fileName,
                                 systemImage: "photo.circle")
                               .labelStyle(.titleAndIcon)
                               .font(.system(size: 11))
                           AsyncImage(url: URL(string: imageFile.fileUrl)) { result in
                               result.image?
                                   .resizable()
                                   .scaledToFill()
                           }
                           .frame(width: 400)
                        }
                        ForEach(self.selectedPdfFiles) { pdfFile in
                            Label(pdfFile.fileName,
                                  systemImage: "doc.circle.fill")
                                .labelStyle(.titleAndIcon)
                                .font(.system(size: 15))
                         }
                        ForEach(self.selectedAudioFiles) { audioFile in
                            Label(audioFile.fileName,
                                  systemImage: "waveform.circle")
                                .labelStyle(.titleAndIcon)
                                .font(.system(size: 15))
                         }
                        ForEach(self.selectedVideoFiles) { videoFile in
                            Label(videoFile.fileName,
                                  systemImage: "video.circle")
                                .labelStyle(.titleAndIcon)
                                .font(.system(size: 15))
                            VideoPlayer(player: player)
                                .frame(width: 400, height: 300)
                        }
                        ForEach(self.selectedTextFiles) { textFile in
                            Label(textFile.fileName,
                                  systemImage: "doc.circle")
                                .labelStyle(.titleAndIcon)
                                .font(.system(size: 15))
                         }
                    }
                }
            }
            .padding(.horizontal, 5)

        }.navigationSplitViewStyle(.prominentDetail)
    }
}

#Preview {
    ContentView()
}
