import Foundation

// Response models for the WAFI API (same contract the Android app uses).
// Money is always Decimal, never Double: see the KeyedDecodingContainer extension below.
// Keys are spelled out (no convertFromSnakeCase) because that strategy would also rewrite
// dictionary keys such as spec names ("camera_mp") and metric names ("gold_pound").

typealias Money = Decimal

// MARK: - Decimal decoding from JSON numbers or strings

private struct LosslessNumber: Decodable {
    let value: Decimal
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let s = try? c.decode(String.self), let d = Decimal(string: s.trimmingCharacters(in: .whitespaces), locale: Locale(identifier: "en_US_POSIX")) {
            value = d
        } else if let i = try? c.decode(Int64.self) {
            value = Decimal(i)
        } else {
            let d = try c.decode(Double.self)
            // shortest round-trip text of the double, then exact decimal parsing: 19999.5 stays 19999.5
            value = Decimal(string: "\(d)", locale: Locale(identifier: "en_US_POSIX")) ?? Decimal(d)
        }
    }
}

extension KeyedDecodingContainer {
    func decode(_ type: Decimal.Type, forKey key: K) throws -> Decimal {
        try decode(LosslessNumber.self, forKey: key).value
    }
    func decodeIfPresent(_ type: Decimal.Type, forKey key: K) throws -> Decimal? {
        guard contains(key), try !decodeNil(forKey: key) else { return nil }
        return try decode(LosslessNumber.self, forKey: key).value
    }
}

/// Decimal as an unquoted JSON number (the API's Decimal fields accept it).
struct MoneyBody: Encodable {
    let value: Decimal
    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(value)
    }
}

// MARK: - Free-form JSON (specs, assistant card items)

enum JSONValue: Codable, Hashable {
    case string(String), number(Double), bool(Bool), array([JSONValue]), object([String: JSONValue]), null

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null }
        else if let b = try? c.decode(Bool.self) { self = .bool(b) }
        else if let n = try? c.decode(Double.self) { self = .number(n) }
        else if let s = try? c.decode(String.self) { self = .string(s) }
        else if let a = try? c.decode([JSONValue].self) { self = .array(a) }
        else { self = .object(try c.decode([String: JSONValue].self)) }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .string(let s): try c.encode(s)
        case .number(let n): try c.encode(n)
        case .bool(let b): try c.encode(b)
        case .array(let a): try c.encode(a)
        case .object(let o): try c.encode(o)
        case .null: try c.encodeNil()
        }
    }

    var string: String? { if case .string(let s) = self { return s }; return nil }
    var int: Int? { if case .number(let n) = self { return Int(n) }; return nil }
    var double: Double? { if case .number(let n) = self { return n }; return nil }
    var bool: Bool? { if case .bool(let b) = self { return b }; return nil }
    var array: [JSONValue]? { if case .array(let a) = self { return a }; return nil }
    var object: [String: JSONValue]? { if case .object(let o) = self { return o }; return nil }
}

typealias Specs = [String: JSONValue]

extension Dictionary where Key == String, Value == JSONValue {
    func str(_ k: String) -> String? { self[k]?.string }
    func int(_ k: String) -> Int? { self[k]?.int }
    func num(_ k: String) -> Double? { self[k]?.double }
    func flag(_ k: String) -> Bool? { self[k]?.bool }
}

// MARK: - Identity

enum Role: String, Comparable {
    case anon, viewer, contributor, editor, owner
    private var rank: Int { [.anon, .viewer, .contributor, .editor, .owner].firstIndex(of: self)! }
    static func < (a: Role, b: Role) -> Bool { a.rank < b.rank }
}

struct Me: Codable, Equatable {
    var authenticated: Bool
    var role: String = "anon"
    var userId: String?
    var email: String?
    var name: String?
    var emailVerified: Bool = false
    var hasPassword: Bool = false
    var pro: Bool = false
    enum CodingKeys: String, CodingKey {
        case authenticated, role, email, name, pro
        case userId = "user_id", emailVerified = "email_verified", hasPassword = "has_password"
    }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        authenticated = try c.decode(Bool.self, forKey: .authenticated)
        role = try c.decodeIfPresent(String.self, forKey: .role) ?? "anon"
        userId = try c.decodeIfPresent(String.self, forKey: .userId)
        email = try c.decodeIfPresent(String.self, forKey: .email)
        name = try c.decodeIfPresent(String.self, forKey: .name)
        emailVerified = try c.decodeIfPresent(Bool.self, forKey: .emailVerified) ?? false
        hasPassword = try c.decodeIfPresent(Bool.self, forKey: .hasPassword) ?? false
        pro = try c.decodeIfPresent(Bool.self, forKey: .pro) ?? false
    }
    var roleValue: Role { Role(rawValue: role) ?? .anon }
}

struct SessionUser: Codable, Equatable {
    var userId: String
    var email: String
    var name: String?
    var role: String?
    enum CodingKeys: String, CodingKey { case email, name, role; case userId = "user_id" }
}

struct SessionResponse: Decodable {
    var token: String
    var user: SessionUser
}

// MARK: - Catalog

enum Category: String, CaseIterable, Identifiable {
    case phones, laptops, audio, tablets, cars, pcParts = "pc_parts", fashion, music, other
    var id: String { rawValue }
    static func from(_ s: String?) -> Category { Category(rawValue: s ?? "") ?? .other }
}

struct ProductSummary: Codable, Identifiable, Hashable {
    var id: String
    var brand: String
    var model: String
    var category: String = "other"
    var gtin: String?
    var titleAr: String
    var titleEn: String
    var storage: String = ""
    var ram: String = ""
    var color: String = ""
    var condition: String = "new"
    var minPrice: Money?
    var bestTotal: Money?
    var offers: Int = 0
    var specs: Specs = [:]
    var imageUrl: String?
    var bestStore: String?
    var bestSeenAt: String?
    var inStock: Bool?

    enum CodingKeys: String, CodingKey {
        case id, brand, model, category, gtin, storage, ram, color, condition, offers, specs
        case titleAr = "title_ar", titleEn = "title_en", minPrice = "min_price", bestTotal = "best_total", imageUrl = "image_url"
        case bestStore = "best_store", bestSeenAt = "best_seen_at", inStock = "in_stock"
    }

    init(id: String, brand: String, model: String, category: String = "other", titleAr: String, titleEn: String,
         condition: String = "new", minPrice: Money? = nil, bestTotal: Money? = nil, offers: Int = 0,
         specs: Specs = [:], imageUrl: String? = nil, storage: String = "", ram: String = "", color: String = "") {
        self.id = id; self.brand = brand; self.model = model; self.category = category; self.titleAr = titleAr
        self.titleEn = titleEn; self.condition = condition; self.minPrice = minPrice; self.bestTotal = bestTotal
        self.offers = offers; self.specs = specs; self.imageUrl = imageUrl; self.storage = storage; self.ram = ram; self.color = color
    }

    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        brand = try c.decodeIfPresent(String.self, forKey: .brand) ?? ""
        model = try c.decodeIfPresent(String.self, forKey: .model) ?? ""
        category = try c.decodeIfPresent(String.self, forKey: .category) ?? "other"
        gtin = try c.decodeIfPresent(String.self, forKey: .gtin)
        titleAr = try c.decode(String.self, forKey: .titleAr)
        titleEn = try c.decode(String.self, forKey: .titleEn)
        storage = try c.decodeIfPresent(String.self, forKey: .storage) ?? ""
        ram = try c.decodeIfPresent(String.self, forKey: .ram) ?? ""
        color = try c.decodeIfPresent(String.self, forKey: .color) ?? ""
        condition = try c.decodeIfPresent(String.self, forKey: .condition) ?? "new"
        minPrice = try c.decodeIfPresent(Decimal.self, forKey: .minPrice)
        bestTotal = try c.decodeIfPresent(Decimal.self, forKey: .bestTotal)
        offers = try c.decodeIfPresent(Int.self, forKey: .offers) ?? 0
        specs = try c.decodeIfPresent(Specs.self, forKey: .specs) ?? [:]
        imageUrl = try c.decodeIfPresent(String.self, forKey: .imageUrl)
        bestStore = try c.decodeIfPresent(String.self, forKey: .bestStore)
        bestSeenAt = try c.decodeIfPresent(String.self, forKey: .bestSeenAt)
        inStock = try c.decodeIfPresent(Bool.self, forKey: .inStock)
    }

    /// The price to show in lists: confirmed best total, else lowest listed price.
    var displayPrice: Money? { bestTotal ?? minPrice }
}

struct Items<T: Decodable>: Decodable { var items: [T] }

