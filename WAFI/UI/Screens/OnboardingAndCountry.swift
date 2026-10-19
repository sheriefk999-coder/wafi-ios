import SwiftUI

// MARK: - Onboarding

private struct Page { var titleAr, titleEn, bodyAr, bodyEn: String; var icon: String }

private let pages = [
    Page(titleAr: "كل أسعار بلدك\nفي رادار واحد", titleEn: "Every price in your country\non one radar",
         bodyAr: "بنقارن السعر شامل الشحن والرسوم بين المتاجر، ونقولك مين الأرخص فعلاً دلوقتي.",
         bodyEn: "We compare the full price, shipping and fees included, and show who is really cheapest now.", icon: Ic.search),
    Page(titleAr: "الدهب والعملات\nأول بأول", titleEn: "Gold and currencies\nas they move",
         bodyAr: "سعر جرام الدهب بكل الأعيرة، والجنيه الدهب، والعملات، مع محوّل سريع ومحفظة لدهبك وتحويشتك.",
         bodyEn: "Gold per gram for every karat, the gold pound and currencies, with a converter and a wallet for your gold and savings.", icon: Ic.gold),
    Page(titleAr: "عربيتك الجاية\nوجهازك الجاي", titleEn: "Your next car,\nyour next PC",
         bodyAr: "دوّر على عربيات بالميزانية والسنة، وقولنا ميزانيتك واستخدامك نجمّعلك PC متوافق.",
         bodyEn: "Search cars by budget and year, and tell us your budget and use to get a compatible PC build.", icon: Ic.car),
]

struct OnboardingScreen: View {
    @Environment(AppState.self) private var app
    @Environment(Router.self) private var router
    @State private var page = 0

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                RadarMark(size: 40)
                VStack(alignment: .leading, spacing: 0) {
                    Text("WAFI").font(.wafi(20, .bold)).tracking(2).foregroundStyle(PR.ink)
                    Text(t("اعرف أكتر. ادفع أذكى.", "Know More. Pay Smarter.")).font(.labelS).foregroundStyle(PR.inkSoft)
                }
                Spacer()
                Button(t("تخطي", "Skip")) { app.onboardingDone = true }.font(.labelL).foregroundStyle(PR.inkSoft)
            }
            .padding(.horizontal, 20).padding(.top, 8)
            TabView(selection: $page) {
                ForEach(Array(pages.enumerated()), id: \.offset) { i, p in
                    VStack(spacing: 18) {
                        Spacer()
                        ZStack {
                            RadarScope(blips: [Blip(angle: Double(30 + i * 70), distance: 0.6, color: PR.amber, big: true), Blip(angle: 160, distance: 0.8), Blip(angle: 260, distance: 0.45)])
                            Image(systemName: p.icon).font(.system(size: 34, weight: .medium)).foregroundStyle(PR.signalDeep)
                                .frame(width: 72, height: 72).background(PR.white).clipShape(Circle()).shadow(color: PR.signal.opacity(0.25), radius: 12)
                        }
                        .frame(width: 230, height: 230)
                        Text(t(p.titleAr, p.titleEn)).font(.display).foregroundStyle(PR.ink).multilineTextAlignment(.center)
                        Text(t(p.bodyAr, p.bodyEn)).font(.bodyL).foregroundStyle(PR.inkSoft).multilineTextAlignment(.center).padding(.horizontal, 28)
                        Spacer()
                    }
                    .tag(i)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            HStack(spacing: 6) {
                ForEach(pages.indices, id: \.self) { i in
                    Capsule().fill(i == page ? PR.signal : PR.line).frame(width: i == page ? 22 : 8, height: 8)
                }
            }
            .animation(.snappy, value: page)
            .padding(.bottom, 18)
            VStack(spacing: 10) {
                if page == pages.count - 1 {
                    PRButton(t("إنشاء حساب", "Create account")) { finish(.signUp) }
                    PRButton(t("عندي حساب", "I have an account"), kind: .outline) { finish(.signIn) }
                    PRButton(t("تصفّح كضيف", "Browse as guest"), kind: .ghost, height: 44) { app.onboardingDone = true }
                } else {
                    PRButton(t("التالي", "Next"), icon: Ic.forward) { withAnimation { page += 1 } }
                }
            }
            .padding(.horizontal, 20).padding(.bottom, 16)
        }
        .background(PR.white)
    }

    private func finish(_ r: Route) {
        app.onboardingDone = true
        router.push(r)
    }
}

// MARK: - Country

private let fallbackCountries = Country.known

