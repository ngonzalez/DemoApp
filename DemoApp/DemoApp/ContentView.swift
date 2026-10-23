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

/* SwiftUI */
import SwiftUI

/* VideoPlayer */
import AVKit

/* GzipSwift */
import Gzip

/* Zip */

/* Logger */
import OSLog

// logger and formatter: Logging.swift

@available(macOS 14, *)
@MainActor
struct ContentView: View {
    /* Credentials */
    @State var userCredentials:Credentials = Credentials(account: "", password: "")

    /* Search */
    @State var searchText: String = ""

    /* Media Player */
    @State var player:AVPlayer = AVPlayer()

    /* Uploads */
    @State var uploadsWithFiles: Array<UploadWithFiles> = Array<UploadWithFiles>()

    /* Attachments */
    @State var uploadImageFiles:Array<ImageFile> = Array<ImageFile>()

    @State var uploadPdfFiles:Array<PdfFile> = Array<PdfFile>()

    @State var uploadAudioFiles:Array<AudioFile> = Array<AudioFile>()

    @State var uploadVideoFiles:Array<VideoFile> = Array<VideoFile>()

    @State var uploadTextFiles:Array<TextFile> = Array<TextFile>()

    /* Searchable */
    @State var searchableImageFiles:Array<ImageFile> = Array<ImageFile>()

    @State var searchablePdfFiles:Array<PdfFile> = Array<PdfFile>()

    @State var searchableAudioFiles:Array<AudioFile> = Array<AudioFile>()

    @State var searchableVideoFiles:Array<VideoFile> = Array<VideoFile>()

    @State var searchableTextFiles:Array<TextFile> = Array<TextFile>()

    @State var searchableFolders:Array<Folder> = Array<Folder>()

    /* Folders  */
    @State var folders: Array<URL> = Array<URL>()

    @State var progress:Float = Float(0)
    @State var isSyncing:Bool = false

    /* Tables  */
    @State var imageFileSortOrder = [KeyPathComparator(\ImageFile.fileName)]

    @State var imageFileSelection = Set<ImageFile.ID>()

    @State var pdfFileSortOrder = [KeyPathComparator(\PdfFile.fileName)]

    @State var pdfFileSelection = Set<PdfFile.ID>()

    @State var audioFileSortOrder = [KeyPathComparator(\AudioFile.fileName)]

    @State var audioFileSelection = Set<AudioFile.ID>()

    @State var videoFileSortOrder = [KeyPathComparator(\VideoFile.fileName)]

    @State var videoFileSelection = Set<VideoFile.ID>()

    @State var textFileSortOrder = [KeyPathComparator(\TextFile.fileName)]

    @State var textFileSelection = Set<TextFile.ID>()

    @State var folderSortOrder = [KeyPathComparator(\Folder.name)]

    @State var folderSelection = Set<Folder.ID>()

    @State var selectedImageFiles:Array<ImageFile> = Array<ImageFile>()

    @State var selectedPdfFiles:Array<PdfFile> = Array<PdfFile>()

    @State var selectedAudioFiles:Array<AudioFile> = Array<AudioFile>()

    @State var selectedVideoFiles:Array<VideoFile> = Array<VideoFile>()

    @State var selectedTextFiles:Array<TextFile> = Array<TextFile>()

    @State var selectedFolders = Set<Folder.ID>()