struct Product: Decodable, Hashable {
    var id: String
    var brand: String
    var model: String
    var category: String
    var gtin: String?
    var titleAr: String
    var titleEn: String
    var storage: String
    var ram: String
    var color: String
    var condition: String
    var specs: Specs
    var imageUrl: String?
    enum CodingKeys: String, CodingKey {
        case id, brand, model, category, gtin, storage, ram, color, condition, specs
        case titleAr = "title_ar", titleEn = "title_en", imageUrl = "image_url"
    }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        brand = try c.decodeIfPresent(String.self, forKey: .brand) ?? ""
        model = try c.decodeIfPresent(String.self, forKey: .model) ?? ""
        category = try c.decodeIfPresent(String.self, forKey: .category) ?? "other"
        gtin = try c.decodeIfPresent(String.self, forKey: .gtin)
        titleAr = try c.decode(String.self, forKey: .titleAr)
        titleEn = try c.decode(String.self, forKey: .titleEn)
        storage = try c.decodeIfPresent(String.self, forKey: .storage) ?? ""
        ram = try c.decodeIfPresent(String.self, forKey: .ram) ?? ""
        color = try c.decodeIfPresent(String.self, forKey: .color) ?? ""
        condition = try c.decodeIfPresent(String.self, forKey: .condition) ?? "new"
        specs = try c.decodeIfPresent(Specs.self, forKey: .specs) ?? [:]
        imageUrl = try c.decodeIfPresent(String.self, forKey: .imageUrl)
    }
    var summary: ProductSummary {
        ProductSummary(id: id, brand: brand, model: model, category: category, titleAr: titleAr, titleEn: titleEn,
                       condition: condition, specs: specs, imageUrl: imageUrl, storage: storage, ram: ram, color: color)
    }
}

struct Offer: Decodable, Identifiable, Hashable {
    var id: Int64
    var productId: String
    var storeId: String
    var storeName: String
    var price: Money
    var shipping: Money?
    var fees: Money?
    var availability: String
    var url: String
    var warranty: String
    var sponsored: Bool
    var observedAt: String
    var total: Money
    var fresh: Bool
    var shippingKnown: Bool
    var shippingFree: Bool
    var totalStatus: String
    enum CodingKeys: String, CodingKey {
        case id, price, shipping, fees, availability, url, warranty, sponsored, total, fresh
        case productId = "product_id", storeId = "store_id", storeName = "store_name", observedAt = "observed_at"
        case shippingKnown = "shipping_known", shippingFree = "shipping_free", totalStatus = "total_status"
    }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int64.self, forKey: .id)
        productId = try c.decode(String.self, forKey: .productId)
        storeId = try c.decode(String.self, forKey: .storeId)
        storeName = try c.decode(String.self, forKey: .storeName)
        price = try c.decode(Decimal.self, forKey: .price)
        shipping = try c.decodeIfPresent(Decimal.self, forKey: .shipping)
        fees = try c.decodeIfPresent(Decimal.self, forKey: .fees)
        availability = try c.decodeIfPresent(String.self, forKey: .availability) ?? "unknown"
        url = try c.decode(String.self, forKey: .url)
        warranty = try c.decodeIfPresent(String.self, forKey: .warranty) ?? ""
        sponsored = try c.decodeIfPresent(Bool.self, forKey: .sponsored) ?? false
        observedAt = try c.decodeIfPresent(String.self, forKey: .observedAt) ?? ""
        total = try c.decode(Decimal.self, forKey: .total)
        fresh = try c.decodeIfPresent(Bool.self, forKey: .fresh) ?? true
        shippingKnown = try c.decodeIfPresent(Bool.self, forKey: .shippingKnown) ?? (shipping != nil)
        shippingFree = try c.decodeIfPresent(Bool.self, forKey: .shippingFree) ?? false
        totalStatus = try c.decodeIfPresent(String.self, forKey: .totalStatus) ?? "confirmed"
    }
}

struct BestOffer: Decodable, Hashable {
    var offerId: Int64
    var storeId: String
    var total: Money
    var totalStatus: String
    var eligibleCount: Int
    enum CodingKeys: String, CodingKey {
        case total
        case offerId = "offer_id", storeId = "store_id", totalStatus = "total_status", eligibleCount = "eligible_count"
    }
}

struct DailyLow: Decodable, Hashable { var day: String; var price: Money }

struct Insight: Decodable, Hashable {
    var status: String
    var verdict: String?
    var percent: Money?
    var median: Money?
    var lowest: Money?
    var windowDays: Int?
    var days: Int?
    var requiredDays: Int?
    enum CodingKeys: String, CodingKey {
        case status, verdict, percent, median, lowest, days
        case windowDays = "window_days", requiredDays = "required_days"
    }
}

struct ProductDetail: Decodable {
    var product: Product
    var offers: [Offer]
    var best: BestOffer?
    var dailyLows: [DailyLow]
    var insight: Insight
    var freshHours: Int
    var historyLimitDays: Int?
    var usedNew: UsedNew?
    var lens: PriceLens?
    var reference: ReferencePrice?
    enum CodingKeys: String, CodingKey {
        case product, offers, best, insight, lens, reference
        case dailyLows = "daily_lows", freshHours = "fresh_hours", historyLimitDays = "history_limit_days", usedNew = "used_new"
    }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        product = try c.decode(Product.self, forKey: .product)
        offers = try c.decodeIfPresent([Offer].self, forKey: .offers) ?? []
        best = try c.decodeIfPresent(BestOffer.self, forKey: .best)
        dailyLows = try c.decodeIfPresent([DailyLow].self, forKey: .dailyLows) ?? []
        insight = try c.decode(Insight.self, forKey: .insight)
        freshHours = try c.decodeIfPresent(Int.self, forKey: .freshHours) ?? 48
        historyLimitDays = try c.decodeIfPresent(Int.self, forKey: .historyLimitDays)
        usedNew = try c.decodeIfPresent(UsedNew.self, forKey: .usedNew)
        lens = try c.decodeIfPresent(PriceLens.self, forKey: .lens)
        reference = try c.decodeIfPresent(ReferencePrice.self, forKey: .reference)
    }
}

/// A market price for a product no store lists yet: a published price list, or the average of current online offers.
struct ReferencePrice: Decodable, Hashable {
    var price: Money
    var priceMax: Money?
    var asOf: String?
    var source: String?
    var kind: String = "list"
    var count: Int?
    var avg: Money?
    enum CodingKeys: String, CodingKey { case price, source, kind, count, avg; case priceMax = "price_max", asOf = "as_of" }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        price = try c.decode(Decimal.self, forKey: .price)
        priceMax = try c.decodeIfPresent(Decimal.self, forKey: .priceMax)
        asOf = try c.decodeIfPresent(String.self, forKey: .asOf)
        source = try c.decodeIfPresent(String.self, forKey: .source)
        kind = try c.decodeIfPresent(String.self, forKey: .kind) ?? "list"
        count = try c.decodeIfPresent(Int.self, forKey: .count)
        avg = try c.decodeIfPresent(Decimal.self, forKey: .avg)
    }
}

struct Store: Decodable, Identifiable, Hashable {
    var id: String
    var name: String
    var country: String?
}

// MARK: - Basket

struct BasketLineIn: Codable, Hashable {
    var productId: String
    var qty: Int
    enum CodingKeys: String, CodingKey { case qty; case productId = "product_id" }
}

struct PlanLine: Decodable, Hashable {
    var productId: String
    var qty: Int
    var unitPrice: Money
    enum CodingKeys: String, CodingKey { case qty; case productId = "product_id", unitPrice = "unit_price" }
}

struct PlanStore: Decodable, Hashable {
    var storeId: String
    var storeName: String
    var lines: [PlanLine]
    enum CodingKeys: String, CodingKey { case lines; case storeId = "store_id", storeName = "store_name" }
}

struct BasketPlan: Decodable, Hashable {
    var kind: String
    var stores: [PlanStore]
    var subtotal: Money
    var shipping: Money
    var total: Money
    var complete: Bool
    var shippingUnknown: [String]
    var belowMinOrder: [String]
    enum CodingKeys: String, CodingKey {
        case kind, stores, subtotal, shipping, total, complete
        case shippingUnknown = "shipping_unknown", belowMinOrder = "below_min_order"
    }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        kind = try c.decode(String.self, forKey: .kind)
        stores = try c.decode([PlanStore].self, forKey: .stores)
        subtotal = try c.decode(Decimal.self, forKey: .subtotal)
        shipping = try c.decode(Decimal.self, forKey: .shipping)
        total = try c.decode(Decimal.self, forKey: .total)
        complete = try c.decode(Bool.self, forKey: .complete)
        shippingUnknown = try c.decodeIfPresent([String].self, forKey: .shippingUnknown) ?? []
        belowMinOrder = try c.decodeIfPresent([String].self, forKey: .belowMinOrder) ?? []
    }
}

