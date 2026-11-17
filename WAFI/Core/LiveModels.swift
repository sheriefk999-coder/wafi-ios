import Foundation

// The live engine's responses: products found across Egyptian shops right now, each price read from that
// shop's own page. Nothing here is an estimate — a product with no current price simply isn't returned.
// Keys are spelled out, as everywhere else in this app.

/// One shop's offer for one product.
struct LiveOffer: Decodable, Identifiable, Hashable {
    var store: String
    var domain: String
    var price: Money
    var availability: String          // in_stock | out_of_stock | preorder | unknown
    var url: String
    var title: String
    var logo: String?
    var total: Money?                 // price + shipping, when the shop states shipping
    var shipping: Money?
    var originalPrice: Money?
    var discountPct: Double?
    var stale: Bool = false
    var doubtful: Bool = false        // shown, but never the price we stand behind
    var priceStatus: String?          // VERIFIED | PARTIALLY_VERIFIED | UNVERIFIED | STALE
    var condition: String?
    var ageMin: Int?                  // how long ago that shop's page confirmed this price
    var method: String?

    var id: String { domain + url }
    var inStock: Bool? { availability == "unknown" ? nil : availability == "in_stock" }
    /// What this offer really costs, shipping included when the shop said it.
    var payable: Money { total ?? price }

    enum CodingKeys: String, CodingKey {
        case store, domain, price, availability, url, title, logo, total, shipping, stale, doubtful, condition, method
        case originalPrice = "original_price"
        case discountPct = "discount_pct"
        case priceStatus = "price_status"
        case ageMin = "age_min"
    }
}

/// One product: the same thing in every shop that sells it, cheapest first.
struct LiveGroup: Decodable, Identifiable, Hashable {
    var key: String
    var title: String
    var variant: String?
    var image: String?
    var rating: Double?
    var ratingCount: Int?
    var stores: Int
    var priceFrom: Money?
    var priceTo: Money?
    var bestStore: String?
    var offers: [LiveOffer] = []
    var specs: [String] = []
    var changePct: Double?
    var historyDays: Int?
    var condition: String?
    var stale: Bool = false
    var brand: String?
    var description: String?
    var verifiedMin: Int?

    var id: String { key }
    var isUsed: Bool { condition == "used" }
    /// The badge the mockup asks for: how far this product's price has come down.
    var dropPct: Double? { if let c = changePct, c < -0.5 { return c }; return nil }

    enum CodingKeys: String, CodingKey {
        case key, title, variant, image, rating, stores, offers, specs, condition, stale, brand, description
        case ratingCount = "rating_count"
        case priceFrom = "price_from"
        case priceTo = "price_to"
        case bestStore = "best_store"
        case changePct = "change_pct"
        case historyDays = "history_days"
        case verifiedMin = "verified_min"
    }
}

/// How much of the market this search actually saw. Never 100%, and every reason is listed.
struct LiveCoverage: Decodable, Hashable {
    var state: String                 // COMPLETE | PARTIAL | LIMITED | FAILED
    var confidence: Double?
    var reasons: [String] = []
    var merchants: Counts?
    var urls: Counts?

    struct Counts: Decodable, Hashable {
        var known: Int?
        var checked: Int?
        var seen: Int?
        var new: Int?
    }

    var shopsChecked: Int { merchants?.checked ?? 0 }
    var pagesSeen: Int { urls?.seen ?? 0 }
    /// One honest line, in the app's language.
    var sentence: String {
        let shops = Fmt.number(shopsChecked), pages = Fmt.number(pagesSeen)
        return t("بحثنا في \(shops) متجر ولقينا \(pages) صفحة منتج",
                 "We checked \(shops) shops and found \(pages) product pages")
    }
}

struct LiveUnderstood: Decodable, Hashable {
    var en: String?
    var ar: String?
    var by: String?
}

struct LiveSearchResponse: Decodable {
    var query: String = ""
    var vertical: String?
    var groups: [LiveGroup] = []
    var understood: LiveUnderstood?
    var coverage: LiveCoverage?
    var pending: Bool = false
    var source: String?
    var tookMs: Int?
    var notice: String?
    var noticeAr: String?

