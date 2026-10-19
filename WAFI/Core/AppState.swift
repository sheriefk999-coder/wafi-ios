import Foundation
import SwiftUI
import Observation

enum ThemeMode: String, CaseIterable { case light, dark, system }

/// Everything the screens share: the session, the remote config, the chosen country, and the local stores.
@MainActor
@Observable
final class AppState {
    static let shared = AppState()

    // MARK: server & session
    var serverURL: URL { didSet { UserDefaults.standard.set(serverURL.absoluteString, forKey: "wafi.server.effective") } }
    private(set) var token: String?
    var user: SessionUser?
    var me: Me?
    @ObservationIgnored let api = API(
        baseURL: { URL(string: UserDefaults.standard.string(forKey: "wafi.server.effective") ?? "") ?? URL(string: "https://api.example.com")! },
        token: { Keychain.get("token") },
        country: { UserDefaults.standard.string(forKey: "wafi.country.code") ?? "EG" })
    /// Random per install; only used so guest quotas are counted per phone.
    let installId: String = {
        if let id = UserDefaults.standard.string(forKey: "wafi.install") { return id }
        let id = UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
        UserDefaults.standard.set(id, forKey: "wafi.install")
        return id
    }()
    /// Free searches left in the current window (nil = unknown or unlimited).
    var searchLeft: Int?

    var isSignedIn: Bool { token != nil }
    var isPro: Bool { me?.pro == true }

    // MARK: config & country
    var config: AppConfig
    var country: Country
    var countries: [Country] = []
    var countryChosen: Bool { UserDefaults.standard.data(forKey: "wafi.country") != nil }
    /// Bumped when the country changes so every screen reloads for the new catalog.
    var catalogEpoch = 0

    // MARK: preferences
    var theme: ThemeMode { didSet { UserDefaults.standard.set(theme.rawValue, forKey: "wafi.theme") } }
    var onboardingDone: Bool { didSet { UserDefaults.standard.set(onboardingDone, forKey: "wafi.onboarded") } }

    // MARK: local stores
    var basket: [BasketLine] { didSet { Saved.save("wafi.basket", basket) } }
    var wallet: [Holding] { didSet { Saved.save("wafi.wallet", wallet) } }
    var recent: [String] { didSet { Saved.save("wafi.recent", recent) } }
    var compare: [ProductSummary] = []

    /// A screen a notification asked to open.
    var pendingRoute: Route?
    var toast: String?

    private init() {
        let env = ProcessInfo.processInfo.environment
        let args = UserDefaults.standard
        let fromBundle = Bundle.main.object(forInfoDictionaryKey: "WAFIAPIBaseURL") as? String
        let raw = args.string(forKey: "WAFI_API") ?? env["WAFI_API"] ?? UserDefaults.standard.string(forKey: "wafi.server") ?? fromBundle ?? "https://api.example.com"
        serverURL = URL(string: raw) ?? URL(string: "https://api.example.com")!
        UserDefaults.standard.set(serverURL.absoluteString, forKey: "wafi.server.effective")
        if args.bool(forKey: "WAFI_RESET") {      // UI tests: every launch starts clean
            Keychain.set("token", nil)
            for k in ["wafi.user", "wafi.basket", "wafi.wallet", "wafi.recent", "wafi.country", "wafi.onboarded", "wafi.config", "wafi.server", "wafi.push.asked"] {
                UserDefaults.standard.removeObject(forKey: k)
            }
        }
        if let injected = args.string(forKey: "WAFI_TOKEN") ?? env["WAFI_TOKEN"], !injected.isEmpty { Keychain.set("token", injected) }
        token = Keychain.get("token")
        user = Saved.load("wafi.user", as: SessionUser.self)
        config = Saved.load("wafi.config", as: AppConfig.self) ?? AppConfig()
        country = Saved.load("wafi.country", as: Country.self) ?? .egypt
        theme = ThemeMode(rawValue: UserDefaults.standard.string(forKey: "wafi.theme") ?? "light") ?? .light
        onboardingDone = UserDefaults.standard.bool(forKey: "wafi.onboarded") || args.bool(forKey: "WAFI_SKIP_ONBOARDING")
        basket = Saved.load("wafi.basket", as: [BasketLine].self) ?? []
        wallet = Saved.load("wafi.wallet", as: [Holding].self) ?? []
        recent = Saved.load("wafi.recent", as: [String].self) ?? []
        MoneyStyle.use(country)
        UserDefaults.standard.set(country.code, forKey: "wafi.country.code")
        if let c = args.string(forKey: "WAFI_COUNTRY"), c.count == 2 {   // screenshot runs
            let known = Country.known.first { $0.code == c } ?? Country(code: c, nameAr: c, nameEn: c)
            country = known
            MoneyStyle.use(known)
            Saved.save("wafi.country", known)
            UserDefaults.standard.set(c, forKey: "wafi.country.code")
        }
        api.onUnauthorized = { [weak self] in Task { @MainActor in self?.clearSession() } }
        let install = installId
        api.device = { install }
        api.onQuotaLeft = { [weak self] n in Task { @MainActor in self?.searchLeft = n } }
    }