struct ProductTitle: Decodable, Hashable {
    var titleAr: String
    var titleEn: String
    enum CodingKeys: String, CodingKey { case titleAr = "title_ar", titleEn = "title_en" }
}

struct BasketResponse: Decodable {
    var unavailableProducts: [String]
    var split: BasketPlan?
    var recommended: BasketPlan?
    var singleStore: [BasketPlan]
    var optimal: Bool
    var notes: [String]
    var products: [String: ProductTitle]
    enum CodingKeys: String, CodingKey {
        case split, recommended, optimal, notes, products
        case unavailableProducts = "unavailable_products", singleStore = "single_store"
    }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        unavailableProducts = try c.decodeIfPresent([String].self, forKey: .unavailableProducts) ?? []
        split = try c.decodeIfPresent(BasketPlan.self, forKey: .split)
        recommended = try c.decodeIfPresent(BasketPlan.self, forKey: .recommended)
        singleStore = try c.decodeIfPresent([BasketPlan].self, forKey: .singleStore) ?? []
        optimal = try c.decodeIfPresent(Bool.self, forKey: .optimal) ?? false
        notes = try c.decodeIfPresent([String].self, forKey: .notes) ?? []
        products = try c.decodeIfPresent([String: ProductTitle].self, forKey: .products) ?? [:]
    }
}

// MARK: - Watchlist & alerts

struct WatchItem: Decodable, Identifiable, Hashable {
    var productId: String
    var target: Money?
    var titleAr: String
    var titleEn: String
    var brand: String
    var bestTotal: Money?
    var targetReached: Bool
    var id: String { productId }
    enum CodingKeys: String, CodingKey {
        case target, brand
        case productId = "product_id", titleAr = "title_ar", titleEn = "title_en", bestTotal = "best_total", targetReached = "target_reached"
    }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        productId = try c.decode(String.self, forKey: .productId)
        target = try c.decodeIfPresent(Decimal.self, forKey: .target)
        titleAr = try c.decode(String.self, forKey: .titleAr)
        titleEn = try c.decode(String.self, forKey: .titleEn)
        brand = try c.decodeIfPresent(String.self, forKey: .brand) ?? ""
        bestTotal = try c.decodeIfPresent(Decimal.self, forKey: .bestTotal)
        targetReached = try c.decodeIfPresent(Bool.self, forKey: .targetReached) ?? false
    }
}

struct AlertItem: Decodable, Identifiable, Hashable {
    var id: Int64
    var productId: String
    var titleAr: String
    var titleEn: String
    var target: Money?
    var total: Money
    var createdAt: String
    var readAt: String?
    enum CodingKeys: String, CodingKey {
        case id, target, total
        case productId = "product_id", titleAr = "title_ar", titleEn = "title_en", createdAt = "created_at", readAt = "read_at"
    }
}

struct AlertList: Decodable { var items: [AlertItem]; var unread: Int? }

// MARK: - Gold & currencies

struct CurrencyRate: Decodable, Hashable, Identifiable {
    var code: String
    var egp: Money
    var changePct: Money?
    var id: String { code }
    enum CodingKeys: String, CodingKey { case code, egp; case changePct = "change_pct" }
}

struct KaratPrice: Decodable, Hashable {
    var karat: Int
    var egpPerGram: Money
    var changePct: Money?
    enum CodingKeys: String, CodingKey { case karat; case egpPerGram = "egp_per_gram", changePct = "change_pct" }
}

struct GoldPrices: Decodable, Hashable {
    var usdPerOunce: Money
    var egpPerOunce: Money
    var karats: [KaratPrice]
    var goldPoundEgp: Money
    var changePct: Money?
    enum CodingKeys: String, CodingKey {
        case karats
        case usdPerOunce = "usd_per_ounce", egpPerOunce = "egp_per_ounce", goldPoundEgp = "gold_pound_egp", changePct = "change_pct"
    }
}

struct SilverPrices: Decodable, Hashable {
    var egpPerGram999: Money
    var usdPerOunce: Money
    enum CodingKeys: String, CodingKey { case egpPerGram999 = "egp_per_gram_999", usdPerOunce = "usd_per_ounce" }
}

struct MarketResponse: Decodable, Hashable {
    var asOf: String
    var base: String
    var currencies: [CurrencyRate]
    var gold: GoldPrices
    var silver: SilverPrices?
    var stale: Bool
    enum CodingKeys: String, CodingKey { case base, currencies, gold, silver, stale; case asOf = "as_of" }
    init(asOf: String, base: String = "EGP", currencies: [CurrencyRate], gold: GoldPrices) {
        self.asOf = asOf; self.base = base; self.currencies = currencies; self.gold = gold; self.stale = false
    }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        asOf = try c.decode(String.self, forKey: .asOf)
        base = try c.decodeIfPresent(String.self, forKey: .base) ?? "EGP"
        currencies = try c.decode([CurrencyRate].self, forKey: .currencies)
        gold = try c.decode(GoldPrices.self, forKey: .gold)
        silver = try c.decodeIfPresent(SilverPrices.self, forKey: .silver)
        stale = try c.decodeIfPresent(Bool.self, forKey: .stale) ?? false
    }
}

struct MarketDay: Decodable, Hashable {
    var day: String
    var gold21: Money
    enum CodingKeys: String, CodingKey { case day; case gold21 = "gold21_gram" }
}

// MARK: - PC builder

/// The same part offered used/refurbished, when it's cheaper than the chosen new one.
struct UsedListing: Decodable, Hashable {
    var productId: String
    var price: Money
    var saving: Money
    var titleAr: String
    var titleEn: String
    var condition: String
    var savingPct: Int = 0
    enum CodingKeys: String, CodingKey { case price, saving, condition; case productId = "product_id", titleAr = "title_ar", titleEn = "title_en", savingPct = "saving_pct" }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        productId = try c.decode(String.self, forKey: .productId)
        price = try c.decode(Decimal.self, forKey: .price)
        saving = try c.decode(Decimal.self, forKey: .saving)
        titleAr = try c.decodeIfPresent(String.self, forKey: .titleAr) ?? ""
        titleEn = try c.decodeIfPresent(String.self, forKey: .titleEn) ?? ""
        condition = try c.decodeIfPresent(String.self, forKey: .condition) ?? "used"
        savingPct = try c.decodeIfPresent(Int.self, forKey: .savingPct) ?? 0
    }
}

/// Facts only: buying one part used frees up money that could move another part up a tier.
struct UsedAdvice: Decodable, Hashable {
    var usedPart: String
    var usedSaving: Money
    var usedPrice: Money
    var usedProductId: String
    var usedTitleAr: String
    var usedTitleEn: String
    var upgradePart: String?
    var toTitleAr: String
    var toTitleEn: String
    var toProductId: String?
    var extraCost: Money?
    enum CodingKeys: String, CodingKey {
        case usedPart = "used_part", usedSaving = "used_saving", usedPrice = "used_price", usedProductId = "used_product_id"
        case usedTitleAr = "used_title_ar", usedTitleEn = "used_title_en", upgradePart = "upgrade_part"
        case toTitleAr = "to_title_ar", toTitleEn = "to_title_en", toProductId = "to_product_id", extraCost = "extra_cost"
    }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        usedPart = try c.decode(String.self, forKey: .usedPart)
        usedSaving = try c.decode(Decimal.self, forKey: .usedSaving)
        usedPrice = try c.decodeIfPresent(Decimal.self, forKey: .usedPrice) ?? 0
        usedProductId = try c.decodeIfPresent(String.self, forKey: .usedProductId) ?? ""
        usedTitleAr = try c.decodeIfPresent(String.self, forKey: .usedTitleAr) ?? ""
        usedTitleEn = try c.decodeIfPresent(String.self, forKey: .usedTitleEn) ?? ""
        upgradePart = try c.decodeIfPresent(String.self, forKey: .upgradePart)
        toTitleAr = try c.decodeIfPresent(String.self, forKey: .toTitleAr) ?? ""
        toTitleEn = try c.decodeIfPresent(String.self, forKey: .toTitleEn) ?? ""
        toProductId = try c.decodeIfPresent(String.self, forKey: .toProductId)
        extraCost = try c.decodeIfPresent(Decimal.self, forKey: .extraCost)
    }
    var toTitle: String { Lang.isArabic ? toTitleAr : toTitleEn }
}

