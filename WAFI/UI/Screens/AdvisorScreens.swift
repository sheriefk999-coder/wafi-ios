import SwiftUI

// MARK: - Hub

struct AdvisorHubScreen: View {
    @Environment(Router.self) private var router
    @State private var float = false
    private struct Tile: Identifiable { var id: String { title }; var icon: String; var bg: Color; var fg: Color; var title: String; var sub: String; var go: Route }

    var body: some View {
        let tiles = [
            Tile(icon: Ic.gold, bg: PR.amberSoft, fg: PR.amberDeep, title: t("الدهب", "Gold"), sub: t("السعر فين من الشهر، وإيه اللي بيحرّكه", "Where the price sits and what moves it"), go: .goldAdvisor),
            Tile(icon: Ic.gpu, bg: PR.signalSoft, fg: PR.signalDeep, title: t("كمبيوتر", "PC"), sub: t("ألعاب، ستريم، شغل: نقسّم الميزانية صح", "Gaming, streaming, work: split the budget right"), go: .pcAdvisor),
            Tile(icon: Ic.phone, bg: PR.skySoft, fg: PR.sky, title: t("موبايل", "Phone"), sub: t("كاميرا ولا بطارية ولا ألعاب؟", "Camera, battery or games?"), go: .picks("phones")),
            Tile(icon: Ic.car, bg: Color(0xFDEDE7, 0x3A1C10), fg: Color(0xC2521F, 0xFF9466), title: t("عربية", "Car"), sub: t("لوحدك ولا عيلة، مدينة ولا سفر", "Solo or family, city or highway"), go: .picks("cars")),
            Tile(icon: Ic.shirt, bg: Color(0xFCE8F3, 0x3A1029), fg: Color(0xC2287A, 0xFF7CC0), title: t("هدوم", "Clothes"), sub: t("شكل حلو ولا دفا؟ ومقاسك إيه", "Look or warmth? And your size"), go: .picks("fashion")),
            Tile(icon: Ic.monitor, bg: Color(0xE7F0FD, 0x10243A), fg: Color(0x1F5FC2, 0x66A3FF), title: t("أجهزة", "Home"), sub: t("تلفزيون، تكييف، أجهزة منزلية", "TVs, ACs and appliances"), go: .picks("home")),
            Tile(icon: Ic.card, bg: Color(0xEAF6EE, 0x10291A), fg: Color(0x1C7A43, 0x66CF95), title: t("تقسيط", "Installment"), sub: t("القسط الشهري وإجمالي التكلفة لأي سعر", "Monthly cost and total for any price"), go: .installment),
            Tile(icon: Ic.gold, bg: PR.amberSoft, fg: PR.amberDeep, title: t("حاسبة الدهب", "Gold calc"), sub: t("سعر قطعة الدهب وخطة ادخار", "A piece's price and a savings plan"), go: .goldCalc),
        ]
        Screen(title: t("المستشار", "Advisor")) {
            VStack(spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        Badge(t("جديد", "New"), .amber, icon: Ic.sparkle)
                        Text(t("قولّي محتاج إيه،\nوأنا أقولك تشتري إيه وليه", "Tell me what you need,\nI'll tell you what to buy and why")).font(.headlineS).foregroundStyle(.white)
                        Text(t("كل ترشيح معاه السبب، من مواصفات وأسعار حقيقية.", "Every pick comes with its reason, from real specs and prices.")).font(.bodyS).foregroundStyle(.white.opacity(0.8))
                    }
                    Spacer(minLength: 0)
                    WafiMark().frame(width: 92, height: 92).offset(y: float ? -4 : 4)
                        .animation(Motion.reduced ? nil : .easeInOut(duration: 2).repeatForever(autoreverses: true), value: float)
                }
                .padding(22)
                .background(LinearGradient(colors: [PR.hero, PR.heroEnd], startPoint: .topLeading, endPoint: .bottomTrailing))
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .padding(.horizontal, 20).padding(.bottom, 10)
                ForEach(Array(tiles.enumerated()), id: \.element.id) { i, tile in
                    Panel(radius: 22, action: { router.push(tile.go) }) {
                        HStack(spacing: 14) {
                            IconTile(icon: tile.icon, bg: tile.bg, fg: tile.fg, size: 54, iconSize: 25)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(tile.title).font(.titleM).foregroundStyle(PR.ink)
                                Text(tile.sub).font(.bodyS).foregroundStyle(PR.inkSoft)
                            }
                            Spacer()
                            Image(systemName: Ic.forward).foregroundStyle(PR.inkFaint)
                        }
                    }
                    .padding(.horizontal, 20).padding(.vertical, 6).reveal(i)
                }
                Panel(radius: 22, background: PR.paper, border: PR.paper, action: { router.push(.assistant) }) {
                    HStack(spacing: 12) {
                        IconTile(icon: Ic.sparkle, bg: PR.white, fg: PR.ink, size: 44, iconSize: 20)
                        VStack(alignment: .leading, spacing: 0) {
                            Text(t("عندك سؤال تاني؟", "Something else?")).font(.titleS).foregroundStyle(PR.ink)
                            Text(t("اكتب للمساعد", "Ask the assistant")).font(.bodyS).foregroundStyle(PR.inkSoft)
                        }
                    }
                }
                .padding(.horizontal, 20).padding(.vertical, 10)
            }
        }
        .onAppear { float = true }
    }
}

// MARK: - Gold (facts only, never buy/sell advice)

