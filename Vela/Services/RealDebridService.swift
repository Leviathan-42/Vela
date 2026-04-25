import Foundation

protocol RealDebridService: Sendable {
    func isAuthenticated() async -> Bool
    func beginDeviceCodeFlow() async throws -> RDDeviceCode
    func pollForToken(deviceCode: String, interval: TimeInterval) async throws -> RDTokens
    func disconnect() async throws
    func resolve(sourceLink: String, fileIndex: Int?) async throws -> URL
    func accountInfo() async throws -> RDAccount?
}

struct RDDeviceCode: Sendable, Codable {
    let deviceCode: String
    let userCode: String
    let verificationURL: URL
    let expiresIn: Int
    let interval: Int
}

struct RDTokens: Sendable, Codable {
    let accessToken: String
    let refreshToken: String
    let expiresAt: Date
    let clientID: String
    let clientSecret: String
}

struct RDAccount: Sendable {
    let username: String
    let email: String?
    let premiumExpiresAt: Date?
}

enum RDError: Error, LocalizedError {
    case notAuthenticated
    case httpError(Int)
    case pollingTimedOut
    case resolutionTimedOut
    case badResponse
    case magnetRejected

    var errorDescription: String? {
        switch self {
        case .notAuthenticated: "Connect Real-Debrid in Settings first."
        case .httpError(let c): "Real-Debrid returned HTTP \(c)."
        case .pollingTimedOut: "Authorization timed out. Try again."
        case .resolutionTimedOut: "Real-Debrid took too long to prepare this torrent."
        case .badResponse: "Unexpected response from Real-Debrid."
        case .magnetRejected: "Real-Debrid rejected this source."
        }
    }
}

struct RealDebridServiceLive: RealDebridService {
    let session: URLSession
    let keychain: any KeychainService
    let bootstrapClientID = "X245A4XAIBGVM"
    let apiBase = URL(string: "https://api.real-debrid.com")!

    init(session: URLSession? = nil, keychain: any KeychainService) {
        if let session {
            self.session = session
        } else {
            let config = URLSessionConfiguration.default
            config.httpAdditionalHeaders = [
                "User-Agent": "Vela/0.1.0 (iOS; SwiftUI)",
                "Accept": "application/json"
            ]
            self.session = URLSession(configuration: config)
        }
        self.keychain = keychain
    }

    func isAuthenticated() async -> Bool {
        (try? keychain.readTokens()) != nil
    }

    // MARK: - OAuth device flow

    func beginDeviceCodeFlow() async throws -> RDDeviceCode {
        var c = URLComponents(url: apiBase.appendingPathComponent("oauth/v2/device/code"), resolvingAgainstBaseURL: false)!
        c.queryItems = [
            URLQueryItem(name: "client_id", value: bootstrapClientID),
            URLQueryItem(name: "new_credentials", value: "yes")
        ]
        let (data, response) = try await session.data(from: c.url!)
        try validate(response)
        struct Resp: Decodable {
            let device_code: String
            let user_code: String
            let verification_url: String
            let expires_in: Int
            let interval: Int
        }
        let r = try JSONDecoder().decode(Resp.self, from: data)
        guard let url = URL(string: r.verification_url) else { throw RDError.badResponse }
        return RDDeviceCode(
            deviceCode: r.device_code,
            userCode: r.user_code,
            verificationURL: url,
            expiresIn: r.expires_in,
            interval: r.interval
        )
    }

    func pollForToken(deviceCode: String, interval: TimeInterval) async throws -> RDTokens {
        let credsURL = apiBase.appendingPathComponent("oauth/v2/device/credentials")
        var c = URLComponents(url: credsURL, resolvingAgainstBaseURL: false)!
        c.queryItems = [
            URLQueryItem(name: "client_id", value: bootstrapClientID),
            URLQueryItem(name: "code", value: deviceCode)
        ]

        struct CredsResp: Decodable {
            let client_id: String
            let client_secret: String
        }

        let deadline = Date().addingTimeInterval(300)
        var userCreds: CredsResp?
        while Date() < deadline {
            try await Task.sleep(for: .seconds(max(interval, 1)))
            guard !Task.isCancelled else { throw CancellationError() }
            let (data, response) = try await session.data(from: c.url!)
            if let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode),
               let got = try? JSONDecoder().decode(CredsResp.self, from: data) {
                userCreds = got
                break
            }
        }
        guard let userCreds else { throw RDError.pollingTimedOut }