struct PcPart: Decodable, Hashable {
    var part: String
    var productId: String
    var titleAr: String
    var titleEn: String
    var price: Money
    var specs: Specs
    var reasonAr: String
    var reasonEn: String
    var used: UsedListing?
    var newUsed: NewUsed?
    var pricedBy: String = "best_total"
    enum CodingKeys: String, CodingKey {
        case part, price, specs, used
        case productId = "product_id", titleAr = "title_ar", titleEn = "title_en", reasonAr = "reason_ar", reasonEn = "reason_en"
        case newUsed = "new_used", pricedBy = "priced_by"
    }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        part = try c.decode(String.self, forKey: .part)
        productId = try c.decode(String.self, forKey: .productId)
        titleAr = try c.decode(String.self, forKey: .titleAr)
        titleEn = try c.decode(String.self, forKey: .titleEn)
        price = try c.decode(Decimal.self, forKey: .price)
        specs = try c.decodeIfPresent(Specs.self, forKey: .specs) ?? [:]
        reasonAr = try c.decodeIfPresent(String.self, forKey: .reasonAr) ?? ""
        reasonEn = try c.decodeIfPresent(String.self, forKey: .reasonEn) ?? ""
        used = try c.decodeIfPresent(UsedListing.self, forKey: .used)
        newUsed = try c.decodeIfPresent(NewUsed.self, forKey: .newUsed)
        pricedBy = try c.decodeIfPresent(String.self, forKey: .pricedBy) ?? "best_total"
    }
}

/// The used side of a pick: a real listing, the online used average, or an estimate (labelled).
struct UsedSide: Decodable, Hashable {
    var price: Money
    var kind: String
    var productId: String?
    var count: Int?
    var sharePct: Int?
    enum CodingKeys: String, CodingKey { case price, kind, count; case productId = "product_id", sharePct = "share_pct" }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        price = try c.decode(Decimal.self, forKey: .price)
        kind = try c.decode(String.self, forKey: .kind)
        productId = try c.decodeIfPresent(String.self, forKey: .productId)
        count = try c.decodeIfPresent(Int.self, forKey: .count)
        sharePct = try c.decodeIfPresent(Int.self, forKey: .sharePct)
    }
}

/// Is the used one worth it: new | either | used, with the numbers.
struct NewUsedVerdict: Decodable, Hashable {
    var choice: String
    var saving: Money
    var savingPct: Int
    var reasonAr: String
    var reasonEn: String
    enum CodingKeys: String, CodingKey { case choice, saving; case savingPct = "saving_pct", reasonAr = "reason_ar", reasonEn = "reason_en" }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        choice = try c.decode(String.self, forKey: .choice)
        saving = try c.decode(Decimal.self, forKey: .saving)
        savingPct = try c.decode(Int.self, forKey: .savingPct)
        reasonAr = try c.decode(String.self, forKey: .reasonAr)
        reasonEn = try c.decode(String.self, forKey: .reasonEn)
    }
}

struct NewUsed: Decodable, Hashable {
    var newPrice: Money
    var used: UsedSide
    var verdict: NewUsedVerdict
    enum CodingKeys: String, CodingKey { case used, verdict; case newPrice = "new_price" }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        newPrice = try c.decode(Decimal.self, forKey: .newPrice)
        used = try c.decode(UsedSide.self, forKey: .used)
        verdict = try c.decode(NewUsedVerdict.self, forKey: .verdict)
    }
}

/// What the budget buys: how many options and their price range.
struct BudgetView: Decodable, Hashable {
    var count: Int
    var min: Money
    var max: Money
    var median: Money
    init(from d: Decoder) throws {
        enum K: String, CodingKey { case count, min, max, median }
        let c = try d.container(keyedBy: K.self)
        count = try c.decode(Int.self, forKey: .count)
        min = try c.decode(Decimal.self, forKey: .min)
        max = try c.decode(Decimal.self, forKey: .max)
        median = try c.decode(Decimal.self, forKey: .median)
    }
}

/// "Found online": web results as leads, never verified offers.
struct OnlineSearchCandidate: Decodable, Identifiable, Hashable {
    var id: String { url }
    var title: String
    var url: String
    var snippet: String
    var priceEgp: String?
    var sourceDomain: String
    enum CodingKeys: String, CodingKey { case title, url, snippet; case priceEgp = "price_egp", sourceDomain = "source_domain" }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
        url = try c.decodeIfPresent(String.self, forKey: .url) ?? ""
        snippet = try c.decodeIfPresent(String.self, forKey: .snippet) ?? ""
        priceEgp = try c.decodeIfPresent(String.self, forKey: .priceEgp)
        sourceDomain = try c.decodeIfPresent(String.self, forKey: .sourceDomain) ?? ""
    }
}

/// A product from an online shopping search (image, price, store) — a licensed result, not scraped; the link opens the store.
struct OnlineProduct: Decodable, Identifiable, Hashable {
    var id: String { url }
    var title: String
    var priceEgp: String?
    var imageUrl: String?
    var store: String
    var url: String
    enum CodingKeys: String, CodingKey { case title, store, url; case priceEgp = "price_egp", imageUrl = "image_url" }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
        priceEgp = try c.decodeIfPresent(String.self, forKey: .priceEgp)
        imageUrl = try c.decodeIfPresent(String.self, forKey: .imageUrl)
        store = try c.decodeIfPresent(String.self, forKey: .store) ?? ""
        url = try c.decodeIfPresent(String.self, forKey: .url) ?? ""
    }
}

struct OnlineSearchResponse: Decodable {
    var products: [OnlineProduct]
    var items: [OnlineSearchCandidate]
    var notice: String?
    var noticeAr: String?
    enum CodingKeys: String, CodingKey { case products, items, notice; case noticeAr = "notice_ar" }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        products = try c.decodeIfPresent([OnlineProduct].self, forKey: .products) ?? []
        items = try c.decodeIfPresent([OnlineSearchCandidate].self, forKey: .items) ?? []
        notice = try c.decodeIfPresent(String.self, forKey: .notice)
        noticeAr = try c.decodeIfPresent(String.self, forKey: .noticeAr)
    }
}

struct BudgetSlice: Decodable, Hashable {
    var part: String
    var sharePct: Int
    var egp: Money
    enum CodingKeys: String, CodingKey { case part, egp; case sharePct = "share_pct" }
}

/// Both /pc-builder and /advisor/pc answer with this shape (the advisor adds split, resolution and reasons).
struct PcBuild: Decodable, Hashable {
    var use: String
    var budget: Money
    var total: Money
    var remaining: Money
    var withinBudget: Bool
    var complete: Bool
    var parts: [PcPart]
    var missing: [String]
    var notes: [String]
    var resolution: String?
    var split: [BudgetSlice]
    /// The advisor's focus part ("gpu" / "cpu").
    var focus: String?
    var usedAdvice: UsedAdvice?
    var approximateParts: Int = 0
    enum CodingKeys: String, CodingKey {
        case use, budget, total, remaining, complete, parts, missing, notes, resolution, split, focus
        case withinBudget = "within_budget", usedAdvice = "used_advice", approximateParts = "approximate_parts"
    }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        use = try c.decode(String.self, forKey: .use)
        budget = try c.decode(Decimal.self, forKey: .budget)
        total = try c.decode(Decimal.self, forKey: .total)
        remaining = try c.decode(Decimal.self, forKey: .remaining)
        withinBudget = try c.decode(Bool.self, forKey: .withinBudget)
        complete = try c.decode(Bool.self, forKey: .complete)
        parts = try c.decode([PcPart].self, forKey: .parts)
        missing = try c.decodeIfPresent([String].self, forKey: .missing) ?? []
        notes = try c.decodeIfPresent([String].self, forKey: .notes) ?? []
        resolution = try c.decodeIfPresent(String.self, forKey: .resolution)
        split = try c.decodeIfPresent([BudgetSlice].self, forKey: .split) ?? []
        focus = try c.decodeIfPresent(String.self, forKey: .focus)
        usedAdvice = try c.decodeIfPresent(UsedAdvice.self, forKey: .usedAdvice)
        approximateParts = try c.decodeIfPresent(Int.self, forKey: .approximateParts) ?? 0
    }
}

// MARK: - Discovery

