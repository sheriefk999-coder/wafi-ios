import Foundation

/// What went wrong with a call, in a shape screens can explain.
enum APIError: Error, Equatable {
    case network(String?)
    case timeout
    case http(status: Int, code: String?, quota: QuotaInfo? = nil)
    case parse(String?)

    var code: String? { if case .http(_, let c, _) = self { return c }; return nil }
    var status: Int? { if case .http(let s, _, _) = self { return s }; return nil }
    var quota: QuotaInfo? { if case .http(_, _, let q) = self { return q }; return nil }
    /// The free plan ran out of something (searches, assistant messages, advisor picks).
    var isQuota: Bool { code == "quota_exceeded" }
    /// Search needs a signed-in account (set in the console).
    var needsSignIn: Bool { code == "sign_in_required" }
}

/// For quota_exceeded / pro_required: which quota, its size, and seconds until a unit frees up.
struct QuotaInfo: Equatable {
    var kind: String?
    var limit: Int?
    var retryIn: Int?
}

/// The search and filter the catalog screens send.
struct ProductFilter: Equatable, Hashable {
    var query = ""
    var category: String?
    var brand: String?
    var condition: String?
    var part: String?
    var minPrice: Decimal?
    var maxPrice: Decimal?
    /// relevance | price_asc | price_desc | newest
    var sort = "relevance"
    var limit = 50
    /// Only products some store has in stock (the default).
    var inStock = true

    var queryItems: [URLQueryItem] {
        var q: [URLQueryItem] = []
        let text = query.trimmingCharacters(in: .whitespaces)
        if !text.isEmpty { q.append(.init(name: "q", value: text)) }
        if let category { q.append(.init(name: "category", value: category)) }
        if let b = brand?.trimmingCharacters(in: .whitespaces), !b.isEmpty { q.append(.init(name: "brand", value: b)) }
        if let condition { q.append(.init(name: "condition", value: condition)) }
        if let part { q.append(.init(name: "part", value: part)) }
        if let minPrice { q.append(.init(name: "min_price", value: "\(minPrice)")) }
        if let maxPrice { q.append(.init(name: "max_price", value: "\(maxPrice)")) }
        if inStock { q.append(.init(name: "in_stock", value: "true")) }
        return q
    }
}

/// The WAFI HTTP API. One instance per app; the token, country and base URL are read per call.
final class API: @unchecked Sendable {
    var baseURL: () -> URL
    var token: () -> String?
    var country: () -> String
    /// This install's random id, so the free plan's guest quotas follow the phone, not the network.
    var device: () -> String = { "" }
    var onUnauthorized: () -> Void = {}
    /// The server's X-PR-Quota-Left after a counted search.
    var onQuotaLeft: (Int) -> Void = { _ in }
    private let session: URLSession
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    init(baseURL: @escaping () -> URL, token: @escaping () -> String?, country: @escaping () -> String, session: URLSession? = nil) {
        self.baseURL = baseURL
        self.token = token
        self.country = country
        if let session { self.session = session } else {
            let cfg = URLSessionConfiguration.default
            cfg.timeoutIntervalForRequest = 20
            cfg.waitsForConnectivity = false
            self.session = URLSession(configuration: cfg)
        }
    }

    // MARK: core

