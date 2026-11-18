import Foundation

// The live engine's responses: products found across Egyptian shops right now, each price read from that
// shop's own page. Nothing here is an estimate — a product with no current price simply isn't returned.
//
// Every type decodes field by field with `decodeIfPresent`, as the rest of this app does, because Swift's
// synthesized decoder ignores a property's default value and throws on an absent key. Decoding this way means
// one missing field never empties a screen: a search that comes back without its coverage report still shows
// its products. Keys are spelled out; money is always Decimal.

/// One shop's offer for one product.
struct LiveOffer: Decodable, Identifiable, Hashable {
    var store = ""
    var domain = ""
    var price: Money = 0
    var availability = "unknown"       // in_stock | out_of_stock | preorder | unknown
    var url = ""
    var title = ""
    var logo: String?
    var total: Money?                  // price + shipping, when the shop states shipping
    var shipping: Money?
    var originalPrice: Money?
    var discountPct: Double?
    var stale = false
    var doubtful = false               // shown, but never the price we stand behind
    var priceStatus: String?           // VERIFIED | PARTIALLY_VERIFIED | UNVERIFIED | STALE
    var condition: String?
    var ageMin: Int?                   // how long ago that shop's page confirmed this price
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

    init() {}
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        store = try c.decodeIfPresent(String.self, forKey: .store) ?? ""
        domain = try c.decodeIfPresent(String.self, forKey: .domain) ?? ""
        price = try c.decodeIfPresent(Money.self, forKey: .price) ?? 0
        availability = try c.decodeIfPresent(String.self, forKey: .availability) ?? "unknown"
        url = try c.decodeIfPresent(String.self, forKey: .url) ?? ""
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
        logo = try c.decodeIfPresent(String.self, forKey: .logo)
        total = try c.decodeIfPresent(Money.self, forKey: .total)
        shipping = try c.decodeIfPresent(Money.self, forKey: .shipping)
        originalPrice = try c.decodeIfPresent(Money.self, forKey: .originalPrice)
        discountPct = try c.decodeIfPresent(Double.self, forKey: .discountPct)
        stale = try c.decodeIfPresent(Bool.self, forKey: .stale) ?? false
        doubtful = try c.decodeIfPresent(Bool.self, forKey: .doubtful) ?? false
        priceStatus = try c.decodeIfPresent(String.self, forKey: .priceStatus)
        condition = try c.decodeIfPresent(String.self, forKey: .condition)
        ageMin = try c.decodeIfPresent(Int.self, forKey: .ageMin)
        method = try c.decodeIfPresent(String.self, forKey: .method)
    }
}

/// One product: the same thing in every shop that sells it, cheapest first.
struct LiveGroup: Decodable, Identifiable, Hashable {
    var key = ""
    var title = ""
    var variant: String?
    var image: String?
    var rating: Double?
    var ratingCount: Int?
    var stores = 0
    var priceFrom: Money?
    var priceTo: Money?
    var bestStore: String?
    var offers: [LiveOffer] = []
    var specs: [String] = []
    var changePct: Double?
    var historyDays: Int?
    var condition: String?
    var stale = false
    var brand: String?
    var verifiedMin: Int?

    var id: String { key }
    var isUsed: Bool { condition == "used" }
    /// The badge the card shows: how far this product's price has come down.
    var dropPct: Double? { if let c = changePct, c < -0.5 { return c }; return nil }

    enum CodingKeys: String, CodingKey {
        case key, title, variant, image, rating, stores, offers, specs, condition, stale, brand
        case ratingCount = "rating_count"
        case priceFrom = "price_from"
        case priceTo = "price_to"
        case bestStore = "best_store"
        case changePct = "change_pct"
        case historyDays = "history_days"
        case verifiedMin = "verified_min"
    }