struct Deal: Decodable, Identifiable, Hashable {
    var id: String
    var brand: String
    var model: String
    var category: String
    var titleAr: String
    var titleEn: String
    var specs: Specs
    var imageUrl: String?
    var minPrice: Money?
    var bestTotal: Money?
    var offers: Int
    var currentMin: Money
    var median: Money
    var verdict: String
    var dropPct: Money
    enum CodingKeys: String, CodingKey {
        case id, brand, model, category, specs, offers, median, verdict
        case titleAr = "title_ar", titleEn = "title_en", imageUrl = "image_url", minPrice = "min_price", bestTotal = "best_total"
        case currentMin = "current_min", dropPct = "drop_pct"
    }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        brand = try c.decodeIfPresent(String.self, forKey: .brand) ?? ""
        model = try c.decodeIfPresent(String.self, forKey: .model) ?? ""
        category = try c.decodeIfPresent(String.self, forKey: .category) ?? "other"
        titleAr = try c.decode(String.self, forKey: .titleAr)
        titleEn = try c.decode(String.self, forKey: .titleEn)
        specs = try c.decodeIfPresent(Specs.self, forKey: .specs) ?? [:]
        imageUrl = try c.decodeIfPresent(String.self, forKey: .imageUrl)
        minPrice = try c.decodeIfPresent(Decimal.self, forKey: .minPrice)
        bestTotal = try c.decodeIfPresent(Decimal.self, forKey: .bestTotal)
        offers = try c.decodeIfPresent(Int.self, forKey: .offers) ?? 0
        currentMin = try c.decode(Decimal.self, forKey: .currentMin)
        median = try c.decode(Decimal.self, forKey: .median)
        verdict = try c.decode(String.self, forKey: .verdict)
        dropPct = try c.decode(Decimal.self, forKey: .dropPct)
    }
    var summary: ProductSummary {
        ProductSummary(id: id, brand: brand, model: model, category: category, titleAr: titleAr, titleEn: titleEn,
                       minPrice: minPrice, bestTotal: bestTotal, offers: offers, specs: specs, imageUrl: imageUrl)
    }
}

struct CompareResponse: Decodable {
    var items: [ProductSummary]
    var cheapestId: String?
    var specKeys: [String]
    var sameCategory: Bool
    enum CodingKeys: String, CodingKey { case items; case cheapestId = "cheapest_id", specKeys = "spec_keys", sameCategory = "same_category" }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        items = try c.decode([ProductSummary].self, forKey: .items)
        cheapestId = try c.decodeIfPresent(String.self, forKey: .cheapestId)
        specKeys = try c.decodeIfPresent([String].self, forKey: .specKeys) ?? []
        sameCategory = try c.decodeIfPresent(Bool.self, forKey: .sameCategory) ?? true
    }
}

struct SuggestProduct: Decodable, Hashable, Identifiable {
    var id: String
    var titleAr: String
    var titleEn: String
    var brand: String
    var category: String
    enum CodingKeys: String, CodingKey { case id, brand, category; case titleAr = "title_ar", titleEn = "title_en" }
}

struct BrandCount: Decodable, Hashable { var brand: String; var products: Int }

struct SuggestResponse: Decodable {
    var products: [SuggestProduct] = []
    var brands: [BrandCount] = []
}

// MARK: - Assistant

struct AssistantCard: Decodable, Hashable {
    var type: String
    var items: [[String: JSONValue]]
    var build: PcBuild?
    var gold: GoldPrices?
    var karat: Int?
    var code: String?
    var egp: Money?
    var amount: Money?
    var result: Money?
    var ids: [String]
    enum CodingKeys: String, CodingKey { case type, items, build, gold, karat, code, egp, amount, result, ids }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        type = try c.decode(String.self, forKey: .type)
        items = try c.decodeIfPresent([[String: JSONValue]].self, forKey: .items) ?? []
        build = try c.decodeIfPresent(PcBuild.self, forKey: .build)
        gold = try c.decodeIfPresent(GoldPrices.self, forKey: .gold)
        karat = try c.decodeIfPresent(Int.self, forKey: .karat)
        code = try c.decodeIfPresent(String.self, forKey: .code)
        egp = try c.decodeIfPresent(Decimal.self, forKey: .egp)
        amount = try c.decodeIfPresent(Decimal.self, forKey: .amount)
        result = try c.decodeIfPresent(Decimal.self, forKey: .result)
        ids = try c.decodeIfPresent([String].self, forKey: .ids) ?? []
    }
}

struct AssistantResponse: Decodable {
    var intent: String
    var reply: String
    var cards: [AssistantCard]
    var suggestions: [String]
    enum CodingKeys: String, CodingKey { case intent, reply, cards, suggestions }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        intent = try c.decode(String.self, forKey: .intent)
        reply = try c.decode(String.self, forKey: .reply)
        cards = try c.decodeIfPresent([AssistantCard].self, forKey: .cards) ?? []
        suggestions = try c.decodeIfPresent([String].self, forKey: .suggestions) ?? []
    }
}

// MARK: - Advisor

struct Pick: Decodable, Identifiable, Hashable {
    var id: String
    var brand: String
    var model: String
    var category: String
    var titleAr: String
    var titleEn: String
    var minPrice: Money?
    var bestTotal: Money?
    var offers: Int
    var specs: Specs
    var imageUrl: String?
    var score: Int
    var reasonsAr: [String]
    var reasonsEn: [String]
    var condition: String = "new"
    var used: UsedListing?
    var vsNew: VsNew?
    var running: CarRunning?
    var priceKind: String = "live"
    var refPrice: Money?
    var refPriceMax: Money?
    var refAsOf: String?
    var refKind: String?
    var refCount: Int?
    var newUsed: NewUsed?
    enum CodingKeys: String, CodingKey {
        case id, brand, model, category, offers, specs, score, condition, used, running
        case titleAr = "title_ar", titleEn = "title_en", minPrice = "min_price", bestTotal = "best_total", imageUrl = "image_url"
        case reasonsAr = "reasons_ar", reasonsEn = "reasons_en", vsNew = "vs_new"
        case priceKind = "price_kind", refPrice = "ref_price", refPriceMax = "ref_price_max", refAsOf = "ref_as_of"
        case refKind = "ref_kind", refCount = "ref_count", newUsed = "new_used"
    }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        brand = try c.decodeIfPresent(String.self, forKey: .brand) ?? ""
        model = try c.decodeIfPresent(String.self, forKey: .model) ?? ""
        category = try c.decodeIfPresent(String.self, forKey: .category) ?? "other"
        titleAr = try c.decode(String.self, forKey: .titleAr)
        titleEn = try c.decode(String.self, forKey: .titleEn)
        minPrice = try c.decodeIfPresent(Decimal.self, forKey: .minPrice)
        bestTotal = try c.decodeIfPresent(Decimal.self, forKey: .bestTotal)
        offers = try c.decodeIfPresent(Int.self, forKey: .offers) ?? 0
        specs = try c.decodeIfPresent(Specs.self, forKey: .specs) ?? [:]
        imageUrl = try c.decodeIfPresent(String.self, forKey: .imageUrl)
        score = try c.decodeIfPresent(Int.self, forKey: .score) ?? 0
        reasonsAr = try c.decodeIfPresent([String].self, forKey: .reasonsAr) ?? []
        reasonsEn = try c.decodeIfPresent([String].self, forKey: .reasonsEn) ?? []
        condition = try c.decodeIfPresent(String.self, forKey: .condition) ?? "new"
        used = try c.decodeIfPresent(UsedListing.self, forKey: .used)
        vsNew = try c.decodeIfPresent(VsNew.self, forKey: .vsNew)
        running = try c.decodeIfPresent(CarRunning.self, forKey: .running)
        priceKind = try c.decodeIfPresent(String.self, forKey: .priceKind) ?? "live"
        refPrice = try c.decodeIfPresent(Decimal.self, forKey: .refPrice)
        refPriceMax = try c.decodeIfPresent(Decimal.self, forKey: .refPriceMax)
        refAsOf = try c.decodeIfPresent(String.self, forKey: .refAsOf)
        refKind = try c.decodeIfPresent(String.self, forKey: .refKind)
        refCount = try c.decodeIfPresent(Int.self, forKey: .refCount)
        newUsed = try c.decodeIfPresent(NewUsed.self, forKey: .newUsed)
    }
    var price: Money? { bestTotal ?? minPrice ?? refPrice }
    var isReference: Bool { bestTotal == nil && minPrice == nil && refPrice != nil }
    var summary: ProductSummary {
        ProductSummary(id: id, brand: brand, model: model, category: category, titleAr: titleAr, titleEn: titleEn,
                       minPrice: minPrice, bestTotal: bestTotal, offers: offers, specs: specs, imageUrl: imageUrl)
    }
}

struct AdviceResponse: Decodable {
    var picks: [Pick]
    var considered: Int
    var notes: [String]
    var usedAdvice: PickUsedAdvice?
    var running: RunningSummary?
    var budgetView: BudgetView?
    enum CodingKeys: String, CodingKey { case picks, considered, notes, running; case usedAdvice = "used_advice", budgetView = "budget_view" }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        picks = try c.decodeIfPresent([Pick].self, forKey: .picks) ?? []
        considered = try c.decodeIfPresent(Int.self, forKey: .considered) ?? 0
        notes = try c.decodeIfPresent([String].self, forKey: .notes) ?? []
        usedAdvice = try c.decodeIfPresent(PickUsedAdvice.self, forKey: .usedAdvice)
        running = try c.decodeIfPresent(RunningSummary.self, forKey: .running)
        budgetView = try c.decodeIfPresent(BudgetView.self, forKey: .budgetView)
    }
}