struct GoldAdvisorScreen: View {
    @Environment(AppState.self) private var app
    @Environment(Router.self) private var router
    @State private var state: Load<GoldAnalysis> = .loading

    var body: some View {
        Screen(title: t("تحليل الدهب", "Gold analysis"), subtitle: t("عيار ٢١ · آخر ٣٠ و٩٠ يوم", "21K · last 30 and 90 days")) {
            switch state {
            case .loading: LoadingList(rows: 5).padding(20)
            case .err(let e):
                EmptyState(icon: Ic.gold, title: t("مقدرناش نجيب التحليل", "Couldn't load the analysis"), bodyText: e.message, action: t("حاول تاني", "Try again")) {
                    Task { await reload() }
                }
                .padding(.top, 40)
            case .ok(let a) where !a.ready:
                VStack(spacing: 12) {
                    IconTile(icon: Ic.chart, bg: PR.amberSoft, fg: PR.amberDeep, size: 72, iconSize: 32)
                    Text(t("بنجمع تاريخ الأسعار", "Collecting price history")).font(.headlineS).foregroundStyle(PR.ink)
                    Text(t("التحليل محتاج \(Fmt.number(a.requiredDays)) أيام على الأقل. عندنا \(Fmt.number(a.days)) لحد دلوقتي.",
                           "The analysis needs at least \(a.requiredDays) days. We have \(a.days) so far."))
                        .font(.bodyM).foregroundStyle(PR.inkSoft).multilineTextAlignment(.center)
                    MeterBar(fraction: Double(a.days) / Double(max(a.requiredDays, 1)), color: PR.amber).frame(width: 220)
                }
                .padding(24).padding(.top, 40)
            case .ok(let a): GoldBody(a: a)
            }
        }
        .task { await reload() }
    }

    private func reload() async { state = await load { try await app.api.goldAdvice() } }
}