    init() {}
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        key = try c.decodeIfPresent(String.self, forKey: .key) ?? ""
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
        variant = try c.decodeIfPresent(String.self, forKey: .variant)
        image = try c.decodeIfPresent(String.self, forKey: .image)
        rating = try c.decodeIfPresent(Double.self, forKey: .rating)
        ratingCount = try c.decodeIfPresent(Int.self, forKey: .ratingCount)
        stores = try c.decodeIfPresent(Int.self, forKey: .stores) ?? 0
        priceFrom = try c.decodeIfPresent(Money.self, forKey: .priceFrom)
        priceTo = try c.decodeIfPresent(Money.self, forKey: .priceTo)
        bestStore = try c.decodeIfPresent(String.self, forKey: .bestStore)
        offers = try c.decodeIfPresent([LiveOffer].self, forKey: .offers) ?? []
        specs = try c.decodeIfPresent([String].self, forKey: .specs) ?? []
        changePct = try c.decodeIfPresent(Double.self, forKey: .changePct)
        historyDays = try c.decodeIfPresent(Int.self, forKey: .historyDays)
        condition = try c.decodeIfPresent(String.self, forKey: .condition)
        stale = try c.decodeIfPresent(Bool.self, forKey: .stale) ?? false
        brand = try c.decodeIfPresent(String.self, forKey: .brand)
        verifiedMin = try c.decodeIfPresent(Int.self, forKey: .verifiedMin)
    }
}

/// How much of the market this search actually saw. Never 100%, and every reason is listed.
struct LiveCoverage: Decodable, Hashable {
    var state = "PARTIAL"              // COMPLETE | PARTIAL | LIMITED | FAILED
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

    enum CodingKeys: String, CodingKey { case state, confidence, reasons, merchants, urls }

    init() {}
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        state = try c.decodeIfPresent(String.self, forKey: .state) ?? "PARTIAL"
        confidence = try c.decodeIfPresent(Double.self, forKey: .confidence)
        reasons = try c.decodeIfPresent([String].self, forKey: .reasons) ?? []
        merchants = try c.decodeIfPresent(Counts.self, forKey: .merchants)
        urls = try c.decodeIfPresent(Counts.self, forKey: .urls)
    }
}

struct LiveUnderstood: Decodable, Hashable {
    var en: String?
    var ar: String?
    var by: String?
}

struct LiveSearchResponse: Decodable {
    var query = ""
    var vertical: String?
    var groups: [LiveGroup] = []
    var understood: LiveUnderstood?
    var coverage: LiveCoverage?
    var pending = false
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

    init() {}
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        query = try c.decodeIfPresent(String.self, forKey: .query) ?? ""
        vertical = try c.decodeIfPresent(String.self, forKey: .vertical)
        groups = try c.decodeIfPresent([LiveGroup].self, forKey: .groups) ?? []
        understood = try c.decodeIfPresent(LiveUnderstood.self, forKey: .understood)
        coverage = try c.decodeIfPresent(LiveCoverage.self, forKey: .coverage)
        pending = try c.decodeIfPresent(Bool.self, forKey: .pending) ?? false
        source = try c.decodeIfPresent(String.self, forKey: .source)
        tookMs = try c.decodeIfPresent(Int.self, forKey: .tookMs)
        notice = try c.decodeIfPresent(String.self, forKey: .notice)
        noticeAr = try c.decodeIfPresent(String.self, forKey: .noticeAr)
    }
}

/// A product's price history, and what it means.
struct LiveHistory: Decodable, Hashable {
    var points: [LivePoint] = []
    var days = 0
    var current: Money?
    var lowest: Money?
    var highest: Money?
    var average: Money?
    var changeVsPrev: Double?
    var changeVsAvg: Double?
    var change7d: Double?
    var verdict: String?
    var verdictAr: String?
    var enough = false

    var text: String? { Lang.isArabic ? (verdictAr ?? verdict) : verdict }

    enum CodingKeys: String, CodingKey {
        case points, days, current, lowest, highest, average, verdict, enough
        case changeVsPrev = "change_vs_prev"
        case changeVsAvg = "change_vs_avg"
        case change7d = "change_7d"
        case verdictAr = "verdict_ar"
    }