struct GoldAnalysis: Decodable {
    struct Point: Decodable, Hashable { var day: String; var gold21: Double
        enum CodingKeys: String, CodingKey { case day; case gold21 = "gold21_gram" } }
    var status: String
    var days: Int
    var requiredDays: Int
    var gold21: Double?
    var change7d: Double?
    var change30d: Double?
    var high30: Double?
    var low30: Double?
    var position30: Double?
    var position: String?
    var volatility: String?
    var trend: String?
    var usdChange30d: Double?
    var ounceChange30d: Double?
    var factsAr: [String]
    var factsEn: [String]
    var tipsAr: [String]
    var tipsEn: [String]
    var disclaimerAr: String
    var disclaimerEn: String
    var series: [Point]
    enum CodingKeys: String, CodingKey {
        case status, days, position, volatility, trend, series
        case requiredDays = "required_days", gold21 = "gold21_gram", change7d = "change_7d_pct", change30d = "change_30d_pct"
        case high30 = "high_30d", low30 = "low_30d", position30 = "position_30d"
        case usdChange30d = "usd_change_30d_pct", ounceChange30d = "ounce_change_30d_pct"
        case factsAr = "facts_ar", factsEn = "facts_en", tipsAr = "tips_ar", tipsEn = "tips_en"
        case disclaimerAr = "disclaimer_ar", disclaimerEn = "disclaimer_en"
    }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        status = try c.decode(String.self, forKey: .status)
        days = try c.decodeIfPresent(Int.self, forKey: .days) ?? 0
        requiredDays = try c.decodeIfPresent(Int.self, forKey: .requiredDays) ?? 7
        gold21 = try c.decodeIfPresent(Double.self, forKey: .gold21)
        change7d = try c.decodeIfPresent(Double.self, forKey: .change7d)
        change30d = try c.decodeIfPresent(Double.self, forKey: .change30d)
        high30 = try c.decodeIfPresent(Double.self, forKey: .high30)
        low30 = try c.decodeIfPresent(Double.self, forKey: .low30)
        position30 = try c.decodeIfPresent(Double.self, forKey: .position30)
        position = try c.decodeIfPresent(String.self, forKey: .position)
        volatility = try c.decodeIfPresent(String.self, forKey: .volatility)
        trend = try c.decodeIfPresent(String.self, forKey: .trend)
        usdChange30d = try c.decodeIfPresent(Double.self, forKey: .usdChange30d)
        ounceChange30d = try c.decodeIfPresent(Double.self, forKey: .ounceChange30d)
        factsAr = try c.decodeIfPresent([String].self, forKey: .factsAr) ?? []
        factsEn = try c.decodeIfPresent([String].self, forKey: .factsEn) ?? []
        tipsAr = try c.decodeIfPresent([String].self, forKey: .tipsAr) ?? []
        tipsEn = try c.decodeIfPresent([String].self, forKey: .tipsEn) ?? []
        disclaimerAr = try c.decodeIfPresent(String.self, forKey: .disclaimerAr) ?? ""
        disclaimerEn = try c.decodeIfPresent(String.self, forKey: .disclaimerEn) ?? ""
        series = try c.decodeIfPresent([Point].self, forKey: .series) ?? []
    }
    var ready: Bool { status == "ok" }
}

// MARK: - Preferences, billing

struct Preferences: Codable, Equatable {
    var pushAlerts = true
    var emailAlerts = true
    var dealsDigest = false
    var language = "ar"
    enum CodingKeys: String, CodingKey {
        case language
        case pushAlerts = "push_alerts", emailAlerts = "email_alerts", dealsDigest = "deals_digest"
    }
}

struct BillingStatus: Decodable { var pro: Bool }

// MARK: - Remote app config (set from the admin console)

struct FirebaseConfig: Codable, Equatable {
    var appId: String
    var apiKey: String
    var projectId: String
    var senderId: String
    enum CodingKeys: String, CodingKey { case appId = "app_id", apiKey = "api_key", projectId = "project_id", senderId = "sender_id" }
}

struct AdsConfig: Codable, Equatable {
    var enabled = false
    var bannerId: String?
    var inlineId: String?
    var placements: [String: Bool] = [:]
    enum CodingKeys: String, CodingKey { case enabled, placements; case bannerId = "banner_id", inlineId = "inline_id" }
}

struct ProConfig: Codable, Equatable {
    var enabled = true
    var monthlyId = "pro_monthly"
    var yearlyId = "pro_yearly"
    enum CodingKeys: String, CodingKey { case enabled; case monthlyId = "monthly_id", yearlyId = "yearly_id" }
}

struct Features: Codable, Equatable {
    var advisor = true
    var assistant = true
    var appleSignIn = true
    enum CodingKeys: String, CodingKey { case advisor, assistant; case appleSignIn = "apple_sign_in" }
}

/// Free-plan limits (limit 0 = unlimited). Pro is never limited.
struct QuotaRule: Codable, Equatable {
    var limit: Int
    var windowHours: Int
    enum CodingKeys: String, CodingKey { case limit; case windowHours = "window_hours" }
}

/// GET /quota: what's left for this account or install (left nil = unlimited).
struct QuotaStatus: Decodable {
    struct Item: Decodable { var limit: Int; var left: Int?; var windowHours: Int; var retryIn: Int?
        enum CodingKeys: String, CodingKey { case limit, left; case windowHours = "window_hours", retryIn = "retry_in" } }
    var search: Item
    var assistant: Item
    var advisor: Item
    var pro: Bool
}

struct Quotas: Codable, Equatable {
    var search = QuotaRule(limit: 15, windowHours: 8)
    var assistant = QuotaRule(limit: 5, windowHours: 24)
    var advisor = QuotaRule(limit: 3, windowHours: 24)
    var compareItems = 2
    var basketItems = 8
    enum CodingKeys: String, CodingKey { case search, assistant, advisor; case compareItems = "compare_items", basketItems = "basket_items" }
    init() {}
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        search = try c.decodeIfPresent(QuotaRule.self, forKey: .search) ?? search
        assistant = try c.decodeIfPresent(QuotaRule.self, forKey: .assistant) ?? assistant
        advisor = try c.decodeIfPresent(QuotaRule.self, forKey: .advisor) ?? advisor
        compareItems = try c.decodeIfPresent(Int.self, forKey: .compareItems) ?? compareItems
        basketItems = try c.decodeIfPresent(Int.self, forKey: .basketItems) ?? basketItems
    }
}

struct Announcement: Codable, Equatable { var ar: String; var en: String; var tone: String?; var url: String? }
struct Maintenance: Codable, Equatable { var ar: String; var en: String }

struct AppConfig: Codable, Equatable {
    var firebase: FirebaseConfig?
    var ads = AdsConfig()
    var pro = ProConfig()
    var features = Features()
    var freeWatchLimit = 10
    var freeHistoryDays = 30
    var freeWalletItems = 3
    var proMarketAlerts = 20
    var quotas = Quotas()
    var announcement: Announcement?
    var maintenance: Maintenance?
    var minVersionCode = 1
    var latestVersionCode = 1
    var storeUrl: String?
    var supportEmail: String?
    var searchRequiresAccount = true
    var onlineSearch = false
    enum CodingKeys: String, CodingKey {
        case searchRequiresAccount = "search_requires_account", onlineSearch = "online_search"
        case firebase, ads, pro, features, announcement, maintenance
        case freeWatchLimit = "free_watch_limit", freeHistoryDays = "free_history_days", freeWalletItems = "free_wallet_items"
        case quotas
        case proMarketAlerts = "pro_market_alerts", minVersionCode = "min_version_code", latestVersionCode = "latest_version_code"
        case storeUrl = "store_url", supportEmail = "support_email"
    }
    init() {}
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        firebase = try c.decodeIfPresent(FirebaseConfig.self, forKey: .firebase)
        ads = try c.decodeIfPresent(AdsConfig.self, forKey: .ads) ?? AdsConfig()
        pro = try c.decodeIfPresent(ProConfig.self, forKey: .pro) ?? ProConfig()
        features = try c.decodeIfPresent(Features.self, forKey: .features) ?? Features()
        freeWatchLimit = try c.decodeIfPresent(Int.self, forKey: .freeWatchLimit) ?? 10
        freeHistoryDays = try c.decodeIfPresent(Int.self, forKey: .freeHistoryDays) ?? 30
        freeWalletItems = try c.decodeIfPresent(Int.self, forKey: .freeWalletItems) ?? 3
        proMarketAlerts = try c.decodeIfPresent(Int.self, forKey: .proMarketAlerts) ?? 20
        quotas = try c.decodeIfPresent(Quotas.self, forKey: .quotas) ?? Quotas()
        announcement = try c.decodeIfPresent(Announcement.self, forKey: .announcement)
        maintenance = try c.decodeIfPresent(Maintenance.self, forKey: .maintenance)
        minVersionCode = try c.decodeIfPresent(Int.self, forKey: .minVersionCode) ?? 1
        latestVersionCode = try c.decodeIfPresent(Int.self, forKey: .latestVersionCode) ?? 1
        storeUrl = try c.decodeIfPresent(String.self, forKey: .storeUrl)
        supportEmail = try c.decodeIfPresent(String.self, forKey: .supportEmail)
        searchRequiresAccount = try c.decodeIfPresent(Bool.self, forKey: .searchRequiresAccount) ?? true
        onlineSearch = try c.decodeIfPresent(Bool.self, forKey: .onlineSearch) ?? false
    }
}