private struct GoldBody: View {
    var a: GoldAnalysis
    @Environment(Router.self) private var router
    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                Text(t("جرام عيار ٢١", "21K per gram")).font(.labelL).foregroundStyle(PR.ink.opacity(0.7))
                AnimatedMoney(value: a.gold21.map { Decimal($0) }, font: .display)
                HStack(spacing: 8) { changePill(t("أسبوع", "7d"), a.change7d); changePill(t("شهر", "30d"), a.change30d) }
                AreaChart(values: a.series.map(\.gold21), color: PR.amberDeep).frame(height: 120).padding(.top, 8)
                HStack {
                    Text(a.series.first?.day ?? "").font(.labelS).foregroundStyle(PR.ink.opacity(0.6))
                    Spacer()
                    Text(a.series.last?.day ?? "").font(.labelS).foregroundStyle(PR.ink.opacity(0.6))
                }
            }
            .padding(20)
            .background(LinearGradient(colors: [PR.goldA, PR.goldB, PR.goldC], startPoint: .topLeading, endPoint: .bottomTrailing))
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            .padding(.horizontal, 20)

            Panel(radius: 22) {
                VStack(spacing: 8) {
                    Text(t("السعر فين من آخر ٣٠ يوم؟", "Where is the price in the last 30 days?")).font(.titleM).foregroundStyle(PR.ink)
                    RangeGauge(value: a.position30 ?? 0.5).frame(width: 220, height: 110)
                    let (label, tone): (String, Color) = a.position == "near_high" ? (t("قريب من أعلى سعر", "Near the high"), PR.danger)
                        : a.position == "near_low" ? (t("قريب من أقل سعر", "Near the low"), PR.signalDeep) : (t("في النص", "Mid-range"), PR.amberDeep)
                    Text(label).font(.headlineS).foregroundStyle(tone)
                    HStack {
                        VStack(alignment: .leading, spacing: 0) {
                            Text(t("أقل", "Low")).font(.labelS).foregroundStyle(PR.inkSoft)
                            Text(a.low30.map { Fmt.money(k21($0)) } ?? "").font(.titleS).foregroundStyle(PR.signalDeep)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 0) {
                            Text(t("أعلى", "High")).font(.labelS).foregroundStyle(PR.inkSoft)
                            Text(a.high30.map { Fmt.money(k21($0)) } ?? "").font(.titleS).foregroundStyle(PR.danger)
                        }
                    }
                    Text(t("(أرقام عيار ٢٤ محوّلة لـ ٢١)", "(24K range converted to 21K)")).font(.labelS).foregroundStyle(PR.inkFaint)
                }
            }
            .padding(.horizontal, 20).padding(.vertical, 12).reveal(1)

            HStack(spacing: 10) {
                stat(a.trend == "rising" ? "chart.line.uptrend.xyaxis" : a.trend == "falling" ? "chart.line.downtrend.xyaxis" : "water.waves",
                     t("الاتجاه", "Trend"), a.trend == "rising" ? t("طالع", "Rising") : a.trend == "falling" ? t("نازل", "Falling") : t("ثابت تقريباً", "Sideways"),
                     a.trend == "rising" ? PR.danger : a.trend == "falling" ? PR.signalDeep : PR.inkSoft)
                stat(Ic.gauge, t("التقلب", "Volatility"), a.volatility == "high" ? t("عالي", "High") : a.volatility == "low" ? t("هادي", "Low") : t("متوسط", "Medium"),
                     a.volatility == "high" ? PR.danger : a.volatility == "low" ? PR.signalDeep : PR.amberDeep)
            }
            .padding(.horizontal, 20).reveal(2)

            if let usd = a.usdChange30d, let oz = a.ounceChange30d {
                Panel(radius: 22) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(t("إيه اللي حرّك السعر الشهر ده؟", "What moved the price this month?")).font(.titleM).foregroundStyle(PR.ink)
                        driver(t("الدولار قدام الجنيه", "Dollar vs pound"), usd, Ic.exchange)
                        driver(t("سعر الأوقية عالمياً", "World ounce price"), oz, Ic.globe)
                    }
                }
                .padding(.horizontal, 20).padding(.vertical, 12).reveal(3)
            }
            Panel(radius: 22) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(t("الخلاصة", "In short")).font(.titleM).foregroundStyle(PR.ink)
                    ForEach(Lang.isArabic ? a.factsAr : a.factsEn, id: \.self) { bullet($0, Ic.chart, PR.sky) }
                }
            }
            .padding(.horizontal, 20).padding(.vertical, 6).reveal(4)
            Panel(radius: 22, background: PR.signalSoft, border: PR.signalSoft) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(t("نصايح وإنت بتشتري", "Tips when you buy")).font(.titleM).foregroundStyle(PR.signalDeep)
                    ForEach(Lang.isArabic ? a.tipsAr : a.tipsEn, id: \.self) { bullet($0, Ic.check, PR.signalDeep) }
                }
            }
            .padding(.horizontal, 20).padding(.vertical, 6).reveal(5)
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: Ic.info).font(.system(size: 13)).foregroundStyle(PR.inkFaint)
                Text(Lang.isArabic ? a.disclaimerAr : a.disclaimerEn).font(.bodyS).foregroundStyle(PR.inkFaint)
            }
            .padding(.horizontal, 24).padding(.vertical, 12)
            PRButton(t("أسعار الدهب والعملات دلوقتي", "Live gold & currency prices"), kind: .outline, icon: Ic.gold) { router.select(.market) }
                .padding(.horizontal, 20)
            AdSlot(kind: .banner, placement: "advisor").padding(.top, 10)
        }
    }

    private func k21(_ v24: Double) -> Decimal { var d = Decimal(v24 * 21 / 24), r = Decimal(); NSDecimalRound(&r, &d, 0, .plain); return r }

    @ViewBuilder private func changePill(_ label: String, _ pct: Double?) -> some View {
        if let pct {
            HStack(spacing: 4) {
                Text(label).font(.labelM).foregroundStyle(PR.ink.opacity(0.7))
                Text((pct >= 0 ? "▲ " : "▼ ") + Fmt.number(abs(pct), decimals: 1) + t("٪", "%")).font(.labelL).foregroundStyle(pct >= 0 ? PR.danger : PR.signalDeep)
            }
            .padding(.horizontal, 10).padding(.vertical, 4).background(PR.white.opacity(0.6)).clipShape(Capsule())
        }
    }

    private func stat(_ icon: String, _ label: String, _ value: String, _ color: Color) -> some View {
        Panel(radius: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Image(systemName: icon).font(.system(size: 22)).foregroundStyle(color)
                Text(label).font(.labelM).foregroundStyle(PR.inkSoft)
                Text(value).font(.titleL).foregroundStyle(color)
            }
        }
    }

    private func driver(_ label: String, _ pct: Double, _ icon: String) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 13)).foregroundStyle(PR.inkSoft)
                Text(label).font(.bodyM).foregroundStyle(PR.ink)
                Spacer()
                Text((pct >= 0 ? "+" : "−") + Fmt.number(abs(pct), decimals: 1) + t("٪", "%")).font(.titleS).foregroundStyle(pct >= 0 ? PR.danger : PR.signalDeep)
            }
            MeterBar(fraction: abs(pct) / 10, color: pct >= 0 ? PR.danger : PR.signal)
        }
    }

    private func bullet(_ text: String, _ icon: String, _ color: Color) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon).font(.system(size: 11, weight: .bold)).foregroundStyle(color)
                .frame(width: 22, height: 22).background(color.opacity(0.14)).clipShape(Circle())
            Text(text).font(.bodyM).foregroundStyle(PR.ink)
        }
    }
}

// MARK: - Shared question widgets

struct Opt: Identifiable { var id: String; var icon: String?; var ar: String; var en: String; var subAr = ""; var subEn = ""
    var label: String { t(ar, en) } }

private struct Question<C: View>: View {
    var index: Int
    var title: String
    @ViewBuilder var content: () -> C
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Text(Fmt.number(index + 1)).font(.labelM).foregroundStyle(.white).frame(width: 24, height: 24).background(PR.hero).clipShape(Circle())
                Text(title).font(.titleM).foregroundStyle(PR.ink)
            }
            content()
        }
        .padding(.horizontal, 20).padding(.vertical, 10)
        .reveal(index)
    }
}

private struct OptionCards: View {
    var options: [Opt]
    @Binding var selected: String
    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
            ForEach(options) { o in
                let sel = o.id == selected
                Panel(padding: 12, radius: 18, background: sel ? PR.signalSoft : PR.white, border: sel ? PR.signal : PR.line, action: { selected = o.id }) {
                    VStack(alignment: .leading, spacing: 6) {
                        if let icon = o.icon { IconTile(icon: icon, bg: sel ? PR.white : PR.paper, fg: sel ? PR.signalDeep : PR.ink, size: 36, iconSize: 17) }
                        Text(o.label).font(.titleS).foregroundStyle(PR.ink)
                        if !o.subAr.isEmpty { Text(t(o.subAr, o.subEn)).font(.bodyS).foregroundStyle(PR.inkSoft) }
                    }
                    .frame(maxWidth: .infinity, minHeight: 70, alignment: .topLeading)
                }
            }
        }
    }
}

