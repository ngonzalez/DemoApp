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
//    @State private var backendURL:String = "https://appshare.site:4040/upload"
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

        /* MP4 */
        "mp4": "video/mp4",
    ]

    @State private var isImporting:Bool = false

    struct UploadItem: Codable {
        var id: Int?
        var uuid: UUID
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
                uuid: UUID(),
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
        let name: String
        let state: String
        let dataUrl: String
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
        let formatInfo: String?
        let fileSize: String?
        let width: Int?
        let height: Int?
        let dimensions: String?
        let megapixels: Float?
    }

    struct PdfFile: Decodable, Identifiable {
        let id: Int
        let folder: Folder
        let fileName: String
        let fileUrl: String
        let dataUrl: String?
        let mimeType: String?
        let formatInfo: String?
    }

    struct TextFile: Decodable, Identifiable {
        let id: Int
        let folder: Folder
        let fileName: String
        let fileUrl: String
        let dataUrl: String?
        let mimeType: String?
        let formatInfo: String?
    }

    struct AudioFile: Decodable, Identifiable {
        let id: Int
        let folder: Folder
        let fileName: String
        let fileUrl: String
        let aasmState: String
        let playlistUrl: String?
        let dataUrl: String?
        let mimeType: String?
        let formatInfo: String?
        let fileSize: Int?
        let title: String?
        let length: Float?
        let bitrate: Int?
        let channels: Int?
        let sampleRate: Int?
    }

    struct VideoFile: Decodable, Identifiable {
        let id: Int
        let folder: Folder
        let fileName: String
        let fileUrl: String
        let aasmState: String
        let playlistUrl: String?
        let dataUrl: String?
        let mimeType: String?
        let formatInfo: String?
        let fileSize: Int?
        let title: String?
        let length: Float?
        let bitrate: Int?
        let frameRate: Int?
        let width: Int?
        let height: Int?
        let aspectRatio: Int?
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
        logger.log("[setUploads] Results count=\(results.count)")

        self.uploadImageFiles = []
        self.uploadPdfFiles = []
        self.uploadAudioFiles = []
        self.uploadVideoFiles = []
        self.uploadTextFiles = []

        for upload in self.uploadsWithFiles {
            self.uploadImageFiles += upload.imageFiles
            for imageFile in upload.imageFiles {
                if self.loadedFolders.map({ $0.id }).contains(imageFile.folder.id) {
                    for i in 0..<self.loadedFolders.count {
                        let el = self.loadedFolders[i]
                        if (el.id == imageFile.folder.id) {
                            self.loadedFolders[i] = imageFile.folder
                        }
                    }
                } else {
                    self.loadedFolders.append(imageFile.folder)
                }
            }
            self.uploadPdfFiles += upload.pdfFiles
            for pdfFile in upload.pdfFiles {
                if self.loadedFolders.map({ $0.id }).contains(pdfFile.folder.id) {
                    for i in 0..<self.loadedFolders.count {
                        let el = self.loadedFolders[i]
                        if (el.id == pdfFile.folder.id) {
                            self.loadedFolders[i] = pdfFile.folder
                        }
                    }
                } else {
                    self.loadedFolders.append(pdfFile.folder)
                }
            }
            self.uploadAudioFiles += upload.audioFiles
            for audioFile in upload.audioFiles {
                if self.loadedFolders.map({ $0.id }).contains(audioFile.folder.id) {
                    for i in 0..<self.loadedFolders.count {
                        let el = self.loadedFolders[i]
                        if (el.id == audioFile.folder.id) {
                            self.loadedFolders[i] = audioFile.folder
                        }
                    }
                } else {
                    self.loadedFolders.append(audioFile.folder)
                }
                DispatchQueue.main.async {
                    getAudioStream(audioFile: audioFile)
                }
            }
            self.uploadVideoFiles += upload.videoFiles
            for videoFile in upload.videoFiles {
                if self.loadedFolders.map({ $0.id }).contains(videoFile.folder.id) {
                    for i in 0..<self.loadedFolders.count {
                        let el = self.loadedFolders[i]
                        if (el.id == videoFile.folder.id) {
                            self.loadedFolders[i] = videoFile.folder
                        }
                    }
                } else {
                    self.loadedFolders.append(videoFile.folder)
                }
                DispatchQueue.main.async {
                    getVideoStream(videoFile: videoFile)
                }
            }
            self.uploadTextFiles += upload.textFiles
            for textFile in upload.textFiles {
                if self.loadedFolders.map({ $0.id }).contains(textFile.folder.id) {
                    for i in 0..<self.loadedFolders.count {
                        let el = self.loadedFolders[i]
                        if (el.id == textFile.folder.id) {
                            self.loadedFolders[i] = textFile.folder
                        }
                    }
                } else {
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

    func getAllUploadsRequest() -> URL {
        if (loadedFolders.count > 0) {
            var str:String = ""
            for folderId in (loadedFolders.map { $0.id }) {
                str += ",\(folderId)"
            }
            let strData:Data = str.data(using: .utf8)!
            let base64str:String = strData.base64EncodedString()
            return URL(string: "\(backendURL)" + "?folderIds=\(base64str)")!
        } else {
            return URL(string: "\(backendURL)")!
        }
    }

    func getAllUploads() {
        let delegateClass = NetworkDelegateClass()
        let delegateSession = URLSession(configuration: .default, delegate: delegateClass, delegateQueue: nil)
        let request = newGetRequest(url: getAllUploadsRequest())
        let task = delegateSession.dataTask(with: request) { data, response, error in
            do {
                let response = try JSONDecoder().decode([UploadWithFiles].self, from: data!)
                DispatchQueue.main.async {
                    setUploads(results: response)
                }
            } catch let error {
                logger.error("[getAllUploads] Request: \(error)")
            }
        }

        task.resume()
    }

    func getSelectedUploadsRequest() -> URL {
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

    func getSelectedUploads() {
        let delegateClass = NetworkDelegateClass()
        let delegateSession = URLSession(configuration: .default, delegate: delegateClass, delegateQueue: nil)
        let request = newGetRequest(url: getSelectedUploadsRequest())
        let task = delegateSession.dataTask(with: request) { data, response, error in
            do {
                let response = try JSONDecoder().decode([UploadWithFiles].self, from: data!)
                DispatchQueue.main.async {
                    setUploads(results: response)
                }
            } catch let error {
                logger.error("[getSelectedUploads] Request: \(error)")
            }
        }

        task.resume()
    }

    /* Users */
    struct User: Codable, Identifiable {
        let id: Int?
        let uuid: UUID
        let firstName: String?
        let lastName: String?
        let emailAddress: String?
        let password: String?
        let createdAt: String?
        let updatedAt: String?
        let errors: [String]?
    }

    @State var identified:Bool = Bool(false)

    @State var newAccount:Bool = Bool(false)

    @State var newPassword:Bool = Bool(false)

    @State var validationErrors:String = String("")

    @State private var signedInUser: User?

    @State private var userName: String = String()

    @State private var password: String = String()

    @State private var firstName: String = String()

    @State private var lastName: String = String()

//    @State private var registrationURL:String = "https://appshare.site:4040/registration"
    @State private var registrationURL:String = "https://link12.ddns.net:4040/registration"
//    @State private var registrationURL:String = "http://127.0.0.1:3002/registration"

//    @State private var sessionURL:String = "https://appshare.site:4040/session"
    @State private var sessionURL:String = "https://link12.ddns.net:4040/session"
//    @State private var sessionURL:String = "http://127.0.0.1:3002/session"

//    @State private var passwordURL:String = "https://appshare.site:4040/password"
    @State private var passwordURL:String = "https://link12.ddns.net:4040/password"
//    @State private var passwordURL:String = "http://127.0.0.1:3002/password"

    func iterateOverErrors(errors: [String?]) {
        validationErrors = ""
        errors.forEach { error in
            validationErrors += "\n▫️\(error!)"
        }
    }

    func submitRegistrationForm() {
        do {
            let item = User(
                id: nil,
                uuid: UUID(),
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
                    if (self.signedInUser != nil) {
                        let errorsData = self.signedInUser?.errors as! [String]
                        iterateOverErrors(errors: errorsData)
                        self.identified = ((self.signedInUser?.createdAt) != nil)
                    }

                    DispatchQueue.main.async {
                        getAllUploads()
                    }

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
                uuid: UUID(),
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
                } catch let error {
                    logger.error("[submitSessionForm] Request: \(error)")
                }
                DispatchQueue.main.async {
                    getAllUploads()
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

    @State var destroySessionFormResponse:Message = Message(message: "")

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
                    let message = try JSONDecoder().decode(Message.self, from: data!)
                    self.destroySessionFormResponse = message
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

    @State var passwordFormResponse:Message = Message(message: "")

    func submitPasswordForm() {
        do {
            let item = User(
                id: nil,
                uuid: UUID(),
                firstName: nil,
                lastName: nil,
                emailAddress: userName,
                password: nil,
                createdAt: nil,
                updatedAt: nil,
                errors: nil
            )

            let data = try JSONEncoder().encode(item)
            let url = URL(string: "\(passwordURL)")!
            let delegateClass = NetworkDelegateClass()
            let delegateSession = URLSession(configuration: .default, delegate: delegateClass, delegateQueue: nil)
            let optimizedData: Data = try! data.gzipped(level: .bestCompression)
            let postLength = String(format: "%lu", UInt(optimizedData.count))
            let request = newPostRequest(url: url, data: optimizedData, postLength: postLength)
            let task = delegateSession.dataTask(with: request) { data, response, error in
                do {
                    let message = try JSONDecoder().decode(Message.self, from: data!)
                    self.passwordFormResponse = message
                } catch let error {
                    logger.error("[submitPasswordForm] Request: \(error)")
                }
            }

            task.resume()

        } catch let error {
            logger.error("[submitRegistrationForm] Error: \(error)")
        }
    }

    func clickRegisterLink() {
        self.newAccount = true
    }

    func clickPasswordLink() {
        self.newPassword = true
    }

    func clickSigninLink() {
        self.newAccount = false
        self.newPassword = false
    }

    /* Navigation */
    enum SideBarItem: String, Identifiable, CaseIterable {
        var id: String { rawValue }

        case account
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

    /* Streaming */
    struct Stream: Decodable, Identifiable {
        let id: Int
        let m3u8Exists:Bool
    }

    @State private var videoStreams:Array<Stream> = Array<Stream>()

    @State private var audioStreams:Array<Stream> = Array<Stream>()

//    @State private var serviceURL:String = "https://appshare.site:5050"
    @State private var serviceURL:String = "https://link12.ddns.net:5050"
//    @State private var serviceURL:String = "http://127.0.0.1:3001"

    func getVideoStream(videoFile: VideoFile) {
        do {
            let delegateClass = NetworkDelegateClass()
            let delegateSession = URLSession(configuration: .default, delegate: delegateClass, delegateQueue: nil)
            let url = URL(string: "\(serviceURL)/video_files/\(videoFile.id).json")!
            let request = newGetRequest(url: url)
            let task = delegateSession.dataTask(with: request) { data, response, error in
                do {
                    let response = try JSONDecoder().decode(Stream.self, from: data!)
                    if response.m3u8Exists == true {
                        if !self.videoStreams.map({ $0.id }).contains(videoFile.id) {
                            self.videoStreams.append(response)
                        }
                    }
                } catch let error {
                    logger.error("[getVideoStream] Request: \(error)")
                }
            }

            task.resume()
        } catch let error {
            logger.error("[getVideoStream] Error: \(error)")
        }
    }

    func getAudioStream(audioFile: AudioFile) {
        do {
            let delegateClass = NetworkDelegateClass()
            let delegateSession = URLSession(configuration: .default, delegate: delegateClass, delegateQueue: nil)
            let url = URL(string: "\(serviceURL)/audio_files/\(audioFile.id).json")!
            let request = newGetRequest(url: url)
            let task = delegateSession.dataTask(with: request) { data, response, error in
                do {
                    if (data != nil) {
                        let response = try JSONDecoder().decode(Stream.self, from: data!)
                        if response.m3u8Exists == true {
                            if !self.audioStreams.map { $0.id }.contains(audioFile.id) {
                                self.audioStreams.append(response)
                            }
                        }
                    }
                } catch let error {
                    logger.error("[getAudioStream] Request: \(error)")
                }
            }

            task.resume()

        } catch let error {
            logger.error("[getAudioStream] Error: \(error)")
        }
    }

    /* Media Player*/
    func initMediaPlayer(url: URL) {
        self.player = AVPlayer(url: url)
    }

    func pauseMediaPlayer() {
        self.player.pause()
    }

    func displayVideo(videoFile: VideoFile) {
        if self.videoStreams.map({ $0.id }).contains(videoFile.id) {
            let url = URL(string: "\(serviceURL)/playlists/video-\(videoFile.id).m3u8")!
            initMediaPlayer(url: url)
        }
    }

    func displayAudio(audioFile: AudioFile) {
        if self.audioStreams.map({ $0.id }).contains(audioFile.id) {
            let url = URL(string: "\(serviceURL)/playlists/audio-\(audioFile.id).m3u8")!
            initMediaPlayer(url: url)
        }
    }

    /* Text, Markdown */

    @State private var textContent:AttributedString = AttributedString()

    func displayText(textFile: TextFile) {
        do {
            let delegateClass = NetworkDelegateClass()
            let delegateSession = URLSession(configuration: .default, delegate: delegateClass, delegateQueue: nil)
            let request = newGetRequest(url: URL(string: "\(textFile.fileUrl)")!)
            let task = delegateSession.dataTask(with: request) { data, response, error in
                do {
                    self.textContent = try AttributedString(markdown: data!)
                } catch let error {
                    logger.error("[displayText] Request: \(error)")
                }
            }

            task.resume()
        } catch let error {
            logger.error("[displayText] Error: \(error)")
        }
    }

    /* Pdf */
//    @State private var pdfContent:PDFDocument = PDFDocument()
//
//    @State private var pdfView:PDFView = PDFView()

//    func displayPdf(pdfFile: PdfFile) {
//        do {
//            let delegateClass = NetworkDelegateClass()
//            let delegateSession = URLSession(configuration: .default, delegate: delegateClass, delegateQueue: nil)
//            let request = newGetRequest(url: URL(string: "\(pdfFile.fileUrl)")!)
//            let task = delegateSession.dataTask(with: request) { data, response, error in
//                do {
////                    self.pdfContent = PDFDocument(data: data!)!
////                    pdfView.document = self.pdfContent
//                } catch let error {
//                    logger.error("[displayText] Request: \(error)")
//                }
//            }
//
//            task.resume()
//
//        } catch let error {
//            logger.error("[displayText] Error: \(error)")
//        }
//    }

    func displayImageFileMimeType(imageFile: ImageFile) -> Text {
        Text("Mime/Type: \(imageFile.mimeType!)")
            .font(.system(size: 11))
    }

    struct FolderIds: Codable {
        var id: Array<Int>
    }

    @State private var publishURL:String = "https://link12.ddns.net:4040/publish"
    //    @State private var publishURL:String = "http://127.0.0.1:3002/publish"

    func publishSelectedFolders() {
        do {
            let item = FolderIds(id: self.selectedFolders.map { $0 })
            let data = try JSONEncoder().encode(item)
            let url = URL(string: "\(publishURL)")!
            let delegateClass = NetworkDelegateClass()
            let delegateSession = URLSession(configuration: .default, delegate: delegateClass, delegateQueue: nil)
            let optimizedData: Data = try! data.gzipped(level: .bestCompression)
            let postLength = String(format: "%lu", UInt(optimizedData.count))
            let request = newPostRequest(url: url, data: optimizedData, postLength: postLength)
            let task = delegateSession.dataTask(with: request) { data, response, error in
                DispatchQueue.main.async {
                    getSelectedUploads()
                }
            }

            task.resume()

        } catch let error {
            logger.error("[publishSelectedFolders] \(error)")
        }
    }

    @State private var unpublishURL:String = "https://link12.ddns.net:4040/unpublish"
    //    @State private var unpublishURL:String = "http://127.0.0.1:3002/unpublish"

    func unpublishSelectedFolders() {
        do {
            let item = FolderIds(id: self.selectedFolders.map { $0 })
            let data = try JSONEncoder().encode(item)
            let url = URL(string: "\(unpublishURL)")!
            let delegateClass = NetworkDelegateClass()
            let delegateSession = URLSession(configuration: .default, delegate: delegateClass, delegateQueue: nil)
            let optimizedData: Data = try! data.gzipped(level: .bestCompression)
            let postLength = String(format: "%lu", UInt(optimizedData.count))
            let request = newPostRequest(url: url, data: optimizedData, postLength: postLength)
            let task = delegateSession.dataTask(with: request) { data, response, error in
                DispatchQueue.main.async {
                    getSelectedUploads()
                }
            }

            task.resume()

        } catch let error {
            logger.error("[unpublishSelectedFolders] \(error)")
        }
    }

    func editAccount() {
        //
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
            case .account:
                if self.identified {

                    Image(systemName: "person.circle")
                        .font(.system(size: 20))
                        .symbolEffect(.bounce, options: .repeat(1))

                    Button(action: editAccount) {
                        Text("Edit account")
                            .foregroundStyle(.blue.gradient)
                    }.buttonStyle(PlainButtonStyle()).padding(10)

                } else if self.newPassword {

                    Form {
                        VStack {
                            Spacer()

                            if let message = self.passwordFormResponse.message {
                                Text("\(message)\n")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.gray)
                            }

                            TextField(text: $userName, prompt: Text("johnatan@apple.com")) {
                                Text("Email")
                            }
                            .disableAutocorrection(true)

                            Button(action: submitPasswordForm) {
                                Text("Submit")
                            }.buttonStyle(PlainButtonStyle())

                            Spacer()
                            Divider()

                            /* Signin */
                            Button(action: clickSigninLink) {
                                Image(systemName: "person.text.rectangle")
                                    .font(.system(size: 20))
                                Text("Back to Sign-In")
                                    .foregroundStyle(.blue.gradient)
                            }.buttonStyle(PlainButtonStyle())
                        }
                        .textFieldStyle(.roundedBorder)
                    }.padding(20)

                } else if self.newAccount {

                    Form {
                        VStack {

                            Spacer()

                            Text("\(validationErrors)\n")
                                .font(.system(size: 11))
                                .foregroundStyle(.gray)

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

                            Spacer()
                            Divider()

                            /* Signin */
                            Button(action: clickSigninLink) {
                                Image(systemName: "person.text.rectangle")
                                    .font(.system(size: 20))
                                Text("Back to Sign-In")
                                    .foregroundStyle(.blue.gradient)
                            }.buttonStyle(PlainButtonStyle())
                        }
                        .textFieldStyle(.roundedBorder)
                    }.padding(20)

                } else {

                    Form {
                        VStack {
                            Spacer()

                            if let message = self.destroySessionFormResponse.message {
                                Text("\(message)\n")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.gray)
                            }

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

                            /* Register */
                            Button(action: clickRegisterLink) {
                                Image(systemName: "person.crop.circle.badge.plus")
                                    .font(.system(size: 20))
                                    .symbolEffect(.bounce, options: .repeat(1))
                                Text("Register a new account")
                                    .foregroundStyle(.blue.gradient)
                            }.buttonStyle(PlainButtonStyle()).padding(10)

                            Spacer()

                            Divider()

                            /* Forgot Password */
                            Button(action: clickPasswordLink) {
                                Image(systemName: "mail")
                                    .font(.system(size: 20))
                                Text("Forgot your password?")
                                    .foregroundStyle(.blue.gradient)
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
                        Button(action: getSelectedUploads) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 20))
                        }
                    }

                    Section {
                        Table(of: Folder.self,
                              selection: $folderSelection,
                              sortOrder: $folderSortOrder) {
                            TableColumn("name") { folder in
                                Label("\(folder.name ?? "")",
                                      systemImage: "folder")
                                .foregroundStyle(.primary)
                                .labelStyle(.titleAndIcon)
                                .font(.system(size: 11))
                            }
                            TableColumn("state") { folder in
                                Label {
                                    Text("\(folder.state)" ?? "")
                                        .font(.system(size: 11))
                                        .foregroundStyle(folder.state == "published" ? .white : .gray)
                                } icon: {
                                    Rectangle()
                                        .fill(folder.state == "published" ? .yellow : .gray)
                                        .frame(width: 8, height: 8)
                                }
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
                            clearSelectedFiles()
                            getSelectedUploads()
                        }
                        .tableStyle(.inset(alternatesRowBackgrounds: false))
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

                                    TableColumn("fileName") { imageFile in
                                        Label((imageFile.fileName ?? ""), systemImage: "doc")
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
//                                        Label(imageFile.mimeType ?? "")
//                                            .labelStyle(.titleAndIcon)
//                                            .font(.system(size: 11))
                                    }
                                } rows: {
                                    ForEach(uploadImageFiles) { imageFile in
                                        TableRow(imageFile)
                                    }
                                }
                            } header: {
                                Text("Image")
                            }
                        }
                        .tableStyle(.inset(alternatesRowBackgrounds: false))
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

                                    TableColumn("fileName") { pdfFile in
                                        Label(pdfFile.fileName ?? "", systemImage: "document")
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
//                                        Label(pdfFile.mimeType ?? "")
//                                            .labelStyle(.titleAndIcon)
//                                            .font(.system(size: 11))
                                    }
                                } rows: {
                                    ForEach(uploadPdfFiles) { pdfFile in
                                        TableRow(pdfFile)
                                    }
                                }
                            } header: {
                                Text("Pdf")
                            }
                        }
                        .tableStyle(.inset(alternatesRowBackgrounds: false))
                        .onChange(of: pdfFileSelection) { selectedIds in
                            self.selectedPdfFiles = []
                            for selectedId in selectedIds {
                                uploadPdfFiles.map { pdfFile in
                                    if pdfFile.id == selectedId {
                                        self.selectedPdfFiles.append(pdfFile)
//                                        displayPdf(pdfFile: pdfFile)
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

                                    TableColumn("fileName") { audioFile in
                                        Label((audioFile.fileName ?? ""), systemImage: "doc")
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
//                                        Label(audioFile.mimeType ?? "")
//                                            .labelStyle(.titleAndIcon)
//                                            .font(.system(size: 11))
                                    }
                                } rows: {
                                    ForEach(uploadAudioFiles) { audioFile in
                                        TableRow(audioFile)
                                    }
                                }
                            } header: {
                                Text("Audio")
                            }
                        }
                        .tableStyle(.inset(alternatesRowBackgrounds: false))
                        .onChange(of: audioFileSelection) { selectedIds in
                            self.selectedAudioFiles = []
                            for selectedId in selectedIds {
                                uploadAudioFiles.map { audioFile in
                                    if audioFile.id == selectedId {
                                        self.selectedAudioFiles.append(audioFile)
                                        self.player = AVPlayer()
                                        displayAudio(audioFile: audioFile)
                                        DispatchQueue.main.async {
                                            getAudioStream(audioFile: audioFile)
                                        }
                                    }
                                }
                            }
                        }
                        .onChange(of: audioFileSelection) { selectedIds in
                            self.selectedAudioFiles = []
                            for selectedId in selectedIds {
                                uploadAudioFiles.map { audioFile in
                                    if audioFile.id == selectedId {
                                        self.selectedAudioFiles.append(audioFile)
                                        displayAudio(audioFile: audioFile)
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

                                    TableColumn("fileName") { videoFile in
                                        Label((videoFile.fileName ?? ""), systemImage: "doc")
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
//                                        Label(videoFile.mimeType ?? "")
//                                            .labelStyle(.titleAndIcon)
//                                            .font(.system(size: 11))
                                    }
                                } rows: {
                                    ForEach(uploadVideoFiles) { videoFile in
                                        TableRow(videoFile)
                                    }
                                }
                            } header: {
                                Text("Video")
                            }
                        }
                        .tableStyle(.inset(alternatesRowBackgrounds: false))
                        .onChange(of: videoFileSelection) { selectedIds in
                            self.selectedVideoFiles = []
                            for selectedId in selectedIds {
                                uploadVideoFiles.map { videoFile in
                                    if videoFile.id == selectedId {
                                        self.selectedVideoFiles.append(videoFile)
                                        displayVideo(videoFile: videoFile)
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

                                    TableColumn("fileName") { textFile in
                                        Label((textFile.fileName ?? ""), systemImage: "doc")
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
//                                        Label(textFile.mimeType ?? "")
//                                            .labelStyle(.titleAndIcon)
//                                            .font(.system(size: 11))
                                    }
                                } rows: {
                                    ForEach(uploadTextFiles) { textFile in
                                        TableRow(textFile)
                                    }
                                }
                            } header: {
                                Text("Text")
                            }
                        }
                        .tableStyle(.inset(alternatesRowBackgrounds: false))
                        .onChange(of: textFileSelection) { selectedIds in
                            self.selectedTextFiles = []
                            for selectedId in selectedIds {
                                uploadTextFiles.map { textFile in
                                    if textFile.id == selectedId {
                                        self.selectedTextFiles.append(textFile)
                                        displayText(textFile: textFile)
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
            case .account:
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

            if (selectedSideBarItem == .upload) {

                HStack {
                    VStack {
                        List {

                            // upload panel

                            if (self.selectedFolders.count > 0 &&
                                (self.selectedImageFiles.count == 0 &&
                                 self.selectedAudioFiles.count == 0 &&
                                 self.selectedPdfFiles.count == 0 &&
                                 self.selectedVideoFiles.count == 0 &&
                                 self.selectedTextFiles.count == 0)) {

                                Button(action: publishSelectedFolders) {
                                    Image(systemName: "newspaper")
                                        .font(.system(size: 9))
                                    Text("Publish \(self.selectedFolders.count) selected folders")
                                        .font(.system(size: 9))
                                        .foregroundStyle(Color.white)
                                }.buttonStyle(.bordered)

                                Button(action: unpublishSelectedFolders) {
                                    Image(systemName: "barcode")
                                        .font(.system(size: 9))
                                    Text("Unpublish \(self.selectedFolders.count) selected folders")
                                        .font(.system(size: 9))
                                        .foregroundStyle(Color.gray)
                                }.buttonStyle(.bordered)
                            }

                            ForEach(self.selectedImageFiles) { imageFile in
                                Label(imageFile.fileName,
                                     systemImage: "photo.circle")
                                   .labelStyle(.titleAndIcon)
                                   .font(.system(size: 13))

                                AsyncImage(url: URL(string: imageFile.fileUrl)) { result in
                                   result.image?
                                       .resizable()
                                       .scaledToFill()
                                }
                                .frame(maxWidth: .infinity, maxHeight: .infinity)

                                Label {
                                   Text("Mime/Type \(imageFile.mimeType ?? "--")")
                                       .font(.system(size: 11))
                                       .foregroundStyle(.gray)
                                } icon: {
                                   Rectangle()
                                       .fill(.gray)
                                       .frame(width: 8, height: 8)
                                }

                                Label {
                                   Text("Format \(imageFile.formatInfo ?? "--")")
                                       .font(.system(size: 11))
                                       .foregroundStyle(.gray)
                                } icon: {
                                   Rectangle()
                                       .fill(.gray)
                                       .frame(width: 8, height: 8)
                                }

                                Label {
                                   Text("Dimensions \(imageFile.dimensions ?? "--")")
                                       .font(.system(size: 11))
                                       .foregroundStyle(.gray)
                                } icon: {
                                   Rectangle()
                                       .fill(.gray)
                                       .frame(width: 8, height: 8)
                                }

                                Label {
                                   Text("Megapixels \(imageFile.megapixels ?? 0.1)")
                                       .font(.system(size: 11))
                                       .foregroundStyle(.gray)
                                } icon: {
                                   Rectangle()
                                       .fill(.gray)
                                       .frame(width: 8, height: 8)
                                }

                                Label {
                                   Text("Width \(imageFile.width ?? 0)")
                                       .font(.system(size: 11))
                                       .foregroundStyle(.gray)
                                } icon: {
                                   Rectangle()
                                       .fill(.gray)
                                       .frame(width: 8, height: 8)
                                }

                                Label {
                                   Text("Height \(imageFile.height ?? 0)")
                                       .font(.system(size: 11))
                                       .foregroundStyle(.gray)
                                } icon: {
                                   Rectangle()
                                       .fill(.gray)
                                       .frame(width: 8, height: 8)
                                }

                                Label {
                                   Text("File Size \(imageFile.fileSize ?? "")")
                                       .font(.system(size: 11))
                                       .foregroundStyle(.gray)
                                } icon: {
                                   Rectangle()
                                       .fill(.gray)
                                       .frame(width: 8, height: 8)
                                }

                                Spacer()
                            }

                            ForEach(self.selectedPdfFiles) { pdfFile in
                                Label(pdfFile.fileName,
                                      systemImage: "doc.circle.fill")
                                    .labelStyle(.titleAndIcon)
                                    .font(.system(size: 13))

                                Label {
                                    Text("Mime/Type \(pdfFile.mimeType ?? "--")")
                                        .font(.system(size: 11))
                                        .foregroundStyle(.gray)
                                } icon: {
                                    Rectangle()
                                        .fill(.gray)
                                        .frame(width: 8, height: 8)
                                }

                                Label {
                                    Text("Format \(pdfFile.formatInfo ?? "--")")
                                        .font(.system(size: 11))
                                        .foregroundStyle(.gray)
                                } icon: {
                                    Rectangle()
                                        .fill(.gray)
                                        .frame(width: 8, height: 8)
                                }

                                Spacer()
                            }

                            ForEach(self.selectedAudioFiles) { audioFile in
                                Label(audioFile.fileName,
                                      systemImage: "waveform.circle")
                                    .labelStyle(.titleAndIcon)
                                    .font(.system(size: 13))

                                if (audioFile.aasmState == "created") {
                                    Text("Processing…")
                                } else if (audioFile.aasmState == "processed") {
                                    VideoPlayer(player: player)
                                        .frame(minWidth: 400, maxWidth: .infinity,
                                               minHeight: 150, maxHeight: .infinity)
                                }

                                Label {
                                    Text("File Size \(audioFile.fileSize ?? 0)")
                                        .font(.system(size: 11))
                                        .foregroundStyle(.gray)
                                } icon: {
                                    Rectangle()
                                        .fill(.gray)
                                        .frame(width: 8, height: 8)
                                }

                                if (audioFile.title != "") {
                                    Label {
                                        Text("Title \(audioFile.title ?? "--")")
                                            .font(.system(size: 11))
                                            .foregroundStyle(.gray)
                                    } icon: {
                                        Rectangle()
                                            .fill(.gray)
                                            .frame(width: 8, height: 8)
                                    }
                                }

                                Label {
                                    Text("Mime/Type \(audioFile.mimeType ?? "--")")
                                        .font(.system(size: 11))
                                        .foregroundStyle(.gray)
                                } icon: {
                                    Rectangle()
                                        .fill(.gray)
                                        .frame(width: 8, height: 8)
                                }

                                Label {
                                    Text("Format \(audioFile.formatInfo ?? "--")")
                                        .font(.system(size: 11))
                                        .foregroundStyle(.gray)
                                } icon: {
                                    Rectangle()
                                        .fill(.gray)
                                        .frame(width: 8, height: 8)
                                }

                                Label {
                                    Text("Bitrate \(audioFile.bitrate ?? 0)")
                                        .font(.system(size: 11))
                                        .foregroundStyle(.gray)
                                } icon: {
                                    Rectangle()
                                        .fill(.gray)
                                        .frame(width: 8, height: 8)
                                }

                                Label {
                                    Text("Channels \(audioFile.channels ?? 0)")
                                        .font(.system(size: 11))
                                        .foregroundStyle(.gray)
                                } icon: {
                                    Rectangle()
                                        .fill(.gray)
                                        .frame(width: 8, height: 8)
                                }

                                Label {
                                    Text("Length (ms) \(audioFile.length ?? 0)")
                                        .font(.system(size: 11))
                                        .foregroundStyle(.gray)
                                } icon: {
                                    Rectangle()
                                        .fill(.gray)
                                        .frame(width: 8, height: 8)
                                }

                                Label {
                                    Text("Sample Rate \(audioFile.sampleRate ?? 0)")
                                        .font(.system(size: 11))
                                        .foregroundStyle(.gray)
                                } icon: {
                                    Rectangle()
                                        .fill(.gray)
                                        .frame(width: 8, height: 8)
                                }

                                Spacer()
                            }

                            ForEach(self.selectedVideoFiles) { videoFile in
                                Label(videoFile.fileName,
                                      systemImage: "video.circle")
                                    .labelStyle(.titleAndIcon)
                                    .font(.system(size: 13))

                                if (videoFile.aasmState == "created") {
                                    Text("Processing…")
                                } else if (videoFile.aasmState == "processed") {
                                    VideoPlayer(player: player)
                                        .frame(minWidth: 400, maxWidth: .infinity,
                                               minHeight: 300, maxHeight: .infinity)
                                }

                                Label {
                                    Text("File Size \(videoFile.fileSize ?? 0)")
                                        .font(.system(size: 11))
                                        .foregroundStyle(.gray)
                                } icon: {
                                    Rectangle()
                                        .fill(.gray)
                                        .frame(width: 8, height: 8)
                                }

                                if (videoFile.title != "") {
                                    Label {
                                        Text("Title \(videoFile.title ?? "--")")
                                            .font(.system(size: 11))
                                            .foregroundStyle(.gray)
                                    } icon: {
                                        Rectangle()
                                            .fill(.gray)
                                            .frame(width: 8, height: 8)
                                    }
                                }

                                Label {
                                    Text("Mime/Type \(videoFile.mimeType ?? "")")
                                        .font(.system(size: 11))
                                        .foregroundStyle(.gray)
                                } icon: {
                                    Rectangle()
                                        .fill(.gray)
                                        .frame(width: 8, height: 8)
                                }

                                Label {
                                    Text("Format \(videoFile.formatInfo ?? "")")
                                        .font(.system(size: 11))
                                        .foregroundStyle(.gray)
                                } icon: {
                                    Rectangle()
                                        .fill(.gray)
                                        .frame(width: 8, height: 8)
                                }

                                Label {
                                    Text("Bitrate \(videoFile.bitrate ?? 0)")
                                        .font(.system(size: 11))
                                        .foregroundStyle(.gray)
                                } icon: {
                                    Rectangle()
                                        .fill(.gray)
                                        .frame(width: 8, height: 8)
                                }

                                Label {
                                    Text("FrameRate \(videoFile.frameRate ?? 0)")
                                        .font(.system(size: 11))
                                        .foregroundStyle(.gray)
                                } icon: {
                                    Rectangle()
                                        .fill(.gray)
                                        .frame(width: 8, height: 8)
                                }

                                Label {
                                    Text("Length (s) \(videoFile.length ?? 0)")
                                        .font(.system(size: 11))
                                        .foregroundStyle(.gray)
                                } icon: {
                                    Rectangle()
                                        .fill(.gray)
                                        .frame(width: 8, height: 8)
                                }

                                Label {
                                    Text("Width \(videoFile.width ?? 0)")
                                        .font(.system(size: 11))
                                        .foregroundStyle(.gray)
                                } icon: {
                                    Rectangle()
                                        .fill(.gray)
                                        .frame(width: 8, height: 8)
                                }

                                Label {
                                    Text("Height \(videoFile.height ?? 0)")
                                        .font(.system(size: 11))
                                        .foregroundStyle(.gray)
                                } icon: {
                                    Rectangle()
                                        .fill(.gray)
                                        .frame(width: 8, height: 8)
                                }

                                Label {
                                    Text("Aspect Ratio: \(videoFile.aspectRatio ?? 0)")
                                        .font(.system(size: 11))
                                        .foregroundStyle(.gray)
                                } icon: {
                                    Rectangle()
                                        .fill(.gray)
                                        .frame(width: 8, height: 8)
                                }

                                Spacer()
                            }

                            ForEach(self.selectedTextFiles) { textFile in
                                Label(textFile.fileName,
                                      systemImage: "doc.circle")
                                    .labelStyle(.titleAndIcon)
                                    .font(.system(size: 13))

        //                            Text("""
        //                                \(textContent)
        //                                """)

                                Label {
                                    Text("Mime/Type \(textFile.mimeType ?? "")")
                                        .font(.system(size: 11))
                                        .foregroundStyle(.gray)
                                } icon: {
                                    Rectangle()
                                        .fill(.gray)
                                        .frame(width: 8, height: 8)
                                }

                                Label {
                                    Text("Format \(textFile.formatInfo ?? "")")
                                        .font(.system(size: 11))
                                        .foregroundStyle(.gray)
                                } icon: {
                                    Rectangle()
                                        .fill(.gray)
                                        .frame(width: 8, height: 8)
                                }

                                Spacer()
                            }

                            if (self.selectedImageFiles.count > 0 ||
                                self.selectedAudioFiles.count > 0 ||
                                self.selectedPdfFiles.count > 0 ||
                                self.selectedVideoFiles.count > 0 ||
                                self.selectedTextFiles.count > 0 ||
                                self.selectedFolders.count > 0) {

                                Button(action: clearSelection) {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 9))
                                        .foregroundStyle(Color.gray)
                                    Text("Clear selection")
                                        .font(.system(size: 9))
                                        .foregroundStyle(Color.gray)
                                }.buttonStyle(.bordered)
                            }
                        }.padding(20)
                    }
                }

            } else {

                // default login panel

            }
        }.navigationSplitViewStyle(.prominentDetail)
    }
}

#Preview {
    ContentView()
}
