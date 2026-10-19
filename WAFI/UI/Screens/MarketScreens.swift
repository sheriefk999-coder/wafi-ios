import SwiftUI

private let currencyNames: [String: (String, String)] = [
    "USD": ("دولار أمريكي", "US dollar"), "EUR": ("يورو", "Euro"), "GBP": ("جنيه إسترليني", "British pound"),
    "SAR": ("ريال سعودي", "Saudi riyal"), "AED": ("درهم إماراتي", "UAE dirham"), "KWD": ("دينار كويتي", "Kuwaiti dinar"),
    "QAR": ("ريال قطري", "Qatari riyal"), "JOD": ("دينار أردني", "Jordanian dinar"), "OMR": ("ريال عماني", "Omani rial"),
    "EGP": ("جنيه مصري", "Egyptian pound"), "BHD": ("دينار بحريني", "Bahraini dinar"), "CNY": ("يوان صيني", "Chinese yuan"),
    "TRY": ("ليرة تركية", "Turkish lira"),
]
func currencyName(_ code: String) -> String { currencyNames[code].map { t($0.0, $0.1) } ?? code }

private func decimalFromInput(_ s: String) -> Decimal? {
    parseDecimal(s.replacingOccurrences(of: ",", with: "").replacingOccurrences(of: "٬", with: ""))
}
private func digitsOnly(_ s: String, max: Int) -> String {
    String(s.filter { $0.isNumber || $0 == "." || $0 == "," || $0 == "٫" }.prefix(max))
}
private func round(_ d: Decimal, _ scale: Int) -> Decimal { var v = d, r = Decimal(); NSDecimalRound(&r, &v, scale, .plain); return r }

struct ChangeBadge: View {
    var p: Decimal?
    var body: some View {
        if let p {
            Badge((p > 0 ? "▲ " : p < 0 ? "▼ " : "") + (Fmt.pct(p) ?? ""), p > 0 ? .signal : p < 0 ? .danger : .neutral)
        }
    }
}

// MARK: - Gold & currencies tab

struct MarketScreen: View {
    @Environment(AppState.self) private var app
    @State private var state: Load<MarketResponse> = .loading

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(t("الدهب والعملات", "Gold & currencies")).font(.headline).foregroundStyle(PR.ink)
                    if let m = state.value {
                        HStack(spacing: 8) {
                            Text(t("أسعار مرجعية · ", "Reference rates · ") + m.asOf).font(.bodyS).foregroundStyle(PR.inkSoft)
                            if m.stale { Badge(t("آخر سعر متاح", "Last known"), .amber) }
                        }
                    }
                }
                .padding(.horizontal, 20).padding(.top, 16).padding(.bottom, 8)
                switch state {
                case .loading:
                    VStack(spacing: 12) { Skeleton(height: 230); Skeleton(height: 160) }.padding(20)
                case .err(let e):
                    EmptyState(icon: Ic.gold, title: t("الأسعار مش متاحة", "Prices unavailable"), bodyText: e.message, action: t("حاول تاني", "Try again")) {
                        Task { await reload() }
                    }
                    .padding(.top, 30)
                case .ok(let m):
                    GoldCard(m: m)
                    MarketShortcuts()
                    GoldHistory()
                    GoldCalculator(m: m)
                    Converter(rates: m.currencies)
                    Text(m.base == "EGP" ? t("العملات قدام الجنيه", "Currencies vs EGP") : t("العملات قدام ", "Currencies vs ") + currencyName(m.base))
                        .font(.titleL).foregroundStyle(PR.ink).padding(.horizontal, 20).padding(.top, 20).padding(.bottom, 8)
                    ForEach(m.currencies) { CurrencyRow(c: $0) }
                    AdSlot(kind: .banner, placement: "market").padding(.top, 8)
                    Text(t("أسعار الدهب محسوبة من السعر العالمي وسعر الصرف المرجعي. سعر الصاغة بيزود عليها المصنعية وهامش المحل.",
                           "Gold prices are computed from the world price and the reference exchange rate. Jewellers add workmanship and their margin."))
                        .font(.bodyS).foregroundStyle(PR.inkSoft).padding(20)
                }
            }
            .padding(.bottom, 80)
        }
        .background(PR.white)
        .refreshable { await reload() }
        .task { if state.value == nil { await reload() } }
    }

    private func reload() async {
        let r = await load { try await app.api.market() }
        if r.value != nil || state.value == nil { state = r }
    }
}