private struct OptChips: View {
    var options: [Opt]
    @Binding var selected: String
    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(options) { o in Chip(o.label, selected: o.id == selected, icon: o.icon) { selected = o.id } }
        }
    }
}

/// Budget on a log scale (so 5,000 and 2,000,000 both get room), with quick presets.
private struct BudgetPicker: View {
    var min: Int
    var max: Int
    @Binding var value: Int
    var presets: [Int]
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            AnimatedMoney(value: Decimal(value), font: .headline)
            Slider(value: Binding(get: { pos(value) }, set: { value = from($0) }), in: 0...1).tint(PR.signal)
            ChipRow { ForEach(presets, id: \.self) { p in Chip(Fmt.compact(Decimal(p)), selected: p == value) { value = p } } }.padding(.horizontal, -20)
        }
    }
    private func pos(_ v: Int) -> Double { (log(Double(v)) - log(Double(min))) / (log(Double(max)) - log(Double(min))) }
    private func from(_ p: Double) -> Int {
        let raw = exp(log(Double(min)) + p * (log(Double(max)) - log(Double(min))))
        let step: Double = raw < 20_000 ? 500 : raw < 200_000 ? 1_000 : raw < 1_000_000 ? 10_000 : 50_000
        return Swift.min(Swift.max(Int((raw / step).rounded() * step), min), max)
    }
}

private struct Analyzing: View {
    var body: some View {
        VStack(spacing: 14) {
            RadarScope(blips: [Blip(angle: 30, distance: 0.5, color: PR.amber, big: true), Blip(angle: 140, distance: 0.8), Blip(angle: 250, distance: 0.35)])
                .frame(width: 150, height: 150)
            Text(t("بقارن المواصفات والأسعار…", "Comparing specs and prices…")).font(.titleM).foregroundStyle(PR.inkSoft)
        }
        .frame(maxWidth: .infinity).padding(.top, 80)
    }
}

private func partColor(_ part: String) -> Color {
    switch part {
    case "gpu": return Color(hex: 0x1463F3)
    case "cpu": return Color(hex: 0x2E9BFF)
    case "motherboard": return Color(hex: 0x6A4CE0)
    case "ram": return Color(hex: 0xF2A516)
    case "storage": return Color(hex: 0x0E7C9E)
    case "psu": return Color(hex: 0xD64545)
    default: return Color(hex: 0x94A3B8)
    }
}

/// The advisor's error: a quota wall when the free picks ran out, else a message with a way back.
private struct AdvisorError: View {
    var e: APIError
    var icon: String
    var title: String
    var back: () -> Void
    var body: some View {
        if e.isQuota { QuotaWall(error: e).padding(.top, 20) }
        else { EmptyState(icon: icon, title: title, bodyText: e.message, action: t("رجوع", "Back"), onAction: back).padding(.top, 40) }
    }
}

// MARK: - PC advisor

private let pcUses = [
    Opt(id: "gaming", icon: Ic.gamepad, ar: "ألعاب", en: "Gaming", subAr: "كارت الشاشة أولاً", subEn: "GPU first"),
    Opt(id: "gaming_stream", icon: Ic.broadcast, ar: "ألعاب + ستريم", en: "Gaming + streaming", subAr: "معالج أقوى للستريم", subEn: "Stronger CPU for streaming"),
    Opt(id: "creator", icon: Ic.film, ar: "مونتاج وتصميم", en: "Editing & design", subAr: "معالج ورامات", subEn: "CPU and RAM"),
    Opt(id: "programming", icon: Ic.code, ar: "برمجة", en: "Programming", subAr: "معالج وتخزين سريع", subEn: "CPU and fast storage"),
    Opt(id: "office", icon: Ic.briefcase, ar: "شغل مكتبي", en: "Office", subAr: "هادي وموفّر", subEn: "Quiet and cheap"),
]
private let resolutions = [Opt(id: "1080p", icon: Ic.monitor, ar: "1080p", en: "1080p"), Opt(id: "1440p", icon: Ic.monitor, ar: "2K · 1440p", en: "1440p"),
                           Opt(id: "4k", icon: Ic.monitor, ar: "4K", en: "4K")]

struct PcAdvisorScreen: View {
    @Environment(AppState.self) private var app
    @Environment(Router.self) private var router
    @State private var state: Load<PcBuild>?
    @State private var use = "gaming_stream"
    @State private var res = "1080p"
    @State private var budget = 60_000