/// "إنت بتشتري منين؟" — the first-run step, and the screen behind the country chip.
struct CountryPickerScreen: View {
    var firstRun: Bool
    var onDone: () -> Void = {}
    @Environment(AppState.self) private var app
    @Environment(Router.self) private var router
    @State private var chosen = ""
    @State private var loading = true

    var body: some View {
        let items = app.countries.isEmpty ? (loading ? [] : fallbackCountries) : app.countries
        VStack(spacing: 0) {
            if !firstRun { TopBar(title: t("البلد", "Country"), onBack: { router.back() }) }
            ScrollView {
                VStack(spacing: 0) {
                    if firstRun {
                        ZStack {
                            RadarScope(blips: [Blip(angle: 30, distance: 0.55, color: PR.amber, big: true), Blip(angle: 140, distance: 0.8), Blip(angle: 250, distance: 0.4, color: PR.sky)])
                            Text(items.first { $0.code == chosen }?.flag ?? "🌍").font(.system(size: 40))
                        }
                        .frame(width: 150, height: 150).padding(.top, 20)
                        Text(t("إنت بتشتري منين؟", "Where do you shop?")).font(.headline).foregroundStyle(PR.ink).padding(.top, 16)
                    }
                    Text(t("هندوّر لك في متاجر البلد دي بس، والأسعار والدهب والعملات هتبقى بعملتها. تقدر تغيّرها في أي وقت من الإعدادات.",
                           "We'll search that country's stores only, with prices, gold and currencies in its money. Change it any time in Settings."))
                        .font(.bodyM).foregroundStyle(PR.inkSoft).multilineTextAlignment(.center).padding(.horizontal, 24).padding(.vertical, 10)
                    if items.isEmpty { LoadingList(rows: 4).padding(.horizontal, 20) }
                    ForEach(Array(items.enumerated()), id: \.element.code) { i, c in
                        row(c, selected: c.code == chosen).reveal(i)
                    }
                }
            }
            let pick = items.first { $0.code == chosen }
            PRButton(pick.map { t("يلا على \($0.nameAr)", "Go with \($0.nameEn)") } ?? t("اختار بلد", "Pick a country"), icon: Ic.check, enabled: pick != nil) {
                guard let pick else { return }
                if pick != app.country || !app.countryChosen { app.setCountry(pick) }
                if firstRun { onDone() } else { router.back() }
            }
            .padding(20)
        }
        .background(PR.white)
        .onAppear { if chosen.isEmpty { chosen = app.country.code } }
        .task { await app.refreshCountries(); loading = false }
    }

    private func row(_ c: Country, selected: Bool) -> some View {
        Button { withAnimation(.snappy) { chosen = c.code } } label: {
            HStack(spacing: 14) {
                Text(c.flag).font(.system(size: 24)).frame(width: 44, height: 44).background(PR.paper).clipShape(Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(c.name).font(.titleM).foregroundStyle(PR.ink)
                    Text(t("الأسعار بـ\(c.symbolAr)", "Prices in \(c.currency)") + (c.stores > 0 ? t(" · \(Fmt.number(c.stores)) متجر", " · \(c.stores) stores") : ""))
                        .font(.labelS).foregroundStyle(PR.inkSoft)
                }
                Spacer()
                ZStack {
                    Circle().fill(selected ? PR.signal : PR.white).overlay(Circle().stroke(selected ? PR.signal : PR.line, lineWidth: 2))
                    if selected { Image(systemName: Ic.check).font(.system(size: 11, weight: .bold)).foregroundStyle(.white) }
                }
                .frame(width: 24, height: 24)
            }
            .padding(.horizontal, 16).padding(.vertical, 14)
            .background(selected ? PR.signalSoft : PR.white)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(selected ? PR.signal : PR.line, lineWidth: selected ? 2 : 1))
        }
        .buttonStyle(Pressable())
        .padding(.horizontal, 20).padding(.vertical, 5)
    }
}

/// The small "🇸🇦 السعودية" pill on the home header.
struct CountryChip: View {
    var action: () -> Void
    @Environment(AppState.self) private var app
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(app.country.flag).font(.system(size: 14))
                Text(app.country.name).font(.labelM).foregroundStyle(PR.ink)
            }
            .padding(.horizontal, 10).padding(.vertical, 6).background(PR.paper).clipShape(Capsule())
        }
        .buttonStyle(Pressable())
        .accessibilityLabel(t("البلد: ", "Country: ") + app.country.name)
    }
}

// MARK: - PC builder

