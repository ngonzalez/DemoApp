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

import Foundation

/// The account's plan and what it uses of it: the `plan` of the backend's
/// `GET /account`, signed in with the session cookie. 5GB: files up to
/// 5 GiB and 3 users; 10GB: 10 GiB and 10 users.
struct PlanUsage: Decodable, Equatable {
    struct Storage: Decodable, Equatable {
        let used: Int
        let limit: Int
    }

    struct Users: Decodable, Equatable {
        let count: Int
        let limit: Int
    }

    static let accountURL = URL(string: "https://api.appshare.site/account")!

    /// 5GB or 10GB
    let name: String
    let storage: Storage
    let users: Users

    /// How much of the storage the files take, from 0 to 1
    var storageFraction: Double {
        storage.limit > 0 ? min(Double(storage.used) / Double(storage.limit), 1) : 0
    }

    /// True when the account has no room left for files or users
    var full: Bool {
        storage.used >= storage.limit || users.count >= users.limit
    }

    /// A size in binary units: 5 GB for 5 GiB, like the plans' names and the backend
    static func size(_ bytes: Int) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .binary)
    }

    /// The signed-in account's plan; nil when it can't be read (signed out,
    /// offline, a backend before plans): the panel just doesn't show it
    static func fetch(url: URL = accountURL, session: URLSession = .shared) async -> PlanUsage? {
        struct Summary: Decodable {
            struct Account: Decodable { let plan: PlanUsage? }
            let account: Account
        }
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        guard let (data, response) = try? await session.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
        return (try? JSONDecoder().decode(Summary.self, from: data))?.account.plan
    }
}
