import Foundation
import Testing
@testable import DirectUpload

/// The account's plan, read from GET /account with the session: in the
/// serialized suite, since it shares StubProtocol's queue
extension DirectUploadTests {
    static let accountURL = URL(string: "https://api.example.test/account")!

    var session: URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubProtocol.self]
        return URLSession(configuration: configuration)
    }

    static func summary(plan: Any) -> StubProtocol.Response {
        json(200, ["account": ["name": "Acme", "subdomain": "acme", "siteUrl": "https://acme.appshare.site", "plan": plan],
                   "user": ["name": "Anna", "emailAddress": "anna@example.com", "admin": false, "statusAdmin": false],
                   "folders": ["created": 0, "published": 0, "archived": 0, "total": 0],
                   "files": ["count": 50, "byteSize": 51_357_725, "lastUploadAt": NSNull()]])
    }

    nonisolated(unsafe) static let fiveGB: [String: Any] = ["name": "5GB", "storage": ["used": 51_357_725, "limit": 5_368_709_120], "users": ["count": 1, "limit": 3]]

    @Test func readsThePlanOfTheSignedInAccount() async throws {
        StubProtocol.responses = [Self.summary(plan: Self.fiveGB)]

        let plan = try #require(await PlanUsage.fetch(url: Self.accountURL, session: session))

        #expect(plan == PlanUsage(name: "5GB", storage: .init(used: 51_357_725, limit: 5_368_709_120), users: .init(count: 1, limit: 3)))
        #expect(StubProtocol.requests.first?.method == "GET")
        #expect(StubProtocol.requests.first?.url == "https://api.example.test/account")
        #expect(StubProtocol.requests.first?.headers["Accept"] == "application/json")
    }

    @Test func noPlanFromABackendBeforePlansOrWithoutASession() async {
        StubProtocol.responses = [Self.summary(plan: NSNull()), (401, Data()), (200, Data("<html>".utf8))]

        #expect(await PlanUsage.fetch(url: Self.accountURL, session: session) == nil)
        #expect(await PlanUsage.fetch(url: Self.accountURL, session: session) == nil)
        #expect(await PlanUsage.fetch(url: Self.accountURL, session: session) == nil)
    }

    @Test func storageFractionAndFull() {
        let plan = PlanUsage(name: "5GB", storage: .init(used: 2_684_354_560, limit: 5_368_709_120), users: .init(count: 1, limit: 3))
        #expect(plan.storageFraction == 0.5)
        #expect(!plan.full)

        #expect(PlanUsage(name: "5GB", storage: .init(used: 6_000_000_000, limit: 5_368_709_120), users: .init(count: 1, limit: 3)).storageFraction == 1)
        #expect(PlanUsage(name: "5GB", storage: .init(used: 5_368_709_120, limit: 5_368_709_120), users: .init(count: 1, limit: 3)).full)
        #expect(PlanUsage(name: "5GB", storage: .init(used: 0, limit: 5_368_709_120), users: .init(count: 3, limit: 3)).full)
        #expect(PlanUsage(name: "x", storage: .init(used: 0, limit: 0), users: .init(count: 0, limit: 1)).storageFraction == 0)
    }

    @Test func sizesInBinaryUnitsLikeThePlansNames() {
        #expect(PlanUsage.size(5_368_709_120) == "5 GB")
        #expect(PlanUsage.size(10_737_418_240) == "10 GB")
    }

    @Test func aFullPlanRefusesTheFileWithTheServersReason() async throws {
        StubProtocol.responses = [Self.json(422, ["message": "Your plan's storage is full: 5 GB of 5 GB used"])]

        let error = await #expect(throws: DirectUpload.Failure.self) { try await send() }
        #expect(error?.status == 422)
        #expect(error?.message == "Your plan's storage is full: 5 GB of 5 GB used")
    }
}
