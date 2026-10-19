import Foundation

/// The app speaks Arabic first; English follows the phone's language.
enum Lang {
    static var isArabic: Bool {
        if let forced = UserDefaults.standard.string(forKey: "wafi.lang") { return forced != "en" }
        return (Bundle.main.preferredLocalizations.first ?? "ar") != "en"
    }
    static var locale: Locale { isArabic ? Locale(identifier: "ar_EG") : Locale(identifier: "en_US") }
    static var code: String { isArabic ? "ar" : "en" }
}

/// Arabic-first inline copy with an English counterpart.
@inline(__always) func t(_ ar: String, _ en: String) -> String { Lang.isArabic ? ar : en }

/// How money is written for the country the user browses. Every price the server sends is already in that
/// country's currency, so one switch here re-labels the whole app.
enum MoneyStyle {
    nonisolated(unsafe) static var currency = "EGP"
    nonisolated(unsafe) static var symbolAr = "ج.م"
    nonisolated(unsafe) static var symbolEn = "EGP"
    static func use(_ c: Country) { currency = c.currency; symbolAr = c.symbolAr; symbolEn = c.symbolEn }
}

enum Fmt {
    private static func formatter(_ locale: Locale, min: Int, max: Int) -> NumberFormatter {
        let f = NumberFormatter()
        f.locale = locale
        f.numberStyle = .decimal
        f.usesGroupingSeparator = true
        f.minimumFractionDigits = min
        f.maximumFractionDigits = max
        f.roundingMode = .halfUp
        return f
    }

    static func number(_ n: Decimal, decimals: Int = 0, locale: Locale = Lang.locale) -> String {
        formatter(locale, min: decimals, max: decimals).string(from: NSDecimalNumber(decimal: n)) ?? "\(n)"
    }
    static func number(_ n: Int, locale: Locale = Lang.locale) -> String { number(Decimal(n), locale: locale) }
    static func number(_ n: Double, decimals: Int = 0, locale: Locale = Lang.locale) -> String {
        formatter(locale, min: decimals, max: decimals).string(from: NSNumber(value: n)) ?? "\(n)"
    }

    /// "٢٠٬٠٥٠ ج.م" / "EGP 20,050" in the chosen country's currency. Whole units unless there are fractions.
    static func money(_ amount: Decimal, symbolAr: String = MoneyStyle.symbolAr, symbolEn: String = MoneyStyle.symbolEn,
                      locale: Locale = Lang.locale) -> String {
        var v = amount, r = Decimal()
        NSDecimalRound(&r, &v, 2, .plain)
        var whole = Decimal(), rr = r
        NSDecimalRound(&whole, &rr, 0, .plain)
        let digits = whole == r ? 0 : 2
        let n = formatter(locale, min: digits, max: 2).string(from: NSDecimalNumber(decimal: r)) ?? "\(r)"
        return locale.language.languageCode?.identifier == "ar" ? "\(n) \(symbolAr)" : "\(symbolEn) \(n)"
    }

    /// Egyptian pounds whatever the chosen country (gold and dollar alerts are priced in Egypt).
    static func egpFixed(_ amount: Decimal) -> String { money(amount, symbolAr: "ج.م", symbolEn: "EGP") }

    /// "١٫٢ مليون" / "1.2M".
    static func compact(_ amount: Decimal, locale: Locale = Lang.locale) -> String {
        let ar = locale.language.languageCode?.identifier == "ar"
        let d = NSDecimalNumber(decimal: amount).doubleValue
        let f = formatter(locale, min: 0, max: 1)
        if d >= 1_000_000 { return (f.string(from: NSNumber(value: d / 1_000_000)) ?? "") + (ar ? " مليون" : "M") }
        if d >= 1_000 { return (f.string(from: NSNumber(value: d / 1_000)) ?? "") + (ar ? " ألف" : "K") }
        return f.string(from: NSNumber(value: d)) ?? ""
    }

    /// Size of a change without its sign ("٠٫٢٧٪"); callers show the direction with ▲/▼ and colour.
    static func pct(_ p: Decimal?, locale: Locale = Lang.locale) -> String? {
        guard let p else { return nil }
        let ar = locale.language.languageCode?.identifier == "ar"
        return number(abs(p), decimals: 2, locale: locale) + (ar ? "٪" : "%")
    }

    /// "النهارده" / "امبارح" / "١٨ أكتوبر" for an ISO timestamp or date.
    static func seen(_ iso: String?, locale: Locale = Lang.locale, today: Date = Date()) -> String? {
        guard let iso, !iso.isEmpty, let day = parseDay(iso) else { return nil }
        let cal = Calendar(identifier: .gregorian)
        let start = cal.startOfDay(for: today)
        let diff = cal.dateComponents([.day], from: cal.startOfDay(for: day), to: start).day ?? 0
        let ar = locale.language.languageCode?.identifier == "ar"
        if diff <= 0 { return ar ? "النهارده" : "Today" }
        if diff == 1 { return ar ? "امبارح" : "Yesterday" }
        let f = DateFormatter()
        f.locale = locale
        f.calendar = cal
        f.dateFormat = cal.component(.year, from: day) == cal.component(.year, from: today) ? "d MMMM" : "d MMMM yyyy"
        return f.string(from: day)
    }

    static func parseDay(_ iso: String) -> Date? {
        let full = ISO8601DateFormatter()
        full.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = full.date(from: iso) { return d }
        full.formatOptions = [.withInternetDateTime]
        if let d = full.date(from: iso) { return d }
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd"
        return f.date(from: String(iso.prefix(10)))
    }
}