private struct GoldCard: View {
    var m: MarketResponse
    @State private var karat = 21
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: Ic.gold).foregroundStyle(PR.amberDeep)
                Text(t("سعر جرام الدهب", "Gold per gram")).font(.titleS).foregroundStyle(PR.amberDeep)
                Spacer()
                ChangeBadge(p: m.gold.changePct)
            }
            Text(t("عيار \(Fmt.number(karat))", "\(karat)K")).font(.labelL).foregroundStyle(PR.ink.opacity(0.7)).padding(.top, 10)
            AnimatedMoney(value: m.gold.karats.first { $0.karat == karat }?.egpPerGram, font: .wafi(38, .bold, relativeTo: .largeTitle))
            HStack(spacing: 6) {
                ForEach(m.gold.karats, id: \.karat) { k in
                    let sel = k.karat == karat
                    Button { withAnimation(.snappy) { karat = k.karat } } label: {
                        Text(Fmt.number(k.karat)).font(.labelL).foregroundStyle(sel ? PR.onAccent : PR.ink)
                            .padding(.horizontal, 12).padding(.vertical, 8)
                            .background(sel ? PR.hero : PR.white.opacity(0.55)).clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(Pressable())
                }
            }
            .padding(.top, 12)
            HStack(alignment: .top) {
                mini(t("الجنيه الدهب", "Gold pound"), Fmt.money(m.gold.goldPoundEgp))
                mini(t("الأوقية", "Ounce"), "$" + Fmt.number(m.gold.usdPerOunce))
                if let s = m.silver { mini(t("فضة ٩٩٩ / جرام", "Silver 999 / g"), Fmt.money(s.egpPerGram999)) }
            }
            .padding(.top, 16)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LinearGradient(colors: [PR.goldA, PR.goldB, PR.goldC], startPoint: .topLeading, endPoint: .bottomTrailing))
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .padding(.horizontal, 20).padding(.vertical, 8)
    }
    private func mini(_ l: String, _ v: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(l).font(.labelS).foregroundStyle(PR.ink.opacity(0.65))
            Text(v).font(.titleS).foregroundStyle(PR.ink).lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Two doors under the gold card: the wallet and the Pro rate alerts.
private struct MarketShortcuts: View {
    @Environment(Router.self) private var router
    var body: some View {
        HStack(spacing: 10) {
            door(Ic.wallet, PR.amberWash, PR.amberDeep, t("محفظتي", "My wallet"), t("دهبك وتحويشتك النهارده", "Your gold & savings today")) { router.push(.wallet) }
            door(Ic.bell, PR.signalSoft, PR.signalDeep, t("نبّهني", "Alert me"), t("لما يوصل لرقمك · Pro", "At your number · Pro")) { router.push(.marketAlerts) }
        }
        .padding(.horizontal, 20).padding(.vertical, 4)
    }
    private func door(_ icon: String, _ bg: Color, _ fg: Color, _ title: String, _ sub: String, _ go: @escaping () -> Void) -> some View {
        Panel(padding: 12, action: go) {
            HStack(spacing: 10) {
                IconTile(icon: icon, bg: bg, fg: fg, size: 36, iconSize: 17)
                VStack(alignment: .leading, spacing: 0) {
                    Text(title).font(.titleS).foregroundStyle(PR.ink)
                    Text(sub).font(.labelS).foregroundStyle(PR.inkSoft).lineLimit(1).minimumScaleFactor(0.8)
                }
            }
        }
    }
}

/// 21K per gram over 7/30/90 days, with a door to the full analysis.
private struct GoldHistory: View {
    @Environment(AppState.self) private var app
    @Environment(Router.self) private var router
    @State private var days = 30
    @State private var history: [MarketDay] = []
    var body: some View {
        Panel(radius: 22) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(t("حركة عيار ٢١", "21K movement")).font(.titleM).foregroundStyle(PR.ink)
                        if history.count >= 2, let first = history.first?.gold21, let last = history.last?.gold21, first > 0 {
                            let pct = round((last - first) * 100 / first, 2)
                            Text((pct >= 0 ? "▲ " : "▼ ") + (Fmt.pct(pct) ?? "") + t(" في الفترة دي", " over this period"))
                                .font(.labelM).foregroundStyle(pct >= 0 ? PR.danger : PR.signalDeep)
                        }
                    }
                    Spacer()
                    ForEach([(7, t("أسبوع", "1W")), (30, t("شهر", "1M")), (90, t("٣ شهور", "3M"))], id: \.0) { d in
                        Chip(d.1, selected: d.0 == days) { days = d.0 }
                    }
                }
                if history.count >= 2 {
                    AreaChart(values: history.map { NSDecimalNumber(decimal: $0.gold21).doubleValue }).frame(height: 130).id(days)
                } else {
                    Text(t("بنسجّل الأسعار يوم بيوم، والرسم هيظهر قريب.", "We record prices daily; the chart appears soon."))
                        .font(.bodyS).foregroundStyle(PR.inkSoft).frame(maxWidth: .infinity, minHeight: 90)
                }
                Button { router.push(.goldAdvisor) } label: {
                    HStack(spacing: 10) {
                        Image(systemName: Ic.compass).foregroundStyle(PR.amberDeep)
                        Text(t("أشتري دهب دلوقتي؟ شوف التحليل", "Buy gold now? See the analysis")).font(.titleS).foregroundStyle(PR.amberDeep)
                        Spacer()
                        Image(systemName: Ic.forward).foregroundStyle(PR.amberDeep)
                    }
                    .padding(12).background(PR.amberSoft).clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(Pressable())
            }
        }
        .padding(.horizontal, 20).padding(.vertical, 10)
        .task(id: days) { if let h = try? await app.api.marketHistory(days: days) { history = h } }
    }
}

/// Weight × karat → value.
private struct GoldCalculator: View {
    var m: MarketResponse
    @State private var grams = "10"
    @State private var karat = 21
    var body: some View {
        let g = decimalFromInput(grams)
        let per = m.gold.karats.first { $0.karat == karat }?.egpPerGram
        let total: Decimal? = (g != nil && per != nil && g! > 0) ? round(g! * per!, 2) : nil
        Panel(radius: 22) {
            VStack(alignment: .leading, spacing: 12) {
                Text(t("حاسبة الدهب", "Gold calculator")).font(.titleM).foregroundStyle(PR.ink)
                PRField(label: t("الوزن بالجرام", "Weight in grams"), text: Binding(get: { grams }, set: { grams = digitsOnly($0, max: 8) }),
                        icon: Ic.gold, keyboard: .decimalPad, ltr: true)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(m.gold.karats, id: \.karat) { k in Chip(t("عيار \(Fmt.number(k.karat))", "\(k.karat)K"), selected: k.karat == karat) { karat = k.karat } }
                    }
                }
                Text(t("القيمة التقريبية", "Approximate value")).font(.labelM).foregroundStyle(PR.inkSoft)
                AnimatedMoney(value: total, font: .headline)
            }
        }
        .padding(.horizontal, 20).padding(.vertical, 8)
    }
}