    var body: some View {
        let games = use == "gaming" || use == "gaming_stream"
        VStack(spacing: 0) {
            TopBar(title: t("مستشار الكمبيوتر", "PC advisor"), onBack: { if state != nil { state = nil } else { router.back() } })
            ScrollView {
                switch state {
                case nil:
                    VStack(spacing: 0) {
                        Question(index: 0, title: t("هتستخدمه في إيه؟", "What will you use it for?")) { OptionCards(options: pcUses, selected: $use) }
                        if games { Question(index: 1, title: t("هتلعب على شاشة إيه؟", "What screen will you play on?")) { OptChips(options: resolutions, selected: $res) } }
                        Question(index: games ? 2 : 1, title: t("ميزانيتك كام؟", "What's your budget?")) {
                            BudgetPicker(min: 15_000, max: 400_000, value: $budget, presets: [25_000, 40_000, 60_000, 90_000, 150_000])
                        }
                        PRButton(t("حلّل ورشّحلي", "Analyse and suggest"), icon: Ic.sparkle) {
                            Task {
                                state = .loading
                                let r = await load { try await app.api.pcAdvice(budget: Decimal(budget), use: use, resolution: games ? res : "1080p") }
                                withAnimation { state = r }
                            }
                        }
                        .padding(20)
                    }
                case .loading: Analyzing()
                case .err(let e): AdvisorError(e: e, icon: Ic.cpu, title: t("مقدرناش نحلّل", "Couldn't analyse")) { state = nil }
                case .ok(let b): PcAdviceBody(a: b)
                }
            }
        }
        .background(PR.white)
    }
}

private struct PcAdviceBody: View {
    var a: PcBuild
    @Environment(AppState.self) private var app
    @Environment(Router.self) private var router
    var body: some View {
        VStack(spacing: 0) {
            Panel(radius: 24) {
                HStack(spacing: 14) {
                    ZStack {
                        Donut(shares: a.split.map { (Double($0.sharePct), partColor($0.part)) })
                        VStack(spacing: 0) {
                            Text(t("الإجمالي", "Total")).font(.labelS).foregroundStyle(PR.inkSoft)
                            Text(Fmt.compact(a.total)).font(.titleS).foregroundStyle(PR.ink)
                        }
                    }
                    .frame(width: 132, height: 132)
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(a.split.prefix(7), id: \.part) { sl in
                            HStack(spacing: 6) {
                                Circle().fill(partColor(sl.part)).frame(width: 10, height: 10)
                                Text(partLabel(sl.part)).font(.bodyS).foregroundStyle(PR.ink)
                                Spacer()
                                Text(Fmt.number(sl.sharePct) + t("٪", "%")).font(.labelM).foregroundStyle(PR.inkSoft)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 20).padding(.vertical, 6)
            HStack(spacing: 10) {
                Image(systemName: a.focus == "gpu" ? Ic.gpu : Ic.cpu).foregroundStyle(PR.signalDeep)
                Text((a.focus == "gpu" ? t("ركّزنا الميزانية على كارت الشاشة", "We put the budget into the graphics card") : t("ركّزنا الميزانية على المعالج", "We put the budget into the processor"))
                     + (a.focus == "gpu" ? " (\(a.resolution ?? "1080p"))" : "")).font(.titleS).foregroundStyle(PR.signalDeep)
                Spacer(minLength: 0)
            }
            .padding(14).background(PR.signalSoft).clipShape(RoundedRectangle(cornerRadius: 16)).padding(.horizontal, 20).padding(.vertical, 6)
            if let ua = a.usedAdvice { PcUsedAdviceCard(ua: ua) }
            ForEach(Array(a.parts.enumerated()), id: \.element.productId) { i, p in
                Panel(radius: 20, action: { router.push(.product(p.productId)) }) {
                  VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: partIcon(p.part)).font(.system(size: 20)).foregroundStyle(partColor(p.part))
                            .frame(width: 44, height: 44).background(partColor(p.part).opacity(0.14)).clipShape(RoundedRectangle(cornerRadius: 14))
                        VStack(alignment: .leading, spacing: 3) {
                            Text(partLabel(p.part).uppercased()).font(.labelM.weight(.bold)).foregroundStyle(partColor(p.part))
                            Text(Lang.isArabic ? p.titleAr : p.titleEn).font(.titleS).foregroundStyle(PR.ink).lineLimit(2)
                            Text(Lang.isArabic ? p.reasonAr : p.reasonEn).font(.bodyS).foregroundStyle(PR.signalDeep)
                            if let u = p.used { UsedTagLine(u: u) }
                        }
                        Spacer(minLength: 4)
                        VStack(alignment: .trailing, spacing: 2) {
                            PriceText(value: p.price, font: .titleS)
                            if p.pricedBy == "reference" { Text(t("تقريبي", "approx.")).font(.labelS).foregroundStyle(PR.amberDeep) }
                        }
                    }
                    if let nu = p.newUsed { NewUsedBlock(nu: nu) }
                  }
                }
                .padding(.horizontal, 20).padding(.vertical, 5).reveal(i)
            }
            ApproxPartsNote(n: a.approximateParts)
            if !a.missing.isEmpty {
                Text(t("مش لاقيين في الكتالوج: ", "Not in the catalog yet: ") + a.missing.map(partLabel).joined(separator: "، "))
                    .font(.bodyS).foregroundStyle(PR.amberDeep).padding(.horizontal, 24).padding(.vertical, 6)
            }
            Panel(background: PR.paper, border: PR.paper) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        VStack(alignment: .leading, spacing: 0) {
                            Text(t("الإجمالي", "Total")).font(.labelM).foregroundStyle(PR.inkSoft)
                            AnimatedMoney(value: a.total, font: .headlineS)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 0) {
                            Text(!a.withinBudget ? t("فوق الميزانية بـ", "Over budget by")
                                 : a.maxed ? t("ميزانيتك تكفي وزيادة", "Budget to spare")
                                 : t("فاضل من ميزانيتك", "Left of your budget")).font(.labelM).foregroundStyle(PR.inkSoft)
                            Text(Fmt.money(abs(a.remaining))).font(.titleM).foregroundStyle(a.withinBudget ? PR.signalDeep : PR.danger)
                        }
                    }
                    if a.maxed && a.withinBudget {
                        Text(t("دي أقوى تجميعة متاحة في الكتالوج — مش محتاج تصرف الميزانية كلها؛ الباقي بيفضل معاك.",
                               "This is the strongest build in the catalog — you don't need to spend the whole budget; the rest stays with you."))
                            .font(.bodyS).foregroundStyle(PR.signalDeep)
                    }
                }
            }
            .padding(.horizontal, 20).padding(.vertical, 8)
            PRButton(t("ضيف الكل للسلة", "Add all to basket"), icon: Ic.basket) {
                for p in a.parts { app.addToBasket(ProductSummary(id: p.productId, brand: "", model: "", category: "pc_parts", titleAr: p.titleAr, titleEn: p.titleEn, bestTotal: p.price)) }
                router.select(.basket)
            }
            .padding(.horizontal, 20)
            AdSlot(kind: .banner, placement: "advisor").padding(.top, 10)
        }
        .padding(.bottom, 28)
    }
}

