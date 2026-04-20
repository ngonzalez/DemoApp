/*
    Copyright 2024,2025,2026 Nicolas GONZALEZ

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

/* SwiftUI */
import SwiftUI

/* VideoPlayer */
import AVKit

/* GzipSwift */
import Gzip

/* Zip */
import Zip

/* Logger */
import OSLog

var logger = Logger()

var formatter = ISO8601DateFormatter()

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

@available(macOS 14, *)
@MainActor
struct ContentView: View {

    @State private var searchText: String = ""

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

    /* Searchable */
    @State private var searchableImageFiles:Array<ImageFile> = Array<ImageFile>()

    @State private var searchablePdfFiles:Array<PdfFile> = Array<PdfFile>()

    @State private var searchableAudioFiles:Array<AudioFile> = Array<AudioFile>()

    @State private var searchableVideoFiles:Array<VideoFile> = Array<VideoFile>()

    @State private var searchableTextFiles:Array<TextFile> = Array<TextFile>()

    @State private var searchableFolders:Array<Folder> = Array<Folder>()

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

    @State private var mimeTypes:[String:String] = [
        /* DOCUMENTS */
        "pdf": "application/pdf",
        "md": "text/markdown",
        "txt": "text/plain",

        /* IMAGES */
        "bmp": "image/bmp",
        "gif": "image/gif",
        "jpg": "image/jpeg",
        "jpeg": "image/jpeg",
        "png": "image/png",
        "tif": "image/tiff",
        "tiff": "image/tiff",
        "webp": "image/webp",

        /* AUDIO */
        "aac": "audio/aac",
        "m4a": "audio/aac",
        "aff": "audio/x-aiff",
        "aif": "audio/x-aiff",
        "aiff": "audio/x-aiff",
        "flac": "audio/flac",
        "mka": "audio/x-matroska",
        "mp3": "audio/mpeg",
        "wav": "audio/wav",
        "weba": "audio/webm",

        /* VIDEO */
        "3gp": "video/3gpp",
        "mkv": "video/x-matroska",
        "mp4": "video/mp4",
        "mp4v": "video/mp4",
        "mpg4": "video/mp4",
        "m1v": "video/mpeg",
        "m2v": "video/mpeg",
        "mpg": "video/mpeg",
        "mpeg": "video/mpeg",
        "webm": "video/webm",
    ]

    @State private var isImporting:Bool = false

    struct UploadItem: Codable {
        var id: Int?
        var uuid: UUID
        var filePath: String
        var mimeType: String
        var source: String
        var uploadFileUuid: UUID?
        var itemData: Data
        var createdAt: String
        var updatedAt: String
    }

    func newUploadRequest(uuid: UUID, source: String, path: String, mimeType: String, uploadData: Data, uploadFileUuid: UUID?, createdAt: Date, updatedAt: Date) {
        do {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
            let createdAtFormatted = dateFormatter.string(from: createdAt)
            let updatedAtFormatted = dateFormatter.string(from: updatedAt)
            let uploadItem = UploadItem(
                uuid: uuid,
                filePath: path,
                mimeType: mimeType,
                source: source,
                uploadFileUuid: uploadFileUuid,
                itemData: uploadData,
                createdAt: createdAtFormatted,
                updatedAt: updatedAtFormatted
            )

            let data = try JSONEncoder().encode(uploadItem)
            let url = URL(string: backendURL)!
            let delegateClass = NetworkDelegateClass()
            let delegateSession = URLSession(configuration: .default, delegate: delegateClass, delegateQueue: nil)
            let optimizedData: Data = try! data.gzipped(level: .bestCompression)
            let postLength = String(format: "%lu", UInt(optimizedData.count))
            let request = newPostRequest(url: url, data: optimizedData, postLength: postLength)
            let task = delegateSession.uploadTask(withStreamedRequest: request)

            task.resume()

        } catch let error {
            logger.error("[newUploadRequest] Error: \(error)")
        }
    }