    /// The notice in the app's language: prices are live, confirm at the shop.
    var notes: String? { Lang.isArabic ? (noticeAr ?? notice) : notice }

    enum CodingKeys: String, CodingKey {
        case query, vertical, groups, understood, coverage, pending, source, notice
        case tookMs = "took_ms"
        case noticeAr = "notice_ar"
    }
}

/// A product's price history, and what it means.
struct LiveHistory: Decodable, Hashable {
    var points: [LivePoint] = []
    var days: Int = 0
    var current: Money?
    var lowest: Money?
    var highest: Money?
    var average: Money?
    var changeVsPrev: Double?
    var changeVsAvg: Double?
    var change7d: Double?
    var verdict: String?
    var verdictAr: String?
    var enough: Bool = false

    var text: String? { Lang.isArabic ? (verdictAr ?? verdict) : verdict }

    enum CodingKeys: String, CodingKey {
        case points, days, current, lowest, highest, average, verdict, enough
        case changeVsPrev = "change_vs_prev"
        case changeVsAvg = "change_vs_avg"
        case change7d = "change_7d"
        case verdictAr = "verdict_ar"
    }
}

struct LivePoint: Decodable, Hashable, Identifiable {
    var day: String
    var price: Money
    var stores: Int?
    var id: String { day }
}

/// Is this a real discount? Needs enough days of readings to say.
struct LiveDeal: Decodable, Hashable {
    var verdict: String?
    var verdictAr: String?
    var genuine: Bool?
    var enough: Bool = false
    var text: String? { Lang.isArabic ? (verdictAr ?? verdict) : verdict }
}

struct LiveProductResponse: Decodable {
    var key: String = ""
    var title: String?
    var image: String?
    var variant: String?
    var rating: Double?
    var specs: [String] = []
    var offers: [LiveOffer] = []
    var history: LiveHistory?
    var deal: LiveDeal?
    var watch: LiveWatch?
    var query: String?
}

/// Wafi Shadow: a product this phone is watching.
struct LiveWatch: Decodable, Hashable, Identifiable {
    var key: String = ""
    var q: String?
    var title: String?
    var image: String?
    var targetPrice: Money?
    var startPrice: Money?
    var lastPrice: Money?
    var inStock: Bool?
    var checkedAt: String?
    var id: String { key }

    enum CodingKeys: String, CodingKey {
        case key, q, title, image
        case targetPrice = "target_price"
        case startPrice = "start_price"
        case lastPrice = "last_price"
        case inStock = "in_stock"
        case checkedAt = "checked_at"
    }
}

struct LiveNotification: Decodable, Hashable, Identifiable {
    var id: Int
    var kind: String                  // target_hit | price_drop | back_in_stock
    var key: String?
    var title: String?
    var oldPrice: Money?
    var newPrice: Money?
    var store: String?
    var createdAt: String?
    var read: Bool = false

    var isUnread: Bool { !read }
    var headline: String {
        switch kind {
        case "target_hit": return t("وصل السعر اللي طلبته", "It hit your target price")
        case "back_in_stock": return t("رجع متوفر", "Back in stock")
        default: return t("السعر نزل", "The price dropped")
        }
    }

    enum CodingKeys: String, CodingKey {
        case id, kind, key, title, store
        case oldPrice = "old_price"
        case newPrice = "new_price"
        case createdAt = "created_at"
        case read
    }
}

struct LiveNotifications: Decodable {
    var unread: Int = 0
    var items: [LiveNotification] = []
}

/// A product people found recently, with live prices from more than one shop (the home screen's strip).
struct LiveTrending: Decodable, Identifiable, Hashable {
    var key: String
    var title: String
    var image: String?
    var q: String?
    var priceFrom: Money?
    var stores: Int = 0
    var id: String { key }

    enum CodingKeys: String, CodingKey {
        case key, title, image, q, stores
        case priceFrom = "price_from"
    }
}
