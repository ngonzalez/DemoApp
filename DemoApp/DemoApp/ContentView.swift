/*
    Copyright 2024,2025 Nicolas GONZALEZ

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

/* VideoPlayer */
import AVKit

/* GzipSwift */
import Gzip

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
//    @State private var backendURL:String = "https://link12.ddns.net:4040/upload"
    @State private var backendURL:String = "http://127.0.0.1:3002/upload"

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

    struct UserWithpassword: Codable, Identifiable {
        let id: Int?
        let uuid: UUID
        let password: String?
        let passwordConfirmation: String?
        let errors: [String]?
    }

    /* Account */
    @State var myAccount:Bool = Bool(false)    // My Account

    @State private var signedInUser: User?
    @State private var identified:Bool = Bool(false)

    @State var newSession:Bool = Bool(true)    // Sign-In
    @State var newSessionComplete:Bool = Bool(false)

    @State var newPassword:Bool = Bool(false)  // Reset Password
    @State var newPasswordComplete:Bool = Bool(false)

    @State var newAccount:Bool = Bool(false)   // Register Account
    @State var newAccountComplete:Bool = Bool(false)

    @State var editAccount:Bool = Bool(false)  // Edit Account
    @State var editAccountComplete:Bool = Bool(false)

    @State var editPassword:Bool = Bool(false) // Edit Password
    @State var editPasswordComplete:Bool = Bool(false)

    /* Register Account */
    @State var newAccountSuccessMessage:Message = Message(message: String())

    @State var newAccountValidationErrors:String = String()

    @State private var firstNameRegistrationForm: String = String()

    @State private var lastNameRegistrationForm: String = String()

    @State private var emailAddressRegistrationForm: String = String()

    @State private var passwordRegistrationForm: String = String()

    /* New Session */
    @State var newSessionSuccessMessage:Message = Message(message: String())

    @State var newSessionValidationErrors:String = String()

    @State private var emailAddressSessionForm: String = String()

    @State private var passwordSessionForm: String = String()

    /* Destroy Session */
    @State var destroySessionFormResponse:Message = Message(message: String())

    /* New Password */
    @State private var emailAddressPasswordForm: String = String()

    @State var newPasswordSuccessMessage:Message = Message(message: String())

    @State var newPasswordValidationErrors:String = String()

    /* Edit Password */
    @State var editPasswordSuccessMessage:Message = Message(message: String())

    @State private var newPasswordEditPasswordForm: String = String()

    @State private var newPasswordConfirmationEditPasswordForm: String = String()

    @State var editPasswordValidationErrors:String = String()

    /* Edit Account */
    @State var editAccountSuccessMessage:Message = Message(message: String())

    @State var editAccountValidationErrors:String = String()

    @State private var firstNameAccountForm: String = String()

    @State private var lastNameAccountForm: String = String()

    @State private var emailAddressAccountForm: String = String()

    @State private var createdAtAccountForm: String = String()

    @State private var updatedAtAccountForm: String = String()

//    @State private var accountURL:String = "https://appshare.site:4040/account"
//    @State private var accountURL:String = "https://link12.ddns.net:4040/account"
    @State private var accountURL:String = "http://127.0.0.1:3002/account"

//    @State private var registrationURL:String = "https://appshare.site:4040/registration"
//    @State private var registrationURL:String = "https://link12.ddns.net:4040/registration"
    @State private var registrationURL:String = "http://127.0.0.1:3002/registration"

//    @State private var sessionURL:String = "https://appshare.site:4040/session"
//    @State private var sessionURL:String = "https://link12.ddns.net:4040/session"
    @State private var sessionURL:String = "http://127.0.0.1:3002/session"

