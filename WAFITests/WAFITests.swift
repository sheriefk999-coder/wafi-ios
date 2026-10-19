import XCTest
@testable import WAFI

final class FormatTests: XCTestCase {
    let en = Locale(identifier: "en_US"), ar = Locale(identifier: "ar_EG")

    func testMoneyKeepsWholeUnitsAndFractions() {
        XCTAssertEqual(Fmt.money(20050, symbolAr: "ج.م", symbolEn: "EGP", locale: en), "EGP 20,050")
        XCTAssertEqual(Fmt.money(Decimal(string: "19999.5")!, symbolAr: "ج.م", symbolEn: "EGP", locale: en), "EGP 19,999.50")
        XCTAssertTrue(Fmt.money(20050, symbolAr: "ج.م", symbolEn: "EGP", locale: ar).hasSuffix("ج.م"))
    }

    func testCompactAndPct() {
        XCTAssertEqual(Fmt.compact(1_200_000, locale: en), "1.2M")
        XCTAssertEqual(Fmt.compact(45_000, locale: en), "45K")
        XCTAssertEqual(Fmt.pct(Decimal(string: "-0.27"), locale: en), "0.27%")
    }

    func testSeenTodayYesterday() {
        let now = Fmt.parseDay("2026-10-19")!
        XCTAssertEqual(Fmt.seen("2026-10-19T08:00:00Z", locale: en, today: now), "Today")
        XCTAssertEqual(Fmt.seen("2026-10-18", locale: en, today: now), "Yesterday")
    }
}

final class DecodingTests: XCTestCase {
    func testMoneyFromStringsAndNumbersIsExact() throws {
        let json = #"{"id":"x","brand":"B","model":"M","title_ar":"ت","title_en":"T","min_price":"19999.50","best_total":20050,"in_stock":true,"specs":{"camera_mp":50}}"#
        let p = try JSONDecoder().decode(ProductSummary.self, from: Data(json.utf8))
        XCTAssertEqual(p.minPrice, Decimal(string: "19999.5"))
        XCTAssertEqual(p.bestTotal, 20050)
        XCTAssertEqual(p.inStock, true)
        XCTAssertEqual(p.specs.int("camera_mp"), 50)      // spec keys are not camel-cased
    }

    func testQuotasInConfig() throws {
        let json = #"{"quotas":{"search":{"limit":15,"window_hours":8},"assistant":{"limit":5,"window_hours":24},"advisor":{"limit":3,"window_hours":24},"compare_items":2,"basket_items":8}}"#
        let c = try JSONDecoder().decode(AppConfig.self, from: Data(json.utf8))
        XCTAssertEqual(c.quotas.search.limit, 15)
        XCTAssertEqual(c.quotas.search.windowHours, 8)
        XCTAssertEqual(c.quotas.compareItems, 2)
        // and a config without them still decodes with the defaults
        XCTAssertEqual(try JSONDecoder().decode(AppConfig.self, from: Data("{}".utf8)).quotas.search.limit, 15)
    }

    func testCountryFlag() {
        XCTAssertEqual(Country(code: "EG").flag, "🇪🇬")
        XCTAssertEqual(Country(code: "SA").flag, "🇸🇦")
    }
}

final class WalletTests: XCTestCase {
    private func market() throws -> MarketResponse {
        let json = #"""
        {"as_of":"2026-10-19","base":"EGP","stale":false,
         "currencies":[{"code":"USD","egp":"48.50"}],
         "gold":{"usd_per_ounce":"2400","egp_per_ounce":"116400","gold_pound_egp":"32000",
                 "karats":[{"karat":24,"egp_per_gram":"4600"},{"karat":21,"egp_per_gram":"4000"},{"karat":18,"egp_per_gram":"3450"}]}}
        """#
        return try JSONDecoder().decode(MarketResponse.self, from: Data(json.utf8))
    }

    func testGoldAndCurrencySidesValueSeparately() throws {
        let m = try market()
        let items = [
            Holding(kind: "gold", karat: 21, amount: 10, cost: 35_000),
            Holding(kind: "currency", code: "USD", amount: 1_000, cost: 47_000),
        ]
        let (gold, cash) = Wallet.split(items, m)
        XCTAssertEqual(gold.value, 40_000)
        XCTAssertEqual(gold.gain, 5_000)
        XCTAssertEqual(cash.value, 48_500)
        XCTAssertEqual(cash.gain, 1_500)
        XCTAssertEqual(Wallet.value(items, m).value, 88_500)
        XCTAssertEqual(items[1].unitCost, 47)
    }
}

final class QuotaTextTests: XCTestCase {
    func testWaitAndWindowText() {
        UserDefaults.standard.set("en", forKey: "wafi.lang")
        defer { UserDefaults.standard.removeObject(forKey: "wafi.lang") }
        XCTAssertEqual(formatWait(4 * 3600 + 12 * 60 + 5), "4h 12m")
        XCTAssertEqual(formatWait(95), "1m 35s")
        XCTAssertEqual(perWindow(QuotaRule(limit: 15, windowHours: 8)), "15 per 8h")
        XCTAssertEqual(perWindow(QuotaRule(limit: 0, windowHours: 8)), "Unlimited")
    }
}