    func request(_ method: String, _ path: String, query: [URLQueryItem] = [], body: Data? = nil) throws -> URLRequest {
        var comps = URLComponents(url: baseURL().appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        if !query.isEmpty { comps.queryItems = query }
        var r = URLRequest(url: comps.url!)
        r.httpMethod = method
        r.setValue("application/json", forHTTPHeaderField: "Accept")
        r.setValue(country(), forHTTPHeaderField: "X-PR-Country")
        let d = device()
        if !d.isEmpty { r.setValue(d, forHTTPHeaderField: "X-PR-Device") }
        if let t = token(), !t.isEmpty { r.setValue("Bearer \(t)", forHTTPHeaderField: "Authorization") }
        if let body {
            r.httpBody = body
            r.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        return r
    }

    func send<T: Decodable>(_ method: String, _ path: String, query: [URLQueryItem] = [], json: [String: Any]? = nil,
                            as: T.Type = T.self) async throws -> T {
        let body = try json.map { try JSONSerialization.data(withJSONObject: $0) }
        let req = try request(method, path, query: query, body: body)
        let data: Data, resp: URLResponse
        do {
            (data, resp) = try await session.data(for: req)
        } catch let e as URLError where e.code == .timedOut {
            throw APIError.timeout
        } catch {
            throw APIError.network(error.localizedDescription)
        }
        let http = resp as? HTTPURLResponse
        let status = http?.statusCode ?? 0
        if let left = http?.value(forHTTPHeaderField: "X-PR-Quota-Left").flatMap(Int.init) { onQuotaLeft(left) }
        guard (200..<300).contains(status) else {
            if status == 401, token() != nil { onUnauthorized() }
            let body = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
            let code = body?["error"] as? String
            var info: QuotaInfo?
            if code == "quota_exceeded" || code == "pro_required" {
                info = QuotaInfo(kind: body?["kind"] as? String, limit: (body?["limit"] as? NSNumber)?.intValue,
                                 retryIn: (body?["retry_in"] as? NSNumber)?.intValue)
            }
            throw APIError.http(status: status, code: code, quota: info)
        }
        if T.self == Empty.self { return Empty() as! T }
        do { return try decoder.decode(T.self, from: data) } catch { throw APIError.parse(String(describing: error)) }
    }

    struct Empty: Decodable {}

    /// Decimal as a JSON number for request bodies (NSDecimalNumber serializes exactly).
    static func num(_ d: Decimal) -> NSDecimalNumber { NSDecimalNumber(decimal: d) }

    // MARK: identity & config

    func me() async throws -> Me { try await send("GET", "me") }
    func health() async -> Bool { (try? await send("GET", "health", as: Empty.self)) != nil }
    func quota() async throws -> QuotaStatus { try await send("GET", "quota") }
    func appConfig() async throws -> AppConfig { try await send("GET", "app/config", query: [.init(name: "platform", value: "ios")]) }
    func countries() async throws -> [Country] { try await send("GET", "countries", as: CountryList.self).items }
    func register(name: String, email: String, password: String) async throws -> SessionResponse {
        try await send("POST", "auth/register", json: ["name": name, "email": email, "password": password])
    }
    func login(email: String, password: String) async throws -> SessionResponse {
        try await send("POST", "auth/password-login", json: ["email": email, "password": password])
    }
    func appleSignIn(identityToken: String, name: String?) async throws -> SessionResponse {
        var j: [String: Any] = ["identity_token": identityToken]
        if let name, !name.isEmpty { j["name"] = String(name.prefix(60)) }
        return try await send("POST", "auth/apple", json: j)
    }
    func logout() async throws { _ = try await send("POST", "auth/logout", as: Empty.self) }
    func forgotPassword(email: String) async throws { _ = try await send("POST", "auth/password/forgot", json: ["email": email], as: Empty.self) }
    func resetPassword(email: String, code: String, newPassword: String) async throws {
        _ = try await send("POST", "auth/password/reset", json: ["email": email, "code": code, "new_password": newPassword], as: Empty.self)
    }
    func sendVerifyCode() async throws { _ = try await send("POST", "auth/email/send-code", as: Empty.self) }
    func verifyEmail(code: String) async throws { _ = try await send("POST", "auth/email/verify", json: ["code": code], as: Empty.self) }
    func changePassword(current: String, new: String) async throws {
        _ = try await send("POST", "me/password", json: ["current_password": current, "new_password": new], as: Empty.self)
    }
    func deleteAccount(password: String?) async throws {
        var j: [String: Any] = ["confirm": "DELETE"]
        if let password, !password.isEmpty { j["password"] = password }
        _ = try await send("POST", "me/delete", json: j, as: Empty.self)
    }
    func registerDevice(token: String) async throws { _ = try await send("POST", "me/devices", json: ["token": token, "platform": "ios"], as: Empty.self) }
    func removeDevice(token: String) async throws { _ = try await send("POST", "me/devices/remove", json: ["token": token], as: Empty.self) }
    func preferences() async throws -> Preferences { try await send("GET", "me/preferences") }
    func savePreferences(_ p: Preferences) async throws -> Preferences {
        try await send("PUT", "me/preferences", json: ["push_alerts": p.pushAlerts, "email_alerts": p.emailAlerts,
                                                       "deals_digest": p.dealsDigest, "language": p.language])
    }

    // MARK: catalog

    func products(_ f: ProductFilter) async throws -> [ProductSummary] {
        var q = f.queryItems
        q.append(.init(name: "limit", value: "\(min(max(f.limit, 1), 200))"))
        if f.sort != "relevance" { q.append(.init(name: "sort", value: f.sort)) }
        return try await send("GET", "products", query: q, as: Items<ProductSummary>.self).items
    }
    func analysis(_ f: ProductFilter) async throws -> SearchAnalysis { try await send("GET", "products/analysis", query: f.queryItems) }
    func product(_ id: String) async throws -> ProductDetail { try await send("GET", "products/\(id)") }
    func stores() async throws -> [Store] { try await send("GET", "stores", as: Items<Store>.self).items }
    func deals(category: String? = nil, limit: Int = 30) async throws -> [Deal] {
        var q = [URLQueryItem(name: "limit", value: "\(limit)")]
        if let category { q.append(.init(name: "category", value: category)) }
        return try await send("GET", "deals", query: q, as: Items<Deal>.self).items
    }
    func compare(ids: [String]) async throws -> CompareResponse {
        try await send("GET", "compare", query: [.init(name: "ids", value: ids.joined(separator: ","))])
    }
    func suggest(_ q: String) async throws -> SuggestResponse { try await send("GET", "suggest", query: [.init(name: "q", value: q)]) }
    func tradeIn(from: String, to: String) async throws -> TradeIn {
        try await send("GET", "tools/trade-in", query: [.init(name: "from_id", value: from), .init(name: "to_id", value: to)])
    }
    func basket(_ lines: [BasketLineIn]) async throws -> BasketResponse {
        try await send("POST", "basket", json: ["items": lines.map { ["product_id": $0.productId, "qty": $0.qty] }])
    }
    func assistant(_ message: String, lang: String) async throws -> AssistantResponse {
        try await send("POST", "assistant", json: ["message": message, "lang": lang])
    }

    // MARK: market

    func market() async throws -> MarketResponse { try await send("GET", "market") }
    func marketHistory(days: Int) async throws -> [MarketDay] {
        try await send("GET", "market/history", query: [.init(name: "days", value: "\(days)")], as: Items<MarketDay>.self).items
    }
    func goldAdvice() async throws -> GoldAnalysis { try await send("GET", "advisor/gold") }

    // MARK: advisor & PC

    func pcBuild(budget: Decimal, use: String) async throws -> PcBuild {
        try await send("POST", "pc-builder", json: ["budget": API.num(budget), "use": use])
    }
    func pcAdvice(budget: Decimal, use: String, resolution: String) async throws -> PcBuild {
        try await send("POST", "advisor/pc", json: ["budget": API.num(budget), "use": use, "resolution": resolution])
    }
    func phonesAdvice(budget: Decimal?, priority: String, category: String = "phones") async throws -> AdviceResponse {
        var j: [String: Any] = ["priority": priority, "category": category]
        if let budget { j["budget"] = API.num(budget) }
        return try await send("POST", "advisor/phones", json: j)
    }
    func carsAdvice(budget: Decimal?, family: String, usage: String, economy: Bool, condition: String) async throws -> AdviceResponse {
        var j: [String: Any] = ["family": family, "usage": usage, "economy": economy, "condition": condition]
        if let budget { j["budget"] = API.num(budget) }
        return try await send("POST", "advisor/cars", json: j)
    }
    func fashionAdvice(budget: Decimal?, need: String, occasion: String, gender: String, size: String?) async throws -> AdviceResponse {
        var j: [String: Any] = ["need": need, "occasion": occasion, "gender": gender]
        if let budget { j["budget"] = API.num(budget) }
        if let size { j["size"] = size }
        return try await send("POST", "advisor/fashion", json: j)
    }

    // MARK: watchlist, alerts, Pro

    func watchlist() async throws -> [WatchItem] { try await send("GET", "me/watchlist", as: Items<WatchItem>.self).items }
    func watch(_ productId: String, target: Decimal?) async throws {
        _ = try await send("PUT", "me/watchlist/\(productId)", json: target.map { ["target": API.num($0)] } ?? [:], as: Empty.self)
    }
    func unwatch(_ productId: String) async throws { _ = try await send("DELETE", "me/watchlist/\(productId)", as: Empty.self) }
    func alerts() async throws -> AlertList { try await send("GET", "me/alerts") }
    func markAlertRead(_ id: Int64) async throws { _ = try await send("POST", "me/alerts/\(id)/read", as: Empty.self) }
    func marketAlerts() async throws -> MarketAlertList { try await send("GET", "me/market-alerts") }
    func createMarketAlert(metric: String, direction: String, target: Decimal) async throws {
        _ = try await send("POST", "me/market-alerts", json: ["metric": metric, "direction": direction, "target": API.num(target)], as: Empty.self)
    }
    func deleteMarketAlert(_ id: Int64) async throws { _ = try await send("DELETE", "me/market-alerts/\(id)", as: Empty.self) }
    func verifyAppStore(signedTransaction: String, renewal: String?) async throws -> BillingStatus {
        var j: [String: Any] = ["signed_transaction": signedTransaction]
        if let renewal { j["signed_renewal_info"] = renewal }
        return try await send("POST", "billing/apple/verify", json: j)
    }
}