//    @State private var passwordURL:String = "https://appshare.site:4040/password"
//    @State private var passwordURL:String = "https://link12.ddns.net:4040/password"
    @State private var passwordURL:String = "http://127.0.0.1:3002/password"

    func newPutRequest(url: URL, data: Data, postLength: String) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
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
        request.addValue("gzip, deflate", forHTTPHeaderField: "Content-Encoding")

        return request
    }

    func newDeleteRequest(url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        return request
    }

    struct UserResponseWithMessage: Codable {
        let user: User?
        let message: String?
    }

    struct Message: Codable {
        let message: String?
    }

    func submitAccountForm() {
        do {
            let user = User(
                id: self.signedInUser?.id,
                uuid: UUID(),
                firstName: firstNameAccountForm,
                lastName: lastNameAccountForm,
                emailAddress: emailAddressAccountForm,
                password: "",
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

    func submitRegistrationForm() {
        do {
            let user = User(
                id: nil,
                uuid: UUID(),
                firstName: firstNameRegistrationForm,
                lastName: lastNameRegistrationForm,
                emailAddress: emailAddressRegistrationForm,
                password: passwordRegistrationForm,
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

    func submitSessionForm() {
        do {
            let user = User(
                id: nil,
                uuid: UUID(),
                firstName: nil,
                lastName: nil,
                emailAddress: emailAddressSessionForm,
                password: passwordSessionForm,
                createdAt: nil,
                updatedAt: nil,
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
                    }
                }

            } catch let error {
                logger.error("[submitDestroySessionForm] Request: \(error)")
            }
        }

        task.resume()
    }

    func submitNewPasswordForm() {
        do {
            let user = User(
                id: nil,
                uuid: UUID(),
                firstName: nil,
                lastName: nil,
                emailAddress: emailAddressPasswordForm,
                password: nil,
                createdAt: nil,
                updatedAt: nil,
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

    func submitEditPasswordForm() {
        do {
            let user = UserWithpassword(
                id: self.signedInUser?.id,
                uuid: UUID(),
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

        // reset forms
        resetValuesNewSession()

        // enable buttons
        self.newSessionComplete = false
    }

    func clickEditAccount() {
        self.editAccount = true

        let emailAddress = self.signedInUser?.emailAddress
        if (emailAddress != nil) {
            let emailAddressUnwrapped = emailAddress!
            self.emailAddressAccountForm = emailAddressUnwrapped
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

    func resetValuesNewSession() {
//        self.newSession = false
        self.newSessionComplete = true

        self.myAccount = true
        self.newAccount = false
        self.newPassword = false
        self.editPassword = false
        self.editAccount = false

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

        // reset errors
        self.editAccountValidationErrors = String()

        // reset message
        self.editAccountSuccessMessage = Message(message: String())

        // reset values
        self.firstNameAccountForm = String()
        self.lastNameAccountForm = String()
        self.emailAddressAccountForm = String()
    }

    func backToMyAccount() {
        // enable my account
        self.myAccount = true

        // disable other sections
        self.newAccount = false
        self.newPassword = false
        self.editPassword = false
        self.editAccount = false

        // reset forms
        resetValuesEditAccount()
        resetValuesEditPassword()
        resetValuesNewSession()

        // enable buttons again
        self.newPasswordComplete = false
        self.editPasswordComplete = false
        self.newAccountComplete = false
        self.editAccountComplete = false
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

    func deleteSelectedFolders() {
    }

    func deleteSelectedImages() {
    }

    func deleteSelectedAudioFiles() {
    }

    func deleteSelectedVideoFiles() {
    }

    func deleteSelectedPdfs() {
    }

    func deleteSelectedTexts() {
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
//    @State private var serviceURL:String = "https://link12.ddns.net:5050"
    @State private var serviceURL:String = "http://127.0.0.1:3001"

    func getVideoStream(videoFile: VideoFile) {
        let delegateClass = NetworkDelegateClass()
        let delegateSession = URLSession(configuration: .default, delegate: delegateClass, delegateQueue: nil)
        let url = URL(string: "\(serviceURL)/video_files/\(videoFile.id).json")!
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
        let url = URL(string: "\(serviceURL)/audio_files/\(audioFile.id).json")!
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

    func displayImageFileMimeType(imageFile: ImageFile) -> Text {
        Text("Mime/Type: \(imageFile.mimeType!)")
            .font(.system(size: 11))
    }

    struct FolderIds: Codable {
        var id: Array<Int>
    }

//    @State private var publishURL:String = "https://link12.ddns.net:4040/folders/publish"
    @State private var publishURL:String = "http://127.0.0.1:3002/folders/publish"

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

//    @State private var unpublishURL:String = "https://link12.ddns.net:4040/folders/unpublish"
    @State private var unpublishURL:String = "http://127.0.0.1:3002/folders/unpublish"

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

                                SecureField(text: $newPasswordEditPasswordForm, prompt: Text("Password")) {
                                    Text("Passowrd")
                                }
                                .disableAutocorrection(true)

                                SecureField(text: $newPasswordConfirmationEditPasswordForm, prompt: Text("Password confirmation")) {
                                    Text("Password confirmation")
                                }
                                .disableAutocorrection(true)

                                if (self.editPasswordComplete) {
                                    Button(action: submitEditPasswordForm) {
                                        Text("Submit")
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    .disabled(true)
                                } else {
                                    Button(action: submitEditPasswordForm) {
                                        Text("Submit")
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }

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

                                let firstName = self.signedInUser?.firstName
                                if (firstName != nil) {
                                    let firstNameUnWrapped:String = firstName!
                                    TextField(text: $firstNameAccountForm, prompt: Text(firstNameUnWrapped)) {
                                        Text("First Name")
                                    }
                                    .disableAutocorrection(true)
                                }

                                let lastName = self.signedInUser?.lastName
                                if (lastName != nil) {
                                    let lastNameUnWrapped:String = lastName!
                                    TextField(text: $lastNameAccountForm, prompt: Text(lastNameUnWrapped)) {
                                        Text("Last Name")
                                    }
                                    .disableAutocorrection(true)
                                }

                                let emailAddress = self.signedInUser?.emailAddress
                                if (emailAddress != nil) {
                                    let emailAddressUnWrapped:String = emailAddress!
                                    TextField(text: $emailAddressAccountForm, prompt: Text(emailAddressUnWrapped)) {
                                        Text("Email Address")
                                    }
                                    .disableAutocorrection(true)
                                    .disabled(true)
                                }

                                let createdAt = self.signedInUser?.createdAt
                                if (createdAt != nil) {
                                    let createdAtUnwrapped = createdAt!
//                                    let createdAtFormatted = formatter.string(from: createdAtUnwrapped)
                                    TextField(text: $createdAtAccountForm, prompt: Text(createdAtUnwrapped)) {
                                        Text("Created At")
                                    }
                                    .disableAutocorrection(true)
                                    .disabled(true)
                                }

                                let updatedAt = self.signedInUser?.updatedAt
                                if (updatedAt != nil) {
                                    let updatedAtUnwrapped = updatedAt!
//                                    let updatedAtFormatted = formatter.string(from: updatedAtUnwrapped)
                                    TextField(text: $updatedAtAccountForm, prompt: Text(updatedAtUnwrapped)) {
                                        Text("Updated At")
                                    }
                                    .disableAutocorrection(true)
                                    .disabled(true)
                                }

                                if (self.editAccountComplete) {
                                    Button(action: submitAccountForm) {
                                        Text("Submit")
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    .disabled(true)
                                } else {
                                    Button(action: submitAccountForm) {
                                        Text("Submit")
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }

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

                        // account panel

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
                    }

                } else if self.newPassword {

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

                            if (self.newPasswordComplete) {
                                Button(action: submitNewPasswordForm) {
                                    Text("Submit")
                                }
                                .buttonStyle(PlainButtonStyle())
                                .disabled(true)
                            } else {
                                Button(action: submitNewPasswordForm) {
                                    Text("Submit")
                                }
                                .buttonStyle(PlainButtonStyle())
                            }

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

                            TextField(text: $firstNameRegistrationForm, prompt: Text("John")) {
                                Text("First Name")
                            }
                            .disableAutocorrection(true)

                            TextField(text: $lastNameRegistrationForm, prompt: Text("Appleseed")) {
                                Text("Last Name")
                            }
                            .disableAutocorrection(true)

                            TextField(text: $emailAddressRegistrationForm, prompt: Text("johnatan@apple.com")) {
                                Text("Email")
                            }
                            .disableAutocorrection(true)

                            SecureField(text: $passwordRegistrationForm, prompt: Text("Required")) {
                                Text("Password")
                            }
                            .disableAutocorrection(true)

                            if (self.newAccountComplete) {
                                Button(action: submitRegistrationForm) {
                                    Text("Submit")
                                }
                                .buttonStyle(PlainButtonStyle())
                                .disabled(true)
                            } else {
                                Button(action: submitRegistrationForm) {
                                    Text("Submit")
                                }
                                .buttonStyle(PlainButtonStyle())
                            }

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

                            SecureField(text: $passwordSessionForm, prompt: Text("Required")) {
                                Text("Password")
                            }
                            .disableAutocorrection(true)

                            if (self.newSessionComplete) {
                                Button(action: submitSessionForm) {
                                    Text("Submit")
                                }
                                .buttonStyle(PlainButtonStyle())
                                .disabled(true)
                            } else {
                                Button(action: submitSessionForm) {
                                    Text("Submit")
                                }
                                .buttonStyle(PlainButtonStyle())
                            }

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
                                        .font(.system(size: 20))
                                        .symbolEffect(.bounce, options: .repeat(1))
                                        .padding(10)
                                } else {
                                    Image(systemName: "square.grid.3x1.folder.badge.plus")
                                        .font(.system(size: 20))
                                        .padding(10)
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
                        Button(action: getAllUploads) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 20))
                        }
                    }

                    Section {
                        Table(of: Folder.self,
                              selection: $folderSelection,
                              sortOrder: $folderSortOrder) {

                            TableColumn("name") { folder in
                                Label("\(folder.name)",
                                      systemImage: "folder")
                                .foregroundStyle(.primary)
                                .labelStyle(.titleAndIcon)
                                .font(.system(size: 11))
                            }

                            TableColumn("state") { folder in
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
                        .onChange(of: folderSelection) {
                            self.selectedFolders = []
                            for selectedId in folderSelection {
                                loadedFolders.forEach { folder in
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
                                        Label((imageFile.fileName), systemImage: "doc")
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
                                        Text("Image")
                                    }
                                    VStack {
                                        if (selectedImageFiles.count > 0) {
                                            Button(action: deleteSelectedImages) {
                                                Text("Delete selected \(selectedImageFiles.count) images")
                                                    .font(.system(size: 11))
                                                    .foregroundStyle(Color.gray)
                                            }
                                            .buttonStyle(.accessoryBarAction)
                                        }
                                    }
                                }
                            }
                        }
                        .tableStyle(.inset(alternatesRowBackgrounds: false))
                        .onChange(of: imageFileSelection) {
                            self.selectedImageFiles = []
                            for selectedId in imageFileSelection {
                                uploadImageFiles.forEach { imageFile in
                                    if imageFile.id == selectedId {
                                        self.selectedImageFiles.append(imageFile)
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
                            Text("Image (\(uploadImageFiles.count))")
                        }

                        VStack {
                            Section {
                                /* PdfFiles */
                                Table(of: PdfFile.self,
                                      selection: $pdfFileSelection,
                                      sortOrder: $pdfFileSortOrder) {

                                    TableColumn("fileName") { pdfFile in
                                        Label(pdfFile.fileName, systemImage: "document")
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
                                        Text("Pdf")
                                    }
                                    VStack {
                                        if (selectedPdfFiles.count > 0) {
                                            Button(action: deleteSelectedPdfs) {
                                                Text("Delete selected \(selectedPdfFiles.count) pdf files")
                                                    .font(.system(size: 11))
                                                    .foregroundStyle(Color.gray)
                                            }
                                            .buttonStyle(.accessoryBarAction)
                                        }
                                    }
                                }
                            }
                        }
                        .tableStyle(.inset(alternatesRowBackgrounds: false))
                        .onChange(of: pdfFileSelection) {
                            self.selectedPdfFiles = []
                            for selectedId in pdfFileSelection {
                                uploadPdfFiles.forEach { pdfFile in
                                    if pdfFile.id == selectedId {
                                        self.selectedPdfFiles.append(pdfFile)
//                                        displayPdf(pdfFile: pdfFile)
                                    }
                                }
                            }
                        }
                        .onChange(of: pdfFileSortOrder) { _, pdfFileSortOrder in
                            uploadPdfFiles.sort(using: pdfFileSortOrder)
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
                                        Label((audioFile.fileName), systemImage: "doc")
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
                                        Text("Audio")
                                    }
                                    VStack {
                                        if (selectedAudioFiles.count > 0) {
                                            Button(action: deleteSelectedAudioFiles) {
                                                Text("Delete selected \(selectedAudioFiles.count) audio files")
                                                    .font(.system(size: 11))
                                                    .foregroundStyle(Color.gray)
                                            }
                                            .buttonStyle(.accessoryBarAction)
                                        }
                                    }
                                }
                            }
                        }
                        .tableStyle(.inset(alternatesRowBackgrounds: false))
                        .onChange(of: audioFileSelection) { _, audioFileSelection in
                            self.selectedAudioFiles = []
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
                                        displayAudio(audioFile: audioFile)
                                    }
                                }
                            }
                        }
                        .onChange(of: audioFileSortOrder) { _, audioFileSortOrder in
                            uploadAudioFiles.sort(using: audioFileSortOrder)
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
                                        Label((videoFile.fileName), systemImage: "doc")
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
                                        Text("Video")
                                    }
                                    VStack {
                                        if (selectedVideoFiles.count > 0) {
                                            Button(action: deleteSelectedVideoFiles) {
                                                Text("Delete selected \(selectedVideoFiles.count) video files")
                                                    .font(.system(size: 11))
                                                    .foregroundStyle(Color.gray)
                                            }
                                            .buttonStyle(.accessoryBarAction)
                                        }
                                    }
                                }
                            }
                        }
                        .tableStyle(.inset(alternatesRowBackgrounds: false))
                        .onChange(of: videoFileSelection) {
                            self.selectedVideoFiles = []
                            for selectedId in videoFileSelection {
                                uploadVideoFiles.forEach { videoFile in
                                    if videoFile.id == selectedId {
                                        self.selectedVideoFiles.append(videoFile)
                                        displayVideo(videoFile: videoFile)
                                    }
                                }
                            }
                        }
                        .onChange(of: videoFileSortOrder) { _, videoFileSortOrder in
                            uploadVideoFiles.sort(using: videoFileSortOrder)
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
                                        Label((textFile.fileName), systemImage: "doc")
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
                                        Text("Text")
                                    }
                                    VStack {
                                        if (selectedTextFiles.count > 0) {
                                            Button(action: deleteSelectedTexts) {
                                                Text("Delete selected \(selectedTextFiles.count) text files")
                                                    .font(.system(size: 11))
                                                    .foregroundStyle(Color.gray)
                                            }
                                            .buttonStyle(.accessoryBarAction)
                                        }
                                    }
                                }
                            }
                        }
                        .tableStyle(.inset(alternatesRowBackgrounds: false))
                        .onChange(of: textFileSelection) {
                            self.selectedTextFiles = []
                            for selectedId in textFileSelection {
                                uploadTextFiles.forEach { textFile in
                                    if textFile.id == selectedId {
                                        self.selectedTextFiles.append(textFile)
//                                        displayText(textFile: textFile)
                                    }
                                }
                            }
                        }
                        .onChange(of: textFileSortOrder) { _, textFileSortOrder in
                            uploadTextFiles.sort(using: textFileSortOrder)
                        }
                        .tabItem {
                            Text("Text (\(uploadTextFiles.count))")
                        }
                    }
                    .padding(.horizontal, 5)
                }
            case .account:
                if self.identified && self.myAccount && (!self.newPassword && !self.editPassword && !self.newAccount && !self.editAccount) {

                    Button(action: submitDestroySessionForm) {
                        Image(systemName: "xmark")
                            .font(.system(size: 9))
                            .foregroundStyle(Color.primary)
                        Text("Sign-out")
                            .font(.system(size: 9))
                            .foregroundStyle(Color.primary)
                    }
                    .buttonStyle(.bordered)
                    .padding(10)
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

                                ForEach(self.loadedFolders) { folder in
                                    if (self.selectedFolders.contains(folder.id) && String(folder.name) != "") {
                                        Label {
                                            Text("\(folder.name)")
                                                .font(.system(size: 11))
                                                .foregroundStyle(.gray)
                                        } icon: {
                                           Rectangle()
                                               .fill(.gray)
                                               .frame(width: 8, height: 8)
                                        }
                                    }
                                }

                                Button(action: publishSelectedFolders) {
                                    Image(systemName: "newspaper")
                                        .font(.system(size: 11))
                                    Text("Publish selected \(self.selectedFolders.count) Folders")
                                        .font(.system(size: 11))
                                        .foregroundStyle(Color.white)
                                }
                                .buttonStyle(.accessoryBarAction)

                                Button(action: unpublishSelectedFolders) {
                                    Text("Unpublish selected \(self.selectedFolders.count) Folders")
                                        .font(.system(size: 11))
                                        .foregroundStyle(Color.gray)
                                }
                                .buttonStyle(.accessoryBarAction)

                                Button(action: deleteSelectedFolders) {
                                    Text("Delete selected \(self.selectedFolders.count) Folders")
                                        .font(.system(size: 11))
                                        .foregroundStyle(Color.gray)
                                }
                                .buttonStyle(.accessoryBarAction)
                            }

                            ForEach(self.selectedImageFiles) { imageFile in

                                let fileName = imageFile.fileName
                                Label(fileName,
                                     systemImage: "photo.circle")
                                   .labelStyle(.titleAndIcon)
                                   .font(.system(size: 13))

                                let fileUrl = imageFile.fileUrl
                                AsyncImage(url: URL(string: fileUrl)) { result in
                                   result.image?
                                       .resizable()
                                       .scaledToFill()
                                }
                                .frame(maxWidth: .infinity, maxHeight: .infinity)

                                Label {
                                    let mimeType = imageFile.mimeType ?? "--"
                                    Text("Mime/Type \(mimeType)")
                                        .font(.system(size: 11))
                                        .foregroundStyle(.gray)
                                } icon: {
                                   Rectangle()
                                       .fill(.gray)
                                       .frame(width: 8, height: 8)
                                }

                                Label {
                                    let formatInfo = imageFile.formatInfo ?? "--"
                                    Text("Format \(formatInfo)")
                                        .font(.system(size: 11))
                                        .foregroundStyle(.gray)
                                } icon: {
                                   Rectangle()
                                       .fill(.gray)
                                       .frame(width: 8, height: 8)
                                }

                                Label {
                                    let dimensions = imageFile.dimensions ?? "--"
                                    Text("Dimensions \(dimensions)")
                                        .font(.system(size: 11))
                                        .foregroundStyle(.gray)
                                } icon: {
                                   Rectangle()
                                       .fill(.gray)
                                       .frame(width: 8, height: 8)
                                }

                                Label {
                                    let megapixels = imageFile.megapixels ?? 0.1
                                    Text("Megapixels \(megapixels)")
                                        .font(.system(size: 11))
                                        .foregroundStyle(.gray)
                                } icon: {
                                   Rectangle()
                                       .fill(.gray)
                                       .frame(width: 8, height: 8)
                                }

                                Label {
                                    let width = imageFile.width ?? 0
                                    Text("Width \(width)")
                                        .font(.system(size: 11))
                                        .foregroundStyle(.gray)
                                } icon: {
                                   Rectangle()
                                       .fill(.gray)
                                       .frame(width: 8, height: 8)
                                }

                                Label {
                                    let height = imageFile.height ?? 0
                                    Text("Height \(height)")
                                        .font(.system(size: 11))
                                        .foregroundStyle(.gray)
                                } icon: {
                                   Rectangle()
                                       .fill(.gray)
                                       .frame(width: 8, height: 8)
                                }

                                Label {
                                    let fileSize = imageFile.fileSize ?? ""
                                    Text("File Size \(fileSize)")
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

                                let fileName = pdfFile.fileName
                                Label(fileName, systemImage: "doc.circle.fill")
                                    .labelStyle(.titleAndIcon)
                                    .font(.system(size: 13))

                                Label {
                                    let mimeType = pdfFile.mimeType ?? "--"
                                    Text("Mime/Type \(mimeType)")
                                        .font(.system(size: 11))
                                        .foregroundStyle(.gray)
                                } icon: {
                                    Rectangle()
                                        .fill(.gray)
                                        .frame(width: 8, height: 8)
                                }

                                Label {
                                    let formatInfo = pdfFile.formatInfo ?? "--"
                                    Text("Format \(formatInfo)")
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

                                let fileName = audioFile.fileName
                                Label(fileName, systemImage: "waveform.circle")
                                    .labelStyle(.titleAndIcon)
                                    .font(.system(size: 13))

                                if (audioFile.aasmState == "created") {
                                    Text("Processing…")
                                        .padding(10)
                                } else if (audioFile.aasmState == "processed") {
                                    VideoPlayer(player: player)
                                        .frame(minWidth: 400, maxWidth: .infinity,
                                               minHeight: 150, maxHeight: .infinity)
                                        .padding(10)
                                }

                                Label {
                                    let fileSize = audioFile.fileSize ?? 0
                                    Text("File Size \(fileSize)")
                                        .font(.system(size: 11))
                                        .foregroundStyle(.gray)
                                } icon: {
                                    Rectangle()
                                        .fill(.gray)
                                        .frame(width: 8, height: 8)
                                }

                                Label {
                                    let title = audioFile.title ?? "--"
                                    Text("Title \(title)")
                                        .font(.system(size: 11))
                                        .foregroundStyle(.gray)
                                } icon: {
                                    Rectangle()
                                        .fill(.gray)
                                        .frame(width: 8, height: 8)
                                }

                                Label {
                                    let mimeType = audioFile.mimeType ?? "--"
                                    Text("Mime/Type \(mimeType)")
                                        .font(.system(size: 11))
                                        .foregroundStyle(.gray)
                                } icon: {
                                    Rectangle()
                                        .fill(.gray)
                                        .frame(width: 8, height: 8)
                                }

                                Label {
                                    let formatInfo = audioFile.formatInfo ?? "--"
                                    Text("Format \(formatInfo)")
                                        .font(.system(size: 11))
                                        .foregroundStyle(.gray)
                                } icon: {
                                    Rectangle()
                                        .fill(.gray)
                                        .frame(width: 8, height: 8)
                                }

                                Label {
                                    let bitrate = audioFile.bitrate ?? 0
                                    Text("Bitrate \(bitrate)")
                                        .font(.system(size: 11))
                                        .foregroundStyle(.gray)
                                } icon: {
                                    Rectangle()
                                        .fill(.gray)
                                        .frame(width: 8, height: 8)
                                }

                                Label {
                                    let channels = audioFile.channels ?? 0
                                    Text("Channels \(channels)")
                                        .font(.system(size: 11))
                                        .foregroundStyle(.gray)
                                } icon: {
                                    Rectangle()
                                        .fill(.gray)
                                        .frame(width: 8, height: 8)
                                }

                                Label {
                                    let length = audioFile.length ?? 0
                                    Text("Length (ms) \(length)")
                                        .font(.system(size: 11))
                                        .foregroundStyle(.gray)
                                } icon: {
                                    Rectangle()
                                        .fill(.gray)
                                        .frame(width: 8, height: 8)
                                }

                                Label {
                                    let sampleRate = audioFile.sampleRate ?? 0
                                    Text("Sample Rate \(sampleRate)")
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

                                let fileName = videoFile.fileName
                                Label(fileName,
                                      systemImage: "video.circle")
                                    .labelStyle(.titleAndIcon)
                                    .font(.system(size: 13))

                                if (videoFile.aasmState == "created") {
                                    Text("Processing…")
                                        .padding(10)
                                } else if (videoFile.aasmState == "processed") {
                                    VideoPlayer(player: player)
                                        .frame(minWidth: 400, maxWidth: .infinity,
                                               minHeight: 300, maxHeight: .infinity)
                                        .padding(10)
                                }

                                Label {
                                    let fileSize = videoFile.fileSize ?? 0
                                    Text("File Size \(fileSize)")
                                        .font(.system(size: 11))
                                        .foregroundStyle(.gray)
                                } icon: {
                                    Rectangle()
                                        .fill(.gray)
                                        .frame(width: 8, height: 8)
                                }

                                Label {
                                    let title = videoFile.title ?? "--"
                                    Text("Title \(title)")
                                        .font(.system(size: 11))
                                        .foregroundStyle(.gray)
                                } icon: {
                                    Rectangle()
                                        .fill(.gray)
                                        .frame(width: 8, height: 8)
                                }

                                Label {
                                    let mimeType = videoFile.mimeType ?? ""
                                    Text("Mime/Type \(mimeType)")
                                        .font(.system(size: 11))
                                        .foregroundStyle(.gray)
                                } icon: {
                                    Rectangle()
                                        .fill(.gray)
                                        .frame(width: 8, height: 8)
                                }

                                Label {
                                    let formatInfo = videoFile.formatInfo ?? ""
                                    Text("Format \(formatInfo)")
                                        .font(.system(size: 11))
                                        .foregroundStyle(.gray)
                                } icon: {
                                    Rectangle()
                                        .fill(.gray)
                                        .frame(width: 8, height: 8)
                                }

                                Label {
                                    let bitrate = videoFile.bitrate ?? 0
                                    Text("Bitrate \(bitrate)")
                                        .font(.system(size: 11))
                                        .foregroundStyle(.gray)
                                } icon: {
                                    Rectangle()
                                        .fill(.gray)
                                        .frame(width: 8, height: 8)
                                }

                                Label {
                                    let frameRate = videoFile.frameRate ?? 0
                                    Text("FrameRate \(frameRate)")
                                        .font(.system(size: 11))
                                        .foregroundStyle(.gray)
                                } icon: {
                                    Rectangle()
                                        .fill(.gray)
                                        .frame(width: 8, height: 8)
                                }

                                Label {
                                    let length = videoFile.length ?? 0
                                    Text("Length (s) \(length)")
                                        .font(.system(size: 11))
                                        .foregroundStyle(.gray)
                                } icon: {
                                    Rectangle()
                                        .fill(.gray)
                                        .frame(width: 8, height: 8)
                                }

                                Label {
                                    let width = videoFile.width ?? 0
                                    Text("Width \(width)")
                                        .font(.system(size: 11))
                                        .foregroundStyle(.gray)
                                } icon: {
                                    Rectangle()
                                        .fill(.gray)
                                        .frame(width: 8, height: 8)
                                }

                                Label {
                                    let height = videoFile.height ?? 0
                                    Text("Height \(height)")
                                        .font(.system(size: 11))
                                        .foregroundStyle(.gray)
                                } icon: {
                                    Rectangle()
                                        .fill(.gray)
                                        .frame(width: 8, height: 8)
                                }

                                Label {
                                    let aspectRatio = videoFile.aspectRatio ?? 0
                                    Text("Aspect Ratio: \(aspectRatio)")
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

                                let fileName = textFile.fileName
                                Label(fileName, systemImage: "doc.circle")
                                    .labelStyle(.titleAndIcon)
                                    .font(.system(size: 13))

//                                Text("""
//                                    \(textContent)
//                                    """).padding(20)

                                Label {
                                    let mimeType = textFile.mimeType ?? ""
                                    Text("Mime/Type \(mimeType)")
                                        .font(.system(size: 11))
                                        .foregroundStyle(.gray)
                                } icon: {
                                    Rectangle()
                                        .fill(.gray)
                                        .frame(width: 8, height: 8)
                                }

                                Label {
                                    let formatInfo = textFile.formatInfo ?? ""
                                    Text("Format \(formatInfo)")
                                        .font(.system(size: 11))
                                        .foregroundStyle(.gray)
                                } icon: {
                                    Rectangle()
                                        .fill(.gray)
                                        .frame(width: 8, height: 8)
                                }

                                Spacer()

                            }


                        }.padding(20)

                        if (self.selectedImageFiles.count > 0 ||
                            self.selectedAudioFiles.count > 0 ||
                            self.selectedPdfFiles.count > 0 ||
                            self.selectedVideoFiles.count > 0 ||
                            self.selectedTextFiles.count > 0 ||
                            self.selectedFolders.count > 0) {

                            Button(action: clearSelection) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 9))
                                    .foregroundStyle(Color.primary)
                                Text("Clear selection")
                                    .font(.system(size: 9))
                                    .foregroundStyle(Color.primary)
                            }.buttonStyle(.bordered)
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