private struct Converter: View {
    var rates: [CurrencyRate]
    @State private var code = "USD"
    @State private var amount = "100"
    @State private var toLocal = true
    var body: some View {
        let rate = rates.first { $0.code == code }?.egp
        let a = decimalFromInput(amount)
        let result: Decimal? = (rate != nil && a != nil && rate! > 0) ? (toLocal ? a! * rate! : round(a! / rate!, 4)) : nil
        let local = MoneyStyle.currency
        Panel(radius: 22) {
            VStack(alignment: .leading, spacing: 12) {
                Text(t("محوّل العملات", "Currency converter")).font(.titleM).foregroundStyle(PR.ink)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) { ForEach(rates) { r in Chip(r.code, selected: r.code == code) { code = r.code } } }
                }
                HStack(alignment: .bottom, spacing: 10) {
                    PRField(label: toLocal ? code : local, text: Binding(get: { amount }, set: { amount = digitsOnly($0, max: 12) }), keyboard: .decimalPad, ltr: true)
                    Button { withAnimation(.snappy) { toLocal.toggle() } } label: {
                        Image(systemName: Ic.exchange).font(.system(size: 19, weight: .semibold)).foregroundStyle(PR.onAccent)
                            .rotationEffect(.degrees(toLocal ? 0 : 180))
                            .frame(width: 52, height: 52).background(PR.hero).clipShape(Circle())
                    }
                    .accessibilityLabel(t("اعكس", "Swap"))
                }
                Text(toLocal ? t("بالـ", "In ") + currencyName(local) : t("بالـ \(code)", "In \(code)")).font(.labelM).foregroundStyle(PR.inkSoft)
                if toLocal {
                    AnimatedMoney(value: result.map { round($0, 2) }, font: .headline)
                } else {
                    Text(result.map { Fmt.number($0, decimals: 2) + " " + code } ?? "—").font(.headline).foregroundStyle(PR.ink)
                        .environment(\.layoutDirection, .leftToRight)
                }
                if let rate {
                    Text("1 \(code) = " + Fmt.money(round(rate, 4))).font(.bodyS).foregroundStyle(PR.inkSoft).environment(\.layoutDirection, .leftToRight)
                }
            }
        }
        .padding(.horizontal, 20).padding(.vertical, 8)
    }
}

private struct CurrencyRow: View {
    var c: CurrencyRate
    var body: some View {
        HStack(spacing: 12) {
            Text(c.code).font(.labelM).foregroundStyle(PR.ink).frame(width: 44, height: 44).background(PR.paper).clipShape(RoundedRectangle(cornerRadius: 14))
            VStack(alignment: .leading, spacing: 0) {
                Text(currencyName(c.code)).font(.titleS).foregroundStyle(PR.ink)
                Text("1 \(c.code)").font(.bodyS).foregroundStyle(PR.inkSoft)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                PriceText(value: round(c.egp, 2), font: .titleS)
                ChangeBadge(p: c.changePct)
            }
        }
        .padding(.horizontal, 20).padding(.vertical, 6)
    }
}

// MARK: - Pro: gold & dollar alerts

func metricLabel(_ m: String) -> String {
    switch m {
    case "gold24": return t("دهب عيار ٢٤", "24K gold")
    case "gold21": return t("دهب عيار ٢١", "21K gold")
    case "gold18": return t("دهب عيار ١٨", "18K gold")
    case "gold_pound": return t("الجنيه الدهب", "Gold pound")
    case "usd": return t("الدولار", "US dollar")
    case "eur": return t("اليورو", "Euro")
    case "sar": return t("الريال السعودي", "Saudi riyal")
    default: return m
    }
}
private func metricUnit(_ m: String) -> String {
    switch m {
    case "gold24", "gold21", "gold18": return t("للجرام", "per gram")
    case "gold_pound": return t("للجنيه", "per coin")
    default: return t("بالجنيه المصري", "in EGP")
    }
}
private let metrics = ["gold21", "gold24", "gold18", "gold_pound", "usd", "eur", "sar"]

struct MarketAlertsScreen: View {
    @Environment(AppState.self) private var app
    @Environment(Router.self) private var router
    @State private var state: Load<MarketAlertList> = .loading