        var req = URLRequest(url: apiBase.appendingPathComponent("oauth/v2/token"))
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        req.httpBody = formBody([
            "client_id": userCreds.client_id,
            "client_secret": userCreds.client_secret,
            "code": deviceCode,
            "grant_type": "http://oauth.net/grant_type/device/1.0"
        ])
        let (data, response) = try await session.data(for: req)
        try validate(response)
        struct TokenResp: Decodable {
            let access_token: String
            let refresh_token: String
            let expires_in: Int
        }
        let t = try JSONDecoder().decode(TokenResp.self, from: data)
        let tokens = RDTokens(
            accessToken: t.access_token,
            refreshToken: t.refresh_token,
            expiresAt: Date().addingTimeInterval(TimeInterval(t.expires_in)),
            clientID: userCreds.client_id,
            clientSecret: userCreds.client_secret
        )
        try keychain.writeTokens(tokens)
        return tokens
    }

    func disconnect() async throws {
        try keychain.deleteTokens()
    }

    func accountInfo() async throws -> RDAccount? {
        guard let tokens = try keychain.readTokens() else { return nil }
        let req = authedRequest(path: "rest/1.0/user", tokens: tokens)
        let (data, response) = try await session.data(for: req)
        try validate(response)
        struct UserResp: Decodable {
            let username: String
            let email: String?
            let expiration: String?
        }
        let u = try JSONDecoder().decode(UserResp.self, from: data)
        let formatter = ISO8601DateFormatter()
        return RDAccount(
            username: u.username,
            email: u.email,
            premiumExpiresAt: u.expiration.flatMap { formatter.date(from: $0) }
        )
    }

    // MARK: - Magnet resolution

    func resolve(sourceLink: String, fileIndex: Int?) async throws -> URL {
        guard var tokens = try keychain.readTokens() else { throw RDError.notAuthenticated }
        if tokens.expiresAt < Date().addingTimeInterval(60) {
            tokens = try await refreshTokens(tokens)
        }

        struct InfoResp: Decodable {
            let status: String
            let links: [String]
            let files: [File]
            struct File: Decodable {
                let id: Int
                let path: String
                let bytes: Int64
                let selected: Int
            }
        }

        // 1. Add magnet
        var addReq = authedPost(path: "rest/1.0/torrents/addMagnet", tokens: tokens)
        addReq.httpBody = formBody(["magnet": sourceLink])
        let (addData, addResp) = try await session.data(for: addReq)
        try validate(addResp)
        struct AddResp: Decodable { let id: String }
        let add = try JSONDecoder().decode(AddResp.self, from: addData)

        // 2. Wait for file list to be parsed (magnet → files takes a moment)
        let earlyDeadline = Date().addingTimeInterval(20)
        var info = try await fetchInfo(id: add.id, tokens: tokens, as: InfoResp.self)
        while info.files.isEmpty && Date() < earlyDeadline {
            if info.status == "magnet_error" || info.status == "error" || info.status == "virus" || info.status == "dead" {
                throw RDError.magnetRejected
            }
            try await Task.sleep(for: .seconds(1))
            info = try await fetchInfo(id: add.id, tokens: tokens, as: InfoResp.self)
        }
        guard !info.files.isEmpty else { throw RDError.resolutionTimedOut }

        // 3. Pick the largest non-sample video file
        let videoExts: Set<String> = ["mkv", "mp4", "avi", "mov", "m4v", "flv", "webm", "ts", "wmv"]
        let videoFiles = info.files.filter { f in
            let ext = (f.path as NSString).pathExtension.lowercased()
            let pathLower = f.path.lowercased()
            let isSample = pathLower.contains("/sample") || pathLower.hasPrefix("sample") || pathLower.contains(".sample.")
            return videoExts.contains(ext) && !isSample
        }
        let chosen = videoFiles.max(by: { $0.bytes < $1.bytes })
            ?? info.files.max(by: { $0.bytes < $1.bytes })
        guard let chosen else { throw RDError.badResponse }

        // 4. Select that single file
        var selectReq = authedPost(path: "rest/1.0/torrents/selectFiles/\(add.id)", tokens: tokens)
        selectReq.httpBody = formBody(["files": "\(chosen.id)"])
        let (_, selectResp) = try await session.data(for: selectReq)
        try validate(selectResp)

        // 5. Poll for "downloaded" status with links
        let deadline = Date().addingTimeInterval(90)
        var ready: InfoResp?
        while Date() < deadline {
            guard !Task.isCancelled else { throw CancellationError() }
            let current = try await fetchInfo(id: add.id, tokens: tokens, as: InfoResp.self)
            if current.status == "downloaded" && !current.links.isEmpty {
                ready = current
                break
            }
            if current.status == "error" || current.status == "virus" || current.status == "dead" {
                throw RDError.magnetRejected
            }
            try await Task.sleep(for: .seconds(2))
        }
        guard let ready else { throw RDError.resolutionTimedOut }

        _ = fileIndex
        let link = ready.links[0]

        // 5. Unrestrict
        var unrestrictReq = authedPost(path: "rest/1.0/unrestrict/link", tokens: tokens)
        unrestrictReq.httpBody = formBody(["link": link])
        let (udata, uresp) = try await session.data(for: unrestrictReq)
        try validate(uresp)
        struct UnRe: Decodable { let download: String }
        let ur = try JSONDecoder().decode(UnRe.self, from: udata)
        guard let out = URL(string: ur.download) else { throw RDError.badResponse }
        return out
    }

    // MARK: - Helpers

    private func fetchInfo<T: Decodable>(id: String, tokens: RDTokens, as: T.Type) async throws -> T {
        let req = authedRequest(path: "rest/1.0/torrents/info/\(id)", tokens: tokens)
        let (data, response) = try await session.data(for: req)
        try validate(response)
        return try JSONDecoder().decode(T.self, from: data)
    }

    private func refreshTokens(_ tokens: RDTokens) async throws -> RDTokens {
        var req = URLRequest(url: apiBase.appendingPathComponent("oauth/v2/token"))
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        req.httpBody = formBody([
            "client_id": tokens.clientID,
            "client_secret": tokens.clientSecret,
            "code": tokens.refreshToken,
            "grant_type": "http://oauth.net/grant_type/device/1.0"
        ])
        let (data, response) = try await session.data(for: req)
        try validate(response)
        struct TokenResp: Decodable {
            let access_token: String
            let refresh_token: String
            let expires_in: Int
        }
        let t = try JSONDecoder().decode(TokenResp.self, from: data)
        let fresh = RDTokens(
            accessToken: t.access_token,
            refreshToken: t.refresh_token,
            expiresAt: Date().addingTimeInterval(TimeInterval(t.expires_in)),
            clientID: tokens.clientID,
            clientSecret: tokens.clientSecret
        )
        try keychain.writeTokens(fresh)
        return fresh
    }

    private func authedRequest(path: String, tokens: RDTokens) -> URLRequest {
        var req = URLRequest(url: apiBase.appendingPathComponent(path))
        req.setValue("Bearer \(tokens.accessToken)", forHTTPHeaderField: "Authorization")
        return req
    }

    private func authedPost(path: String, tokens: RDTokens) -> URLRequest {
        var req = authedRequest(path: path, tokens: tokens)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        return req
    }

    private func validate(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else { throw RDError.badResponse }
        guard (200..<300).contains(http.statusCode) else { throw RDError.httpError(http.statusCode) }
    }

    private func formBody(_ fields: [String: String]) -> Data {
        let encoded = fields
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }
            .joined(separator: "&")
        return encoded.data(using: .utf8) ?? Data()
    }
}