    init() {}
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        points = try c.decodeIfPresent([LivePoint].self, forKey: .points) ?? []
        days = try c.decodeIfPresent(Int.self, forKey: .days) ?? 0
        current = try c.decodeIfPresent(Money.self, forKey: .current)
        lowest = try c.decodeIfPresent(Money.self, forKey: .lowest)
        highest = try c.decodeIfPresent(Money.self, forKey: .highest)
        average = try c.decodeIfPresent(Money.self, forKey: .average)
        changeVsPrev = try c.decodeIfPresent(Double.self, forKey: .changeVsPrev)
        changeVsAvg = try c.decodeIfPresent(Double.self, forKey: .changeVsAvg)
        change7d = try c.decodeIfPresent(Double.self, forKey: .change7d)
        verdict = try c.decodeIfPresent(String.self, forKey: .verdict)
        verdictAr = try c.decodeIfPresent(String.self, forKey: .verdictAr)
        enough = try c.decodeIfPresent(Bool.self, forKey: .enough) ?? false
    }
}

struct LivePoint: Decodable, Hashable, Identifiable {
    var day = ""
    var price: Money = 0
    var stores: Int?
    var id: String { day }

    enum CodingKeys: String, CodingKey { case day, price, stores }

    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        day = try c.decodeIfPresent(String.self, forKey: .day) ?? ""
        price = try c.decodeIfPresent(Money.self, forKey: .price) ?? 0
        stores = try c.decodeIfPresent(Int.self, forKey: .stores)
    }
}

/// Is this a real discount? Needs enough days of readings to say.
struct LiveDeal: Decodable, Hashable {
    var verdict: String?
    var verdictAr: String?
    var genuine: Bool?
    var enough = false
    var text: String? { Lang.isArabic ? (verdictAr ?? verdict) : verdict }

    enum CodingKeys: String, CodingKey { case verdict, genuine, enough; case verdictAr = "verdict_ar" }

    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        verdict = try c.decodeIfPresent(String.self, forKey: .verdict)
        verdictAr = try c.decodeIfPresent(String.self, forKey: .verdictAr)
        genuine = try c.decodeIfPresent(Bool.self, forKey: .genuine)
        enough = try c.decodeIfPresent(Bool.self, forKey: .enough) ?? false
    }
}

struct LiveProductResponse: Decodable {
    var key = ""
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

    enum CodingKeys: String, CodingKey {
        case key, title, image, variant, rating, specs, offers, history, deal, watch, query
    }

    init() {}
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        key = try c.decodeIfPresent(String.self, forKey: .key) ?? ""
        title = try c.decodeIfPresent(String.self, forKey: .title)
        image = try c.decodeIfPresent(String.self, forKey: .image)
        variant = try c.decodeIfPresent(String.self, forKey: .variant)
        rating = try c.decodeIfPresent(Double.self, forKey: .rating)
        specs = try c.decodeIfPresent([String].self, forKey: .specs) ?? []
        offers = try c.decodeIfPresent([LiveOffer].self, forKey: .offers) ?? []
        history = try c.decodeIfPresent(LiveHistory.self, forKey: .history)
        deal = try c.decodeIfPresent(LiveDeal.self, forKey: .deal)
        watch = try c.decodeIfPresent(LiveWatch.self, forKey: .watch)
        query = try c.decodeIfPresent(String.self, forKey: .query)
    }
}

/// Wafi Shadow: a product this phone is watching.
struct LiveWatch: Decodable, Hashable, Identifiable {
    var key = ""
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

    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        key = try c.decodeIfPresent(String.self, forKey: .key) ?? ""
        q = try c.decodeIfPresent(String.self, forKey: .q)
        title = try c.decodeIfPresent(String.self, forKey: .title)
        image = try c.decodeIfPresent(String.self, forKey: .image)
        targetPrice = try c.decodeIfPresent(Money.self, forKey: .targetPrice)
        startPrice = try c.decodeIfPresent(Money.self, forKey: .startPrice)
        lastPrice = try c.decodeIfPresent(Money.self, forKey: .lastPrice)
        inStock = try c.decodeIfPresent(Bool.self, forKey: .inStock)
        checkedAt = try c.decodeIfPresent(String.self, forKey: .checkedAt)
    }
}