// MARK: - Phones / cars / fashion

struct PicksAdvisorScreen: View {
    var kind: String
    @Environment(AppState.self) private var app
    @Environment(Router.self) private var router
    @State private var state: Load<AdviceResponse>?
    // phones
    @State private var cat = "phones"
    @State private var priority = "value"
    @State private var phoneBudget = 15_000
    // cars
    @State private var family = "couple"
    @State private var usage = "mixed"
    @State private var economy = true
    @State private var condition = "any"
    @State private var carBudget = 1_000_000
    // fashion
    @State private var gender = "any"
    @State private var need = "both"
    @State private var occasion = "casual"
    @State private var size = "any"
    @State private var clothesBudget = 2_500
    // home electronics
    @State private var homeCat = "tv"
    @State private var homePriority = "balanced"
    @State private var homeKind = "refrigerator"
    @State private var homeRoom = 20
    @State private var homeBudget = 25_000

    var body: some View {
        let title = kind == "cars" ? t("مستشار العربيات", "Car advisor") : kind == "fashion" ? t("مستشار الهدوم", "Clothes advisor")
            : kind == "home" ? t("مستشار الأجهزة", "Home advisor") : t("مستشار الموبايلات", "Phone advisor")
        VStack(spacing: 0) {
            TopBar(title: title, onBack: { if state != nil { state = nil } else { router.back() } })
            ScrollView {
                switch state {
                case nil:
                    VStack(spacing: 0) {
                        switch kind {
                        case "cars": cars
                        case "fashion": fashion
                        case "home": home
                        default: phones
                        }
                        PRButton(t("رشّحلي", "Suggest"), icon: Ic.sparkle) { Task { await run() } }.padding(20)
                    }
                case .loading: Analyzing()
                case .err(let e): AdvisorError(e: e, icon: Ic.sparkle, title: t("مقدرناش نرشّح", "Couldn't suggest")) { state = nil }
                case .ok(let r): PicksBody(r: r) { state = nil }
                }
            }
        }
        .background(PR.white)
    }

    @ViewBuilder private var phones: some View {
        Question(index: 0, title: t("بتدوّر على إيه؟", "What are you after?")) {
            OptChips(options: [Opt(id: "phones", icon: Ic.phone, ar: "موبايل", en: "Phone"), Opt(id: "tablets", icon: Ic.tablet, ar: "تابلت", en: "Tablet"),
                               Opt(id: "laptops", icon: Ic.laptop, ar: "لابتوب", en: "Laptop")], selected: $cat)
        }
        Question(index: 1, title: t("أهم حاجة عندك؟", "What matters most?")) {
            OptionCards(options: [
                Opt(id: "camera", icon: Ic.camera, ar: "الكاميرا", en: "Camera", subAr: "صور وفيديو", subEn: "Photos and video"),
                Opt(id: "battery", icon: Ic.battery, ar: "البطارية", en: "Battery", subAr: "يعيش اليوم كله", subEn: "Lasts all day"),
                Opt(id: "gaming", icon: Ic.gamepad, ar: "الألعاب والأداء", en: "Games & speed", subAr: "معالج قوي", subEn: "A fast chip"),
                Opt(id: "value", icon: Ic.tag, ar: "أحسن قيمة", en: "Best value", subAr: "أكتر حاجة بأقل فلوس", subEn: "Most for the money"),
            ], selected: $priority)
        }
        Question(index: 2, title: t("ميزانيتك لحد كام؟", "Up to what budget?")) {
            BudgetPicker(min: 3_000, max: 150_000, value: $phoneBudget, presets: [8_000, 15_000, 25_000, 40_000, 70_000])
        }
    }