    @State var mimeTypes:[String:String] = [
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

    @State var isImporting:Bool = false

    @State var loadedFolders: Array<Folder> = Array<Folder>()

    /* Account */
    @State var registrationAccount:Account?
    @State var signedInUser:UserWithAccount?
    @State var identified:Bool = Bool(false)

    @State var myAccount:Bool = Bool(false)                 // My Account

    @State var newSession:Bool = Bool(true)                 // New Session
    @State var newSessionComplete:Bool = Bool(false)

    @State var newPassword:Bool = Bool(false)               // New Password
    @State var newPasswordComplete:Bool = Bool(false)

    @State var newAccount:Bool = Bool(false)                // New Account
    @State var newAccountComplete:Bool = Bool(false)

    @State var editAccount:Bool = Bool(false)               // Edit Account
    @State var editAccountComplete:Bool = Bool(false)

    @State var editPassword:Bool = Bool(false)              // Edit Password
    @State var editPasswordComplete:Bool = Bool(false)

    @State var editEmailAddress:Bool = Bool(false)          // Edit Email
    @State var editEmailAddressComplete:Bool = Bool(false)

    /* New Session */
    @State var newSessionSuccessMessage:Message = Message(message: String())

    @State var newSessionValidationErrors:String = String()

    @State var emailAddressSessionForm: String = String()

    @State var passwordSessionForm: String = String()

    /* Destroy Session */
    @State var destroySessionFormResponse:Message = Message(message: String())

    /* New Account */
    @State var newAccountSuccessMessage:Message = Message(message: String())

    @State var newAccountValidationErrors:String = String()

    @State var accountCodeSuccessMessage:Message = Message(message: String())

    @State var accountCodeValidationErrors:String = String()

    @State var accountCodeRegistrationForm: String = String()

    @State var accountUuidRegistrationForm: String = String()

    @State var accountNameRegistrationForm: String = String()

    @State var accountAddressRegistrationForm: String = String()

    @State var firstNameRegistrationForm: String = String()

    @State var lastNameRegistrationForm: String = String()

    @State var emailAddressRegistrationForm: String = String()

    @State var passwordRegistrationForm: String = String()

    @State var passwordConfirmationRegistrationForm: String = String()

    /* Edit Account */
    @State var editAccountSuccessMessage:Message = Message(message: String())

    @State var editAccountValidationErrors:String = String()

    @State var accountUuidAccountForm: String = String()

    @State var accountNameAccountForm: String = String()

    @State var accountAddressAccountForm: String = String()
    // the address of the account's site: <subdomain>.appshare.site
    @State var subdomainAccountForm: String = String()

    @State var firstNameAccountForm: String = String()

    @State var lastNameAccountForm: String = String()

    @State var emailAddressAccountForm: String = String()

    @State var notifyOnSignInAccountForm: Bool = false

    @State var notifyOnAccountUpdateAccountForm: Bool = false

    @State var uuidAccountForm: String = String()

    @State var createdAtAccountForm: String = String()

    @State var updatedAtAccountForm: String = String()

    /* New Password */
    @State var newPasswordSuccessMessage:Message = Message(message: String())

    @State var newPasswordValidationErrors:String = String()

    @State var emailAddressPasswordForm: String = String()

    /* Edit Password */
    @State var editPasswordSuccessMessage:Message = Message(message: String())

    @State var editPasswordValidationErrors:String = String()

    @State var newPasswordEditPasswordForm: String = String()

    @State var newPasswordConfirmationEditPasswordForm: String = String()

    /* Edit Email */
    @State var editEmailAddressSuccessMessage:Message = Message(message: String())

    @State var editEmailAddressValidationErrors:String = String()

    @State var emailAddressEditEmailAddressForm: String = String()

    @State var newEmailAddressEditEmailAddressForm: String = String()

    /*
        Backend URLs
     */

    @State var accountsURL:String = "https://api.appshare.site/accounts"
//    @State private var accountsURL:String = "http://192.168.1.11:3000/accounts"

    @State var userURL:String = "https://api.appshare.site/user"
//    @State private var userURL:String = "http://192.168.1.11:3000/user"

    @State var registrationURL:String = "https://api.appshare.site/registration"
//    @State private var registrationURL:String = "http://192.168.1.11:3000/registration"

    @State var sessionURL:String = "https://api.appshare.site/session"
//    @State private var sessionURL:String = "http://192.168.1.11:3000/session"

    @State var passwordURL:String = "https://api.appshare.site/password"
//    @State private var passwordURL:String = "http://192.168.1.11:3000/password"

    @State var emailURL:String = "https://api.appshare.site/email"
//    @State private var emailURL:String = "http://192.168.1.11:3000/email"

    @State var backendURL:String = "https://api.appshare.site/upload"
//    @State private var backendURL:String = "http://192.168.1.11:3000/upload"

    @State var foldersPublishURL:String = "https://api.appshare.site/folders/publish"
//    @State private var foldersPublishURL:String = "http://192.168.1.11:3000/folders/publish"

    @State var foldersUnpublishURL:String = "https://api.appshare.site/folders/unpublish"
//    @State private var foldersUnpublishURL:String = "http://192.168.1.11:3000/folders/unpublish"

    @State var foldersArchiveURL:String = "https://api.appshare.site/folders/archive"
//    @State private var foldersArchiveURL:String = "http://192.168.1.11:3000/folders/archive"

    @State var foldersUnarchiveURL:String = "https://api.appshare.site/folders/unarchive"
//    @State private var foldersUnarchiveURL:String = "http://192.168.1.11:3000/folders/unarchive"

    @State var foldersDeleteURL:String = "https://api.appshare.site/folders/delete"
//    @State private var foldersDeleteURL:String = "http://192.168.1.11:3000/folders/delete"

    @State var attachmentsDeleteURL:String = "https://api.appshare.site/attachments/delete"
//    @State private var attachmentsDeleteURL:String = "http://192.168.1.11:3000/attachments/delete"

    @State var videoFilesServiceURL:String = "https://stream.appshare.site/video_files"
//    @State private var videoFilesServiceURL:String = "http://192.168.1.11:3001/video_files"

    @State var audioFilesServiceURL:String = "https://stream.appshare.site/audio_files"
//    @State private var audioFilesServiceURL:String = "http://192.168.1.11:3001/audio_files"

    @State var playlistsServiceURL:String = "https://stream.appshare.site/playlists"
//    @State private var playlistsServiceURL:String = "http://192.168.1.11:3001/playlists"

    @State var eventURL:String = "https://api.appshare.site/event"
//    @State private var eventURL:String = "http://192.168.1.11:3000/event"

    @State var selectedSideBarItem: SideBarItem = .upload

    @State var visibility: NavigationSplitViewVisibility = .detailOnly

    @State var videoStreams:Array<Stream> = Array<Stream>()

    @State var audioStreams:Array<Stream> = Array<Stream>()

    @State var selectedFolderAction: FolderAction = .none

    @Environment(\.openURL) var openURL


    /* Navigation */
    enum SideBarItem: String, Identifiable, CaseIterable {
        var id: String { rawValue }

        case account
        case upload

        var title: LocalizedStringKey {
            switch self {
            case .account: "Account"
            case .upload: "Upload"
            }
        }
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $visibility) {
            sideBarColumn
        } content: {
            switch selectedSideBarItem {
            case .account:
                accountPanel
            case .upload:
                uploadPanel
            }
            switch selectedSideBarItem {
            case .upload:
                uploadFilesPanel
            case .account:
                signOutPanel
            }
        } detail: {
            detailColumn
        }
        .navigationSplitViewStyle(.prominentDetail)
        .onAppear {
            self.userCredentials = readCredentials(server: "appshare.site")
            emailAddressSessionForm = self.userCredentials.account
            passwordSessionForm = self.userCredentials.password
        }
    }

    // The sidebar: Account and Upload
    @ViewBuilder
    var sideBarColumn: some View {
        List(SideBarItem.allCases, selection: $selectedSideBarItem) { item in
            NavigationLink(
                item.title,
                value: item
            )
        }
    }
}

#Preview {
    ContentView()
}