// MARK: - Pro: gold and dollar alerts

struct MarketAlert: Decodable, Identifiable, Hashable {
    var id: Int64
    var metric: String
    var direction: String
    var target: Money
    var triggeredAt: String?
    var triggeredValue: Money?
    enum CodingKeys: String, CodingKey { case id, metric, direction, target; case triggeredAt = "triggered_at", triggeredValue = "triggered_value" }
}

struct MarketAlertList: Decodable {
    var items: [MarketAlert]
    var current: [String: Money]
    var limit: Int
    enum CodingKeys: String, CodingKey { case items, current, limit }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        items = try c.decodeIfPresent([MarketAlert].self, forKey: .items) ?? []
        // metric -> value; values may be numbers or strings
        let raw = try c.decodeIfPresent([String: JSONValue].self, forKey: .current) ?? [:]
        var out: [String: Money] = [:]
        for (k, v) in raw {
            if let s = v.string, let d = Decimal(string: s, locale: Locale(identifier: "en_US_POSIX")) { out[k] = d }
            else if let n = v.double { out[k] = Decimal(string: "\(n)", locale: Locale(identifier: "en_US_POSIX")) }
        }
        current = out
        limit = try c.decodeIfPresent(Int.self, forKey: .limit) ?? 20
    }
}

// MARK: - Countries

struct Country: Codable, Hashable, Identifiable {
    var code = "EG"
    var nameAr = "مصر"
    var nameEn = "Egypt"
    var currency = "EGP"
    var symbolAr = "ج.م"
    var symbolEn = "EGP"
    var stores = 0
    var id: String { code }
    enum CodingKeys: String, CodingKey {
        case code, currency, stores
        case nameAr = "name_ar", nameEn = "name_en", symbolAr = "symbol_ar", symbolEn = "symbol_en"
    }
    init(code: String = "EG", nameAr: String = "مصر", nameEn: String = "Egypt", currency: String = "EGP",
         symbolAr: String = "ج.م", symbolEn: String = "EGP", stores: Int = 0) {
        self.code = code; self.nameAr = nameAr; self.nameEn = nameEn; self.currency = currency
        self.symbolAr = symbolAr; self.symbolEn = symbolEn; self.stores = stores
    }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        code = try c.decode(String.self, forKey: .code)
        nameAr = try c.decode(String.self, forKey: .nameAr)
        nameEn = try c.decode(String.self, forKey: .nameEn)
        currency = try c.decode(String.self, forKey: .currency)
        symbolAr = try c.decode(String.self, forKey: .symbolAr)
        symbolEn = try c.decode(String.self, forKey: .symbolEn)
        stores = try c.decodeIfPresent(Int.self, forKey: .stores) ?? 0
    }
    /// 🇪🇬 from "EG" (regional indicator letters).
    var flag: String {
        code.uppercased().unicodeScalars.compactMap { UnicodeScalar(127397 + $0.value) }.map(String.init).joined()
    }
    static let egypt = Country()
    /// Shown before the server's list arrives (and on screenshot runs).
    static let known = [
        Country(),
        Country(code: "SA", nameAr: "السعودية", nameEn: "Saudi Arabia", currency: "SAR", symbolAr: "ر.س", symbolEn: "SAR"),
        Country(code: "AE", nameAr: "الإمارات", nameEn: "UAE", currency: "AED", symbolAr: "د.إ", symbolEn: "AED"),
        Country(code: "KW", nameAr: "الكويت", nameEn: "Kuwait", currency: "KWD", symbolAr: "د.ك", symbolEn: "KWD"),
        Country(code: "QA", nameAr: "قطر", nameEn: "Qatar", currency: "QAR", symbolAr: "ر.ق", symbolEn: "QAR"),
    ]
}

struct CountryList: Decodable { var items: [Country] }

// MARK: - Price analysis above search results

struct SearchAnalysis: Decodable {
    struct Point: Decodable, Hashable { var day: String; var price: Money
        enum CodingKeys: String, CodingKey { case day, price }
        init(from d: Decoder) throws { let c = try d.container(keyedBy: CodingKeys.self)
            day = try c.decode(String.self, forKey: .day); price = try c.decode(Decimal.self, forKey: .price) } }
    struct Focus: Decodable {
        var id: String
        var titleAr: String
        var titleEn: String
        var current: Money?
        var series: [Point]
        var low90: Money?
        var high90: Money?
        var change30d: Money?
        enum CodingKeys: String, CodingKey {
            case id, current, series
            case titleAr = "title_ar", titleEn = "title_en", low90 = "low_90d", high90 = "high_90d", change30d = "change_30d"
        }
        init(from d: Decoder) throws {
            let c = try d.container(keyedBy: CodingKeys.self)
            id = try c.decode(String.self, forKey: .id)
            titleAr = try c.decode(String.self, forKey: .titleAr)
            titleEn = try c.decode(String.self, forKey: .titleEn)
            current = try c.decodeIfPresent(Decimal.self, forKey: .current)
            series = try c.decodeIfPresent([Point].self, forKey: .series) ?? []
            low90 = try c.decodeIfPresent(Decimal.self, forKey: .low90)
            high90 = try c.decodeIfPresent(Decimal.self, forKey: .high90)
            change30d = try c.decodeIfPresent(Decimal.self, forKey: .change30d)
        }
    }
    struct Drop: Decodable {
        var id: String
        var titleAr: String
        var titleEn: String
        var changePct: Money
        enum CodingKeys: String, CodingKey { case id; case titleAr = "title_ar", titleEn = "title_en", changePct = "change_pct" }
        init(from d: Decoder) throws {
            let c = try d.container(keyedBy: CodingKeys.self)
            id = try c.decode(String.self, forKey: .id)
            titleAr = try c.decode(String.self, forKey: .titleAr)
            titleEn = try c.decode(String.self, forKey: .titleEn)
            changePct = try c.decode(Decimal.self, forKey: .changePct)
        }
    }
    var status: String
    var products: Int
    var inStock: Int
    var priced: Int
    var min: Money?
    var max: Money?
    var tracked: Int
    var dropped: Int
    var rose: Int
    var flat: Int
    var avgChange30d: Money?
    var biggestDrop: Drop?
    var focus: Focus?
    enum CodingKeys: String, CodingKey {
        case status, products, priced, min, max, tracked, dropped, rose, flat, focus
        case inStock = "in_stock", avgChange30d = "avg_change_30d", biggestDrop = "biggest_drop"
    }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        status = try c.decode(String.self, forKey: .status)
        products = try c.decodeIfPresent(Int.self, forKey: .products) ?? 0
        inStock = try c.decodeIfPresent(Int.self, forKey: .inStock) ?? 0
        priced = try c.decodeIfPresent(Int.self, forKey: .priced) ?? 0
        min = try c.decodeIfPresent(Decimal.self, forKey: .min)
        max = try c.decodeIfPresent(Decimal.self, forKey: .max)
        tracked = try c.decodeIfPresent(Int.self, forKey: .tracked) ?? 0
        dropped = try c.decodeIfPresent(Int.self, forKey: .dropped) ?? 0
        rose = try c.decodeIfPresent(Int.self, forKey: .rose) ?? 0
        flat = try c.decodeIfPresent(Int.self, forKey: .flat) ?? 0
        avgChange30d = try c.decodeIfPresent(Decimal.self, forKey: .avgChange30d)
        biggestDrop = try c.decodeIfPresent(Drop.self, forKey: .biggestDrop)
        focus = try c.decodeIfPresent(Focus.self, forKey: .focus)
    }
}


// MARK: - Used vs new, price lens, trade-in, running cost