    func importItem(itemPath: String, createdAt: Date, updatedAt: Date, uuid: UUID, source: String) {
        do {
            let fileExt = URL(fileURLWithPath: itemPath).pathExtension
            let allowedMimeTypes = mimeTypes.map { (key, value) in return key }

            if allowedMimeTypes.contains(fileExt) {
               let mimeType = String(mimeTypes[fileExt]!).lowercased()
               let data = try Data(contentsOf: URL(fileURLWithPath: itemPath))
               let chunkSize = 104857600 // 100MB

               if (data.count > chunkSize) {
                   let zipFilePath = try Zip.quickZipFiles([URL(fileURLWithPath: itemPath)], fileName: "archive")

                   let tempDir = FileManager.default.temporaryDirectory
                   let tempFileURL = tempDir.appendingPathComponent("sample")

                   let chunker = FileChunker.init(input: zipFilePath, outputDirectory: tempFileURL, chunkSize: chunkSize)
                   let _ = try chunker.chunk()

                   let directoryContents = try
                      FileManager.default.contentsOfDirectory(at: tempFileURL,
                             includingPropertiesForKeys:[.contentModificationDateKey],
                             options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants])
                          .filter { $0.lastPathComponent.hasSuffix(".block") }
                          .sorted(by: {
                              let date0 = try $0.promisedItemResourceValues(forKeys:[.contentModificationDateKey]).contentModificationDate!
                              let date1 = try $1.promisedItemResourceValues(forKeys:[.contentModificationDateKey]).contentModificationDate!
                              return date0.compare(date1) == .orderedAscending
                           })

                   let FilePaths = directoryContents.map{ $0.path() }
                   var i = 0
                   let filesCount = FilePaths.count

                    for counter in 0..<filesCount {
                        let fileData = try Data(contentsOf: URL(fileURLWithPath: FilePaths[counter]))

                        newUploadRequest(
                            uuid: UUID(),
                            source: source,
                            path: "\(itemPath).\(i + 1)-\(filesCount).block",
                            mimeType: "application/octet-stream",
                            uploadData: fileData,
                            uploadFileUuid: uuid,
                            createdAt: createdAt,
                            updatedAt: updatedAt
                        )
                        i += 1
                    }

                    try FileManager.default.removeItem(at: tempFileURL)
                    try FileManager.default.removeItem(at: zipFilePath)

                    newUploadRequest(
                        uuid: uuid,
                        source: source,
                        path: itemPath,
                        mimeType: mimeType,
                        uploadData: Data(),
                        uploadFileUuid: nil,
                        createdAt: createdAt,
                        updatedAt: updatedAt
                    )

               } else {
                    let fileData = try Data(contentsOf: URL(fileURLWithPath: itemPath))

                    newUploadRequest(
                        uuid: UUID(),
                        source: source,
                        path: itemPath,
                        mimeType: mimeType,
                        uploadData: fileData,
                        uploadFileUuid: nil,
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
              let uuid = UUID()

              if (fsFileType == "NSFileTypeRegular") {

                  importItem(itemPath: itemPath, createdAt: itemCreatedAt, updatedAt: itemUpdatedAt, uuid: uuid, source: "root")

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
                      let uuid = UUID()

                      if (folderFsFileType == "NSFileTypeRegular") {

                          importItem(itemPath: folderItemPath, createdAt: folderItemCreatedAt, updatedAt: folderItemUpdatedAt, uuid: uuid, source: "folder")

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
                              let uuid = UUID()

                              if (subfolderFsFileType == "NSFileTypeRegular") {

                                  importItem(itemPath: subfolderItemPath, createdAt: subfolderItemCreatedAt, updatedAt: subfolderItemUpdatedAt, uuid: uuid, source: "subfolder")

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
        let webUrl: String
    }

    struct ImageFile: Decodable, Identifiable {
        let id: Int
        let folder: Folder
        let fileName: String
        let fileUrl: String
        let webUrl: String
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
        let webUrl: String
        let webViewUrl: String
        let dataUrl: String?
        let mimeType: String?
        let formatInfo: String?
        let fileSize: String?
    }

    struct TextFile: Decodable, Identifiable {
        let id: Int
        let folder: Folder
        let fileName: String
        let fileUrl: String
        let webUrl: String
        let webViewUrl: String
        let dataUrl: String?
        let mimeType: String?
        let formatInfo: String?
        let fileSize: String?
    }

    struct AudioFile: Decodable, Identifiable {
        let id: Int
        let folder: Folder
        let fileName: String
        let fileUrl: String
        let webUrl: String
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
        let webUrl: String
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
                if !self.loadedFolders.map({ $0.id }).contains(imageFile.folder.id) {
                    self.loadedFolders.append(imageFile.folder)
                }
            }
            self.uploadPdfFiles += upload.pdfFiles
            for pdfFile in upload.pdfFiles {
                if !self.loadedFolders.map({ $0.id }).contains(pdfFile.folder.id) {
                    self.loadedFolders.append(pdfFile.folder)
                }
            }
            self.uploadAudioFiles += upload.audioFiles
            for audioFile in upload.audioFiles {
                if !self.loadedFolders.map({ $0.id }).contains(audioFile.folder.id) {
                    self.loadedFolders.append(audioFile.folder)
                }
                DispatchQueue.main.async {
                    getAudioStream(audioFile: audioFile)
                }
            }
            self.uploadVideoFiles += upload.videoFiles
            for videoFile in upload.videoFiles {
                if !self.loadedFolders.map({ $0.id }).contains(videoFile.folder.id) {
                    self.loadedFolders.append(videoFile.folder)
                }
                DispatchQueue.main.async {
                    getVideoStream(videoFile: videoFile)
                }
            }
            self.uploadTextFiles += upload.textFiles
            for textFile in upload.textFiles {
                if !self.loadedFolders.map({ $0.id }).contains(textFile.folder.id) {
                    self.loadedFolders.append(textFile.folder)
                }
            }
        }
        if (loadedFolders.count > 0) {
            searchableFolders = loadedFolders.map { $0 }
        }
        if (uploadImageFiles.count > 0) {
            searchableImageFiles = uploadImageFiles.map { $0 }
        }
        if (uploadVideoFiles.count > 0) {
            searchableVideoFiles = uploadVideoFiles.map { $0 }
        }
        if (uploadAudioFiles.count > 0) {
            searchableAudioFiles = uploadAudioFiles.map { $0 }
        }
        if (uploadPdfFiles.count > 0) {
            searchablePdfFiles = uploadPdfFiles.map { $0 }
        }
        if (uploadTextFiles.count > 0) {
            searchableTextFiles = uploadTextFiles.map { $0 }
        }
    }

    func newGetRequest(url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        return request
    }

    func getAllUploads() {
        let delegateClass = NetworkDelegateClass()
        let delegateSession = URLSession(configuration: .default, delegate: delegateClass, delegateQueue: nil)
        let request = newGetRequest(url: URL(string: "\(backendURL)")!)
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

    /* Account */
    @State var myAccount:Bool = Bool(false)    // My Account

    @State private var signedInUser:UserWithAccount?
    @State private var identified:Bool = Bool(false)

    @State var newSession:Bool = Bool(true)             // New Session
    @State var newSessionComplete:Bool = Bool(false)

    @State var newPassword:Bool = Bool(false)           // New Password
    @State var newPasswordComplete:Bool = Bool(false)

    @State var newAccount:Bool = Bool(false)            // New Account
    @State var newAccountComplete:Bool = Bool(false)

    @State var editAccount:Bool = Bool(false)           // Edit Account
    @State var editAccountComplete:Bool = Bool(false)

    @State var editPassword:Bool = Bool(false)          // Edit Password
    @State var editPasswordComplete:Bool = Bool(false)

    @State var editEmailAddress:Bool = Bool(false)             // Edit Email
    @State var editEmailAddressComplete:Bool = Bool(false)

    /* New Session */
    @State var newSessionSuccessMessage:Message = Message(message: String())

    @State var newSessionValidationErrors:String = String()

    @State private var emailAddressSessionForm: String = String()

    @State private var passwordSessionForm: String = String()

    /* Destroy Session */
    @State var destroySessionFormResponse:Message = Message(message: String())

    /* New Account */
    @State var newAccountSuccessMessage:Message = Message(message: String())

    @State var newAccountValidationErrors:String = String()

    @State private var accountNameRegistrationForm: String = String()

    @State private var accountAddressRegistrationForm: String = String()

    @State private var firstNameRegistrationForm: String = String()

    @State private var lastNameRegistrationForm: String = String()

    @State private var emailAddressRegistrationForm: String = String()

    @State private var passwordRegistrationForm: String = String()

    /* Edit Account */
    @State var editAccountSuccessMessage:Message = Message(message: String())

    @State var editAccountValidationErrors:String = String()

    @State private var accountNameAccountForm: String = String()

    @State private var accountAddressAccountForm: String = String()

    @State private var firstNameAccountForm: String = String()

    @State private var lastNameAccountForm: String = String()

    @State private var emailAddressAccountForm: String = String()

    @State private var notifyOnSignInAccountForm: Bool = false

    @State private var notifyOnAccountUpdateAccountForm: Bool = false

    @State private var uuidAccountForm: String = String()

    @State private var createdAtAccountForm: String = String()

    @State private var updatedAtAccountForm: String = String()

    /* New Password */
    @State private var emailAddressPasswordForm: String = String()

    @State var newPasswordSuccessMessage:Message = Message(message: String())

    @State var newPasswordValidationErrors:String = String()

    /* Edit Password */
    @State var editPasswordSuccessMessage:Message = Message(message: String())

    @State private var newPasswordEditPasswordForm: String = String()

    @State private var newPasswordConfirmationEditPasswordForm: String = String()

    @State var editPasswordValidationErrors:String = String()

    /* Edit Email */
    @State var editEmailAddressSuccessMessage:Message = Message(message: String())

    @State private var emailAddressEditEmailAddressForm: String = String()

    @State private var newEmailAddressEditEmailAddressForm: String = String()

    @State var editEmailAddressValidationErrors:String = String()

    /*
        Backend URLs
     */

//    @State private var accountURL:String = "https://appshare.site:4040/account"
    @State private var accountURL:String = "https://link12.ddns.net:4040/account"
//    @State private var accountURL:String = "http://192.168.1.11:3000/account"

//    @State private var registrationURL:String = "https://appshare.site:4040/registration"
    @State private var registrationURL:String = "https://link12.ddns.net:4040/registration"
//    @State private var registrationURL:String = "http://192.168.1.11:3000/registration"

//    @State private var sessionURL:String = "https://appshare.site:4040/session"
    @State private var sessionURL:String = "https://link12.ddns.net:4040/session"
//    @State private var sessionURL:String = "http://192.168.1.11:3000/session"

//    @State private var passwordURL:String = "https://appshare.site:4040/password"
    @State private var passwordURL:String = "https://link12.ddns.net:4040/password"
//    @State private var passwordURL:String = "http://192.168.1.11:3000/password"

//    @State private var emailURL:String = "https://appshare.site:4040/email"
    @State private var emailURL:String = "https://link12.ddns.net:4040/email"
//    @State private var emailURL:String = "http://192.168.1.11:3000/email"

//    @State private var backendURL:String = "https://appshare.site:4040/upload"
    @State private var backendURL:String = "https://link12.ddns.net:4040/upload"
//    @State private var backendURL:String = "http://192.168.1.11:3000/upload"

//    @State private var foldersPublishURL:String = "https://appshare.site:4040/folders/publish"
    @State private var foldersPublishURL:String = "https://link12.ddns.net:4040/folders/publish"
//    @State private var foldersPublishURL:String = "http://192.168.1.11:3000/folders/publish"

//    @State private var foldersUnpublishURL:String = "https://appshare.site:4040/folders/unpublish"
    @State private var foldersUnpublishURL:String = "https://link12.ddns.net:4040/folders/unpublish"
//    @State private var foldersUnpublishURL:String = "http://192.168.1.11:3000/folders/unpublish"

//    @State private var foldersArchiveURL:String = "https://appshare.site:4040/folders/archive"
    @State private var foldersArchiveURL:String = "https://link12.ddns.net:4040/folders/archive"
//    @State private var foldersArchiveURL:String = "http://192.168.1.11:3000/folders/archive"

//    @State private var foldersUnarchiveURL:String = "https://appshare.site:4040/folders/unarchive"
    @State private var foldersUnarchiveURL:String = "https://link12.ddns.net:4040/folders/unarchive"
//    @State private var foldersUnarchiveURL:String = "http://192.168.1.11:3000/folders/unarchive"

//    @State private var foldersDeleteURL:String = "https://appshare.site:4040/folders/delete"
    @State private var foldersDeleteURL:String = "https://link12.ddns.net:4040/folders/delete"
//    @State private var foldersDeleteURL:String = "http://192.168.1.11:3000/folders/delete"

//    @State private var attachmentsDeleteURL:String = "https://appshare.site:4040/attachments/delete"
    @State private var attachmentsDeleteURL:String = "https://link12.ddns.net:4040/attachments/delete"
//    @State private var attachmentsDeleteURL:String = "http://192.168.1.11:3000/attachments/delete"

//    @State private var videoFilesServiceURL:String = "https://appshare.site:5050/video_files"
    @State private var videoFilesServiceURL:String = "https://link12.ddns.net:5050/video_files"
//    @State private var videoFilesServiceURL:String = "http://192.168.1.11:3001/video_files"

//    @State private var audioFilesServiceURL:String = "https://appshare.site:5050/audio_files"
    @State private var audioFilesServiceURL:String = "https://link12.ddns.net:5050/audio_files"
//    @State private var audioFilesServiceURL:String = "http://192.168.1.11:3001/audio_files"

//    @State private var playlistsServiceURL:String = "https://appshare.site:5050/playlists"
    @State private var playlistsServiceURL:String = "https://link12.ddns.net:5050/playlists"
//    @State private var playlistsServiceURL:String = "http://192.168.1.11:3001/playlists"

    /*
        Backend Requests
     */

    func newPutRequest(url: URL, data: Data, postLength: String) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.httpBody = data
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(postLength, forHTTPHeaderField: "Content-Length")

        return request
    }

    func newPostRequestWithContent(url: URL, data: Data, postLength: String) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = data
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(postLength, forHTTPHeaderField: "Content-Length")
        request.addValue("gzip, deflate", forHTTPHeaderField: "Content-Encoding")

        return request
    }

    func newPostRequest(url: URL, data: Data, postLength: String) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = data
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(postLength, forHTTPHeaderField: "Content-Length")

        return request
    }

    func newDeleteRequest(url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        return request
    }

    func newDeleteRequestWithContent(url: URL, data: Data, postLength: String) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.httpBody = data
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(postLength, forHTTPHeaderField: "Content-Length")
        request.addValue("gzip, deflate", forHTTPHeaderField: "Content-Encoding")

        return request
    }

    struct UserResponseWithMessage: Codable {
        let user: UserWithAccount?
        let message: String?
    }

    struct Message: Codable {
        let message: String?
    }

    func submitAccountForm() {
        do {
            let user = UserWithAccount(
                id: self.signedInUser?.id,
                accountUuid: self.signedInUser?.accountUuid,
                accountName: accountNameAccountForm,
                accountAddress: accountAddressAccountForm,
                firstName: firstNameAccountForm,
                lastName: lastNameAccountForm,
                emailAddress: emailAddressAccountForm,
                password: "",
                deliverNotificationsSignIn: notifyOnSignInAccountForm,
                deliverNotificationsAccountUpdate: notifyOnAccountUpdateAccountForm,
                createdAt: self.signedInUser?.createdAt,
                updatedAt: self.signedInUser?.updatedAt,
                errors: nil
            )

            let data = try JSONEncoder().encode(user)
            let url = URL(string: "\(accountURL)")!
            let delegateClass = NetworkDelegateClass()
            let delegateSession = URLSession(configuration: .default, delegate: delegateClass, delegateQueue: nil)
            let optimizedData: Data = try! data.gzipped(level: .bestCompression)
            let postLength = String(format: "%lu", UInt(optimizedData.count))
            let request = newPutRequest(url: url, data: optimizedData, postLength: postLength)
            let task = delegateSession.dataTask(with: request) { data, response, error in
                do {
                    let userResponseWithMessage = try JSONDecoder().decode(UserResponseWithMessage.self, from: data!)

                    DispatchQueue.main.async {

                        // validation errors
                        let httpResponse = response as? HTTPURLResponse
                        let httpResponseUnwrapped = httpResponse!

                        // validation errors
                        if (userResponseWithMessage.user != nil) {
                            let errorsData = userResponseWithMessage.user?.errors!
                            if (errorsData == [] && httpResponseUnwrapped.statusCode == 200) {
                                self.signedInUser = userResponseWithMessage.user
                                resetValuesEditAccount()
                            } else {
                                let errorsDataUnwrapped = errorsData!
                                iterateOverErrorsEditAccount(errors: errorsDataUnwrapped)
                            }
                        }

                        // validation message
                        if (userResponseWithMessage.message != nil) {
                            let message = Message(message: userResponseWithMessage.message)
                            self.editAccountSuccessMessage = message
                        }
                    }
                } catch let error {
                    logger.error("[submitAccountForm] Request: \(error)")
                }
            }

            task.resume()

        } catch let error {
            logger.error("[submitAccountForm] Error: \(error)")
        }
    }

    func iterateOverErrorsNewSession(errors: [String?]) {
        self.newSessionValidationErrors = String()
        errors.forEach { error in
            newSessionValidationErrors += "\n▫️\(error!)"
        }
    }

    func iterateOverErrorsEditAccount(errors: [String?]) {
        self.editAccountValidationErrors = String()
        errors.forEach { error in
            editAccountValidationErrors += "\n▫️\(error!)"
        }
    }

    func iterateOverErrorsNewAccount(errors: [String?]) {
        self.newAccountValidationErrors = String()
        errors.forEach { error in
            newAccountValidationErrors += "\n▫️\(error!)"
        }
    }

    func iterateOverErrorsNewPassword(errors: [String?]) {
        self.newPasswordValidationErrors = String()
        errors.forEach { error in
            newPasswordValidationErrors += "\n▫️\(error!)"
        }
    }

    func iterateOverErrorsEditPassword(errors: [String?]) {
        self.editPasswordValidationErrors = String()
        errors.forEach { error in
            editPasswordValidationErrors += "\n▫️\(error!)"
        }
    }

    func iterateOverErrorsEditEmailAddress(errors: [String?]) {
        self.editEmailAddressValidationErrors = String()
        errors.forEach { error in
            editEmailAddressValidationErrors += "\n▫️\(error!)"
        }
    }

    struct User: Codable, Identifiable {
        let id: Int?
        let firstName: String?
        let lastName: String?
        let emailAddress: String?
        let password: String?
        let deliverNotificationsSignIn: Bool?
        let deliverNotificationsAccountUpdate: Bool?
        let createdAt: String?
        let updatedAt: String?
        let errors: [String]?
    }

    struct UserWithAccount: Codable, Identifiable {
        let id: Int?
        let accountUuid: UUID?
        let accountName: String?
        let accountAddress: String?
        let firstName: String?
        let lastName: String?
        let emailAddress: String?
        let password: String?
        let deliverNotificationsSignIn: Bool?
        let deliverNotificationsAccountUpdate: Bool?
        let createdAt: String?
        let updatedAt: String?
        let errors: [String]?
    }

    func submitRegistrationForm() {
        do {
            let user = UserWithAccount(
                id: nil,
                accountUuid: UUID(),
                accountName: accountNameRegistrationForm,
                accountAddress: accountAddressRegistrationForm,
                firstName: firstNameRegistrationForm,
                lastName: lastNameRegistrationForm,
                emailAddress: emailAddressRegistrationForm,
                password: passwordRegistrationForm,
                deliverNotificationsSignIn: false,
                deliverNotificationsAccountUpdate: false,
                createdAt: nil,
                updatedAt: nil,
                errors: nil
            )

            let data = try JSONEncoder().encode(user)
            let url = URL(string: "\(registrationURL)")!
            let delegateClass = NetworkDelegateClass()
            let delegateSession = URLSession(configuration: .default, delegate: delegateClass, delegateQueue: nil)
            let optimizedData: Data = try! data.gzipped(level: .bestCompression)
            let postLength = String(format: "%lu", UInt(optimizedData.count))
            let request = newPostRequest(url: url, data: optimizedData, postLength: postLength)
            let task = delegateSession.dataTask(with: request) { data, response, error in
                do {
                    let userResponseWithMessage = try JSONDecoder().decode(UserResponseWithMessage.self, from: data!)
                    DispatchQueue.main.async {

                        // validation errors
                        let httpResponse = response as? HTTPURLResponse
                        let httpResponseUnwrapped = httpResponse!

                        // validation errors
                        if (userResponseWithMessage.user != nil) {
                            let errorsData = userResponseWithMessage.user?.errors!
                            if (errorsData == [] && httpResponseUnwrapped.statusCode == 200) {
                                resetValuesNewAccount()
                            } else {
                                let errorsDataUnwrapped = errorsData!
                                iterateOverErrorsNewAccount(errors: errorsDataUnwrapped)
                            }
                        }

                        // validation message
                        if (userResponseWithMessage.message != nil) {
                            let message = Message(message: userResponseWithMessage.message)
                            self.newAccountSuccessMessage = message
                        }
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

    struct UserWithEmailAddressAndPassword: Codable, Identifiable {
        let id: Int?
        let emailAddress: String?
        let password: String?
        let errors: [String]?
    }

    func submitSessionForm() {
        do {
            let user = UserWithEmailAddressAndPassword(
                id: nil,
                emailAddress: emailAddressSessionForm,
                password: passwordSessionForm,
                errors: nil
            )

            let data = try JSONEncoder().encode(user)
            let url = URL(string: "\(sessionURL)")!
            let delegateClass = NetworkDelegateClass()
            let delegateSession = URLSession(configuration: .default, delegate: delegateClass, delegateQueue: nil)
            let optimizedData: Data = try! data.gzipped(level: .bestCompression)
            let postLength = String(format: "%lu", UInt(optimizedData.count))
            let request = newPostRequest(url: url, data: optimizedData, postLength: postLength)
            let task = delegateSession.dataTask(with: request) { data, response, error in
                do {
                    let userResponseWithMessage = try JSONDecoder().decode(UserResponseWithMessage.self, from: data!)

                    DispatchQueue.main.async {

                        // validation errors
                        let httpResponse = response as? HTTPURLResponse
                        let httpResponseUnwrapped = httpResponse!

                        // validation errors
                        let errorsData = userResponseWithMessage.user?.errors!
                        if (errorsData == [] && httpResponseUnwrapped.statusCode == 200) {

                            // set current user
                            self.signedInUser = userResponseWithMessage.user
                            self.identified = (self.signedInUser?.createdAt != nil)

                            resetValuesNewSession()
                        } else if errorsData != nil {
                            let errorsDataUnwrapped = errorsData!
                            iterateOverErrorsNewSession(errors: errorsDataUnwrapped)
                        }

                        // validation message
                        if (userResponseWithMessage.message != nil) {
                            let message = Message(message: userResponseWithMessage.message)
                            logger.info("\(message.message!)")
                            self.newSessionSuccessMessage = message
                        }
                    }

                    DispatchQueue.main.async {
                        getAllUploads()
                    }

                } catch let error {
                    logger.error("[submitSessionForm] Request: \(error)")
                }
            }

            task.resume()

        } catch let error {
            logger.error("[submitSessionForm] Error: \(error)")
        }
    }

    func submitDestroySessionForm() {
        let url = URL(string: "\(sessionURL)")!
        let delegateClass = NetworkDelegateClass()
        let delegateSession = URLSession(configuration: .default, delegate: delegateClass, delegateQueue: nil)
        let request = newDeleteRequest(url: url)
        let task = delegateSession.dataTask(with: request) { data, response, error in
            do {
                let message = try JSONDecoder().decode(Message.self, from: data!)

                DispatchQueue.main.async {
                    let httpResponse = response as? HTTPURLResponse
                    let httpResponseUnwrapped = httpResponse!

                    if (httpResponseUnwrapped.statusCode == 200) {
                        self.destroySessionFormResponse = message
                        self.signedInUser = nil
                        self.identified = false
                        self.newSession = true
                        self.newSessionComplete = false

                        clearSelectedFolders()

                        self.loadedFolders = Array<Folder>()
                        self.selectedFolders = Set()
                    }
                }

            } catch let error {
                logger.error("[submitDestroySessionForm] Request: \(error)")
            }
        }

        task.resume()
    }

    struct UserWithEmailAddress: Codable, Identifiable {
        let id: Int?
        let emailAddress: String?
        let errors: [String]?
    }

    func submitNewPasswordForm() {
        do {
            let user = UserWithEmailAddress(
                id: nil,
                emailAddress: emailAddressPasswordForm,
                errors: nil
            )

            let data = try JSONEncoder().encode(user)
            let url = URL(string: "\(passwordURL)")!
            let delegateClass = NetworkDelegateClass()
            let delegateSession = URLSession(configuration: .default, delegate: delegateClass, delegateQueue: nil)
            let optimizedData: Data = try! data.gzipped(level: .bestCompression)
            let postLength = String(format: "%lu", UInt(optimizedData.count))
            let request = newPostRequest(url: url, data: optimizedData, postLength: postLength)
            let task = delegateSession.dataTask(with: request) { data, response, error in
                do {
                    let userResponseWithMessage = try JSONDecoder().decode(UserResponseWithMessage.self, from: data!)

                    DispatchQueue.main.async {

                        let httpResponse = response as? HTTPURLResponse
                        let httpResponseUnwrapped = httpResponse!

                        // validation errors
                        if (userResponseWithMessage.user != nil) {
                            if (httpResponseUnwrapped.statusCode == 200) {
                                resetValuesNewPassword()
                            }
                        }

                        // validation message
                        if (userResponseWithMessage.message != nil) {
                            let message = Message(message: userResponseWithMessage.message)
                            self.newPasswordSuccessMessage = message
                        }
                    }

                } catch let error {
                    logger.error("[submitNewPasswordForm] Request: \(error)")
                }
            }

            task.resume()

        } catch let error {
            logger.error("[submitNewPasswordForm] Error: \(error)")
        }
    }

    struct UserWithPasswordAndPasswordConfirmation: Codable, Identifiable {
        let id: Int?
        let password: String?
        let passwordConfirmation: String?
        let errors: [String]?
    }

    func submitEditPasswordForm() {
        do {
            let user = UserWithPasswordAndPasswordConfirmation(
                id: self.signedInUser?.id,
                password: newPasswordEditPasswordForm,
                passwordConfirmation: newPasswordConfirmationEditPasswordForm,
                errors: nil
            )

            let data = try JSONEncoder().encode(user)
            let url = URL(string: "\(passwordURL)")!
            let delegateClass = NetworkDelegateClass()
            let delegateSession = URLSession(configuration: .default, delegate: delegateClass, delegateQueue: nil)
            let optimizedData: Data = try! data.gzipped(level: .bestCompression)
            let postLength = String(format: "%lu", UInt(optimizedData.count))
            let request = newPutRequest(url: url, data: optimizedData, postLength: postLength)
            let task = delegateSession.dataTask(with: request) { data, response, error in
                do {
                    let userResponseWithMessage = try JSONDecoder().decode(UserResponseWithMessage.self, from: data!)

                    DispatchQueue.main.async {

                        let httpResponse = response as? HTTPURLResponse
                        let httpResponseUnwrapped = httpResponse!

                        // validation errors
                        if (userResponseWithMessage.user != nil) {
                            let errorsData = userResponseWithMessage.user?.errors!
                            if (errorsData == [] && httpResponseUnwrapped.statusCode == 200) {
                                resetValuesEditPassword()
                            } else {
                                let errorsDataUnwrapped = errorsData!
                                iterateOverErrorsEditPassword(errors: errorsDataUnwrapped)
                            }
                        }

                        // validation message
                        if (userResponseWithMessage.message != nil) {
                            let message = Message(message: userResponseWithMessage.message)
                            self.editPasswordSuccessMessage = message
                        }
                    }

                } catch let error {
                    logger.error("[submitEditPasswordForm] Request: \(error)")
                }
            }

            task.resume()

        } catch let error {
            logger.error("[submitEditPasswordForm] Error: \(error)")
        }
    }

    struct UserWithEmailAddressAndNewEmailAddress: Codable, Identifiable {
        let id: Int?
        let emailAddress: String?
        let errors: [String]?
    }

    func submitEditEmailAddressForm() {
        do {
            let user = UserWithEmailAddressAndNewEmailAddress(
                id: self.signedInUser?.id,
                emailAddress: newEmailAddressEditEmailAddressForm,
                errors: nil
            )

            let data = try JSONEncoder().encode(user)
            let url = URL(string: "\(emailURL)")!
            let delegateClass = NetworkDelegateClass()
            let delegateSession = URLSession(configuration: .default, delegate: delegateClass, delegateQueue: nil)
            let optimizedData: Data = try! data.gzipped(level: .bestCompression)
            let postLength = String(format: "%lu", UInt(optimizedData.count))
            let request = newPutRequest(url: url, data: optimizedData, postLength: postLength)
            let task = delegateSession.dataTask(with: request) { data, response, error in
                do {
                    let userResponseWithMessage = try JSONDecoder().decode(UserResponseWithMessage.self, from: data!)

                    DispatchQueue.main.async {

                        let httpResponse = response as? HTTPURLResponse
                        let httpResponseUnwrapped = httpResponse!

                        // validation errors
                        if (userResponseWithMessage.user != nil) {
                            let errorsData = userResponseWithMessage.user?.errors!
                            if (errorsData == [] && httpResponseUnwrapped.statusCode == 200) {
                                resetValuesEditEmailAddress()
                            } else {
                                let errorsDataUnwrapped = errorsData!
                                iterateOverErrorsEditEmailAddress(errors: errorsDataUnwrapped)
                            }
                        }

                        // validation message
                        if (userResponseWithMessage.message != nil) {
                            let message = Message(message: userResponseWithMessage.message)
                            self.editEmailAddressSuccessMessage = message
                        }
                    }

                } catch let error {
                    logger.error("[submitEditPasswordForm] Request: \(error)")
                }
            }

            task.resume()

        } catch let error {
            logger.error("[submitEditPasswordForm] Error: \(error)")
        }
    }

    func clickRegisterLink() {
        self.newAccount = true
    }

    func clickPasswordLink() {
        self.newPassword = true
    }

    func clickBackToAccountLink() {
        backToMyAccount()
    }

    func clickSigninLink() {
        // enable new session
        self.newSession = true

        // disable other sections
        self.myAccount = false
        self.newAccount = false
        self.newPassword = false
        self.editPassword = false
        self.editAccount = false
        self.editEmailAddress = false

        // reset forms
        resetValuesNewSession()

        // enable buttons
        self.newSessionComplete = false
    }

    func clickEditAccount() {
        self.editAccount = true

        let accountName = self.signedInUser?.accountName
        if (accountName != nil) {
            let accountNameUnWrapped = accountName!
            self.accountNameAccountForm = accountNameUnWrapped
        }
        let accountAddress = self.signedInUser?.accountAddress
        if (accountAddress != nil) {
            let accountAddressUnWrapped = accountAddress!
            self.accountAddressAccountForm = accountAddressUnWrapped
        }
        let firstName = self.signedInUser?.firstName
        if (firstName != nil) {
            let firstNameUnWrapped = firstName!
            self.firstNameAccountForm = firstNameUnWrapped
        }
        let lastName = self.signedInUser?.lastName
        if (lastName != nil) {
            let lastNameUnWrapped = lastName!
            self.lastNameAccountForm = lastNameUnWrapped
        }
        let emailAddress = self.signedInUser?.emailAddress
        if (emailAddress != nil) {
            let emailAddressUnWrapped = emailAddress!
            self.emailAddressAccountForm = emailAddressUnWrapped
        }
        let notifyOnSignIn = self.signedInUser?.deliverNotificationsSignIn
        if (notifyOnSignIn != nil) {
            let notifyOnSignInUnWrapped = notifyOnSignIn!
            self.notifyOnSignInAccountForm = notifyOnSignInUnWrapped
        }
        let notifyOnAccountUpdate = self.signedInUser?.deliverNotificationsAccountUpdate
        if (notifyOnAccountUpdate != nil) {
            let notifyOnAccountUpdateUnWrapped = notifyOnAccountUpdate!
            self.notifyOnAccountUpdateAccountForm = notifyOnAccountUpdateUnWrapped
        }
    }

    func clickEditPassword() {
        self.editPassword = true

        let password = self.signedInUser?.password
        if (password != nil) {
            let passwordUnwrapped = password!
            self.newPasswordEditPasswordForm = passwordUnwrapped
            self.newPasswordConfirmationEditPasswordForm = passwordUnwrapped
        }
    }

    func clickEditEmailAddress() {
        self.editEmailAddress = true

        let emailAddress = self.signedInUser?.emailAddress
        if (emailAddress != nil) {
            let emailAddressUnwrapped = emailAddress!
            self.emailAddressEditEmailAddressForm = emailAddressUnwrapped
        }
    }

    func resetValuesNewSession() {
//        self.newSession = false
        self.newSessionComplete = true

        self.myAccount = true
        self.newAccount = false
        self.newPassword = false
        self.editPassword = false
        self.editAccount = false
        self.editEmailAddress = false

        // reset errors
        self.newSessionValidationErrors = String()

        // reset message
        self.newSessionSuccessMessage = Message(message: String())
        self.destroySessionFormResponse = Message(message: String())

        // reset values
        self.emailAddressPasswordForm = String()
    }

    func resetValuesNewPassword() {
//        self.newPassword = false
        self.newPasswordComplete = true

        self.newAccount = false
        self.editPassword = false
        self.editAccount = false
        self.editEmailAddress = false

        // reset errors
        self.newPasswordValidationErrors = String()

        // reset message
        self.newPasswordSuccessMessage = Message(message: String())

        // reset values
        self.emailAddressPasswordForm = String()
    }

    func resetValuesEditPassword() {
//        self.editPassword = false
        self.editPasswordComplete = true

        self.newAccount = false
        self.newPassword = false
        self.editAccount = false
        self.editEmailAddress = false

        // reset errors
        self.editPasswordValidationErrors = String()

        // reset message
        self.editPasswordSuccessMessage = Message(message: String())

        // reset values
        self.newPasswordEditPasswordForm = String()
        self.newPasswordConfirmationEditPasswordForm = String()
    }

    func resetValuesNewAccount() {
//        self.newAccount = false
        self.newAccountComplete = true

        self.newPassword = false
        self.editPassword = false
        self.editAccount = false
        self.editEmailAddress = false

        // reset errors
        self.newAccountValidationErrors = String()

        // reset message
        self.newAccountSuccessMessage = Message(message: String())

        // reset values
        self.firstNameRegistrationForm = String()
        self.lastNameRegistrationForm = String()
        self.emailAddressRegistrationForm = String()
        self.passwordRegistrationForm = String()
    }

    func resetValuesEditAccount() {
//        self.editAccount = false
        self.editAccountComplete = true

        self.newAccount = false
        self.newPassword = false
        self.editPassword = false
        self.editEmailAddress = false

        // reset errors
        self.editAccountValidationErrors = String()

        // reset message
        self.editAccountSuccessMessage = Message(message: String())

        // reset values
        self.accountNameAccountForm = String()
        self.accountAddressAccountForm = String()
        self.firstNameAccountForm = String()
        self.lastNameAccountForm = String()
        self.emailAddressAccountForm = String()
//        self.notifyOnSignInAccountForm = false
//        self.notifyOnAccountUpdateAccountForm = false
    }

    func resetValuesEditEmailAddress() {
//        self.editEmailAddress = false
        self.editEmailAddressComplete = true

        self.editAccount = false
        self.newAccount = false
        self.newPassword = false
        self.editPassword = false

        // reset errors
        self.editEmailAddressValidationErrors = String()

        // reset message
        self.editEmailAddressSuccessMessage = Message(message: String())

        // reset values
        self.emailAddressEditEmailAddressForm = String()
        self.newEmailAddressEditEmailAddressForm = String()
    }

    func backToMyAccount() {
        // enable my account
        self.myAccount = true

        // disable other sections
        self.newAccount = false
        self.newPassword = false
        self.editPassword = false
        self.editAccount = false
        self.editEmailAddress = false

        // reset forms
        resetValuesEditAccount()
        resetValuesEditPassword()
        resetValuesNewSession()
        resetValuesEditEmailAddress()

        // enable buttons again
        self.newPasswordComplete = false
        self.editPasswordComplete = false
        self.newAccountComplete = false
        self.editAccountComplete = false
        self.editEmailAddressComplete = false
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

    struct AttachmentIds: Codable {
        var id: Array<Int>
        var type: String
    }

    func submitDestroyAttachments(ids: Array<Int>, type: String) {
        do {
            let ids = AttachmentIds(id: ids, type: type)
            let data = try JSONEncoder().encode(ids)
            let url = URL(string: "\(attachmentsDeleteURL)")!
            let delegateClass = NetworkDelegateClass()
            let delegateSession = URLSession(configuration: .default, delegate: delegateClass, delegateQueue: nil)
            let optimizedData: Data = try! data.gzipped(level: .bestCompression)
            let postLength = String(format: "%lu", UInt(optimizedData.count))
            let request = newPostRequestWithContent(url: url, data: optimizedData, postLength: postLength)
            let task = delegateSession.dataTask(with: request) { data, response, error in
                DispatchQueue.main.async {
                    self.loadedFolders = []
                    clearSelectedFolders()
                    clearSelectedFiles()
                    getAllUploads()
                }
            }

            task.resume()

        } catch let error {
            logger.error("[submitDestroyAttachments] Request: \(error)")
        }
    }

    func deleteSelectedImages() {
        submitDestroyAttachments(
            ids: self.selectedImageFiles.map { $0.id },
            type: "ImageFile"
        )
        refreshUploads()
    }

    func deleteSelectedAudioFiles() {
        submitDestroyAttachments(
            ids: self.selectedAudioFiles.map { $0.id },
            type: "AudioFile"
        )
        refreshUploads()
    }

    func deleteSelectedVideoFiles() {
        submitDestroyAttachments(
            ids: self.selectedVideoFiles.map { $0.id },
            type: "VideoFile"
        )
        refreshUploads()
    }

    func deleteSelectedPdfs() {
        submitDestroyAttachments(
            ids: self.selectedPdfFiles.map { $0.id },
            type: "PdfFile"
        )
        refreshUploads()
    }

    func deleteSelectedTextFiles() {
        submitDestroyAttachments(
            ids: self.selectedTextFiles.map { $0.id },
            type: "TextFile"
        )
        refreshUploads()
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

    /*
     Audio, Video: Streaming
    */
    struct Stream: Decodable, Identifiable {
        let id: Int
        let m3u8Exists:Bool
    }

    @State private var videoStreams:Array<Stream> = Array<Stream>()

    @State private var audioStreams:Array<Stream> = Array<Stream>()

    func getVideoStream(videoFile: VideoFile) {
        let delegateClass = NetworkDelegateClass()
        let delegateSession = URLSession(configuration: .default, delegate: delegateClass, delegateQueue: nil)
        let url = URL(string: "\(videoFilesServiceURL)/\(videoFile.id).json")!
        let request = newGetRequest(url: url)
        let task = delegateSession.dataTask(with: request) { data, response, error in
            do {
                if (data != nil) {
                    let dataUnwrapped = data!
                    let response = try JSONDecoder().decode(Stream.self, from: dataUnwrapped)

                    DispatchQueue.main.async {
                        if response.m3u8Exists == true {
                            if !self.videoStreams.map({ $0.id }).contains(videoFile.id) {
                                self.videoStreams.append(response)
                            }
                        }
                    }
                }
            } catch let error {
                logger.error("[getVideoStream] Request: \(error)")
            }
        }

        task.resume()
    }

    func getAudioStream(audioFile: AudioFile) {
        let delegateClass = NetworkDelegateClass()
        let delegateSession = URLSession(configuration: .default, delegate: delegateClass, delegateQueue: nil)
        let url = URL(string: "\(audioFilesServiceURL)/\(audioFile.id).json")!
        let request = newGetRequest(url: url)
        let task = delegateSession.dataTask(with: request) { data, response, error in
            do {
                if (data != nil) {
                    let dataUnwrapped = data!
                    let response = try JSONDecoder().decode(Stream.self, from: dataUnwrapped)

                    DispatchQueue.main.async {
                        if response.m3u8Exists == true {
                            if !self.audioStreams.map({ $0.id }).contains(audioFile.id) {
                                self.audioStreams.append(response)
                            }
                        }
                    }
                }
            } catch let error {
                logger.error("[getAudioStream] Request: \(error)")
            }
        }

        task.resume()
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
            let url = URL(string: "\(playlistsServiceURL)/video-\(videoFile.id).m3u8")!
            initMediaPlayer(url: url)
        }
    }

    func displayAudio(audioFile: AudioFile) {
        if self.audioStreams.map({ $0.id }).contains(audioFile.id) {
            let url = URL(string: "\(playlistsServiceURL)/audio-\(audioFile.id).m3u8")!
            initMediaPlayer(url: url)
        }
    }

    /*
        Folder: Publish / Unpublish
    */
    enum FolderAction: String, CaseIterable, Identifiable {
        case none, publish, unpublish, archive, unarchive, delete
        var id: Self { self }
    }

    @State private var selectedFolderAction: FolderAction = .none

    func updateSelectedFolders() {
        self.searchText = "";
        if ($selectedFolderAction.wrappedValue == FolderAction.publish) {
            publishSelectedFolders()
        } else if ($selectedFolderAction.wrappedValue == FolderAction.unpublish) {
            unpublishSelectedFolders()
        } else if ($selectedFolderAction.wrappedValue == FolderAction.archive) {
            archiveSelectedFolders()
        } else if ($selectedFolderAction.wrappedValue == FolderAction.unarchive) {
            unarchiveSelectedFolders()
        } else if ($selectedFolderAction.wrappedValue == FolderAction.delete) {
            deleteSelectedFolders()
        }
    }

    struct FolderIds: Codable {
        var id: Array<Int>
    }

    func publishSelectedFolders() {
        do {
            let item = FolderIds(id: self.selectedFolders.map { $0 })
            let data = try JSONEncoder().encode(item)
            let url = URL(string: "\(foldersPublishURL)")!
            let delegateClass = NetworkDelegateClass()
            let delegateSession = URLSession(configuration: .default, delegate: delegateClass, delegateQueue: nil)
            let optimizedData: Data = try! data.gzipped(level: .bestCompression)
            let postLength = String(format: "%lu", UInt(optimizedData.count))
            let request = newPostRequestWithContent(url: url, data: optimizedData, postLength: postLength)
            let task = delegateSession.dataTask(with: request) { data, response, error in
                DispatchQueue.main.async {
                    self.loadedFolders = []
                    getAllUploads()
                }
            }

            task.resume()

        } catch let error {
            logger.error("[publishSelectedFolders] \(error)")
        }
    }

    func unpublishSelectedFolders() {
        do {
            let item = FolderIds(id: self.selectedFolders.map { $0 })
            let data = try JSONEncoder().encode(item)
            let url = URL(string: "\(foldersUnpublishURL)")!
            let delegateClass = NetworkDelegateClass()
            let delegateSession = URLSession(configuration: .default, delegate: delegateClass, delegateQueue: nil)
            let optimizedData: Data = try! data.gzipped(level: .bestCompression)
            let postLength = String(format: "%lu", UInt(optimizedData.count))
            let request = newPostRequest(url: url, data: optimizedData, postLength: postLength)
            let task = delegateSession.dataTask(with: request) { data, response, error in
                DispatchQueue.main.async {
                    self.loadedFolders = []
                    getAllUploads()
                }
            }

            task.resume()

        } catch let error {
            logger.error("[unpublishSelectedFolders] \(error)")
        }
    }

    func archiveSelectedFolders() {
        do {
            let item = FolderIds(id: self.selectedFolders.map { $0 })
            let data = try JSONEncoder().encode(item)
            let url = URL(string: "\(foldersArchiveURL)")!
            let delegateClass = NetworkDelegateClass()
            let delegateSession = URLSession(configuration: .default, delegate: delegateClass, delegateQueue: nil)
            let optimizedData: Data = try! data.gzipped(level: .bestCompression)
            let postLength = String(format: "%lu", UInt(optimizedData.count))
            let request = newPostRequest(url: url, data: optimizedData, postLength: postLength)
            let task = delegateSession.dataTask(with: request) { data, response, error in
                DispatchQueue.main.async {
                    self.loadedFolders = []
                    getAllUploads()
                }
            }

            task.resume()

        } catch let error {
            logger.error("[archiveSelectedFolders] \(error)")
        }
    }

    func unarchiveSelectedFolders() {
        do {
            let item = FolderIds(id: self.selectedFolders.map { $0 })
            let data = try JSONEncoder().encode(item)
            let url = URL(string: "\(foldersUnarchiveURL)")!
            let delegateClass = NetworkDelegateClass()
            let delegateSession = URLSession(configuration: .default, delegate: delegateClass, delegateQueue: nil)
            let optimizedData: Data = try! data.gzipped(level: .bestCompression)
            let postLength = String(format: "%lu", UInt(optimizedData.count))
            let request = newPostRequest(url: url, data: optimizedData, postLength: postLength)
            let task = delegateSession.dataTask(with: request) { data, response, error in
                DispatchQueue.main.async {
                    self.loadedFolders = []
                    getAllUploads()
                }
            }

            task.resume()

        } catch let error {
            logger.error("[unarchiveSelectedFolders] \(error)")
        }
    }

    func deleteSelectedFolders() {
        do {
            let item = FolderIds(id: self.selectedFolders.map { $0 })
            let data = try JSONEncoder().encode(item)
            let url = URL(string: "\(foldersDeleteURL)")!
            let delegateClass = NetworkDelegateClass()
            let delegateSession = URLSession(configuration: .default, delegate: delegateClass, delegateQueue: nil)
            let optimizedData: Data = try! data.gzipped(level: .bestCompression)
            let postLength = String(format: "%lu", UInt(optimizedData.count))
            let request = newPostRequestWithContent(url: url, data: optimizedData, postLength: postLength)
            let task = delegateSession.dataTask(with: request) { data, response, error in
                DispatchQueue.main.async {
                    self.loadedFolders = []
                    clearSelectedFolders()
                    clearSelectedFiles()
                    getAllUploads()
                }
            }

            task.resume()

        } catch let error {
            logger.error("[deleteSelectedFolders] Request: \(error)")
        }
    }

    /*
        Search Folders
    */
    func fetchSearchResults(for searchQuery: String) {
        logger.info("[fetchSearchResults] \(searchQuery)")

        if (searchQuery == "" || searchQuery.count <= 3) {
            refreshUploads()
        } else {
            loadedFolders = searchableFolders.filter { folder in
                folder.name
                    .lowercased()
                    .contains(searchQuery.lowercased())
            }
            uploadImageFiles = searchableImageFiles.filter { imageFile in
                imageFile.fileName
                    .lowercased()
                    .contains(searchQuery.lowercased())
            }
            uploadImageFiles.forEach { imageFile in
                var i = 0
                self.loadedFolders.forEach { folder in
                    if (folder.id == imageFile.folder.id) {
                        self.loadedFolders.remove(at: i)
                    }
                    i += 1
                }
                self.loadedFolders.append(imageFile.folder)
            }
            uploadVideoFiles = searchableVideoFiles.filter { videoFile in
                videoFile.fileName
                    .lowercased()
                    .contains(searchQuery.lowercased())
            }
            uploadVideoFiles.forEach { videoFile in
                var i = 0
                self.loadedFolders.forEach { folder in
                    if (folder.id == videoFile.folder.id) {
                        self.loadedFolders.remove(at: i)
                    }
                    i += 1
                }
                self.loadedFolders.append(videoFile.folder)
            }
            uploadAudioFiles = searchableAudioFiles.filter { audioFile in
                audioFile.fileName
                    .lowercased()
                    .contains(searchQuery.lowercased())
            }
            uploadAudioFiles.forEach { audioFile in
                var i = 0
                self.loadedFolders.forEach { folder in
                    if (folder.id == audioFile.folder.id) {
                        self.loadedFolders.remove(at: i)
                    }
                    i += 1
                }
                self.loadedFolders.append(audioFile.folder)
            }
            uploadPdfFiles = searchablePdfFiles.filter { pdfFile in
                pdfFile.fileName
                    .lowercased()
                    .contains(searchQuery.lowercased())
            }
            uploadPdfFiles.forEach { pdfFile in
                var i = 0
                self.loadedFolders.forEach { folder in
                    if (folder.id == pdfFile.folder.id) {
                        self.loadedFolders.remove(at: i)
                    }
                    i += 1
                }
                self.loadedFolders.append(pdfFile.folder)
            }
            uploadTextFiles = searchableTextFiles.filter { textFile in
                textFile.fileName
                    .lowercased()
                    .contains(searchQuery.lowercased())
            }
            uploadTextFiles.forEach { textFile in
                var i = 0
                self.loadedFolders.forEach { folder in
                    if (folder.id == textFile.folder.id) {
                        self.loadedFolders.remove(at: i)
                    }
                    i += 1
                }
                self.loadedFolders.append(textFile.folder)
            }
        }
    }

    func refreshUploads() {
        clearSelectedFolders()
        getAllUploads()
    }

    @Environment(\.openURL) var openURL

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
                    if self.editPassword {
                        /*
                            Account: Edit Password
                        */
                        Form {
                            VStack {
                                Spacer()

                                Text("Change Password")
                                    .font(.system(size: 15))

                                if let message = editPasswordSuccessMessage.message {
                                    Text("\(message)")
                                        .font(.system(size: 11))
                                        .foregroundStyle(Color.secondary)
                                }

                                Text("\(editPasswordValidationErrors)\n")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.gray)

                                SecureField(text: $newPasswordEditPasswordForm, prompt: Text("New Password")) {
                                    Text("New Password")
                                }
                                .disableAutocorrection(true)
                                .disabled(self.editPasswordComplete)

                                SecureField(text: $newPasswordConfirmationEditPasswordForm, prompt: Text("New Password confirmation")) {
                                    Text("New Password confirmation")
                                }
                                .disableAutocorrection(true)
                                .disabled(self.editPasswordComplete)

                                Button(action: submitEditPasswordForm) {
                                    Text("Submit")
                                }
                                .buttonStyle(PlainButtonStyle())
                                .disabled(self.editPasswordComplete)

                                Spacer()

                                Divider()

                                /* Account */
                                Button(action: clickBackToAccountLink) {
                                    Image(systemName: "person.text.rectangle")
                                        .font(.system(size: 20))
                                    Text("Back to my account")
                                        .foregroundStyle(.blue.gradient)
                                }.buttonStyle(PlainButtonStyle())
                            }
                            .textFieldStyle(.roundedBorder)
                        }.padding(20)
                    } else if self.editEmailAddress {
                        /*
                            Account: Edit Email Address
                        */
                        Form {
                            VStack {
                                Spacer()

                                Text("Change Email Address")
                                    .font(.system(size: 15))

                                if let message = editEmailAddressSuccessMessage.message {
                                    Text("\(message)")
                                        .font(.system(size: 11))
                                        .foregroundStyle(Color.secondary)
                                }

                                Text("\(editEmailAddressValidationErrors)\n")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.gray)

                                let emailAddress = self.signedInUser?.emailAddress
                                let emailAddressUnwrapped = emailAddress!
                                TextField(text: $emailAddressEditEmailAddressForm, prompt: Text("\(emailAddressUnwrapped)")) {
                                    Text("Current Email Address")
                                }
                                .disableAutocorrection(true)
//                                .disabled(self.editEmailAddressComplete)
                                .disabled(true)

                                TextField(text: $newEmailAddressEditEmailAddressForm) {
                                    Text("New Email Address")
                                }
                                .disableAutocorrection(true)
                                .disabled(self.editEmailAddressComplete)

                                Button(action: submitEditEmailAddressForm) {
                                    Text("Submit")
                                }
                                .buttonStyle(PlainButtonStyle())
                                .disabled(self.editEmailAddressComplete)

                                Spacer()

                                Divider()

                                /* Account */
                                Button(action: clickBackToAccountLink) {
                                    Image(systemName: "person.text.rectangle")
                                        .font(.system(size: 20))
                                    Text("Back to my account")
                                        .foregroundStyle(.blue.gradient)
                                }.buttonStyle(PlainButtonStyle())
                            }
                            .textFieldStyle(.roundedBorder)
                        }.padding(20)

                    } else if self.editAccount {
                        /*
                            Account: Edit Account
                        */
                        Form {
                            VStack {
                                Spacer()

                                Text("Edit Account")
                                    .font(.system(size: 15))

                                if let message = editAccountSuccessMessage.message {
                                    Text("\(message)")
                                        .font(.system(size: 11))
                                        .foregroundStyle(Color.secondary)
                                }

                                Text("\(editAccountValidationErrors)\n")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.gray)

                                let accountName = self.signedInUser?.accountName
                                if (accountName != nil) {
                                    let accountNameUnWrapped:String = accountName!
                                    TextField(text: $accountNameAccountForm, prompt: Text(accountNameUnWrapped)) {
                                        Text("Account Name")
                                    }
                                    .disableAutocorrection(true)
                                    .disabled(self.editAccountComplete)
                                }

                                let accountAddress = self.signedInUser?.accountAddress
                                if (accountAddress != nil) {
                                    let accountAddressUnWrapped:String = accountAddress!
                                    TextField(text: $accountAddressAccountForm, prompt: Text(accountAddressUnWrapped)) {
                                        Text("Account Name")
                                    }
                                    .disableAutocorrection(true)
                                    .disabled(self.editAccountComplete)
                                }

                                let firstName = self.signedInUser?.firstName
                                if (firstName != nil) {
                                    let firstNameUnWrapped:String = firstName!
                                    TextField(text: $firstNameAccountForm, prompt: Text(firstNameUnWrapped)) {
                                        Text("First Name")
                                    }
                                    .disableAutocorrection(true)
                                    .disabled(self.editAccountComplete)
                                }

                                let lastName = self.signedInUser?.lastName
                                if (lastName != nil) {
                                    let lastNameUnWrapped:String = lastName!
                                    TextField(text: $lastNameAccountForm, prompt: Text(lastNameUnWrapped)) {
                                        Text("Last Name")
                                    }
                                    .disableAutocorrection(true)
                                    .disabled(self.editAccountComplete)
                                }

                                let emailAddress = self.signedInUser?.emailAddress
                                if (emailAddress != nil) {
                                    let emailAddressUnWrapped:String = emailAddress!
                                    TextField(text: $emailAddressAccountForm, prompt: Text(emailAddressUnWrapped)) {
                                        Text("Email Address")
                                    }
                                    .disableAutocorrection(true)
//                                    .disabled(self.editAccountComplete)
                                    .disabled(true)
                                }

                                let uuid = self.signedInUser?.accountUuid!.uuidString
                                if (uuid != nil) {
                                    let uuidUnwrapped = uuid!
                                    TextField(text: $uuidAccountForm, prompt: Text(uuidUnwrapped)) {
                                        Text("UUID")
                                    }
                                    .disableAutocorrection(true)
                                    .disabled(true)
                                }

                                let createdAt = self.signedInUser?.createdAt
                                if (createdAt != nil) {
                                    let createdAtUnwrapped = createdAt!
                                    TextField(text: $createdAtAccountForm, prompt: Text(createdAtUnwrapped)) {
                                        Text("Created At")
                                    }
                                    .disableAutocorrection(true)
                                    .disabled(true)
                                }
//
                                let updatedAt = self.signedInUser?.updatedAt
                                if (updatedAt != nil) {
                                    let updatedAtUnwrapped = updatedAt!
                                    TextField(text: $updatedAtAccountForm, prompt: Text(updatedAtUnwrapped)) {
                                        Text("Updated At")
                                    }
                                    .disableAutocorrection(true)
                                    .disabled(true)
                                }

                                Spacer()

                                let notifyOnSignIn = self.signedInUser?.deliverNotificationsSignIn
                                if (notifyOnSignIn != nil) {
                                    Toggle(
                                        "Notify me when I sign-in",
                                        isOn: $notifyOnSignInAccountForm
                                    )
                                    .buttonStyle(.plain)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .disabled(self.editAccountComplete)
                                }

                                let notifyOnAccountUpdate = self.signedInUser?.deliverNotificationsAccountUpdate
                                if (notifyOnAccountUpdate != nil) {
                                    Toggle(
                                        "Notify me when my account is updated",
                                        isOn: $notifyOnAccountUpdateAccountForm
                                    )
                                    .buttonStyle(.plain)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .disabled(self.editAccountComplete)
                                }

                                Spacer()

                                Button(action: submitAccountForm) {
                                    Text("Submit")
                                }
                                .buttonStyle(PlainButtonStyle())
                                .disabled(self.editAccountComplete)

                                Spacer()

                                Divider()

                                /* Account */
                                Button(action: clickBackToAccountLink) {
                                    Image(systemName: "person.text.rectangle")
                                        .font(.system(size: 20))
                                    Text("Back to my account")
                                        .foregroundStyle(.blue.gradient)
                                }.buttonStyle(PlainButtonStyle())
                            }
                            .textFieldStyle(.roundedBorder)
                        }.padding(20)

                    } else if self.myAccount {
                        /*
                            Account Panel
                        */
                        Text("My Account")
                            .font(.system(size: 15))

                        if #available(macOS 15.0, *) {
                            Image(systemName: "person.circle")
                                .font(.system(size: 20))
                                .symbolEffect(.bounce, options: .repeat(1))
                                .padding(10)
                        } else {
                            Image(systemName: "person.circle")
                                .font(.system(size: 20))
                                .padding(10)
                        }

                        /* User Email */
                        let emailAddress = self.signedInUser?.emailAddress
                        if (emailAddress != nil) {
                            let emailAddressUnWrapped:String = emailAddress!
                            Text(emailAddressUnWrapped)
                                .padding(10)
                        }

                        /* Edit Account */
                        Button(action: clickEditAccount) {
                            Text("Edit account")
                                .foregroundStyle(.blue.gradient)
                        }.buttonStyle(PlainButtonStyle())

                        /* Reset Password */
                        Button(action: clickEditPassword) {
                            Text("Change password")
                                .foregroundStyle(.blue.gradient)
                        }.buttonStyle(PlainButtonStyle())

                        /* Edit Email Address */
                        Button(action: clickEditEmailAddress) {
                            Text("Change Email Address")
                                .foregroundStyle(.blue.gradient)
                        }.buttonStyle(PlainButtonStyle())
                    }

                } else if self.newPassword {
                    /*
                        Account: Reset Password
                    */
                    Form {
                        VStack {
                            Spacer()

                            Text("Reset Password")
                                .font(.system(size: 15))

                            if let message = newPasswordSuccessMessage.message {
                                Text("\(message)")
                                    .font(.system(size: 11))
                                    .foregroundStyle(Color.secondary)
                            }

                            Text("\(newPasswordValidationErrors)\n")
                                .font(.system(size: 11))
                                .foregroundStyle(.gray)

                            TextField(text: $emailAddressPasswordForm, prompt: Text("johnatan@apple.com")) {
                                Text("Email")
                            }
                            .disableAutocorrection(true)
                            .disabled(self.newPasswordComplete)

                            Button(action: submitNewPasswordForm) {
                                Text("Submit")
                            }
                            .buttonStyle(PlainButtonStyle())
                            .disabled(self.newPasswordComplete)

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
                    /*
                        Account: Registration
                    */
                    Form {
                        VStack {
                            Spacer()

                            Text("Register Account")
                                .font(.system(size: 15))

                            if let message = newAccountSuccessMessage.message {
                                Text("\(message)")
                                    .font(.system(size: 11))
                                    .foregroundStyle(Color.secondary)
                            }

                            Text("\(newAccountValidationErrors)\n")
                                .font(.system(size: 11))
                                .foregroundStyle(.gray)

                            TextField(text: $accountNameRegistrationForm, prompt: Text("Company Name")) {
                                Text("Company Name")
                            }
                            .disableAutocorrection(true)
                            .disabled(self.newAccountComplete)

                            TextField(text: $accountAddressRegistrationForm, prompt: Text("Company Address")) {
                                Text("Company Address")
                            }
                            .disableAutocorrection(true)
                            .disabled(self.newAccountComplete)

                            Divider()

                            TextField(text: $firstNameRegistrationForm, prompt: Text("John")) {
                                Text("First Name")
                            }
                            .disableAutocorrection(true)
                            .disabled(self.newAccountComplete)

                            TextField(text: $lastNameRegistrationForm, prompt: Text("Appleseed")) {
                                Text("Last Name")
                            }
                            .disableAutocorrection(true)
                            .disabled(self.newAccountComplete)

                            TextField(text: $emailAddressRegistrationForm, prompt: Text("johnatan@apple.com")) {
                                Text("Email")
                            }
                            .disableAutocorrection(true)
                            .disabled(self.newAccountComplete)

                            SecureField(text: $passwordRegistrationForm, prompt: Text("Required")) {
                                Text("Password")
                            }
                            .disableAutocorrection(true)
                            .disabled(self.newAccountComplete)

                            Button(action: submitRegistrationForm) {
                                Text("Submit")
                            }
                            .buttonStyle(PlainButtonStyle())
                            .disabled(self.newAccountComplete)

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

                } else if self.newSession {
                    /*
                        Account: Sign-In
                    */
                    Form {
                        VStack {
                            Spacer()

                            Text("New Session")
                                .font(.system(size: 15))

                            Text("\(newSessionValidationErrors)\n")
                                .font(.system(size: 11))
                                .foregroundStyle(.gray)

                            TextField(text: $emailAddressSessionForm, prompt: Text("johnatan@apple.com")) {
                                Text("Email")
                            }
                            .disableAutocorrection(true)
                            .disabled(self.newSessionComplete)

                            SecureField(text: $passwordSessionForm, prompt: Text("Required")) {
                                Text("Password")
                            }
                            .disableAutocorrection(true)
                            .disabled(self.newSessionComplete)

                            Button(action: submitSessionForm) {
                                Text("Submit")
                            }
                            .buttonStyle(PlainButtonStyle())
                            .disabled(self.newSessionComplete)

                            /* Register */
                            Button(action: clickRegisterLink) {
                                if #available(macOS 15.0, *) {
                                    Image(systemName: "person.crop.circle.badge.plus")
                                        .font(.system(size: 20))
                                        .symbolEffect(.bounce, options: .repeat(1))
                                        .padding(10)
                                } else {
                                    Image(systemName: "person.crop.circle.badge.plus")
                                        .font(.system(size: 20))
                                        .padding(10)
                                }
                                Text("Register for a new account")
                                    .foregroundStyle(.blue.gradient)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .padding(30)

                            Spacer()

                            Divider()

                            /* Forgot Password */
                            Button(action: clickPasswordLink) {
                                Image(systemName: "mail")
                                    .font(.system(size: 20))
                                Text("Forgot my password")
                                    .foregroundStyle(.blue.gradient)
                            }.buttonStyle(PlainButtonStyle())
                        }
                        .textFieldStyle(.roundedBorder)

                    }.padding(20)
                }

            case .upload:
                if !self.identified {
                    Text("You need to be identified. Please sign-in.")
                } else {
                    /*
                        Main Upload Panel
                    */
                    HStack {
                        /* Browse Button */
                        VStack {
                            Button(action: syncFolders) {
                                let folderNames = folders.map { String($0.path().split(separator: "/").last!) }
                                Image(systemName: "arrow.down.square")
                                Text("Import \(folderNames.joined(separator: ", "))")
                                ProgressView(value: progress)
                            }
                        }

                        /* Clear Button */
                        VStack {
                            Button(action: clearFolders) {
                                Text("Clear")
                                    .foregroundStyle(.blue.gradient)
                            }.buttonStyle(PlainButtonStyle())
                        }

                        /* Import Button */
                        VStack {
                            Button(action: {
                                isImporting = true
                            }) {
                                if #available(macOS 15.0, *) {
                                    Image(systemName: "square.grid.3x1.folder.badge.plus")
                                        .font(.system(size: 11))
                                        .buttonStyle(.plain)
                                        .symbolEffect(.bounce, options: .repeat(1))
                                } else {
                                    Image(systemName: "square.grid.3x1.folder.badge.plus")
                                        .font(.system(size: 11))
                                        .buttonStyle(.plain)
                                }
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
                    .navigationTitle("DemoApp (\(String(describing: self.signedInUser?.emailAddress))")
                    .toolbar {
                        Button(action: refreshUploads) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 20))
                        }
                    }

                    Section {
                        Table(of: Folder.self,
                              selection: $folderSelection,
                              sortOrder: $folderSortOrder) {

                            TableColumn("Name", value: \.name) { folder in
                                Label("\(folder.name)",
                                      systemImage: "folder")
                                .foregroundStyle(.primary)
                                .labelStyle(.titleAndIcon)
                                .font(.system(size: 11))
                            }
                            TableColumn("State", value: \.state) { folder in
                                Label {
                                    Text("\(folder.state)")
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
                        .onChange(of: folderSortOrder) { _, folderSortOrder in
                            withAnimation {
                                loadedFolders.sort(using: folderSortOrder)
                            }
                        }
                        .onChange(of: folderSelection) {
                            DispatchQueue.main.async {
                                clearSelectedFiles()
                                self.selectedFolders = []
                                for selectedId in folderSelection {
                                    loadedFolders.forEach { folder in
                                        if folder.id == selectedId {
                                            self.selectedFolders.insert(folder.id)
                                        }
                                    }
                                }
                                getSelectedUploads()
                            }
                        }
                        .tableStyle(.inset(alternatesRowBackgrounds: false))
                            .frame(height: 250)
                    } header: {
                        Text("Folders")
                            .searchable(text: $searchText, prompt: "Search Folders")
                    }.onChange(of: searchText) {
                        DispatchQueue.main.async {
                            fetchSearchResults(for: searchText)
                        }
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
                                        Label((imageFile.fileName), systemImage: "doc")
                                            .labelStyle(.titleAndIcon)
                                            .font(.system(size: 11))
                                    }
                                    TableColumn("mimeType") { imageFile in
                                        let mimeType = imageFile.mimeType
                                        let mimeTypeUnwrapped = mimeType!
                                        Text(mimeTypeUnwrapped)
                                            .labelStyle(.titleAndIcon)
                                            .font(.system(size: 11))
                                    }
                                } rows: {
                                    ForEach(uploadImageFiles) { imageFile in
                                        TableRow(imageFile)
                                    }
                                }
                            } header: {
                                HStack {
                                    VStack {
                                        Text("Image Files")
                                    }
                                    VStack {
                                        if (selectedImageFiles.count > 0) {
                                            Button(action: deleteSelectedImages) {
                                                Image(systemName: "minus.circle")
                                                    .font(.system(size: 11))
                                                Text("Delete selected \(self.selectedImageFiles.count > 1 ? "Image Files" : "Image File")")
                                                    .font(.system(size: 11))
                                            }
                                            .buttonStyle(.borderedProminent)
                                            .tint(.black)
                                        }
                                    }
                                }
                            }
                        }
                        .tableStyle(.inset(alternatesRowBackgrounds: false))
                        .onChange(of: imageFileSelection) {
                            self.selectedImageFiles = []
                            self.selectedFolders = Set()
                            for selectedId in imageFileSelection {
                                uploadImageFiles.forEach { imageFile in
                                    if imageFile.id == selectedId {
                                        self.selectedImageFiles.append(imageFile)
                                        if (!self.selectedFolders.contains(imageFile.folder.id)) {
                                            self.selectedFolders.insert(imageFile.folder.id)
                                        }
                                        var i = 0
                                        self.loadedFolders.forEach { folder in
                                            if (folder.id == imageFile.folder.id) {
                                                self.loadedFolders.remove(at: i)
                                            }
                                            i += 1
                                        }
                                        self.loadedFolders.append(imageFile.folder)
                                    }
                                }
                            }
                        }
                        .onChange(of: imageFileSortOrder) { _, imageFileSortOrder in
                            withAnimation {
                                uploadImageFiles.sort(using: imageFileSortOrder)
                            }
                        }
                        .tabItem {
                            Text("Image Files (\(uploadImageFiles.count))")
                        }

                        VStack {
                            Section {
                                /* AudioFiles */
                                Table(of: AudioFile.self,
                                      selection: $audioFileSelection,
                                      sortOrder: $audioFileSortOrder) {

                                    TableColumn("fileName") { audioFile in
                                        Label((audioFile.fileName), systemImage: "doc")
                                            .labelStyle(.titleAndIcon)
                                            .font(.system(size: 11))
                                    }
                                    TableColumn("mimeType") { audioFile in
                                        let mimeType = audioFile.mimeType
                                        let mimeTypeUnwrapped = mimeType!
                                        Text(mimeTypeUnwrapped)
                                            .labelStyle(.titleAndIcon)
                                            .font(.system(size: 11))
                                    }
                                } rows: {
                                    ForEach(uploadAudioFiles) { audioFile in
                                        TableRow(audioFile)
                                    }
                                }
                            } header: {
                                HStack {
                                    VStack {
                                        Text("Audio Files")
                                    }
                                    VStack {
                                        if (selectedAudioFiles.count > 0) {
                                            Button(action: deleteSelectedAudioFiles) {
                                                Image(systemName: "minus.circle")
                                                    .font(.system(size: 11))
                                                Text("Delete selected \(self.selectedAudioFiles.count > 1 ? "Audio Files" : "Audio File")")
                                                    .font(.system(size: 11))
                                            }
                                            .buttonStyle(.borderedProminent)
                                            .tint(.black)
                                        }
                                    }
                                }
                            }
                        }
                        .tableStyle(.inset(alternatesRowBackgrounds: false))
                        .onChange(of: audioFileSelection) { _, audioFileSelection in
                            self.selectedAudioFiles = []
                            self.selectedFolders = Set()
                            for selectedId in audioFileSelection {
                                uploadAudioFiles.forEach { audioFile in
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
                        .onChange(of: audioFileSelection) {
                            self.selectedAudioFiles = []
                            for selectedId in audioFileSelection {
                                uploadAudioFiles.forEach { audioFile in
                                    if audioFile.id == selectedId {
                                        self.selectedAudioFiles.append(audioFile)
                                        if (!self.selectedFolders.contains(audioFile.folder.id)) {
                                            self.selectedFolders.insert(audioFile.folder.id)
                                        }
                                        var i = 0
                                        self.loadedFolders.forEach { folder in
                                            if (folder.id == audioFile.folder.id) {
                                                self.loadedFolders.remove(at: i)
                                            }
                                            i += 1
                                        }
                                        self.loadedFolders.append(audioFile.folder)

                                        displayAudio(audioFile: audioFile)
                                    }
                                }
                            }
                        }
                        .onChange(of: audioFileSortOrder) { _, audioFileSortOrder in
                            uploadAudioFiles.sort(using: audioFileSortOrder)
                        }
                        .tabItem {
                            Text("Audio Files (\(uploadAudioFiles.count))")
                        }

                        VStack {
                            Section {
                                /* VideoFiles */
                                Table(of: VideoFile.self,
                                      selection: $videoFileSelection,
                                      sortOrder: $videoFileSortOrder) {

                                    TableColumn("fileName") { videoFile in
                                        Label((videoFile.fileName), systemImage: "doc")
                                            .labelStyle(.titleAndIcon)
                                            .font(.system(size: 11))
                                    }
                                    TableColumn("mimeType") { videoFile in
                                        let mimeType = videoFile.mimeType
                                        let mimeTypeUnwrapped = mimeType!
                                        Text(mimeTypeUnwrapped)
                                            .labelStyle(.titleAndIcon)
                                            .font(.system(size: 11))
                                    }
                                } rows: {
                                    ForEach(uploadVideoFiles) { videoFile in
                                        TableRow(videoFile)
                                    }
                                }
                            } header: {
                                HStack {
                                    VStack {
                                        Text("Video Files")
                                    }
                                    VStack {
                                        if (selectedVideoFiles.count > 0) {
                                            Button(action: deleteSelectedVideoFiles) {
                                                Image(systemName: "minus.circle")
                                                    .font(.system(size: 11))
                                                Text("Delete selected \(self.selectedVideoFiles.count > 1 ? "Video Files" : "Video File")")
                                                    .font(.system(size: 11))
                                            }
                                            .buttonStyle(.borderedProminent)
                                            .tint(.black)
                                        }
                                    }
                                }
                            }
                        }
                        .tableStyle(.inset(alternatesRowBackgrounds: false))
                        .onChange(of: videoFileSelection) {
                            self.selectedVideoFiles = []
                            self.selectedFolders = Set()
                            for selectedId in videoFileSelection {
                                uploadVideoFiles.forEach { videoFile in
                                    if videoFile.id == selectedId {
                                        self.selectedVideoFiles.append(videoFile)
                                        if (!self.selectedFolders.contains(videoFile.folder.id)) {
                                            self.selectedFolders.insert(videoFile.folder.id)
                                        }
                                        var i = 0
                                        self.loadedFolders.forEach { folder in
                                            if (folder.id == videoFile.folder.id) {
                                                self.loadedFolders.remove(at: i)
                                            }
                                            i += 1
                                        }
                                        self.loadedFolders.append(videoFile.folder)

                                        displayVideo(videoFile: videoFile)
                                    }
                                }
                            }
                        }
                        .onChange(of: videoFileSortOrder) { _, videoFileSortOrder in
                            uploadVideoFiles.sort(using: videoFileSortOrder)
                        }
                        .tabItem {
                            Text("Video Files (\(uploadVideoFiles.count))").colorMultiply(.cyan)
                        }

                        VStack {
                            Section {
                                /* PdfFiles */
                                Table(of: PdfFile.self,
                                      selection: $pdfFileSelection,
                                      sortOrder: $pdfFileSortOrder) {

                                    TableColumn("fileName") { pdfFile in
                                        Label(pdfFile.fileName, systemImage: "doc")
                                            .labelStyle(.titleAndIcon)
                                            .font(.system(size: 11))
                                    }
                                    TableColumn("mimeType") { pdfFile in
                                        let mimeType = pdfFile.mimeType
                                        let mimeTypeUnwrapped = mimeType!
                                        Text(mimeTypeUnwrapped)
                                            .labelStyle(.titleAndIcon)
                                            .font(.system(size: 11))
                                    }
                                } rows: {
                                    ForEach(uploadPdfFiles) { pdfFile in
                                        TableRow(pdfFile)
                                    }
                                }
                            } header: {
                                HStack {
                                    VStack {
                                        Text("Pdf Files")
                                    }
                                    VStack {
                                        if (selectedPdfFiles.count > 0) {
                                            Button(action: deleteSelectedPdfs) {
                                                Image(systemName: "minus.circle")
                                                    .font(.system(size: 11))
                                                Text("Delete selected \(self.selectedPdfFiles.count > 1 ? "Pdf Files" : "Pdf File")")
                                                    .font(.system(size: 11))
                                            }
                                            .buttonStyle(.borderedProminent)
                                            .tint(.black)
                                        }
                                    }
                                }
                            }
                        }
                        .tableStyle(.inset(alternatesRowBackgrounds: false))
                        .onChange(of: pdfFileSelection) {
                            self.selectedPdfFiles = []
                            self.selectedFolders = Set()
                            for selectedId in pdfFileSelection {
                                uploadPdfFiles.forEach { pdfFile in
                                    if pdfFile.id == selectedId {
                                        self.selectedPdfFiles.append(pdfFile)
                                        if (!self.selectedFolders.contains(pdfFile.folder.id)) {
                                            self.selectedFolders.insert(pdfFile.folder.id)
                                        }
                                        var i = 0
                                        self.loadedFolders.forEach { folder in
                                            if (folder.id == pdfFile.folder.id) {
                                                self.loadedFolders.remove(at: i)
                                            }
                                            i += 1
                                        }
                                        self.loadedFolders.append(pdfFile.folder)
                                    }
                                }
                            }
                        }
                        .onChange(of: pdfFileSortOrder) { _, pdfFileSortOrder in
                            uploadPdfFiles.sort(using: pdfFileSortOrder)
                        }
                        .tabItem {
                            Text("Pdf Files (\(uploadPdfFiles.count))")
                        }

                        VStack {
                            Section {
                                /* TextFiles */
                                Table(of: TextFile.self,
                                      selection: $textFileSelection,
                                      sortOrder: $textFileSortOrder) {

                                    TableColumn("fileName") { textFile in
                                        Label((textFile.fileName), systemImage: "doc")
                                            .labelStyle(.titleAndIcon)
                                            .font(.system(size: 11))
                                    }
                                    TableColumn("mimeType") { textFile in
                                        let mimeType = textFile.mimeType
                                        let mimeTypeUnwrapped = mimeType!
                                        Text(mimeTypeUnwrapped)
                                            .labelStyle(.titleAndIcon)
                                            .font(.system(size: 11))
                                    }
                                } rows: {
                                    ForEach(uploadTextFiles) { textFile in
                                        TableRow(textFile)
                                    }
                                }
                            } header: {
                                HStack {
                                    VStack {
                                        Text("Text Files")
                                    }
                                    VStack {
                                        if (selectedTextFiles.count > 0) {
                                            Button(action: deleteSelectedTextFiles) {
                                                Image(systemName: "minus.circle")
                                                    .font(.system(size: 11))
                                                Text("Delete selected \(self.selectedTextFiles.count > 1 ? "Text Files" : "Text File")")
                                                    .font(.system(size: 11))
                                            }
                                            .buttonStyle(.borderedProminent)
                                            .tint(.black)
                                        }
                                    }
                                }
                            }
                        }
                        .tableStyle(.inset(alternatesRowBackgrounds: false))
                        .onChange(of: textFileSelection) {
                            self.selectedTextFiles = []
                            self.selectedFolders = Set()
                            for selectedId in textFileSelection {
                                uploadTextFiles.forEach { textFile in
                                    if textFile.id == selectedId {
                                        self.selectedTextFiles.append(textFile)
                                        if (!self.selectedFolders.contains(textFile.folder.id)) {
                                            self.selectedFolders.insert(textFile.folder.id)
                                        }
                                        var i = 0
                                        self.loadedFolders.forEach { folder in
                                            if (folder.id == textFile.folder.id) {
                                                self.loadedFolders.remove(at: i)
                                            }
                                            i += 1
                                        }
                                        self.loadedFolders.append(textFile.folder)
                                    }
                                }
                            }
                        }
                        .onChange(of: textFileSortOrder) { _, textFileSortOrder in
                            uploadTextFiles.sort(using: textFileSortOrder)
                        }
                        .tabItem {
                            Text("Text Files (\(uploadTextFiles.count))")
                        }
                    }
                    .padding(10)
                }
            case .account:
                /*
                  Account: Sign-Out
                */
                if self.identified && self.myAccount && (!self.newPassword && !self.editPassword && !self.editEmailAddress && !self.newAccount && !self.editAccount) {
                    Button(action: submitDestroySessionForm) {
                        Image(systemName: "xmark")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.primary)
                        Text("Sign-out")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.primary)
                    }
                    .buttonStyle(.plain)
                    .padding(10)
                }
            }
        } detail: {
            if (selectedSideBarItem == .upload) {
                HStack {
                    VStack(spacing: 0) {
                        if (self.selectedFolders.count > 0) {
                            HStack {
                                VStack {
                                    Picker("Folder actions", selection: $selectedFolderAction) {
                                        ForEach(FolderAction.allCases) { action in
                                            Text((action == FolderAction.none) ? "" : action.rawValue.capitalized)
                                                .font(.system(size: 11))
                                        }
                                    }
                                    .pickerStyle(MenuPickerStyle())
                                    .tint(.blue)
                                }.frame(width: 250)
                                Button(action: updateSelectedFolders) {
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 11))
                                    Text("Update \(self.selectedFolders.count > 1 ? "Folders" : "Folder")")
                                        .font(.system(size: 11))
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.blue)
                                Text("\(self.selectedFolders.count) \(self.selectedFolders.count > 1 ? "Folders" : "Folder") selected")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.gray)
                                    .truncationMode(.middle)
                            }
                            .frame(height: 30)
                            .padding(5)
                        }

                        List {
                            /*
                              ImageFile
                            */
                            ForEach(self.selectedImageFiles) { imageFile in
                                Section {

                                    Spacer()

                                    Label {
                                        Link("\(imageFile.folder.name)", destination: URL(string: imageFile.folder.webUrl)!)
                                            .font(.system(size: 11))
                                            .truncationMode(.middle)
                                            .tint(.blue)
                                    } icon: {
                                        Rectangle()
                                            .fill(imageFile.folder.state == "published" ? .yellow : .gray)
                                            .frame(width: 8, height: 8)
                                    }

                                    AsyncImage(url: URL(string: imageFile.fileUrl)) { result in
                                        result.image?
                                            .resizable()
                                            .scaledToFill()
                                    }
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                                    HStack {
                                        Image(systemName: "photo")
                                            .font(.system(size: 13))

                                        Link("\(imageFile.fileName)", destination: URL(string: imageFile.webUrl)!)
                                            .font(.system(size: 13))
                                            .truncationMode(.middle)
                                            .tint(.blue)
                                    }

                                    VStack(alignment: .leading, spacing: 0) {

                                        Label {
                                            Text("Mime/Type \(imageFile.mimeType ?? "")")
                                                .font(.system(size: 11))
                                                .foregroundStyle(.gray)
                                        } icon: {
                                            Rectangle()
                                                .fill(.gray)
                                                .frame(width: 8, height: 8)
                                        }

                                        Label {
                                            Text("Format \(imageFile.formatInfo ?? "")")
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

                                        Label {
                                            Text("Dimensions \(imageFile.dimensions ?? "")")
                                                .font(.system(size: 11))
                                                .foregroundStyle(.gray)
                                        } icon: {
                                            Rectangle()
                                                .fill(.gray)
                                                .frame(width: 8, height: 8)
                                        }

                                        Label {
                                            Text("Megapixels \(imageFile.megapixels ?? 0)")
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
                                            Link("File URL", destination: URL(string: imageFile.fileUrl)!)
                                                .font(.system(size: 11))
                                                .tint(.blue)
                                        } icon: {
                                            Rectangle()
                                                .fill(.gray)
                                                .frame(width: 8, height: 8)
                                        }
                                    }
                                    .frame(minWidth: 0, maxWidth: .infinity, alignment: .topLeading)
                                    .padding(5)

                                    Spacer()
                                }
                            }
                            .listRowSeparator(.hidden)
                            .listRowBackground(Ellipse()
                                .background(Color.black)
                                .foregroundColor(Color.clear)
                                .opacity(0.25)
                            )

                            
                            /*
                              AudioFile
                            */
                            ForEach(self.selectedAudioFiles) { audioFile in
                                Section {
                                    Spacer()

                                    Label {
                                        Link("\(audioFile.folder.name)", destination: URL(string: audioFile.folder.webUrl)!)
                                            .font(.system(size: 11))
                                            .truncationMode(.middle)
                                            .tint(.blue)
                                    } icon: {
                                        Rectangle()
                                            .fill(audioFile.folder.state == "published" ? .yellow : .gray)
                                            .frame(width: 8, height: 8)
                                    }

                                    if (audioFile.aasmState == "created") {
                                        Text("Processing…")
                                            .font(.system(size: 13))
                                            .padding(10)
                                    } else if (audioFile.aasmState == "processed") {
                                        VideoPlayer(player: player)
                                            .frame(minWidth: 400, maxWidth: .infinity,
                                                   minHeight: 150, maxHeight: .infinity)
                                            .padding(10)
                                    }

                                    HStack {
                                        Image(systemName: "waveform.circle")
                                            .font(.system(size: 13))

                                        Link("\(audioFile.fileName)", destination: URL(string: audioFile.webUrl)!)
                                            .font(.system(size: 13))
                                            .truncationMode(.middle)
                                            .tint(.blue)
                                    }

                                    VStack(alignment: .leading, spacing: 0) {
                                        Label {
                                            Text("Format \(audioFile.formatInfo ?? "")")
                                                .font(.system(size: 11))
                                                .foregroundStyle(.gray)
                                        } icon: {
                                            Rectangle()
                                                .fill(.gray)
                                                .frame(width: 8, height: 8)
                                        }

                                        Label {
                                            Text("Mime/Type \(audioFile.mimeType ?? "")")
                                                .font(.system(size: 11))
                                                .foregroundStyle(.gray)
                                        } icon: {
                                            Rectangle()
                                                .fill(.gray)
                                                .frame(width: 8, height: 8)
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

                                        Label {
                                            Text("Title \(audioFile.title ?? "")")
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

                                        Label {
                                            Link("File URL", destination: URL(string: audioFile.fileUrl)!)
                                                .font(.system(size: 11))
                                                .tint(.blue)
                                        } icon: {
                                            Rectangle()
                                                .fill(.gray)
                                                .frame(width: 8, height: 8)
                                        }

                                        Label {
                                            Link("Web URL", destination: URL(string: audioFile.webUrl)!)
                                                .font(.system(size: 11))
                                                .tint(.blue)
                                        } icon: {
                                            Rectangle()
                                                .fill(.gray)
                                                .frame(width: 8, height: 8)
                                        }
                                    }
                                    .frame(minWidth: 0, maxWidth: .infinity, alignment: .topLeading)
                                    .padding(5)

                                    Spacer()
                                }
                            }
                            .listRowSeparator(.hidden)
                            .listRowBackground(Ellipse()
                                .background(Color.black)
                                .foregroundColor(Color.clear)
                                .opacity(0.25)
                            )

                            /*
                              VideoFile
                            */
                            ForEach(self.selectedVideoFiles) { videoFile in
                                Section {
                                    Spacer()

                                    Label {
                                        Link("\(videoFile.folder.name)", destination: URL(string: videoFile.folder.webUrl)!)
                                            .font(.system(size: 11))
                                            .truncationMode(.middle)
                                            .tint(.blue)
                                    } icon: {
                                        Rectangle()
                                            .fill(videoFile.folder.state == "published" ? .yellow : .gray)
                                            .frame(width: 8, height: 8)
                                    }.padding(5)

                                    if (videoFile.aasmState == "created") {
                                        Text("Processing…")
                                            .font(.system(size: 13))
                                            .padding(10)
                                    } else if (videoFile.aasmState == "processed") {
                                        VideoPlayer(player: player)
                                            .frame(minWidth: 400, maxWidth: .infinity,
                                                   minHeight: 300, maxHeight: .infinity)
                                            .padding(10)
                                    }

                                    HStack {
                                        Image(systemName: "video.circle")
                                            .font(.system(size: 13))

                                        Link("\(videoFile.fileName)", destination: URL(string: videoFile.webUrl)!)
                                            .font(.system(size: 13))
                                            .truncationMode(.middle)
                                            .tint(.blue)
                                    }

                                    VStack(alignment: .leading, spacing: 0) {
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
                                            Text("Mime/Type \(videoFile.mimeType ?? "")")
                                                .font(.system(size: 11))
                                                .foregroundStyle(.gray)
                                        } icon: {
                                            Rectangle()
                                                .fill(.gray)
                                                .frame(width: 8, height: 8)
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

                                        Label {
                                            Text("Title \(videoFile.title ?? "")")
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

                                        Label {
                                            Link("File URL", destination: URL(string: videoFile.fileUrl)!)
                                                .font(.system(size: 11))
                                                .tint(.blue)
                                        } icon: {
                                            Rectangle()
                                                .fill(.gray)
                                                .frame(width: 8, height: 8)
                                        }

                                        Label {
                                            Link("Web URL", destination: URL(string: videoFile.webUrl)!)
                                                .font(.system(size: 11))
                                                .tint(.blue)
                                        } icon: {
                                            Rectangle()
                                                .fill(.gray)
                                                .frame(width: 8, height: 8)
                                        }
                                    }
                                    .frame(minWidth: 0, maxWidth: .infinity, alignment: .topLeading)
                                    .padding(5)

                                    Spacer()
                                }
                            }
                            .listRowSeparator(.hidden)
                            .listRowBackground(Ellipse()
                                .background(Color.black)
                                .foregroundColor(Color.clear)
                                .opacity(0.25)
                            )

                            /*
                              PdfFile
                            */
                            ForEach(self.selectedPdfFiles) { pdfFile in
                                Section {
                                    Spacer()

                                    Label {
                                        Link("\(pdfFile.folder.name)", destination: URL(string: pdfFile.folder.webUrl)!)
                                            .font(.system(size: 11))
                                            .truncationMode(.middle)
                                            .tint(.blue)
                                    } icon: {
                                        Rectangle()
                                            .fill(pdfFile.folder.state == "published" ? .yellow : .gray)
                                            .frame(width: 8, height: 8)
                                    }.padding(5)

                                    Image(systemName: "square.text.square")
                                        .font(.system(size: 40))
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(10)

                                    HStack {
                                        Image(systemName: "doc.circle.fill")
                                            .font(.system(size: 13))

                                        Link("\(pdfFile.fileName)", destination: URL(string: pdfFile.webUrl)!)
                                            .font(.system(size: 13))
                                            .truncationMode(.middle)
                                            .tint(.blue)
                                    }

                                    VStack(alignment: .leading, spacing: 5) {
                                        Label {
                                            Text("Mime/Type \(pdfFile.mimeType ?? "")")
                                                .font(.system(size: 11))
                                                .foregroundStyle(.gray)
                                        } icon: {
                                            Rectangle()
                                                .fill(.gray)
                                                .frame(width: 8, height: 8)
                                        }

                                        Label {
                                            Text("Format \(pdfFile.formatInfo ?? "")")
                                                .font(.system(size: 11))
                                                .foregroundStyle(.gray)
                                        } icon: {
                                            Rectangle()
                                                .fill(.gray)
                                                .frame(width: 8, height: 8)
                                        }

                                        Label {
                                            Text("File Size \(pdfFile.fileSize ?? "")")
                                                .font(.system(size: 11))
                                                .foregroundStyle(.gray)
                                        } icon: {
                                            Rectangle()
                                                .fill(.gray)
                                                .frame(width: 8, height: 8)
                                        }

                                        Label {
                                            Link("File URL", destination: URL(string: pdfFile.fileUrl)!)
                                                .font(.system(size: 11))
                                                .tint(.blue)
                                        } icon: {
                                            Rectangle()
                                                .fill(.gray)
                                                .frame(width: 8, height: 8)
                                        }

                                        Label {
                                            Link("Web URL", destination: URL(string: pdfFile.webUrl)!)
                                                .font(.system(size: 11))
                                                .tint(.blue)
                                        } icon: {
                                            Rectangle()
                                                .fill(.gray)
                                                .frame(width: 8, height: 8)
                                        }

                                        Spacer()

                                        Divider()

                                        Spacer()

                                        Button(action: {
                                            if let url = URL(string: pdfFile.webViewUrl) {
                                                openURL(url)
                                            }
                                        }) {
                                            Image(systemName: "globe")
                                                .font(.system(size: 11))

                                            Text("Open in web view")
                                                .font(.system(size: 11))
                                        }
                                        .buttonStyle(.borderedProminent)
                                        .tint(.blue)
                                        .padding(5)
                                    }
                                    .frame(minWidth: 0, maxWidth: .infinity, alignment: .topLeading)
                                    .padding(5)

                                    Spacer()
                                }
                            }
                            .listRowSeparator(.hidden)
                            .listRowBackground(Ellipse()
                                .background(Color.black)
                                .foregroundColor(Color.clear)
                                .opacity(0.25)
                            )

                            /*
                              TextFile
                            */
                            ForEach(self.selectedTextFiles) { textFile in

                                Section {
                                    Spacer()

                                    Label {
                                        Link("\(textFile.folder.name)", destination: URL(string: textFile.folder.webUrl)!)
                                            .font(.system(size: 11))
                                            .truncationMode(.middle)
                                            .tint(.blue)
                                    } icon: {
                                        Rectangle()
                                            .fill(textFile.folder.state == "published" ? .yellow : .gray)
                                            .frame(width: 8, height: 8)
                                    }.padding(5)

                                    HStack {
                                        Image(systemName: "doc.circle")
                                            .font(.system(size: 13))

                                        Link("\(textFile.fileName)", destination: URL(string: textFile.webUrl)!)
                                            .font(.system(size: 13))
                                            .truncationMode(.middle)
                                            .tint(.blue)
                                    }

                                    VStack(alignment: .leading, spacing: 5) {
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

                                        Label {
                                            Text("File Size \(textFile.fileSize ?? "")")
                                                .font(.system(size: 11))
                                                .foregroundStyle(.gray)
                                        } icon: {
                                            Rectangle()
                                                .fill(.gray)
                                                .frame(width: 8, height: 8)
                                        }

                                        Label {
                                            Link("File URL", destination: URL(string: textFile.fileUrl)!)
                                                .font(.system(size: 11))
                                                .tint(.blue)
                                        } icon: {
                                            Rectangle()
                                                .fill(.gray)
                                                .frame(width: 8, height: 8)
                                        }

                                        Label {
                                            Link("Web URL", destination: URL(string: textFile.webUrl)!)
                                                .font(.system(size: 11))
                                                .tint(.blue)
                                        } icon: {
                                            Rectangle()
                                                .fill(.gray)
                                                .frame(width: 8, height: 8)
                                        }

                                        Spacer()

                                        Divider()

                                        Spacer()

                                        Button(action: {
                                            if let url = URL(string: textFile.webViewUrl) {
                                                openURL(url)
                                            }
                                        }) {
                                            Image(systemName: "globe")
                                                .font(.system(size: 11))

                                            Text("Open in web view")
                                                .font(.system(size: 11))
                                        }
                                        .buttonStyle(.borderedProminent)
                                        .tint(.blue)
                                        .padding(5)
                                    }
                                    .frame(minWidth: 0, maxWidth: .infinity, alignment: .topLeading)
                                    .padding(5)

                                    Spacer()
                                }
                            }
                            .listRowSeparator(.hidden)
                            .listRowBackground(Ellipse()
                                .background(Color.black)
                                .foregroundColor(Color.clear)
                                .opacity(0.25)
                            )
                        }

                        /*
                          Folders, Attachments: Clear selection
                        */
                        if (self.selectedImageFiles.count > 0 ||
                            self.selectedAudioFiles.count > 0 ||
                            self.selectedPdfFiles.count > 0 ||
                            self.selectedVideoFiles.count > 0 ||
                            self.selectedTextFiles.count > 0 ||
                            self.selectedFolders.count > 0) {

                            HStack {
                                Button(action: clearSelection) {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 9))
                                        .foregroundStyle(Color.primary)
                                    Text("Clear selection")
                                        .font(.system(size: 9))
                                        .foregroundStyle(Color.primary)
                                }.buttonStyle(.bordered)
                            }
                            .padding(5)
                        }
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