    // MARK: - remote config

    func refreshConfig() async {
        if let c = try? await api.appConfig() {
            config = c
            Saved.save("wafi.config", c)
            Push.shared.configure(c.firebase)
        }
    }

    func refreshCountries() async {
        guard let list = try? await api.countries() else { return }
        countries = list
        if let same = list.first(where: { $0.code == country.code }), same != country, countryChosen { setCountry(same) }
    }

    func setCountry(_ c: Country) {
        let changed = c.code != country.code
        country = c
        MoneyStyle.use(c)
        Saved.save("wafi.country", c)
        UserDefaults.standard.set(c.code, forKey: "wafi.country.code")
        if changed { catalogEpoch += 1 }
    }

    // MARK: - session

    func signedIn(_ s: SessionResponse) async {
        Keychain.set("token", s.token)
        token = s.token
        user = s.user
        Saved.save("wafi.user", s.user)
        await refreshMe()
        await Push.shared.registerIfSignedIn()
        await Billing.shared.syncEntitlements()
    }

    func refreshMe() async {
        guard token != nil else { me = nil; return }
        me = try? await api.me()
    }

    func signOut() async {
        await Push.shared.unregister()
        try? await api.logout()
        clearSession()
    }

    func clearSession() {
        Keychain.set("token", nil)
        token = nil
        user = nil
        me = nil
        UserDefaults.standard.removeObject(forKey: "wafi.user")
    }

    // MARK: - basket

    func addToBasket(_ p: ProductSummary, qty: Int = 1) {
        if let i = basket.firstIndex(where: { $0.productId == p.id }) {
            basket[i].qty = min(basket[i].qty + qty, BasketLine.maxQty)
        } else {
            basket.append(BasketLine(productId: p.id, qty: max(1, min(qty, BasketLine.maxQty)), titleAr: p.titleAr, titleEn: p.titleEn, price: p.displayPrice))
            if basket.count > BasketLine.maxLines { basket.removeFirst(basket.count - BasketLine.maxLines) }
        }
    }

    func setQty(_ id: String, _ qty: Int) {
        if qty <= 0 { basket.removeAll { $0.productId == id } }
        else if let i = basket.firstIndex(where: { $0.productId == id }) { basket[i].qty = min(qty, BasketLine.maxQty) }
    }

    // MARK: - compare (Pro up to 4, the free plan fewer; same session only)

    var compareLimit: Int { isPro ? 4 : min(4, max(2, config.quotas.compareItems)) }

    @discardableResult
    func toggleCompare(_ p: ProductSummary) -> Bool {
        if let i = compare.firstIndex(where: { $0.id == p.id }) { compare.remove(at: i); return true }
        guard compare.count < compareLimit else { return false }
        compare.append(p)
        return true
    }

    // MARK: - recent searches

    func remember(_ q: String) {
        let s = q.trimmingCharacters(in: .whitespaces)
        guard s.count >= 2 else { return }
        recent.removeAll { $0.caseInsensitiveCompare(s) == .orderedSame }
        recent.insert(s, at: 0)
        if recent.count > 8 { recent = Array(recent.prefix(8)) }
    }
}

extension AppState {
    /// Point the app at another server (Account → Server address); kept across launches.
    func useServer(_ url: URL) {
        serverURL = url
        UserDefaults.standard.set(url.absoluteString, forKey: "wafi.server")
        catalogEpoch += 1
    }
}
