import Foundation
import Testing
@testable import DirectUpload

/// The requests go to `StubProtocol`, which records them and answers in order
@Suite(.serialized) struct DirectUploadTests {
    static let uuid = "0f8fad5b-d9cb-469f-a165-70867728950e"
    static let signedURL = "https://storage.example.test/container/key?sig=abc"

    let file: URL
    let upload: DirectUpload

    init() throws {
        file = FileManager.default.temporaryDirectory.appending(path: "direct-upload-\(UUID().uuidString).png")
        try Data("hello".utf8).write(to: file)
        StubProtocol.reset()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubProtocol.self]
        upload = DirectUpload(uploadURL: URL(string: "https://api.example.test/upload")!, session: URLSession(configuration: configuration))
    }

    static func json(_ status: Int, _ body: [String: Any]) -> StubProtocol.Response {
        (status, try! JSONSerialization.data(withJSONObject: body))
    }

    static let created = json(201, [
        "uuid": uuid,
        "signedBlobId": "signed-blob",
        "directUpload": ["url": signedURL, "headers": ["Content-Type": "image/png", "Content-MD5": "XUFAKrxLKna5cZ2REBfFkg==", "x-ms-blob-type": "BlockBlob"]],
    ])

    func send() async throws -> String {
        try await upload.upload(fileURL: file, source: "folder", mimeType: "image/png",
                                createdAt: Date(timeIntervalSince1970: 1_759_312_800), updatedAt: Date(timeIntervalSince1970: 1_759_399_200))
    }

    @Test func mimeTypeWhateverTheCaseOfTheExtension() {
        let mimeTypes = ["jpg": "image/jpeg", "png": "image/png", "pdf": "application/PDF"]

        #expect(DirectUpload.mimeType(of: URL(fileURLWithPath: "/DCIM/IMG_0001.JPG"), in: mimeTypes) == "image/jpeg")
        #expect(DirectUpload.mimeType(of: URL(fileURLWithPath: "/Scans/scan.Png"), in: mimeTypes) == "image/png")
        #expect(DirectUpload.mimeType(of: URL(fileURLWithPath: "/a/invoice.pdf"), in: mimeTypes) == "application/pdf")
        #expect(DirectUpload.mimeType(of: URL(fileURLWithPath: "/a/setup.EXE"), in: mimeTypes) == nil)
        #expect(DirectUpload.mimeType(of: URL(fileURLWithPath: "/a/README"), in: mimeTypes) == nil)
    }

    @Test func md5IsTheBase64DigestOfTheFile() throws {
        // printf hello | openssl dgst -md5 -binary | base64
        #expect(try DirectUpload.md5(of: file) == "XUFAKrxLKna5cZ2REBfFkg==")
    }

    @Test func uploadsTheWholeFileInOnePutBetweenTheTwoBackendCalls() async throws {
        StubProtocol.responses = [Self.created, (201, Data()), Self.json(202, ["uuid": Self.uuid, "status": "processing"])]

        #expect(try await send() == Self.uuid)

        let requests = StubProtocol.requests
        try #require(requests.count == 3)

        let create = requests[0]
        #expect(create.method == "POST")
        #expect(create.url == "https://api.example.test/upload/direct")
        let details = try #require(try JSONSerialization.jsonObject(with: create.body) as? [String: Any])
        #expect(details["filePath"] as? String == file.path)
        #expect(details["source"] as? String == "folder")
        #expect(details["mimeType"] as? String == "image/png")
        #expect(details["byteSize"] as? Int == 5)
        #expect(details["checksum"] as? String == "XUFAKrxLKna5cZ2REBfFkg==")
        #expect(details["createdAt"] as? String == "2025-10-01T10:00:00Z")

        let put = requests[1]
        #expect(put.method == "PUT")
        #expect(put.url == Self.signedURL)
        #expect(put.headers["Content-MD5"] == "XUFAKrxLKna5cZ2REBfFkg==")
        #expect(put.headers["x-ms-blob-type"] == "BlockBlob")
        #expect(put.headers["Content-Type"] == "image/png")

        let complete = requests[2]
        #expect(complete.url == "https://api.example.test/upload/direct/\(Self.uuid)/complete")
        let completeBody = try #require(try JSONSerialization.jsonObject(with: complete.body) as? [String: Any])
        #expect(completeBody["signedBlobId"] as? String == "signed-blob")
    }

    @Test func aRefusedFileIsNotSent() async throws {
        StubProtocol.responses = [Self.json(422, ["message": "This file type is not supported"])]

        let error = await #expect(throws: DirectUpload.Failure.self) { try await send() }
        #expect(error?.status == 422)
        #expect(error?.message == "This file type is not supported")
        #expect(StubProtocol.requests.count == 1)
    }

    @Test func aFailedPutIsNotCompleted() async throws {
        StubProtocol.responses = [Self.created, (403, Data("<Error><Code>AuthenticationFailed</Code></Error>".utf8))]

        let error = await #expect(throws: DirectUpload.Failure.self) { try await send() }
        #expect(error?.status == 403)
        #expect(StubProtocol.requests.count == 2)
    }

    @Test func aFailedCompletionIsReported() async throws {
        StubProtocol.responses = [Self.created, (201, Data()), Self.json(422, ["message": "The file is not in the storage yet"])]

        let error = await #expect(throws: DirectUpload.Failure.self) { try await send() }
        #expect(error?.message == "The file is not in the storage yet")
    }

    @Test func anExpiredSessionIsReported() async throws {
        StubProtocol.responses = [(401, Data())]

        let error = await #expect(throws: DirectUpload.Failure.self) { try await send() }
        #expect(error?.status == 401)
    }
}

/// Records each request and answers with the next queued response
final class StubProtocol: URLProtocol, @unchecked Sendable {
    typealias Response = (status: Int, body: Data)
    struct Request { let method: String; let url: String; let headers: [String: String]; let body: Data }

    nonisolated(unsafe) static var responses: [Response] = []
    nonisolated(unsafe) static var requests: [Request] = []
    static let lock = NSLock()

    static func reset() {
        lock.withLock { responses = []; requests = [] }
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let response = Self.lock.withLock { () -> Response in
            Self.requests.append(Request(method: request.httpMethod ?? "GET", url: request.url!.absoluteString,
                                         headers: request.allHTTPHeaderFields ?? [:], body: Self.body(of: request)))
            return Self.responses.isEmpty ? (500, Data()) : Self.responses.removeFirst()
        }
        let http = HTTPURLResponse(url: request.url!, statusCode: response.status, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "application/json"])!
        client?.urlProtocol(self, didReceive: http, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: response.body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

    static func body(of request: URLRequest) -> Data {
        if let body = request.httpBody { return body }
        guard let stream = request.httpBodyStream else { return Data() }
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            if count <= 0 { break }
            data.append(buffer, count: count)
        }
        return data
    }
}