/// For a used item: the same product new, and how much the used one saves.
struct VsNew: Decodable, Hashable {
    var productId: String
    var price: Money
    var saving: Money
    var savingPct: Int
    var titleAr: String
    var titleEn: String
    enum CodingKeys: String, CodingKey { case price, saving; case productId = "product_id", savingPct = "saving_pct", titleAr = "title_ar", titleEn = "title_en" }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        productId = try c.decode(String.self, forKey: .productId)
        price = try c.decode(Decimal.self, forKey: .price)
        saving = try c.decode(Decimal.self, forKey: .saving)
        savingPct = try c.decodeIfPresent(Int.self, forKey: .savingPct) ?? 0
        titleAr = try c.decodeIfPresent(String.self, forKey: .titleAr) ?? ""
        titleEn = try c.decodeIfPresent(String.self, forKey: .titleEn) ?? ""
    }
}

/// Product page: the same product in the other condition (never for clothing).
struct UsedNew: Decodable, Hashable {
    var used: UsedListing?
    var new: VsNew?
    var usedListings: Int
    enum CodingKeys: String, CodingKey { case used, new; case usedListings = "used_listings" }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        used = try c.decodeIfPresent(UsedListing.self, forKey: .used)
        new = try c.decodeIfPresent(VsNew.self, forKey: .new)
        usedListings = try c.decodeIfPresent(Int.self, forKey: .usedListings) ?? 0
    }
}

/// The price through the dollar and 21k gold, and its ~30-day move in pounds vs dollars.
struct PriceLens: Decodable, Hashable {
    var usd: Money
    var gold21Grams: Money?
    var egpChangePct: Money?
    var usdChangePct: Money?
    enum CodingKeys: String, CodingKey { case usd; case gold21Grams = "gold21_grams", egpChangePct = "egp_change_pct", usdChangePct = "usd_change_pct" }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        usd = try c.decode(Decimal.self, forKey: .usd)
        gold21Grams = try c.decodeIfPresent(Decimal.self, forKey: .gold21Grams)
        egpChangePct = try c.decodeIfPresent(Decimal.self, forKey: .egpChangePct)
        usdChangePct = try c.decodeIfPresent(Decimal.self, forKey: .usdChangePct)
    }
}

/// Upgrade cost: resale of what you own (used listings of the same model) and the net price of the new one.
struct TradeIn: Decodable {
    struct Ref: Decodable { var id: String; var titleAr: String; var titleEn: String; var price: Money?
        enum CodingKeys: String, CodingKey { case id, price; case titleAr = "title_ar", titleEn = "title_en" }
        init(from d: Decoder) throws {
            let c = try d.container(keyedBy: CodingKeys.self)
            id = try c.decode(String.self, forKey: .id)
            titleAr = try c.decodeIfPresent(String.self, forKey: .titleAr) ?? ""
            titleEn = try c.decodeIfPresent(String.self, forKey: .titleEn) ?? ""
            price = try c.decodeIfPresent(Decimal.self, forKey: .price)
        }
    }
    struct Range: Decodable { var low: Money; var median: Money; var high: Money
        enum CodingKeys: String, CodingKey { case low, median, high }
        init(from d: Decoder) throws {
            let c = try d.container(keyedBy: CodingKeys.self)
            low = try c.decode(Decimal.self, forKey: .low); median = try c.decode(Decimal.self, forKey: .median); high = try c.decode(Decimal.self, forKey: .high)
        }
    }
    var from: Ref
    var to: Ref
    var status: String
    var listings: Int
    var resale: Range?
    var netCost: Money?
    var noteAr: String
    var noteEn: String
    enum CodingKeys: String, CodingKey { case from, to, status, listings, resale; case netCost = "net_cost", noteAr = "note_ar", noteEn = "note_en" }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        from = try c.decode(Ref.self, forKey: .from)
        to = try c.decode(Ref.self, forKey: .to)
        status = try c.decode(String.self, forKey: .status)
        listings = try c.decodeIfPresent(Int.self, forKey: .listings) ?? 0
        resale = try c.decodeIfPresent(Range.self, forKey: .resale)
        netCost = try c.decodeIfPresent(Decimal.self, forKey: .netCost)
        noteAr = try c.decodeIfPresent(String.self, forKey: .noteAr) ?? ""
        noteEn = try c.decodeIfPresent(String.self, forKey: .noteEn) ?? ""
    }
}

/// Cars: estimated fuel cost for a typical month of the chosen usage.
struct CarRunning: Decodable, Hashable {
    var kmMonth: Int
    var electric: Bool
    var monthly: Money?
    enum CodingKeys: String, CodingKey { case electric, monthly; case kmMonth = "km_month" }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        kmMonth = try c.decodeIfPresent(Int.self, forKey: .kmMonth) ?? 0
        electric = try c.decodeIfPresent(Bool.self, forKey: .electric) ?? false
        monthly = try c.decodeIfPresent(Decimal.self, forKey: .monthly)
    }
}

struct RunningSummary: Decodable {
    var kmMonth: Int
    var fuelPrice: Money?
    var yearlyGap: Money?
    var cheapestTitleAr: String
    var cheapestTitleEn: String
    var dearestTitleAr: String
    var dearestTitleEn: String
    enum CodingKeys: String, CodingKey {
        case kmMonth = "km_month", fuelPrice = "fuel_price", yearlyGap = "yearly_gap"
        case cheapestTitleAr = "cheapest_title_ar", cheapestTitleEn = "cheapest_title_en", dearestTitleAr = "dearest_title_ar", dearestTitleEn = "dearest_title_en"
    }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        kmMonth = try c.decodeIfPresent(Int.self, forKey: .kmMonth) ?? 0
        fuelPrice = try c.decodeIfPresent(Decimal.self, forKey: .fuelPrice)
        yearlyGap = try c.decodeIfPresent(Decimal.self, forKey: .yearlyGap)
        cheapestTitleAr = try c.decodeIfPresent(String.self, forKey: .cheapestTitleAr) ?? ""
        cheapestTitleEn = try c.decodeIfPresent(String.self, forKey: .cheapestTitleEn) ?? ""
        dearestTitleAr = try c.decodeIfPresent(String.self, forKey: .dearestTitleAr) ?? ""
        dearestTitleEn = try c.decodeIfPresent(String.self, forKey: .dearestTitleEn) ?? ""
    }
}

/// The advisor's used-vs-new lead: a better model that fits the budget used, or the top pick cheaper used.
struct PickUsedAdvice: Decodable {
    struct StepUp: Decodable { var productId: String; var titleAr: String; var titleEn: String; var newPrice: Money; var used: UsedListing
        var reasonsAr: [String]; var reasonsEn: [String]
        enum CodingKeys: String, CodingKey { case used; case productId = "product_id", titleAr = "title_ar", titleEn = "title_en", newPrice = "new_price", reasonsAr = "reasons_ar", reasonsEn = "reasons_en" }
        init(from d: Decoder) throws {
            let c = try d.container(keyedBy: CodingKeys.self)
            productId = try c.decode(String.self, forKey: .productId)
            titleAr = try c.decodeIfPresent(String.self, forKey: .titleAr) ?? ""
            titleEn = try c.decodeIfPresent(String.self, forKey: .titleEn) ?? ""
            newPrice = try c.decode(Decimal.self, forKey: .newPrice)
            used = try c.decode(UsedListing.self, forKey: .used)
            reasonsAr = try c.decodeIfPresent([String].self, forKey: .reasonsAr) ?? []
            reasonsEn = try c.decodeIfPresent([String].self, forKey: .reasonsEn) ?? []
        }
    }
    struct Save: Decodable { var productId: String; var titleAr: String; var titleEn: String; var newPrice: Money; var used: UsedListing
        enum CodingKeys: String, CodingKey { case used; case productId = "product_id", titleAr = "title_ar", titleEn = "title_en", newPrice = "new_price" }
        init(from d: Decoder) throws {
            let c = try d.container(keyedBy: CodingKeys.self)
            productId = try c.decode(String.self, forKey: .productId)
            titleAr = try c.decodeIfPresent(String.self, forKey: .titleAr) ?? ""
            titleEn = try c.decodeIfPresent(String.self, forKey: .titleEn) ?? ""
            newPrice = try c.decode(Decimal.self, forKey: .newPrice)
            used = try c.decode(UsedListing.self, forKey: .used)
        }
    }
    var kind: String
    var stepUp: StepUp?
    var save: Save?
    var noteAr: String
    var noteEn: String
    enum CodingKeys: String, CodingKey { case kind, save; case stepUp = "step_up", noteAr = "note_ar", noteEn = "note_en" }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        kind = try c.decode(String.self, forKey: .kind)
        stepUp = try c.decodeIfPresent(StepUp.self, forKey: .stepUp)
        save = try c.decodeIfPresent(Save.self, forKey: .save)
        noteAr = try c.decodeIfPresent(String.self, forKey: .noteAr) ?? ""
        noteEn = try c.decodeIfPresent(String.self, forKey: .noteEn) ?? ""
    }
}