    @ViewBuilder private var cars: some View {
        Question(index: 0, title: t("مين هيركب معاك؟", "Who rides with you?")) {
            OptionCards(options: [Opt(id: "single", icon: Ic.user, ar: "لوحدي", en: "Just me"), Opt(id: "couple", icon: Ic.heart, ar: "اتنين", en: "Two of us"),
                                  Opt(id: "family", icon: Ic.family, ar: "عيلة", en: "Family", subAr: "مساحة وكراسي", subEn: "Space and seats")], selected: $family)
        }
        Question(index: 1, title: t("هتمشي بيها فين أكتر؟", "Where will you drive most?")) {
            OptChips(options: [Opt(id: "city", icon: Ic.store, ar: "في المدينة", en: "City"), Opt(id: "highway", icon: Ic.truck, ar: "سفر وطرق سريعة", en: "Highway"),
                               Opt(id: "mixed", icon: Ic.compass, ar: "الاتنين", en: "Both")], selected: $usage)
        }
        Question(index: 2, title: t("التوفير في البنزين مهم؟", "Is saving fuel important?")) {
            Toggle(isOn: $economy) {
                Label(t("أيوه، عايز عربية موفّرة", "Yes, I want an economical car"), systemImage: Ic.leaf).font(.bodyM).foregroundStyle(PR.ink)
            }
            .tint(PR.signal).padding(14).background(PR.paper).clipShape(RoundedRectangle(cornerRadius: 16))
        }
        Question(index: 3, title: t("زيرو ولا مستعملة؟", "New or used?")) {
            OptChips(options: [Opt(id: "any", ar: "مش فارقة", en: "Either"), Opt(id: "new", ar: "زيرو", en: "New"), Opt(id: "used", ar: "مستعملة", en: "Used")], selected: $condition)
        }
        Question(index: 4, title: t("ميزانيتك؟", "Your budget?")) {
            BudgetPicker(min: 150_000, max: 6_000_000, value: $carBudget, presets: [500_000, 800_000, 1_200_000, 2_000_000, 3_500_000])
        }
    }

    @ViewBuilder private var fashion: some View {
        Question(index: 0, title: t("لمين؟", "For whom?")) {
            OptChips(options: [Opt(id: "men", ar: "رجالي", en: "Men"), Opt(id: "women", ar: "حريمي", en: "Women"), Opt(id: "kids", ar: "أطفال", en: "Kids"),
                               Opt(id: "any", ar: "أي حاجة", en: "Any")], selected: $gender)
        }
        Question(index: 1, title: t("محتاج إيه أكتر؟", "What do you need more?")) {
            OptionCards(options: [Opt(id: "warmth", icon: Ic.snow, ar: "حاجة تدفّي", en: "Warmth", subAr: "للبرد والشتا", subEn: "For cold days"),
                                  Opt(id: "style", icon: Ic.sparkle, ar: "شكل حلو", en: "Style", subAr: "شيك ومظبوط", subEn: "Sharp and neat"),
                                  Opt(id: "both", icon: Ic.check, ar: "الاتنين", en: "Both", subAr: "دافي وشيك", subEn: "Warm and sharp")], selected: $need)
        }
        Question(index: 2, title: t("رايح فين؟", "What's the occasion?")) {
            OptChips(options: [Opt(id: "casual", ar: "خروج وكاجوال", en: "Casual"), Opt(id: "formal", ar: "شغل ورسمي", en: "Formal"), Opt(id: "sport", ar: "رياضة", en: "Sport")], selected: $occasion)
        }
        Question(index: 3, title: t("مقاسك؟", "Your size?")) {
            OptChips(options: [Opt(id: "any", ar: "أي مقاس", en: "Any")] + ["S", "M", "L", "XL", "XXL"].map { Opt(id: $0, ar: $0, en: $0) }, selected: $size)
        }
        Question(index: 4, title: t("ميزانيتك للقطعة؟", "Budget per piece?")) {
            BudgetPicker(min: 300, max: 20_000, value: $clothesBudget, presets: [800, 1_500, 2_500, 4_000, 7_000])
        }
    }

    @ViewBuilder private var home: some View {
        Question(index: 0, title: t("بتدوّر على إيه؟", "What are you after?")) {
            OptChips(options: [Opt(id: "tv", icon: Ic.monitor, ar: "تلفزيون", en: "TV"), Opt(id: "ac", icon: Ic.snow, ar: "تكييف", en: "AC"),
                               Opt(id: "appliances", icon: Ic.store, ar: "أجهزة منزلية", en: "Appliance")], selected: $homeCat)
        }
        if homeCat == "appliances" {
            Question(index: 1, title: t("أي جهاز؟", "Which appliance?")) {
                OptChips(options: [Opt(id: "refrigerator", ar: "تلاجة", en: "Fridge"), Opt(id: "washer", ar: "غسالة", en: "Washer"),
                                   Opt(id: "deep_freezer", ar: "ديب فريزر", en: "Freezer"), Opt(id: "cooker", ar: "بوتاجاز", en: "Cooker"),
                                   Opt(id: "water_heater", ar: "سخان", en: "Heater"), Opt(id: "microwave", ar: "ميكروويف", en: "Microwave"),
                                   Opt(id: "dishwasher", ar: "غسالة أطباق", en: "Dishwasher")], selected: $homeKind)
            }
        }
        if homeCat == "ac" {
            Question(index: 1, title: t("مساحة الأوضة بالمتر؟", "Room size (m²)?")) {
                BudgetPicker(min: 6, max: 60, value: $homeRoom, presets: [12, 18, 25, 35, 50])
            }
        }
        Question(index: 2, title: t("الأهم؟", "What matters most?")) {
            OptionCards(options: [Opt(id: "balanced", icon: Ic.check, ar: "متوازن", en: "Balanced", subAr: "جودة وسعر", subEn: "Quality and price"),
                                  Opt(id: "quality", icon: Ic.crown, ar: "الأعلى جودة", en: "Best quality", subAr: "أحسن حاجة", subEn: "The best there is"),
                                  Opt(id: "value", icon: Ic.tag, ar: "أوفر", en: "Best value", subAr: "أقل سعر مناسب", subEn: "Lowest sensible price")], selected: $homePriority)
        }
        Question(index: 3, title: t("ميزانيتك؟", "Your budget?")) {
            BudgetPicker(min: 3_000, max: 120_000, value: $homeBudget, presets: [10_000, 20_000, 35_000, 60_000, 90_000])
        }
    }