private struct UseCard { var id, icon, ar, en, subAr, subEn: String }
private let uses = [
    UseCard(id: "gaming", icon: Ic.gamepad, ar: "ألعاب", en: "Gaming", subAr: "أغلب الميزانية لكارت الشاشة", subEn: "Most of the budget on the GPU"),
    UseCard(id: "gaming_stream", icon: Ic.broadcast, ar: "ألعاب + ستريم", en: "Gaming + streaming", subAr: "معالج أقوى عشان الستريم", subEn: "A stronger CPU for streaming"),
    UseCard(id: "creator", icon: Ic.film, ar: "مونتاج وتصميم", en: "Editing & design", subAr: "معالج قوي ورامات كتير", subEn: "Strong CPU and lots of RAM"),
    UseCard(id: "programming", icon: Ic.code, ar: "برمجة", en: "Programming", subAr: "معالج ورامات وتخزين سريع", subEn: "CPU, RAM and fast storage"),
    UseCard(id: "office", icon: Ic.briefcase, ar: "شغل مكتبي", en: "Office", subAr: "هادي وموفّر، من غير كارت شاشة", subEn: "Quiet and efficient, no GPU"),
]

struct PcBuilderScreen: View {
    @Environment(AppState.self) private var app
    @Environment(Router.self) private var router
    @State private var budget: Double = 45_000
    @State private var use = "gaming"
    @State private var result: Load<PcBuild>?

