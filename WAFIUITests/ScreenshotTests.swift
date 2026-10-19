import XCTest

/// Opens every main screen against the mock API (ci/mock_api.py) and saves a PNG per screen.
/// Screens are opened directly with -WAFI_ROUTE (see LaunchScript.swift) so the tour doesn't depend on taps.
/// Environment (passed as TEST_RUNNER_* by xcodebuild): WAFI_SHOTS (output folder), WAFI_SEED (ci/fixtures/seed.json).
final class ScreenshotTests: XCTestCase {
    private var seed: [String: Any] = [:]
    private var shots = ""

    override func setUpWithError() throws {
        continueAfterFailure = true
        let env = ProcessInfo.processInfo.environment
        shots = env["WAFI_SHOTS"] ?? NSTemporaryDirectory()
        try? FileManager.default.createDirectory(atPath: shots, withIntermediateDirectories: true)
        if let p = env["WAFI_SEED"], let d = FileManager.default.contents(atPath: p) {
            seed = (try JSONSerialization.jsonObject(with: d) as? [String: Any]) ?? [:]
        }
    }

    private func pid(_ k: String) -> String { ((seed["products"] as? [String: String]) ?? [:])[k] ?? "missing" }
    private var member: String { seed["member"] as? String ?? "" }
    private var pro: String { seed["pro"] as? String ?? "" }

    private func launch(route: String? = nil, token: String? = nil, lang: String = "ar", dark: Bool = false,
                        onboarded: Bool = true, country: Bool = true, extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        var args = ["-WAFI_RESET", "YES", "-WAFI_API", "http://127.0.0.1:8000", "-WAFI_SCREENSHOTS", "-WAFI_NO_ADS", "-wafi.lang", lang,
                    "-AppleLanguages", "(\(lang))", "-AppleLocale", lang == "ar" ? "ar_EG" : "en_US",
                    "-wafi.theme", dark ? "dark" : "light"]
        if onboarded { args += ["-WAFI_SKIP_ONBOARDING", "YES"] }
        if country { args += ["-WAFI_COUNTRY", "EG"] }
        if let route { args += ["-WAFI_ROUTE", route] }
        if let token { args += ["-WAFI_TOKEN", token] }
        app.launchArguments = args + extra
        app.launch()
        return app
    }

    @discardableResult
    private func wait(_ app: XCUIApplication, _ text: String, timeout: TimeInterval = 20) -> Bool {
        let q = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", text))
        return q.firstMatch.waitForExistence(timeout: timeout)
    }

    private func snap(_ app: XCUIApplication, _ name: String) {
        sleep(2)   // let charts finish drawing in
        let shot = app.screenshot()
        let a = XCTAttachment(screenshot: shot)
        a.name = name
        a.lifetime = .keepAlways
        add(a)
        try? shot.pngRepresentation.write(to: URL(fileURLWithPath: shots).appendingPathComponent(name + ".png"))
    }

    // MARK: Arabic, light