    var body: some View {
        Screen(title: t("نبّهني بالسعر", "Rate alerts"), subtitle: t("الدهب والدولار · Pro", "Gold and dollar · Pro")) {
            VStack(alignment: .leading, spacing: 0) {
                Text(t("قولنا الرقم اللي مستنيه، وأول ما السعر المرجعي يوصله هيجيلك إشعار. بنراجع كل ٥ دقايق.",
                       "Name the number you're waiting for. The moment the reference rate gets there you get a notification. Checked every 5 minutes."))
                    .font(.bodyM).foregroundStyle(PR.inkSoft).padding(.horizontal, 20).padding(.vertical, 4)
                if app.country.code != "EG" {
                    Text(t("التنبيهات دي على سعر الدهب والعملات في مصر، بالجنيه المصري.", "These alerts follow Egypt's gold and currency rates, in Egyptian pounds."))
                        .font(.labelM).foregroundStyle(PR.amberDeep).padding(.horizontal, 20).padding(.vertical, 4)
                }
                if !app.isSignedIn {
                    EmptyState(icon: Ic.lock, title: t("سجّل دخولك الأول", "Sign in first"), bodyText: t("التنبيهات بتتبعت لحسابك.", "Alerts are sent to your account."),
                               action: t("تسجيل الدخول", "Sign in")) { router.push(.signIn) }
                        .padding(.top, 24)
                } else if !app.isPro {
                    ProUpsell(title: t("خلّي الرادار يستنى بدالك", "Let the radar wait for you"),
                              text: t("حدد سعر الدهب أو الدولار اللي عايزه، وإحنا نبعتلك أول ما يوصله. من غير ما تفتح التطبيق كل شوية.",
                                      "Set the gold or dollar price you want and we'll ping you when it gets there, no need to keep checking."))
                    AlertExample()
                } else {
                    switch state {
                    case .loading: Skeleton(height: 220).padding(20)
                    case .err(let e):
                        EmptyState(icon: Ic.bell, title: t("مش قادرين نجيب تنبيهاتك", "Couldn't load your alerts"), bodyText: e.message,
                                   action: t("حاول تاني", "Try again")) { Task { await reload() } }
                    case .ok(let data):
                        NewAlertCard(data: data) { await reload() }
                        HStack {
                            Text(t("تنبيهاتي", "My alerts")).font(.titleL).foregroundStyle(PR.ink)
                            Spacer()
                            Text(t("\(Fmt.number(data.items.count)) من \(Fmt.number(data.limit))", "\(data.items.count) of \(data.limit)")).font(.labelM).foregroundStyle(PR.inkFaint)
                        }
                        .padding(.horizontal, 20).padding(.top, 18).padding(.bottom, 6)
                        if data.items.isEmpty {
                            Text(t("لسه ما حطّتش تنبيه.", "No alerts yet.")).font(.bodyM).foregroundStyle(PR.inkSoft).padding(.horizontal, 20)
                        }
                        ForEach(data.items) { a in
                            AlertRow(a: a, now: data.current[a.metric]) { delete(a.id, from: data) }
                        }
                    }
                }
            }
        }
        .task(id: app.isPro) { if app.isSignedIn && app.isPro { await reload() } }
    }

    private func reload() async {
        let r = await load { try await app.api.marketAlerts() }
        if r.value != nil || state.value == nil { state = r }
    }

    private func delete(_ id: Int64, from data: MarketAlertList) {
        var d = data
        d.items.removeAll { $0.id == id }
        state = .ok(d)
        Task { try? await app.api.deleteMarketAlert(id) }
    }
}

private struct AlertExample: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(t("مثال", "Example")).font(.labelM).foregroundStyle(PR.inkFaint)
            Panel(padding: 14) {
                HStack(spacing: 12) {
                    IconTile(icon: Ic.gold, bg: PR.amberWash, fg: PR.amberDeep, size: 40, iconSize: 19)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(t("عيار ٢١ نزل تحت ٥٬٠٠٠ ج.م", "21K went below EGP 5,000")).font(.titleS).foregroundStyle(PR.ink)
                        Text(t("سعر الجرام دلوقتي ٤٬٩٨٠ ج.م", "A gram is now EGP 4,980")).font(.bodyS).foregroundStyle(PR.inkSoft)
                    }
                    Spacer()
                    Badge(t("وصل", "Hit"), .signal, icon: Ic.check)
                }
            }
        }
        .padding(.horizontal, 20).padding(.vertical, 8)
    }
}

private struct NewAlertCard: View {
    var data: MarketAlertList
    var onAdded: () async -> Void
    @Environment(AppState.self) private var app
    @State private var metric = "gold21"
    @State private var direction = "below"
    @State private var target = ""
    @State private var busy = false
    @State private var error: String?

    var body: some View {
        let now = data.current[metric]
        let value = decimalFromInput(target)
        let full = data.items.count >= data.limit
        Panel {
            VStack(alignment: .leading, spacing: 10) {
                Text(t("تنبيه جديد", "New alert")).font(.titleM).foregroundStyle(PR.ink)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) { ForEach(metrics, id: \.self) { m in Chip(metricLabel(m), selected: m == metric) { metric = m; target = "" } } }
                }
                HStack(spacing: 8) {
                    Chip(t("لما ينزل تحت", "Goes below"), selected: direction == "below", icon: Ic.minus) { direction = "below" }
                    Chip(t("لما يطلع فوق", "Goes above"), selected: direction == "above", icon: Ic.plus) { direction = "above" }
                }
                if let now {
                    HStack(spacing: 4) {
                        Text(t("دلوقتي", "Now")).font(.bodyS).foregroundStyle(PR.inkSoft)
                        Text(Fmt.egpFixed(now)).font(.titleS).foregroundStyle(PR.ink)
                        Text(metricUnit(metric)).font(.bodyS).foregroundStyle(PR.inkSoft)
                    }
                }
                PRField(label: t("الرقم المستهدف بالجنيه المصري", "Target in EGP"), text: Binding(get: { target }, set: { target = digitsOnly($0, max: 10) }),
                        icon: Ic.tag, keyboard: .decimalPad, ltr: true, placeholder: now.map { Fmt.number($0) })
                if let error { Text(error).font(.bodyS).foregroundStyle(PR.danger) }
                PRButton(full ? t("وصلت للحد الأقصى", "Limit reached") : t("ضيف التنبيه", "Add alert"), icon: Ic.bell, loading: busy,
                         enabled: !full && (value ?? 0) > 0, height: 48) {
                    guard let value else { return }
                    Task { await add(value) }
                }
            }
        }
        .padding(.horizontal, 20).padding(.vertical, 10)
    }

    private func add(_ value: Decimal) async {
        busy = true; error = nil
        defer { busy = false }
        do {
            try await app.api.createMarketAlert(metric: metric, direction: direction, target: value)
            target = ""
            if !Push.shared.hasAsked { _ = await Push.shared.requestPermission(); await Push.shared.registerIfSignedIn() }
            await onAdded()
        } catch let e as APIError {
            switch e.code {
            case "too_many_alerts": error = t("وصلت للحد الأقصى للتنبيهات. امسح واحد الأول.", "You've reached the alert limit. Delete one first.")
            case "pro_required": error = t("الميزة دي لمشتركين Pro.", "This is a Pro feature.")
            default: error = e.message
            }
        } catch { self.error = APIError.network(nil).message }
    }
}