    var body: some View {
        VStack(spacing: 0) {
            TopBar(title: t("جمّع PC", "Build a PC"), subtitle: t("ميزانيتك + استخدامك = تجميعة متوافقة", "Your budget + your use = a compatible build"), onBack: { router.back() })
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Panel(radius: 24) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(t("ميزانيتك", "Your budget")).font(.labelL).foregroundStyle(PR.inkSoft)
                            AnimatedMoney(value: Decimal(budget), font: .display)
                            Slider(value: $budget, in: 10_000...300_000, step: 1_000).tint(PR.signal)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 6) {
                                    ForEach([25_000, 45_000, 75_000, 120_000, 200_000], id: \.self) { v in
                                        Chip(Fmt.compact(Decimal(v)), selected: Int(budget) == v) { budget = Double(v) }
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20).padding(.vertical, 8)
                    Text(t("هتستخدمه في إيه؟", "What's it for?")).font(.titleL).foregroundStyle(PR.ink).padding(.horizontal, 20).padding(.top, 16).padding(.bottom, 10)
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                        ForEach(uses, id: \.id) { u in
                            let sel = u.id == use
                            Panel(padding: 14, background: sel ? PR.signalSoft : PR.white, border: sel ? PR.signal : PR.line, action: { use = u.id }) {
                                VStack(alignment: .leading, spacing: 4) {
                                    IconTile(icon: u.icon, bg: sel ? PR.white : PR.paper, fg: sel ? PR.signalDeep : PR.ink, size: 40, iconSize: 19).padding(.bottom, 6)
                                    Text(t(u.ar, u.en)).font(.titleS).foregroundStyle(PR.ink)
                                    Text(t(u.subAr, u.subEn)).font(.bodyS).foregroundStyle(PR.inkSoft).lineLimit(2, reservesSpace: true)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    PRButton(t("اقترح تجميعة", "Suggest a build"), kind: .dark, icon: Ic.sparkle, loading: result?.isLoading == true) { Task { await build() } }
                        .padding(20)
                    switch result {
                    case nil: EmptyView()
                    case .loading: LoadingList(rows: 4).padding(.horizontal, 20)
                    case .err(let e):
                        EmptyState(icon: Ic.cpu, title: t("مقدرناش نجمّع", "Couldn't build"), bodyText: e.message, action: t("حاول تاني", "Try again")) { Task { await build() } }
                    case .ok(let b): buildBody(b)
                    }
                }
                .padding(.bottom, 32)
            }
        }
        .background(PR.white)
    }

    private func build() async {
        result = .loading
        let r = await load { try await app.api.pcBuild(budget: Decimal(budget), use: use) }
        withAnimation { result = r }
    }

    @ViewBuilder private func buildBody(_ b: PcBuild) -> some View {
        let ratio = b.budget > 0 ? NSDecimalNumber(decimal: b.total / b.budget).doubleValue : 0
        Panel(radius: 24, border: b.withinBudget ? PR.signal : PR.amber) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(t("إجمالي التجميعة", "Build total")).font(.labelL).foregroundStyle(PR.inkSoft)
                        AnimatedMoney(value: b.total, font: .headline)
                    }
                    Spacer()
                    if b.withinBudget { Badge(t("في حدود الميزانية", "Within budget"), .signal, icon: Ic.check) } else { Badge(t("أعلى من الميزانية", "Over budget"), .amber) }
                }
                MeterBar(fraction: ratio, color: b.withinBudget ? PR.signal : PR.amber)
                Text(b.remaining >= 0 ? t("فاضل معاك ", "Left over: ") + Fmt.money(b.remaining) : t("محتاج زيادة ", "Short by ") + Fmt.money(-b.remaining))
                    .font(.bodyS).foregroundStyle(PR.inkSoft)
            }
        }
        .padding(.horizontal, 20).padding(.vertical, 6)
        VStack(alignment: .leading, spacing: 6) {
            ForEach(checks(b.parts), id: \.self) { c in
                HStack(spacing: 8) {
                    Image(systemName: Ic.check).font(.system(size: 11, weight: .bold)).foregroundStyle(PR.signalDeep)
                        .frame(width: 22, height: 22).background(PR.signalSoft).clipShape(Circle())
                    Text(c).font(.bodyM).foregroundStyle(PR.ink)
                }
            }
        }
        .padding(.horizontal, 20).padding(.vertical, 8)
        ForEach(b.parts, id: \.part) { p in
            Panel(padding: 12, action: { router.push(.product(p.productId)) }) {
                HStack(spacing: 12) {
                    IconTile(icon: partIcon(p.part), size: 48, iconSize: 22)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(partLabel(p.part)).font(.labelM).foregroundStyle(PR.inkSoft)
                        Text(Lang.isArabic ? p.titleAr : p.titleEn).font(.titleS).foregroundStyle(PR.ink).lineLimit(1)
                        let line = partLine(p.specs)
                        if !line.isEmpty { Text(line).font(.bodyS).foregroundStyle(PR.inkSoft).lineLimit(1) }
                    }
                    Spacer(minLength: 4)
                    PriceText(value: p.price, font: .titleS)
                }
            }
            .padding(.horizontal, 20).padding(.vertical, 5)
        }
        if !b.missing.isEmpty {
            Panel(background: PR.amberSoft, border: PR.amberSoft) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(t("قطع مش لاقيينها في الكتالوج", "Parts we couldn't find")).font(.titleS).foregroundStyle(PR.amberDeep)
                    Text(b.missing.map(partLabel).joined(separator: "، ")).font(.bodyM).foregroundStyle(PR.ink)
                    HStack(spacing: 6) {
                        ForEach(b.missing.prefix(3), id: \.self) { part in
                            Button(t("دوّر على ", "Find ") + partLabel(part)) { router.push(.search(category: "pc_parts", query: "", part: part)) }
                                .font(.labelM).foregroundStyle(PR.ink).padding(.horizontal, 10).padding(.vertical, 6).background(PR.white).clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }
                }
            }
            .padding(.horizontal, 20).padding(.vertical, 8)
        }
        if !b.parts.isEmpty {
            PRButton(t("أضف التجميعة كلها للسلة", "Add the whole build to basket"), icon: Ic.basket) {
                for p in b.parts { app.addToBasket(ProductSummary(id: p.productId, brand: "", model: "", category: "pc_parts", titleAr: p.titleAr, titleEn: p.titleEn, bestTotal: p.price)) }
                router.select(.basket)
            }
            .padding(20)
        }
    }

    /// The checks the server applied, shown from the chosen parts' own specs.
    private func checks(_ parts: [PcPart]) -> [String] {
        let m = Dictionary(parts.map { ($0.part, $0) }, uniquingKeysWith: { a, _ in a })
        var out: [String] = []
        if let cpu = m["cpu"], m["motherboard"] != nil { out.append(t("السوكت متوافق", "Socket matches") + " · " + (cpu.specs.str("socket") ?? "?")) }
        if let ram = m["ram"], m["motherboard"] != nil { out.append(t("نوع الرامات متوافق", "Memory type matches") + " · " + (ram.specs.str("ram_type") ?? "?")) }
        if let psu = m["psu"] {
            let cpuTdp: Int = m["cpu"]?.specs.int("tdp") ?? 65
            let gpuTdp: Int = m["gpu"]?.specs.int("tdp") ?? 0
            let need: Int = (cpuTdp + gpuTdp) * 3 / 2 + 100
            let watts: Int = psu.specs.int("watts") ?? 0
            let label: String = t("الباور كفاية", "PSU has headroom")
            out.append(label + " · \(watts)W ≥ \(need)W")
        }
        return out
    }
}