struct LiveNotification: Decodable, Hashable, Identifiable {
    var id = 0
    var kind = "price_drop"            // target_hit | price_drop | back_in_stock
    var key: String?
    var title: String?
    var oldPrice: Money?
    var newPrice: Money?
    var store: String?
    var createdAt: String?
    var read = false

    var isUnread: Bool { !read }
    var headline: String {
        switch kind {
        case "target_hit": return t("وصل السعر اللي طلبته", "It hit your target price")
        case "back_in_stock": return t("رجع متوفر", "Back in stock")
        default: return t("السعر نزل", "The price dropped")
        }
    }

    enum CodingKeys: String, CodingKey {
        case id, kind, key, title, store, read
        case oldPrice = "old_price"
        case newPrice = "new_price"
        case createdAt = "created_at"
    }

    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(Int.self, forKey: .id) ?? 0
        kind = try c.decodeIfPresent(String.self, forKey: .kind) ?? "price_drop"
        key = try c.decodeIfPresent(String.self, forKey: .key)
        title = try c.decodeIfPresent(String.self, forKey: .title)
        oldPrice = try c.decodeIfPresent(Money.self, forKey: .oldPrice)
        newPrice = try c.decodeIfPresent(Money.self, forKey: .newPrice)
        store = try c.decodeIfPresent(String.self, forKey: .store)
        createdAt = try c.decodeIfPresent(String.self, forKey: .createdAt)
        read = try c.decodeIfPresent(Bool.self, forKey: .read) ?? false
    }
}

struct LiveNotifications: Decodable {
    var unread = 0
    var items: [LiveNotification] = []

    enum CodingKeys: String, CodingKey { case unread, items }

    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        unread = try c.decodeIfPresent(Int.self, forKey: .unread) ?? 0
        items = try c.decodeIfPresent([LiveNotification].self, forKey: .items) ?? []
    }
}

/// A product people found recently, with live prices from more than one shop (the home screen's strip).
struct LiveTrending: Decodable, Identifiable, Hashable {
    var key = ""
    var title = ""
    var image: String?
    var q: String?
    var priceFrom: Money?
    var stores = 0
    var id: String { key }

    enum CodingKeys: String, CodingKey {
        case key, title, image, q, stores
        case priceFrom = "price_from"
    }

    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        key = try c.decodeIfPresent(String.self, forKey: .key) ?? ""
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
        image = try c.decodeIfPresent(String.self, forKey: .image)
        q = try c.decodeIfPresent(String.self, forKey: .q)
        priceFrom = try c.decodeIfPresent(Money.self, forKey: .priceFrom)
        stores = try c.decodeIfPresent(Int.self, forKey: .stores) ?? 0
    }
}

/// What the live engine holds right now: counts only, for the home screen's radar.
struct LiveStats: Decodable {
    var offers = 0
    var shops = 0
    var fresh48h = 0
    var stale = 0
    var approved = 0
    var successPct: Double?

    enum CodingKeys: String, CodingKey {
        case offers, shops, stale, approved
        case fresh48h = "fresh_48h"
        case successPct = "success_pct"
    }

    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        offers = try c.decodeIfPresent(Int.self, forKey: .offers) ?? 0
        shops = try c.decodeIfPresent(Int.self, forKey: .shops) ?? 0
        fresh48h = try c.decodeIfPresent(Int.self, forKey: .fresh48h) ?? 0
        stale = try c.decodeIfPresent(Int.self, forKey: .stale) ?? 0
        approved = try c.decodeIfPresent(Int.self, forKey: .approved) ?? 0
        successPct = try c.decodeIfPresent(Double.self, forKey: .successPct)
    }
}
