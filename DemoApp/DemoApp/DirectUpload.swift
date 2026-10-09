//
//  DirectUpload.swift
//  DemoApp
//

import CryptoKit
import Foundation

/// Uploads a file straight to the storage, in one PUT and without chunks
/// (the backend's `/upload/direct`, with the signed-in session's cookie):
/// 1. `POST /upload/direct`: the file's details → a signed URL
/// 2. `PUT` the file to that URL, streamed from the disk (up to 5000 MiB)
/// 3. `POST /upload/direct/:uuid/complete`: the backend attaches it
/// Every response is checked: a failure throws with the server's message.
struct DirectUpload {
    /// The uploads endpoint, e.g. https://api.appshare.site/upload
    let uploadURL: URL
    /// `.shared` carries the session cookie; the tests pass a stubbed session
    var session: URLSession = .shared

    struct Created: Decodable {
        struct Target: Decodable {
            let url: URL
            let headers: [String: String]
        }
        let uuid: String
        let signedBlobId: String
        let directUpload: Target
    }

    struct Failure: LocalizedError {
        let status: Int
        let message: String
        var errorDescription: String? { "HTTP \(status): \(message)" }
    }

    /// Upload one file
    /// - Returns: the upload's uuid; the backend attaches the file in the background
    func upload(fileURL: URL, source: String, mimeType: String, createdAt: Date, updatedAt: Date) async throws -> String {
        // The MD5 reads the whole file: off the main thread
        let (byteSize, checksum) = try await Task.detached(priority: .userInitiated) {
            (try fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0, try DirectUpload.md5(of: fileURL))
        }.value

        let dates = ISO8601DateFormatter()
        let created: Created = try await post(uploadURL.appending(path: "direct"), [
            "filePath": fileURL.path,
            "source": source,
            "mimeType": mimeType,
            "byteSize": byteSize,
            "checksum": checksum,
            "createdAt": dates.string(from: createdAt),
            "updatedAt": dates.string(from: updatedAt),
        ])

        var put = URLRequest(url: created.directUpload.url)
        put.httpMethod = "PUT"
        created.directUpload.headers.forEach { put.setValue($0.value, forHTTPHeaderField: $0.key) }
        let (data, response) = try await session.upload(for: put, fromFile: fileURL)
        try DirectUpload.check(data, response)

        struct Completed: Decodable { let uuid: String }
        let completed: Completed = try await post(uploadURL.appending(path: "direct/\(created.uuid)/complete"),
                                                  ["signedBlobId": created.signedBlobId])
        return completed.uuid
    }

    private func post<Response: Decodable>(_ url: URL, _ body: [String: Any]) async throws -> Response {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await session.data(for: request)
        try DirectUpload.check(data, response)
        return try JSONDecoder().decode(Response.self, from: data)
    }

    private static func check(_ data: Data, _ response: URLResponse) throws {
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else {
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            throw Failure(status: status, message: json?["message"] as? String ?? HTTPURLResponse.localizedString(forStatusCode: status))
        }
    }

    /// The MIME type of a file from its extension, whatever its case (a
    /// camera's `IMG_0001.JPG`); nil for a type the app doesn't upload
    static func mimeType(of fileURL: URL, in mimeTypes: [String: String]) -> String? {
        mimeTypes[fileURL.pathExtension.lowercased()]?.lowercased()
    }

    /// Base64 MD5, read in 4 MiB pieces: a large video never sits in memory
    static func md5(of url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hash = Insecure.MD5()
        while let data = try handle.read(upToCount: 4 * 1024 * 1024), !data.isEmpty {
            hash.update(data: data)
        }
        return Data(hash.finalize()).base64EncodedString()
    }
}