private struct AlertRow: View {
    var a: MarketAlert
    var now: Decimal?
    var onDelete: () -> Void
    var body: some View {
        let hit = a.triggeredAt != nil
        let gold = a.metric.hasPrefix("gold")
        Panel(padding: 14, background: hit ? PR.signalSoft : PR.white, border: hit ? PR.signal : PR.line) {
            HStack(spacing: 12) {
                IconTile(icon: gold ? Ic.gold : Ic.exchange, bg: gold ? PR.amberWash : PR.skySoft, fg: gold ? PR.amberDeep : PR.sky, size: 40, iconSize: 19)
                VStack(alignment: .leading, spacing: 2) {
                    Text(metricLabel(a.metric)).font(.titleS).foregroundStyle(PR.ink)
                    Text((a.direction == "below" ? t("لما ينزل تحت ", "When below ") : t("لما يطلع فوق ", "When above ")) + Fmt.egpFixed(a.target))
                        .font(.bodyS).foregroundStyle(PR.inkSoft)
                    if hit {
                        Text(t("وصل ", "Hit ") + (a.triggeredValue.map { Fmt.egpFixed($0) } ?? "") + (Fmt.seen(a.triggeredAt).map { " · \($0)" } ?? ""))
                            .font(.labelS).foregroundStyle(PR.signalDeep)
                    } else if let now {
                        Text(t("دلوقتي ", "Now ") + Fmt.egpFixed(now)).font(.labelS).foregroundStyle(PR.inkFaint)
                    }
                }
                Spacer()
                if hit { Badge(t("وصل", "Hit"), .signal, icon: Ic.check) } else { Badge(t("مستني", "Waiting")) }
                Button(action: onDelete) { Image(systemName: Ic.trash).foregroundStyle(PR.inkFaint).frame(width: 36, height: 36) }
                    .accessibilityLabel(t("امسح", "Delete"))
            }
        }
        .padding(.horizontal, 20).padding(.vertical, 5)
    }
}

// MARK: - محفظتي: gold and currency savings

struct WalletScreen: View {
    @Environment(AppState.self) private var app
    @State private var market: Load<MarketResponse> = .loading
    @State private var adding: String?          // "gold" | "currency"

