/*
    Copyright (c) 2026 Nicolas GONZALEZ

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
import AVKit
import Gzip
import OSLog

// Upload: the synced folders, the uploads and their files, upload events,
// deleting files, folder actions (publish, archive, delete) and search
extension ContentView {
    /// Upload a file of an imported folder straight to the storage, in one
    /// request (`DirectUpload`), then record the upload event. Unsupported
    /// file types are skipped; a failed upload is logged.
    func importItem(itemPath: String, createdAt: Date, updatedAt: Date, uuid: UUID, source: String) async {
        let fileURL = URL(fileURLWithPath: itemPath)
        guard let mimeType = DirectUpload.mimeType(of: fileURL, in: mimeTypes) else { return }

        do {
            let uploadUuid = try await DirectUpload(uploadURL: URL(string: backendURL)!).upload(
                fileURL: fileURL,
                source: source,
                mimeType: mimeType,
                createdAt: createdAt,
                updatedAt: updatedAt
            )

            let fileSize = try fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
            createEvent(url: "\(backendURL)/\(uploadUuid)", eventType: "upload",
                        uploadDetails: UploadDetails(fileSize: fileSize, fileName: itemPath, mimeType: mimeType))
        } catch let error {
            logger.error("[importItem] \(itemPath): \(error.localizedDescription)")
        }
    }

    // Pauses after each file (`await Task.yield()`) so that SwiftUI can redraw
    // the progress bar and the window stays responsive during an import
    func importFolder(folder: URL, item: String) async {

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

                  await importItem(itemPath: itemPath, createdAt: itemCreatedAt, updatedAt: itemUpdatedAt, uuid: uuid, source: "root")
                  await Task.yield()

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

                          await importItem(itemPath: folderItemPath, createdAt: folderItemCreatedAt, updatedAt: folderItemUpdatedAt, uuid: uuid, source: "folder")
                          await Task.yield()

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

                                  await importItem(itemPath: subfolderItemPath, createdAt: subfolderItemCreatedAt, updatedAt: subfolderItemUpdatedAt, uuid: uuid, source: "subfolder")
                                  await Task.yield()

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

    func browseFolder(folder: URL) async {
        let fm = FileManager.default

        do {
            let items = try fm.contentsOfDirectory(atPath: folder.path).filter { $0 != ".DS_Store" }

            for item in items {
                await importFolder(folder: folder, item: item)
            }
        } catch let error {
            logger.error("[browseFolder] Error: \(error)")
        }
    }

    // Import the folders in a task on the main actor (the upload requests read
    // the signed-in user's state): it pauses between files and folders, so the
    // progress bar moves folder by folder. The Import and Clear buttons are
    // disabled meanwhile. The folders stay readable (security scoped access)
    // until they are cleared, so they can be imported again
    func syncFolders() {
        guard !isSyncing else { return }
        isSyncing = true
        progress = Float(0)
        let selectedFolders = folders

        Task { @MainActor in
            defer { isSyncing = false }

            var index = 0
            for folder in selectedFolders {
                do {
                    let attributes = try FileManager.default.attributesOfItem(atPath: folder.path)
                    let fsItemType:String = attributes[FileAttributeKey.type] as! String
                    if (fsItemType == "NSFileTypeDirectory") {
                        await browseFolder(folder: folder)
                    }
                } catch {
                    logger.error("[syncFolders] Error: \(error)")
                }

                // Set progress
                index += 1
                progress = Float(index) / Float(selectedFolders.count)
                await Task.yield()
            }
        }
    }

    // Forget the selected folders, and give back their access
    func clearFolders() {
        folders.forEach { $0.stopAccessingSecurityScopedResource() }
        self.folders = []
        progress = Float(0)
    }

    func setUploads(results: Array<UploadWithFiles>) {
        self.uploadsWithFiles = results
        logger.log("[setUploads] Results count=\(results.count)")

        self.uploadImageFiles = []
        self.uploadPdfFiles = []
        self.uploadAudioFiles = []
        self.uploadVideoFiles = []
        self.uploadTextFiles = []

        for upload in self.uploadsWithFiles {
            // ImageFile
            var i = 0
            var imageFiles = upload.imageFiles
            for imageFileItem in imageFiles {
                if (imageFileItem.folder.state == "archived") {
                    imageFiles.remove(at: i)
                }
                i += 1
            }
            self.uploadImageFiles += imageFiles
            for imageFile in upload.imageFiles {
                if !self.loadedFolders.map({ $0.id }).contains(imageFile.folder.id) {
                    self.loadedFolders.append(imageFile.folder)
                }
            }

            // PdfFile
            i = 0
            var pdfFiles = upload.pdfFiles
            for pdfFileItem in pdfFiles {
                if (pdfFileItem.folder.state == "archived") {
                    pdfFiles.remove(at: i)
                }
                i += 1
            }
            self.uploadPdfFiles += pdfFiles
            for pdfFile in upload.pdfFiles {
                if !self.loadedFolders.map({ $0.id }).contains(pdfFile.folder.id) {
                    self.loadedFolders.append(pdfFile.folder)
                }
            }

            // TextFile
            i = 0
            var textFiles = upload.textFiles
            for textFileItem in textFiles {
                if (textFileItem.folder.state == "archived") {
                    textFiles.remove(at: i)
                }
                i += 1
            }
            self.uploadTextFiles += textFiles
            for textFile in upload.textFiles {
                if !self.loadedFolders.map({ $0.id }).contains(textFile.folder.id) {
                    self.loadedFolders.append(textFile.folder)
                }
            }

            // AudioFile
            i = 0
            var audioFiles = upload.audioFiles
            for audioFileItem in audioFiles {
                if (audioFileItem.folder.state == "archived") {
                    audioFiles.remove(at: i)
                }
                i += 1
            }
            self.uploadAudioFiles += audioFiles
            for audioFile in upload.audioFiles {
                if !self.loadedFolders.map({ $0.id }).contains(audioFile.folder.id) {
                    self.loadedFolders.append(audioFile.folder)
                }
                DispatchQueue.main.async {
                    getAudioStream(audioFile: audioFile)
                }
            }

            // VideoFile
            i = 0
            var videoFiles = upload.videoFiles
            for videoFileItem in videoFiles {
                if (videoFileItem.folder.state == "archived") {
                    videoFiles.remove(at: i)
                }
                i += 1
            }
            self.uploadVideoFiles += videoFiles
            for videoFile in upload.videoFiles {
                if !self.loadedFolders.map({ $0.id }).contains(videoFile.folder.id) {
                    self.loadedFolders.append(videoFile.folder)
                }
                DispatchQueue.main.async {
                    getVideoStream(videoFile: videoFile)
                }
            }
        }
        if (loadedFolders.count > 0) {
            searchableFolders = loadedFolders.map { $0 }
        }
        if (uploadImageFiles.count > 0) {
            searchableImageFiles = uploadImageFiles.map { $0 }
        }
        if (uploadPdfFiles.count > 0) {
            searchablePdfFiles = uploadPdfFiles.map { $0 }
        }
        if (uploadTextFiles.count > 0) {
            searchableTextFiles = uploadTextFiles.map { $0 }
        }
        if (uploadAudioFiles.count > 0) {
            searchableAudioFiles = uploadAudioFiles.map { $0 }
        }
        if (uploadVideoFiles.count > 0) {
            searchableVideoFiles = uploadVideoFiles.map { $0 }
        }
    }

    func getAllUploads() {
        logger.info("[getAllUploads] New Request")
        let delegateClass = NetworkDelegateClass()
        let delegateSession = URLSession(configuration: .default, delegate: delegateClass, delegateQueue: nil)
        let accountUuid = self.signedInUser?.accountUuid!.uuidString
        let accountUuidUnwrapped = (accountUuid ?? "")!
        let request = newGetRequest(url: URL(string: "\(backendURL)/\(accountUuidUnwrapped)")!)
        let task = delegateSession.dataTask(with: request) { data, response, error in
            do {
                let response = try JSONDecoder().decode([UploadWithFiles].self, from: data!)

                DispatchQueue.main.async {
                    self.loadedFolders = Array<Folder>()
                    self.selectedFolders = Set()
                    setUploads(results: response)
                }
            } catch let error {
                logger.error("[getAllUploads] Request: \(error)")
            }
        }

        task.resume()
    }

    func getSelectedUploadsRequest() -> URL {
        let accountUuid = self.signedInUser?.accountUuid!.uuidString
        let accountUuidUnwrapped = (accountUuid ?? "")!
        let url = URL(string: "\(backendURL)/\(accountUuidUnwrapped)")!

        if (selectedFolders.count > 0) {
            var str:String = ""
            for folderId in selectedFolders {
                str += ",\(folderId)"
            }
            let strData:Data = str.data(using: .utf8)!
            let base64str:String = strData.base64EncodedString()

            return URL(string: "\(url)" + "?folderIds=\(base64str)")!
        } else {

            return URL(string: "\(url)")!
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

    func createEvent(url: String, eventType: String, uploadDetails: UploadDetails) {
        do {
            let infoDictionary:[String:Any]? = Bundle.main.infoDictionary ?? [:]
            let infoDictionaryUnwrapped = infoDictionary!

            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
            let openAtFormatted = dateFormatter.string(from: Date())

            let platformDetails = PlatformDetails(
                CFBundleDevelopmentRegion: infoDictionaryUnwrapped["CFBundleDevelopmentRegion"] as! String,
                DTSDKName: infoDictionaryUnwrapped["DTSDKName"] as! String,
                DTXcodeBuild: infoDictionaryUnwrapped["DTXcodeBuild"] as! String,
                CFBundleIdentifier: infoDictionaryUnwrapped["CFBundleIdentifier"] as! String,
                DTCompiler: infoDictionaryUnwrapped["DTCompiler"] as! String,
                BuildMachineOSBuild: infoDictionaryUnwrapped["BuildMachineOSBuild"] as! String,
                LSMinimumSystemVersion: infoDictionaryUnwrapped["LSMinimumSystemVersion"] as! String,
                DTSDKBuild: infoDictionaryUnwrapped["DTSDKBuild"] as! String,
                CFBundleInfoDictionaryVersion: infoDictionaryUnwrapped["CFBundleInfoDictionaryVersion"] as! String,
                DTPlatformName: infoDictionaryUnwrapped["DTPlatformName"] as! String,
                DTPlatformBuild: infoDictionaryUnwrapped["DTPlatformBuild"] as! String,
                DTPlatformVersion: infoDictionaryUnwrapped["DTPlatformVersion"] as! String,
                CFBundleName: infoDictionaryUnwrapped["CFBundleName"] as! String,
                CFBundleShortVersionString: infoDictionaryUnwrapped["CFBundleShortVersionString"] as! String,
                CFBundlePackageType: infoDictionaryUnwrapped["CFBundlePackageType"] as! String,
                DTXcode: infoDictionaryUnwrapped["DTXcode"] as! String,
                CFBundleExecutable: infoDictionaryUnwrapped["CFBundleExecutable"] as! String,
            )

            let parameters = EventParameters(
                id: nil,
                OpenAt: openAtFormatted,
                platformDetails: platformDetails,
                uploadDetails: uploadDetails
            )

            let parametersData = try JSONEncoder().encode(parameters)
            let accountUuid = self.signedInUser?.accountUuid!.uuidString
            let accountUuidUnwrapped = accountUuid!

            let event = Event(
                id: nil,
                accountUuid: accountUuidUnwrapped,
                url: url,
                eventType: eventType,
                parameters: parametersData
            )
            let data = try JSONEncoder().encode(event)

            let url = URL(string: "\(eventURL)")!
            let delegateClass = NetworkDelegateClass()
            let delegateSession = URLSession(configuration: .default, delegate: delegateClass, delegateQueue: nil)
            let optimizedData: Data = try! data.gzipped(level: .bestCompression)
            let postLength = String(format: "%lu", UInt(optimizedData.count))
            let request = newPostRequestWithContent(url: url, data: optimizedData, postLength: postLength)
            let task = delegateSession.dataTask(with: request) { data, response, error in
                //
            }

            task.resume()

        } catch let error {
            logger.error("[createEvent] Error: \(error)")
        }
    }

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
        return folderNames.joined(separator: ", ")
    }

    /*
        Folder: Publish / Unpublish
    */
    enum FolderAction: String, CaseIterable, Identifiable {
        case none, publish, unpublish, archive, unarchive, delete
        var id: Self { self }

        var title: LocalizedStringKey {
            switch self {
            case .none: ""
            case .publish: "Publish"
            case .unpublish: "Unpublish"
            case .archive: "Archive"
            case .unarchive: "Unarchive"
            case .delete: "Delete"
            }
        }
    }

    func updateSelectedFolders() {
        // Reset search text
        self.searchText = ""

        logger.info("[updateSelectedFolders] Update Folders")
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
                    clearSelectedFolders()
                    clearSelectedFiles()
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
                    clearSelectedFolders()
                    clearSelectedFiles()
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
                    clearSelectedFolders()
                    clearSelectedFiles()
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
                    clearSelectedFolders()
                    clearSelectedFiles()
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

        if (searchQuery == "") {
            // Reload Folders
            refreshUploads()
        } else {
            loadedFolders = searchableFolders.filter { folder in
                folder.name
                    .lowercased()
                    .contains(searchQuery.lowercased())
            }
            uploadImageFiles = searchableImageFiles.filter { imageFile in
                imageFile.folder.name
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
                videoFile.folder.name
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
                audioFile.folder.name
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
                pdfFile.folder.name
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
                textFile.folder.name
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
        if (isImporting) {
            logger.error("[refreshUploads] $isImporting is set to true, which means the refresh action will happen after that.")
        } else {
            clearSelectedFolders()
            getAllUploads()
        }
    }
}
