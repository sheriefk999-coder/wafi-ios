import Foundation

/// Launch arguments used by the UI tests (screenshots) to open a screen directly, e.g.
/// `-WAFI_ROUTE product:<id>`, `-WAFI_ROUTE tab:market`, `-WAFI_ROUTE assistant:<message>`, `-WAFI_DEMO_WALLET YES`.
/// Ignored in normal use (nobody passes them).
@MainActor
enum LaunchScript {
    private static var done = false
    /// A message the assistant sends by itself when it opens.
    static var assistantMessage: String?

    static func run(app: AppState, router: Router) async {
        guard !done else { return }
        done = true
        let d = UserDefaults.standard
        if d.bool(forKey: "WAFI_DEMO_WALLET") && app.wallet.isEmpty {
            app.wallet = [
                Holding(kind: "gold", karat: 21, amount: 45, cost: 45 * 3_950, note: t("شبكة", "Wedding set"), boughtOn: "2025-11-02"),
                Holding(kind: "gold_pound", amount: 2, cost: 2 * 30_400, boughtOn: "2026-02-15"),
                Holding(kind: "currency", code: "USD", amount: 1_500, cost: 1_500 * 47.6, note: t("تحويشة", "Savings"), boughtOn: "2026-01-10"),
                Holding(kind: "currency", code: "SAR", amount: 4_000, cost: 4_000 * 12.85, boughtOn: "2026-05-20"),
            ]
        }
        guard let raw = d.string(forKey: "WAFI_ROUTE") else { return }
        let parts = raw.split(separator: ":", maxSplits: 1).map(String.init)
        let key = parts[0], arg = parts.count > 1 ? parts[1] : ""
        switch key {
        case "tab":
            router.select(Tab(rawValue: arg) ?? .home)
        case "product": router.push(.product(arg))
        case "search": router.push(.search(category: nil, query: arg, part: nil))
        case "category": router.push(.search(category: arg, query: "", part: nil))
        case "picks": router.push(.picks(arg))
        case "assistant":
            assistantMessage = arg.isEmpty ? nil : arg
            router.push(.assistant)
        case "compare":
            app.compare = arg.split(separator: ",").map { ProductSummary(id: String($0), brand: "", model: "", titleAr: "", titleEn: "") }
            router.push(.compare)
        case "basket":
            for id in arg.split(separator: ",").map(String.init) {
                if let p = try? await app.api.product(id) {
                    let best = p.best?.total ?? p.offers.first?.total
                    app.addToBasket(ProductSummary(id: id, brand: p.product.brand, model: p.product.model, category: p.product.category,
                                                   titleAr: p.product.titleAr, titleEn: p.product.titleEn, bestTotal: best))
                }
            }
            router.select(.basket)
        default:
            let simple: [String: Route] = [
                "pro": .pro, "wallet": .wallet, "advisor": .advisor, "goldAdvisor": .goldAdvisor, "pcAdvisor": .pcAdvisor, "pc": .pc,
                "cars": .cars, "deals": .deals, "marketAlerts": .marketAlerts, "settings": .settings, "country": .country,
                "signIn": .signIn, "signUp": .signUp, "watchlist": .watchlist, "alerts": .alerts, "security": .security,
            ]
            if let r = simple[key] { router.push(r) }
        }
    }
}