    var body: some View {
        let m = market.value
        let totals = Wallet.value(app.wallet, m)
        let (goldSide, cashSide) = Wallet.split(app.wallet, m)
        let limit = app.config.freeWalletItems
        let canAdd = app.isPro || app.wallet.count < limit
        Screen(title: t("محفظتي", "My wallet"), subtitle: t("دهبك وتحويشة العملات بسعر النهارده", "Your gold and savings at today's rates")) {
            VStack(alignment: .leading, spacing: 0) {
                WalletHero(totals: totals, m: m, loading: market.isLoading)
                if case .err = market, m == nil {
                    Text(t("الأسعار مش متاحة دلوقتي، القيم هتظهر أول ما ترجع.", "Rates are unavailable; values will show when they're back."))
                        .font(.bodyS).foregroundStyle(PR.amberDeep).padding(.horizontal, 20)
                }
                if !app.isPro && app.wallet.count <= limit {
                    Text(t("مسجّل \(Fmt.number(app.wallet.count)) من \(Fmt.number(limit)) في المجاني", "\(app.wallet.count) of \(limit) on the free plan"))
                        .font(.labelM).foregroundStyle(PR.inkFaint).padding(.horizontal, 20).padding(.top, 10)
                }
                if app.wallet.isEmpty && adding == nil {
                    Panel(background: PR.paper, border: PR.paper) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(t("سجّل دهبك وتحويشة العملات", "Log your gold and currency savings")).font(.titleS).foregroundStyle(PR.ink)
                            Text(t("شبكة، سبيكة، جنيه دهب، أو دولارات وريالات حوّشتها — سجّل سعر الشرا وهنقولك قيمتها النهارده ومكسبك أو خسارتك.",
                                   "A necklace, a bar, a gold pound, or dollars you saved — log what you paid and we'll show today's value and your gain or loss."))
                                .font(.bodyS).foregroundStyle(PR.inkSoft)
                        }
                    }
                    .padding(.horizontal, 20).padding(.vertical, 10)
                }
                WalletSection(title: t("الدهب", "Gold"), icon: Ic.gold, bg: PR.amberWash, fg: PR.amberDeep, side: goldSide,
                              onAdd: canAdd && adding == nil ? { withAnimation { adding = "gold" } } : nil)
                ForEach(Array(goldSide.items.enumerated()), id: \.element.id) { i, v in
                    HoldingRow(v: v, m: m) { remove(v.holding.id) }.reveal(i)
                }
                if adding == "gold" { AddHolding(m: m, currencyMode: false, onCancel: { adding = nil }) { app.wallet.append($0); adding = nil } }
                WalletSection(title: t("تحويش العملات", "Currency savings"), icon: Ic.exchange, bg: PR.skySoft, fg: PR.sky, side: cashSide,
                              onAdd: canAdd && adding == nil ? { withAnimation { adding = "currency" } } : nil)
                if cashSide.items.isEmpty && adding != "currency" {
                    Text(t("بتحوّش دولار أو ريال أو يورو؟ سجّل المبلغ وسعر الشرا، وتابع قيمته بالسعر النهارده.",
                           "Saving dollars, riyals or euros? Log the amount and the rate you paid, and follow its value at today's rate."))
                        .font(.bodyS).foregroundStyle(PR.inkSoft).padding(.horizontal, 20).padding(.vertical, 2)
                }
                ForEach(Array(cashSide.items.enumerated()), id: \.element.id) { i, v in
                    HoldingRow(v: v, m: m) { remove(v.holding.id) }.reveal(i)
                }
                if adding == "currency" { AddHolding(m: m, currencyMode: true, onCancel: { adding = nil }) { app.wallet.append($0); adding = nil } }
                if !canAdd && adding == nil {
                    ProUpsell(title: t("محفظة من غير حد", "An unlimited wallet"),
                              text: t("المجاني بيسجّل لحد \(Fmt.number(limit)) حاجات. مع Pro سجّل كل دهبك وعملاتك.",
                                      "The free plan holds up to \(limit) items. With Pro, log everything you own."))
                }
                Text(t("القيمة محسوبة بالسعر المرجعي للجرام من غير مصنعية، وده مش عرض بيع أو شرا. بيانات المحفظة محفوظة على موبايلك بس ومش بتتبعت لحد.",
                       "Values use the reference gram price without workmanship; this isn't a buy or sell quote. Your wallet stays on this phone and is never uploaded."))
                    .font(.bodyS).foregroundStyle(PR.inkFaint).padding(20)
            }
        }
        .task {
            let r = await load { try await app.api.market() }
            if r.value != nil || market.value == nil { market = r }
        }
    }

    private func remove(_ id: String) { withAnimation { app.wallet.removeAll { $0.id == id } } }
}

private struct WalletHero: View {
    var totals: WalletTotals
    var m: MarketResponse?
    var loading: Bool
    var body: some View {
        let gold = totals.items.filter { !$0.holding.isCurrency }.compactMap(\.value).reduce(0, +)
        let cash = totals.value - gold
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text(t("قيمة محفظتك النهارده", "Your wallet today")).font(.labelL).foregroundStyle(.white.opacity(0.75))
                if loading && !totals.items.isEmpty { Skeleton(height: 34).frame(width: 160) }
                else { AnimatedMoney(value: totals.value, font: .headline, color: .white) }
                if let g = totals.gain {
                    let up = g >= 0
                    Text((up ? "▲ " : "▼ ") + Fmt.money(abs(g)) + (Fmt.pct(totals.gainPct).map { " (\($0))" } ?? ""))
                        .font(.labelL).foregroundStyle(up ? Color(hex: 0x7CF0C4) : Color(hex: 0xFFA7A0))
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background((up ? PR.signal : PR.danger).opacity(0.22)).clipShape(Capsule())
                    Text(up ? t("مكسبك من وقت ما اشتريت", "Gain since you bought") : t("أقل من اللي دفعته", "Below what you paid"))
                        .font(.labelS).foregroundStyle(.white.opacity(0.65))
                }
                if let m { Text(t("أسعار ", "Rates ") + m.asOf).font(.labelS).foregroundStyle(.white.opacity(0.5)) }
            }
            Spacer()
            if totals.value > 0 {
                ZStack {
                    Donut(shares: [(NSDecimalNumber(decimal: gold).doubleValue, PR.goldB), (NSDecimalNumber(decimal: cash).doubleValue, PR.sky)], thickness: 12)
                    VStack(spacing: 0) {
                        Text(Fmt.number(round(gold * 100 / totals.value, 0)) + t("٪", "%")).font(.titleS).foregroundStyle(.white)
                        Text(t("دهب", "gold")).font(.labelS).foregroundStyle(.white.opacity(0.65))
                    }
                }
                .frame(width: 84, height: 84)
            }
        }
        .padding(20)
        .background(LinearGradient(colors: [PR.hero, PR.heroEnd], startPoint: .topLeading, endPoint: .bottomTrailing))
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .padding(.horizontal, 20).padding(.vertical, 8)
    }
}

func holdingTitle(_ h: Holding) -> String {
    switch h.kind {
    case "gold": return t("دهب عيار \(Fmt.number(h.karat ?? 21))", "\(h.karat ?? 21)K gold")
    case "gold_pound": return t("جنيه دهب", "Gold pound")
    default: return currencyName(h.code ?? "")
    }
}

private func amountLine(_ h: Holding) -> String {
    switch h.kind {
    case "gold": return Fmt.number(h.amount, decimals: h.amount == h.amount.rounded0 ? 0 : 2) + t(" جرام", " g")
    case "gold_pound": return Fmt.number(h.amount) + t(" جنيه", " coins")
    default: return Fmt.number(h.amount, decimals: 2) + " " + (h.code ?? "")
    }
}