    private func run() async {
        state = .loading
        let api = app.api
        let r: Load<AdviceResponse>
        switch kind {
        case "cars": r = await load { try await api.carsAdvice(budget: Decimal(carBudget), family: family, usage: usage, economy: economy, condition: condition) }
        case "fashion": r = await load { try await api.fashionAdvice(budget: Decimal(clothesBudget), need: need, occasion: occasion, gender: gender, size: size == "any" ? nil : size) }
        case "home": r = await load { try await api.homeAdvice(budget: Decimal(homeBudget), category: homeCat, priority: homePriority,
                                                                kind: homeCat == "appliances" ? homeKind : nil,
                                                                roomM2: homeCat == "ac" ? Double(homeRoom) : nil) }
        default: r = await load { try await api.phonesAdvice(budget: Decimal(phoneBudget), priority: priority, category: cat) }
        }
        withAnimation { state = r }
    }
}

private struct PicksBody: View {
    var r: AdviceResponse
    var again: () -> Void
    @Environment(Router.self) private var router
    var body: some View {
        if r.picks.isEmpty {
            EmptyState(icon: Ic.search, title: t("ملقيناش حاجة مناسبة", "Nothing suitable yet"),
                       bodyText: t("الكتالوج لسه مفيهوش منتجات بالمواصفات دي. جرّب ميزانية تانية أو اختيارات أوسع.", "The catalog has nothing with these needs yet. Try another budget or wider choices."),
                       action: t("غيّر الاختيارات", "Change answers"), onAction: again)
                .padding(.top, 40)
        } else {
            VStack(alignment: .leading, spacing: 0) {
                Text(t("قارنّا \(Fmt.number(r.considered)) منتج، ودول الأنسب ليك:", "We compared \(r.considered) products; these fit you best:"))
                    .font(.bodyM).foregroundStyle(PR.inkSoft).padding(.horizontal, 20).padding(.vertical, 6)
                if r.notes.contains("over_budget") {
                    Label(t("مفيش حاجة جوه الميزانية، فدول أقرب اختيارات فوقها.", "Nothing fits the budget, so these are the closest above it."), systemImage: Ic.info)
                        .font(.bodyS).foregroundStyle(PR.amberDeep).padding(12).frame(maxWidth: .infinity, alignment: .leading)
                        .background(PR.amberSoft).clipShape(RoundedRectangle(cornerRadius: 14)).padding(.horizontal, 20).padding(.vertical, 6)
                }
                if let bv = r.budgetView { BudgetViewCard(bv: bv) }
                if let ua = r.usedAdvice { UsedLeadCard(ua: ua) }
                if let rs = r.running { RunningSummaryCard(rs: rs) }
                ForEach(Array(r.picks.enumerated()), id: \.element.id) { i, p in
                    pickCard(p, rank: i + 1).reveal(i)
                }
                PRButton(t("غيّر الاختيارات", "Change answers"), kind: .outline, action: again).padding(.horizontal, 20).padding(.top, 6)
                AdSlot(kind: .banner, placement: "advisor").padding(.top, 10)
            }
            .padding(.bottom, 28)
        }
    }

    private func pickCard(_ p: Pick, rank: Int) -> some View {
        let best = rank == 1
        return Panel(radius: 22, background: best ? PR.amberWash : PR.white, border: best ? PR.amber : PR.line, action: { router.push(.product(p.id)) }) {
            VStack(alignment: .leading, spacing: 10) {
                if best { Badge(t("الاختيار الأنسب", "Best match"), .amber, icon: Ic.crown) }
                HStack(spacing: 12) {
                    ProductImage(category: p.category, imageURL: p.imageUrl, size: 58, radius: 16).frame(width: 58, height: 58)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(Lang.isArabic ? p.titleAr : p.titleEn).font(.titleS).foregroundStyle(PR.ink).lineLimit(2)
                        PriceText(value: p.price, font: .titleM, color: best ? PR.amberDeep : PR.ink)
                    }
                    Spacer()
                    Text(Fmt.number(rank)).font(.titleM).foregroundStyle(best ? Color(hex: 0x0B1633) : PR.inkSoft)
                        .frame(width: 46, height: 46)
                        .background(best ? AnyShapeStyle(LinearGradient(colors: [PR.goldB, PR.amber], startPoint: .top, endPoint: .bottom)) : AnyShapeStyle(PR.paper))
                        .clipShape(Circle()).overlay(Circle().stroke(best ? PR.amber : PR.line, lineWidth: 2))
                }
                ForEach(Lang.isArabic ? p.reasonsAr : p.reasonsEn, id: \.self) { reason in
                    HStack(spacing: 8) {
                        Image(systemName: Ic.check).font(.system(size: 12, weight: .bold)).foregroundStyle(PR.signalDeep)
                        Text(reason).font(.bodyS).foregroundStyle(PR.ink)
                    }
                }
                PickValueLines(p: p)
                if let nu = p.newUsed { NewUsedBlock(nu: nu) }
            }
        }
        .padding(.horizontal, 20).padding(.vertical, 6)
    }
}