    func test01_onboarding() { let a = launch(onboarded: false, country: false); wait(a, "رادار واحد"); snap(a, "01_onboarding") }
    func test02_country() { let a = launch(country: false); wait(a, "بتشتري منين"); snap(a, "02_country") }
    func test03_home() { let a = launch(); wait(a, "الرادار شغّال"); snap(a, "03_home"); a.swipeUp(); snap(a, "04_home_more") }
    func test05_searchAnalysis() { let a = launch(route: "search:آيفون"); wait(a, "تحليل الأسعار"); snap(a, "05_search_analysis") }
    func test06_category() { let a = launch(route: "category:phones"); wait(a, "تحليل الأسعار"); snap(a, "06_phones") }
    func test07_music() { let a = launch(route: "category:music"); wait(a, "تحليل الأسعار"); snap(a, "07_music") }
    func test08_product() { let a = launch(route: "product:" + pid("a55")); wait(a, "أرخص سعر"); snap(a, "08_product"); a.swipeUp(); snap(a, "09_product_offers") }
    func test10_market() { let a = launch(route: "tab:market"); wait(a, "سعر جرام الدهب"); snap(a, "10_market"); a.swipeUp(); snap(a, "11_market_tools") }
    func test12_wallet() { let a = launch(route: "wallet", extra: ["-WAFI_DEMO_WALLET", "YES"]); wait(a, "تحويش العملات"); snap(a, "12_wallet") }
    func test13_goldAdvisor() { let a = launch(route: "goldAdvisor"); wait(a, "عيار ٢١"); snap(a, "13_gold_analysis") }
    func test14_assistant() { let a = launch(route: "assistant:عايز موبايل في حدود ٢٠ ألف"); wait(a, "ج.م", timeout: 25); snap(a, "14_assistant") }
    func test15_advisorHub() { let a = launch(route: "advisor"); wait(a, "قولّي محتاج إيه"); snap(a, "15_advisor") }
    func test16_phoneAdvisor() {
        let a = launch(route: "picks:phones"); wait(a, "أهم حاجة عندك")
        a.buttons.matching(NSPredicate(format: "label CONTAINS %@", "رشّحلي")).firstMatch.tap()
        wait(a, "الاختيار الأنسب"); snap(a, "16_phone_picks")
    }
    func test17_pcAdvisor() {
        let a = launch(route: "pcAdvisor"); wait(a, "هتستخدمه في إيه")
        a.buttons.matching(NSPredicate(format: "label CONTAINS %@", "حلّل")).firstMatch.tap()
        wait(a, "ركّزنا"); snap(a, "17_pc_advice")
    }
    func test18_deals() { let a = launch(route: "deals"); wait(a, "نزلت أسعارها"); snap(a, "18_deals") }
    func test19_compare() { let a = launch(route: "compare:" + [pid("a55"), pid("ip15"), pid("rn13")].joined(separator: ","), token: pro); wait(a, "الأرخص"); snap(a, "19_compare") }
    func test20_basket() {
        let a = launch(route: "basket:" + [pid("a55"), pid("xm5"), pid("ipad")].joined(separator: ","))
        wait(a, "احسب أرخص خطة")
        a.buttons.matching(NSPredicate(format: "label CONTAINS %@", "احسب أرخص خطة")).firstMatch.tap()
        wait(a, "الإجمالي"); snap(a, "20_basket_plan")
    }
    func test21_pro() { let a = launch(route: "pro", token: member); wait(a, "مجاني"); snap(a, "21_pro") }
    func test22_account() { let a = launch(route: "tab:account", token: member); wait(a, "حسابي"); snap(a, "22_account") }
    func test23_accountGuest() { let a = launch(route: "tab:account"); wait(a, "بحث من غير حد"); snap(a, "23_account_guest") }
    func test24_signIn() { let a = launch(route: "signIn"); wait(a, "أهلاً بيك"); snap(a, "24_sign_in") }
    func test25_marketAlerts() { let a = launch(route: "marketAlerts", token: pro); wait(a, "تنبيه جديد"); snap(a, "25_market_alerts") }
    func test26_cars() { let a = launch(route: "cars"); wait(a, "دوّر على عربية"); snap(a, "26_cars") }
    func test27_pcBuilder() {
        let a = launch(route: "pc"); wait(a, "ميزانيتك")
        a.buttons.matching(NSPredicate(format: "label CONTAINS %@", "اقترح تجميعة")).firstMatch.tap()
        wait(a, "إجمالي التجميعة"); snap(a, "27_pc_build")
    }
    func test28_settings() { let a = launch(route: "settings", token: member); wait(a, "المظهر"); snap(a, "28_settings") }

    // MARK: dark and English

    func test40_darkHome() { let a = launch(dark: true); wait(a, "الرادار شغّال"); snap(a, "40_dark_home") }
    func test41_darkProduct() { let a = launch(route: "product:" + pid("ip15"), dark: true); wait(a, "أرخص سعر"); snap(a, "41_dark_product") }
    func test42_darkMarket() { let a = launch(route: "tab:market", dark: true); wait(a, "سعر جرام الدهب"); snap(a, "42_dark_market") }
    func test50_enHome() { let a = launch(lang: "en"); wait(a, "Radar live"); snap(a, "50_en_home") }
    func test51_enSearch() { let a = launch(route: "search:iPhone", lang: "en"); wait(a, "Price analysis"); snap(a, "51_en_search") }
    func test52_enProduct() { let a = launch(route: "product:" + pid("a55"), lang: "en"); wait(a, "Lowest full price"); snap(a, "52_en_product") }
    func test53_enMarket() { let a = launch(route: "tab:market", lang: "en"); wait(a, "Gold per gram"); snap(a, "53_en_market") }
    func test54_enWallet() { let a = launch(route: "wallet", lang: "en", extra: ["-WAFI_DEMO_WALLET", "YES"]); wait(a, "Currency savings"); snap(a, "54_en_wallet") }
    func test55_enAssistant() { let a = launch(route: "assistant:A phone around EGP 20K", lang: "en"); wait(a, "EGP", timeout: 25); snap(a, "55_en_assistant") }
    func test56_enPro() { let a = launch(route: "pro", token: member, lang: "en"); wait(a, "Free"); snap(a, "56_en_pro") }
}