private extension Decimal {
    var rounded0: Decimal { var v = self, r = Decimal(); NSDecimalRound(&r, &v, 0, .plain); return r }
}

/// "من ٣ شهور" for a yyyy-MM-dd purchase day.
private func heldFor(_ day: String?) -> String? {
    guard let day, let d = Fmt.parseDay(day) else { return nil }
    let cal = Calendar(identifier: .gregorian)
    let days = cal.dateComponents([.day], from: d, to: Date()).day ?? 0
    let months = cal.dateComponents([.month], from: d, to: Date()).month ?? 0
    if days < 1 { return t("النهارده", "today") }
    if months < 1 { return t("من \(Fmt.number(days)) يوم", "\(days) days ago") }
    if months < 12 { return t("من \(Fmt.number(months)) شهر", "\(months) months ago") }
    return t("من \(Fmt.number(months / 12)) سنة", "\(months / 12) years ago")
}

/// "الدهب" / "تحويش العملات": the side's value today and its gain over what was paid.
private struct WalletSection: View {
    var title: String
    var icon: String
    var bg: Color
    var fg: Color
    var side: WalletTotals
    var onAdd: (() -> Void)?
    var body: some View {
        HStack(spacing: 10) {
            IconTile(icon: icon, bg: bg, fg: fg, size: 34, iconSize: 16)
            VStack(alignment: .leading, spacing: 0) {
                Text(title).font(.titleL).foregroundStyle(PR.ink)
                if !side.items.isEmpty {
                    HStack(spacing: 6) {
                        Text(Fmt.money(side.value)).font(.labelL).foregroundStyle(PR.inkSoft)
                        if let g = side.gain {
                            Text((g >= 0 ? "▲ " : "▼ ") + Fmt.money(abs(g)) + (Fmt.pct(side.gainPct).map { " (\($0))" } ?? ""))
                                .font(.labelM).foregroundStyle(g >= 0 ? PR.signalDeep : PR.danger)
                        }
                    }
                }
            }
            Spacer()
            if let onAdd {
                Button(action: onAdd) {
                    Label(t("ضيف", "Add"), systemImage: Ic.plus).font(.labelL).foregroundStyle(fg)
                        .padding(.horizontal, 12).padding(.vertical, 7).background(bg).clipShape(Capsule())
                }
                .buttonStyle(Pressable())
                .accessibilityIdentifier("wallet.add.\(title)")
            }
        }
        .padding(.leading, 20).padding(.trailing, 12).padding(.top, 18).padding(.bottom, 6)
    }
}