// MARK: - Labels shared by many screens

func categoryLabel(_ c: Category) -> String {
    switch c {
    case .phones: return t("موبايلات", "Phones")
    case .laptops: return t("لابتوب", "Laptops")
    case .audio: return t("سماعات", "Audio")
    case .tablets: return t("تابلت", "Tablets")
    case .cars: return t("عربيات", "Cars")
    case .pcParts: return t("قطع PC", "PC parts")
    case .fashion: return t("هدوم", "Fashion")
    case .music: return t("أدوات موسيقى", "Music")
    case .other: return t("أخرى", "Other")
    }
}

func partLabel(_ p: String) -> String {
    switch p {
    case "cpu": return t("المعالج", "Processor")
    case "gpu": return t("كارت الشاشة", "Graphics card")
    case "motherboard": return t("اللوحة الأم", "Motherboard")
    case "ram": return t("الرامات", "Memory")
    case "storage": return t("التخزين", "Storage")
    case "psu": return t("الباور", "Power supply")
    case "case": return t("الكيسة", "Case")
    default: return p
    }
}

func transmissionLabel(_ v: String) -> String { v == "automatic" ? t("أوتوماتيك", "Automatic") : v == "manual" ? t("مانيوال", "Manual") : v }

func fuelLabel(_ v: String) -> String {
    switch v {
    case "petrol": return t("بنزين", "Petrol")
    case "diesel": return t("ديزل", "Diesel")
    case "hybrid": return t("هايبرد", "Hybrid")
    case "electric": return t("كهرباء", "Electric")
    case "natural_gas": return t("غاز طبيعي", "Natural gas")
    default: return v
    }
}

func instrumentLabel(_ v: String) -> String {
    switch v {
    case "guitar": return t("جيتار", "Guitar")
    case "bass": return t("باص جيتار", "Bass")
    case "keyboard": return t("أورج / كيبورد", "Keyboard")
    case "piano": return t("بيانو", "Piano")
    case "drums": return t("درامز", "Drums")
    case "violin": return t("كمان", "Violin")
    case "oud": return t("عود", "Oud")
    case "ukulele": return t("يوكوليلي", "Ukulele")
    case "wind": return t("آلة نفخ", "Wind")
    case "microphone": return t("مايك", "Microphone")
    case "interface": return t("كارت صوت", "Audio interface")
    case "amplifier": return t("أمبليفاير", "Amplifier")
    case "dj": return t("أجهزة DJ", "DJ gear")
    default: return t("أخرى", "Other")
    }
}

func levelLabel(_ v: String) -> String {
    switch v {
    case "beginner": return t("للمبتدئين", "Beginner")
    case "intermediate": return t("متوسط", "Intermediate")
    case "pro": return t("احترافي", "Pro")
    default: return v
    }
}

func carLine(_ s: Specs) -> String {
    [s.int("year").map { "\($0)" },
     s.int("km").map { $0 == 0 ? t("زيرو", "0 km") : Fmt.number($0) + t(" كم", " km") },
     s.str("transmission").map(transmissionLabel),
     s.str("fuel").map(fuelLabel)].compactMap { $0 }.joined(separator: " · ")
}

func partLine(_ s: Specs) -> String {
    [s.str("part").map(partLabel), s.str("socket"), s.str("ram_type"),
     s.int("capacity_gb").map { $0 >= 1000 ? "\($0 / 1000)TB" : "\($0)GB" }, s.int("watts").map { "\($0)W" }]
        .compactMap { $0 }.joined(separator: " · ")
}

func musicLine(_ s: Specs) -> String {
    [s.str("instrument").map(instrumentLabel),
     s.flag("electric").map { $0 ? t("كهربا", "Electric") : t("أكوستيك", "Acoustic") },
     s.int("strings").map { Fmt.number($0) + t(" أوتار", " strings") },
     s.int("keys").map { Fmt.number($0) + t(" مفتاح", " keys") },
     s.str("level").map(levelLabel)].compactMap { $0 }.joined(separator: " · ")
}

extension ProductSummary {
    var title: String { Lang.isArabic ? titleAr : titleEn }
    var categoryValue: Category { Category.from(category) }
    var variantLine: String { [storage, ram, color].filter { !$0.isEmpty }.joined(separator: " · ") }
    /// The line under a product title, specific to its kind.
    var subtitle: String {
        switch categoryValue {
        case .cars: return carLine(specs)
        case .pcParts: let p = partLine(specs); return p.isEmpty ? "\(brand) \(model)" : p
        case .music: return [brand, musicLine(specs)].filter { !$0.isEmpty }.joined(separator: " · ")
        default: return ["\(brand) \(model)", variantLine].filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }.joined(separator: " · ")
        }
    }
}

extension Product { var title: String { Lang.isArabic ? titleAr : titleEn } }
extension Country { var name: String { Lang.isArabic ? nameAr : nameEn } }

/// Turns user typing (Arabic or Latin digits, separators) into a Decimal.
func parseDecimal(_ s: String) -> Decimal? {
    let map: [Character: Character] = ["٠": "0", "١": "1", "٢": "2", "٣": "3", "٤": "4", "٥": "5", "٦": "6", "٧": "7", "٨": "8", "٩": "9", "٫": "."]
    let cleaned = String(s.compactMap { c -> Character? in
        if let m = map[c] { return m }
        if c == "," || c == "٬" || c == " " { return nil }
        return c
    })
    guard !cleaned.isEmpty else { return nil }
    return Decimal(string: cleaned, locale: Locale(identifier: "en_US_POSIX"))
}
