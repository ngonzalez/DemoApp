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

// The backend's JSON: folders, files, uploads, users, accounts, events
extension ContentView {
    struct Folder: Decodable, Identifiable {
        let id: Int
        let name: String
        let state: String
        let dataUrl: String
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

    struct AccountResponseWithMessage: Codable {
        let account: Account?
        let message: String?
    }

    struct UserResponseWithMessage: Codable {
        let user: UserWithAccount?
        let message: String?
    }

    struct Message: Codable {
        let message: String?
    }

    struct Event: Codable, Identifiable {
        let id: Int?
        let accountUuid: String
        let url: String
        let eventType: String
        let parameters: Data
    }

    struct PlatformDetails: Codable {
        let CFBundleDevelopmentRegion: String
        let DTSDKName: String
        let DTXcodeBuild: String
        let CFBundleIdentifier: String
        let DTCompiler: String
        let BuildMachineOSBuild: String
        let LSMinimumSystemVersion: String
        let DTSDKBuild: String
        let CFBundleInfoDictionaryVersion: String
        let DTPlatformName: String
        let DTPlatformBuild: String
        let DTPlatformVersion: String
        let CFBundleName: String
        let CFBundleShortVersionString: String
        let CFBundlePackageType: String
        let DTXcode: String
        let CFBundleExecutable: String
    }

    struct UploadDetails: Codable {
        let fileSize: Int
        let fileName: String
        let mimeType: String
    }

    struct EventParameters: Codable {
        let id: Int?
        let OpenAt: String
        let platformDetails: PlatformDetails
        let uploadDetails: UploadDetails
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
        let emailAddressValidatedAt: String?
        let password: String?
        let deliverNotificationsSignIn: Bool?
        let deliverNotificationsAccountUpdate: Bool?
        let createdAt: String?
        let updatedAt: String?
        let errors: [String]?
        // the account's subdomain, as the backend sends it
        var accountSubdomain: String? = nil
        // a new subdomain to save (PUT /user): the previous one keeps redirecting
        var subdomain: String? = nil
    }

    struct Account: Codable, Identifiable {
        let id: Int?
        let uuid: UUID?
        let name: String?
        let address: String?
        let dataUrl: String?
        let createdAt: String?
        let updatedAt: String?
        let errors: [String]?
    }

    struct UserWithEmailAddressAndPassword: Codable, Identifiable {
        let id: Int?
        let emailAddress: String?
        let password: String?
        let errors: [String]?
    }

    struct Credentials: Codable {
        let account: String!
        let password: String!
    }

    struct UserWithEmailAddress: Codable, Identifiable {
        let id: Int?
        let emailAddress: String?
        let errors: [String]?
    }

    struct UserWithPasswordAndPasswordConfirmation: Codable, Identifiable {
        let id: Int?
        let password: String?
        let passwordConfirmation: String?
        let errors: [String]?
    }

    struct UserWithEmailAddressAndNewEmailAddress: Codable, Identifiable {
        let id: Int?
        let emailAddress: String?
        let errors: [String]?
    }

    struct AttachmentIds: Codable {
        var id: Array<Int>
        var type: String
    }

    /*
     Audio, Video: Streaming
    */
    struct Stream: Decodable, Identifiable {
        let id: Int
        let m3u8Exists:Bool
    }

    struct FolderIds: Codable {
        var id: Array<Int>
    }
}