private struct HoldingRow: View {
    var v: Valued
    var m: MarketResponse?
    var onDelete: () -> Void
    var body: some View {
        let h = v.holding
        let gold = !h.isCurrency
        let now = m.flatMap { Wallet.unitPrice(h, $0) }
        Panel(padding: 14) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    IconTile(icon: gold ? Ic.gold : Ic.exchange, bg: gold ? PR.amberWash : PR.skySoft, fg: gold ? PR.amberDeep : PR.sky, size: 42, iconSize: 20)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(holdingTitle(h)).font(.titleS).foregroundStyle(PR.ink)
                        Text([amountLine(h), h.note.isEmpty ? nil : h.note, heldFor(h.boughtOn)].compactMap { $0 }.joined(separator: " · "))
                            .font(.bodyS).foregroundStyle(PR.inkSoft).lineLimit(1)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 0) {
                        PriceText(value: v.value, font: .titleM)
                        if let g = v.gain {
                            Text((g >= 0 ? "▲ " : "▼ ") + Fmt.money(abs(g)) + (Fmt.pct(v.gainPct).map { " · \($0)" } ?? ""))
                                .font(.labelS).foregroundStyle(g >= 0 ? PR.signalDeep : PR.danger)
                        }
                    }
                    Button(action: onDelete) { Image(systemName: Ic.trash).font(.system(size: 15)).foregroundStyle(PR.inkFaint).frame(width: 34, height: 34) }
                        .accessibilityLabel(t("امسح", "Delete"))
                }
                if now != nil || h.unitCost != nil {
                    HStack(alignment: .bottom) {
                        VStack(alignment: .leading, spacing: 0) {
                            Text(t("اشتريت بـ", "Bought at")).font(.labelS).foregroundStyle(PR.inkSoft)
                            Text(h.unitCost.map { Fmt.money(round($0, 2)) } ?? "—").font(.labelL).foregroundStyle(PR.ink)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        VStack(alignment: .leading, spacing: 0) {
                            Text(t("النهارده", "Today")).font(.labelS).foregroundStyle(PR.inkSoft)
                            Text(now.map { Fmt.money(round($0, 2)) } ?? "—").font(.labelL).foregroundStyle(PR.ink)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        Text(h.kind == "gold" ? t("للجرام", "per g") : h.kind == "gold_pound" ? t("للجنيه", "per coin") : t("للوحدة", "per unit"))
                            .font(.labelS).foregroundStyle(PR.inkFaint)
                    }
                    .padding(.horizontal, 12).padding(.vertical, 8).background(PR.paper).clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .padding(.horizontal, 20).padding(.vertical, 5)
    }
}

private struct AddHolding: View {
    var m: MarketResponse?
    var currencyMode: Bool
    var onCancel: () -> Void
    var onAdd: (Holding) -> Void
    @State private var kind = ""
    @State private var karat = 21
    @State private var code = "USD"
    @State private var amount = ""
    @State private var price = ""
    @State private var perUnit = true
    @State private var note = ""
    @State private var boughtOn: Date?
    @State private var picking = false

    var body: some View {
        let k = kind.isEmpty ? (currencyMode ? "currency" : "gold") : kind
        let a = decimalFromInput(amount)
        let p = decimalFromInput(price).flatMap { $0 > 0 ? $0 : nil }
        let cost: Decimal? = (p == nil || a == nil) ? nil : (perUnit ? round(p! * a!, 2) : p)
        let local = MoneyStyle.currency
        let codes = Array((m?.currencies.map(\.code) ?? ["USD", "EUR", "SAR", "AED", "KWD", "GBP"]).filter { $0 != local }.prefix(12))
        let nowRate = m.flatMap { Wallet.unitPrice(Holding(kind: k, karat: k == "gold" ? karat : nil, code: k == "currency" ? code : nil, amount: 1), $0) }
        Panel(background: currencyMode ? PR.skySoft : PR.amberWash, border: currencyMode ? PR.sky : PR.amber) {
            VStack(alignment: .leading, spacing: 10) {
                Text(currencyMode ? t("ضيف لتحويشة العملات", "Add to currency savings") : t("ضيف دهب", "Add gold")).font(.titleM).foregroundStyle(PR.ink)
                if !currencyMode {
                    HStack(spacing: 8) {
                        Chip(t("دهب بالجرام", "Gold (g)"), selected: k == "gold", icon: Ic.gold) { kind = "gold" }
                        Chip(t("جنيه دهب", "Gold pound"), selected: k == "gold_pound") { kind = "gold_pound" }
                    }
                }
                if k == "gold" {
                    HStack(spacing: 8) { ForEach([24, 21, 18], id: \.self) { kk in Chip(t("عيار \(Fmt.number(kk))", "\(kk)K"), selected: karat == kk) { karat = kk } } }
                } else if k == "currency" {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) { ForEach(codes, id: \.self) { cd in Chip(currencyName(cd), selected: code == cd) { code = cd } } }
                    }
                }
                PRField(label: k == "gold" ? t("الوزن بالجرام", "Weight in grams") : k == "gold_pound" ? t("عدد الجنيهات", "Number of coins") : t("المبلغ اللي حوّشته", "Amount you saved"),
                        text: Binding(get: { amount }, set: { amount = digitsOnly($0, max: 10) }), keyboard: .decimalPad, ltr: true)
                HStack(spacing: 8) {
                    Chip(k == "gold" ? t("سعر الجرام", "Price per gram") : k == "gold_pound" ? t("سعر الجنيه", "Price per coin") : t("سعر الشرا للوحدة", "Rate per unit"),
                         selected: perUnit) { perUnit = true }
                    Chip(t("المبلغ الإجمالي", "Total paid"), selected: !perUnit) { perUnit = false }
                }
                PRField(label: perUnit ? t("اشتريت بكام؟", "What did you pay?") : t("دفعت كام إجمالي؟", "Total you paid"),
                        text: Binding(get: { price }, set: { price = digitsOnly($0, max: 12) }), icon: Ic.tag, keyboard: .decimalPad, ltr: true,
                        placeholder: perUnit ? nowRate.map { Fmt.number($0, decimals: 2) } : nil)
                if let cost, perUnit { Text(t("الإجمالي ", "Total ") + Fmt.money(cost)).font(.labelM).foregroundStyle(PR.inkSoft) }
                Button { withAnimation { picking.toggle() } } label: {
                    HStack(spacing: 10) {
                        Image(systemName: Ic.calendar).foregroundStyle(PR.inkSoft)
                        Text(boughtOn.map { t("اشتريتها يوم ", "Bought on ") + $0.formatted(.dateTime.day().month().year().locale(Lang.locale)) }
                             ?? t("اشتريتها إمتى؟ (اختياري)", "When did you buy? (optional)"))
                            .font(.bodyM).foregroundStyle(boughtOn == nil ? PR.inkFaint : PR.ink)
                        Spacer()
                    }
                    .padding(.horizontal, 14).padding(.vertical, 12).background(PR.white).clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
                if picking {
                    DatePicker("", selection: Binding(get: { boughtOn ?? Date() }, set: { boughtOn = $0 }), in: ...Date(), displayedComponents: .date)
                        .datePickerStyle(.graphical).tint(PR.signal).environment(\.locale, Lang.locale)
                }
                PRField(label: currencyMode ? t("ملاحظة (اختياري) — مثلاً: تحويشة الجواز", "Note (optional) — e.g. wedding savings")
                                           : t("ملاحظة (اختياري) — مثلاً: شبكة", "Note (optional) — e.g. wedding set"),
                        text: Binding(get: { note }, set: { note = String($0.prefix(40)) }))
                HStack(spacing: 10) {
                    PRButton(t("إلغاء", "Cancel"), kind: .outline, height: 46, action: onCancel)
                    PRButton(t("ضيف", "Add"), icon: Ic.check, enabled: (a ?? 0) > 0, height: 46) {
                        guard let a else { return }
                        onAdd(Holding(kind: k, karat: k == "gold" ? karat : nil, code: k == "currency" ? code : nil, amount: a, cost: cost,
                                      note: note.trimmingCharacters(in: .whitespaces), boughtOn: boughtOn.map(Self.day)))
                    }
                }
            }
        }
        .padding(.horizontal, 20).padding(.vertical, 8)
    }

    static func day(_ d: Date) -> String {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: d)
    }
}
