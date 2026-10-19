import Foundation
import Security

// Small persistent stores kept on the phone: the session token (Keychain), the basket, the wallet,
// recent searches, the products picked for comparison, and a cache of the last config.

enum Keychain {
    private static let service = "app.wafi.session"

    static func get(_ key: String) -> String? {
        let q: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
                                kSecAttrAccount as String: key, kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne]
        var out: CFTypeRef?
        guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess, let d = out as? Data else { return nil }
        return String(data: d, encoding: .utf8)
    }

    static func set(_ key: String, _ value: String?) {
        let base: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
                                   kSecAttrAccount as String: key]
        SecItemDelete(base as CFDictionary)
        guard let value else { return }
        var add = base
        add[kSecValueData as String] = Data(value.utf8)
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(add as CFDictionary, nil)
    }
}

/// JSON values in UserDefaults.
enum Saved {
    static func load<T: Decodable>(_ key: String, as: T.Type) -> T? {
        guard let d = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(T.self, from: d)
    }
    static func save<T: Encodable>(_ key: String, _ value: T) {
        if let d = try? JSONEncoder().encode(value) { UserDefaults.standard.set(d, forKey: key) }
    }
}

// MARK: - Basket

struct BasketLine: Codable, Hashable, Identifiable {
    var productId: String
    var qty: Int
    var titleAr: String
    var titleEn: String
    var price: Decimal?
    var id: String { productId }
    var title: String { Lang.isArabic ? titleAr : titleEn }
    static let maxLines = 15
    static let maxQty = 20
}

// MARK: - Wallet ("محفظتي")

/// Something the user owns that has a market price: gold by karat (grams), gold pounds (coins), or a foreign
/// currency they saved. [cost] is what they paid for the whole holding, in the browsing currency.
struct Holding: Codable, Hashable, Identifiable {
    var id: String = UUID().uuidString
    var kind: String            // "gold" | "gold_pound" | "currency"
    var karat: Int?
    var code: String?
    var amount: Decimal
    var cost: Decimal?
    var note: String = ""
    var addedAt: Date = Date()
    /// The day it was bought (yyyy-MM-dd), optional.
    var boughtOn: String?

    var isCurrency: Bool { kind == "currency" }
    var unitCost: Decimal? {
        guard let cost, amount > 0 else { return nil }
        return cost / amount
    }
}

struct Valued: Hashable, Identifiable {
    var holding: Holding
    var value: Decimal?
    var gain: Decimal?
    var gainPct: Decimal?
    var id: String { holding.id }
}

struct WalletTotals {
    var value: Decimal
    var cost: Decimal
    var gain: Decimal?
    var gainPct: Decimal?
    var items: [Valued]
}

enum Wallet {
    /// Price of one unit of [h] today in the browsing currency, or nil when the feed doesn't carry it.
    static func unitPrice(_ h: Holding, _ m: MarketResponse) -> Decimal? {
        switch h.kind {
        case "gold": return m.gold.karats.first { $0.karat == h.karat }?.egpPerGram
        case "gold_pound": return m.gold.goldPoundEgp
        case "currency": return m.currencies.first { $0.code == h.code }?.egp
        default: return nil
        }
    }

    static func round2(_ d: Decimal) -> Decimal { var v = d, r = Decimal(); NSDecimalRound(&r, &v, 2, .plain); return r }

    static func value(_ items: [Holding], _ m: MarketResponse?) -> WalletTotals {
        let valued: [Valued] = items.map { h in
            let v = m.flatMap { unitPrice(h, $0) }.map { round2($0 * h.amount) }
            let gain: Decimal? = (v != nil && h.cost != nil) ? v! - h.cost! : nil
            let pct: Decimal? = (gain != nil && (h.cost ?? 0) > 0) ? round2(gain! * 100 / h.cost!) : nil
            return Valued(holding: h, value: v, gain: gain, gainPct: pct)
        }
        let total = valued.compactMap(\.value).reduce(0, +)
        let withCost = valued.filter { $0.gain != nil }
        let cost = withCost.reduce(Decimal(0)) { $0 + ($1.holding.cost ?? 0) }
        let gain: Decimal? = withCost.isEmpty ? nil : withCost.reduce(Decimal(0)) { $0 + ($1.gain ?? 0) }
        let pct: Decimal? = (gain != nil && cost > 0) ? round2(gain! * 100 / cost) : nil
        return WalletTotals(value: total, cost: cost, gain: gain, gainPct: pct, items: valued)
    }

    /// The gold side and the currency-savings side, each with its own totals.
    static func split(_ items: [Holding], _ m: MarketResponse?) -> (gold: WalletTotals, cash: WalletTotals) {
        (value(items.filter { !$0.isCurrency }, m), value(items.filter(\.isCurrency), m))
    }
}
