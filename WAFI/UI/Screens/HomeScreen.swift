import SwiftUI

struct HomeData {
    var products: [ProductSummary]
    var stores: [Store]
    var market: MarketResponse?
    var deals: [Deal]
}

struct HomeScreen: View {
    @Environment(AppState.self) private var app
    @Environment(Router.self) private var router
    @State private var state: Load<HomeData> = .loading
    @State private var hiddenAnnouncement: String?

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                header
                searchPill
                banners
                if app.config.features.assistant { assistantCard }
                switch state {
                case .loading: skeleton
                case .err(let e):
                    EmptyState(icon: Ic.server, title: t("الرادار مش واصل للخادم", "The radar can't reach the server"), bodyText: e.message,
                               action: t("حاول تاني", "Try again")) { Task { await reload() } }
                case .ok(let d): content(d)
                }
            }
            .padding(.bottom, 24)
        }
        .background(PR.white)
        .refreshable { await app.refreshConfig(); await reload() }
        .task { if state.value == nil { await reload() } }
    }

    private func reload() async {
        async let products = app.api.products(ProductFilter(limit: 40))
        async let stores = app.api.stores()
        async let market = app.api.market()
        async let deals = app.api.deals(limit: 12)
        do {
            let p = try await products
            state = .ok(HomeData(products: p, stores: (try? await stores) ?? [], market: try? await market, deals: (try? await deals) ?? []))
        } catch let e as APIError {
            if state.value == nil { state = .err(e) }
        } catch {
            if state.value == nil { state = .err(.network(nil)) }
        }
    }

    // MARK: pieces

    private var greeting: String {
        let h = Calendar.current.component(.hour, from: Date())
        return h < 12 ? t("صباح الخير", "Good morning") : h < 18 ? t("يومك سعيد", "Good afternoon") : t("مساء الخير", "Good evening")
    }

    private var header: some View {
        HStack(spacing: 12) {
            RadarMark(size: 42)
            VStack(alignment: .leading, spacing: 0) {
                Text(greeting + (app.user?.name.flatMap { $0.split(separator: " ").first.map { "، \($0)" } } ?? ""))
                    .font(.bodyS).foregroundStyle(PR.inkSoft)
                Text("WAFI").font(.wafi(19, .bold)).tracking(2).foregroundStyle(PR.ink)
            }
            Spacer()
            CountryChip { router.push(.country) }
            Button { router.push(app.isSignedIn ? .alerts : .signIn) } label: {
                Image(systemName: Ic.bell).font(.system(size: 19)).foregroundStyle(PR.ink).frame(width: 44, height: 44)
            }
            .accessibilityLabel(t("التنبيهات", "Alerts"))
        }
        .padding(.leading, 20).padding(.trailing, 12).padding(.top, 12).padding(.bottom, 4)
    }

    private var searchPill: some View {
        Button { router.select(.search) } label: {
            HStack(spacing: 10) {
                Image(systemName: Ic.search).foregroundStyle(PR.inkSoft)
                Text(t("دوّر على موبايل، لابتوب، عربية…", "Search phones, laptops, cars…")).font(.bodyL).foregroundStyle(PR.inkFaint)
                Spacer()
                Image(systemName: Ic.filter).font(.system(size: 15)).foregroundStyle(PR.ink).frame(width: 34, height: 34).background(PR.white)
                    .clipShape(RoundedRectangle(cornerRadius: 11))
            }
            .padding(.horizontal, 16).frame(height: 54)
            .background(PR.paper).clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(Pressable())
        .padding(.horizontal, 20).padding(.vertical, 10)
    }

    @ViewBuilder private var banners: some View {
        if let ann = app.config.announcement, hiddenAnnouncement != ann.ar {
            let (bg, fg): (Color, Color) = ann.tone == "success" ? (PR.signalSoft, PR.signalDeep) : ann.tone == "warning" ? (PR.amberSoft, PR.amberDeep) : (PR.skySoft, PR.sky)
            HStack(spacing: 10) {
                Image(systemName: Ic.bell).foregroundStyle(fg)
                Text(Lang.isArabic ? ann.ar : ann.en).font(.bodyM).foregroundStyle(fg).frame(maxWidth: .infinity, alignment: .leading)
                Button { hiddenAnnouncement = ann.ar } label: { Image(systemName: Ic.close).font(.system(size: 13)).foregroundStyle(fg).frame(width: 36, height: 36) }
            }
            .padding(.leading, 14).padding(.vertical, 6)
            .background(bg).clipShape(RoundedRectangle(cornerRadius: 16))
            .onTapGesture { openURL(ann.url) }
            .padding(.horizontal, 20).padding(.vertical, 6)
        }
        if app.config.latestVersionCode > AppInfo.build && app.config.minVersionCode <= AppInfo.build {
            Button { openURL(app.config.storeUrl) } label: {
                HStack(spacing: 10) {
                    Image(systemName: Ic.refresh).foregroundStyle(PR.signalDeep)
                    Text(t("فيه نسخة جديدة من التطبيق، حدّث عشان المميزات الجديدة", "A new version is available; update for the latest features"))
                        .font(.bodyM).foregroundStyle(PR.ink).frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(14).background(PR.paper).clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(Pressable()).padding(.horizontal, 20).padding(.vertical, 6)
        }
    }

    private var assistantCard: some View {
        Button { router.push(.assistant) } label: {
            HStack(spacing: 12) {
                Image(systemName: Ic.sparkle).font(.system(size: 19)).foregroundStyle(PR.amber).frame(width: 40, height: 40)
                    .background(PR.hero).clipShape(RoundedRectangle(cornerRadius: 13))
                VStack(alignment: .leading, spacing: 0) {
                    Text(t("اسأل المساعد", "Ask the assistant")).font(.titleS).foregroundStyle(PR.ink)
                    Text(t("«عايز موبايل في حدود ٢٠ ألف»", "“A phone around 20K”")).font(.bodyS).foregroundStyle(PR.inkSoft)
                }
                Spacer()
                Image(systemName: Ic.forward).foregroundStyle(PR.ink)
            }
            .padding(14)
            .background(LinearGradient(colors: [PR.signalSoft, PR.skySoft], startPoint: .leading, endPoint: .trailing))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(Pressable()).padding(.horizontal, 20).padding(.vertical, 4)
    }

    private var skeleton: some View {
        VStack(spacing: 14) {
            Skeleton(height: 190)
            Skeleton(height: 46)
            HStack(spacing: 10) { Skeleton(height: 110); Skeleton(height: 110) }
            LoadingList(rows: 3)
        }
        .padding(20)
    }

    @ViewBuilder private func content(_ d: HomeData) -> some View {
        RadarHero(d: d)
        if let m = d.market { MarketTicker(m: m) { router.select(.market) } }
        if app.config.features.advisor { AdvisorBanner { router.push(.advisor) } }
        if !d.deals.isEmpty {
            SectionHeader(title: t("نزلت أسعارها", "Price drops"), action: t("الكل", "All")) { router.push(.deals) }
                .padding(.leading, 20).padding(.trailing, 12).padding(.top, 18).padding(.bottom, 10)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) { ForEach(d.deals) { deal in DealTile(deal: deal) { router.push(.product(deal.id)) } } }.padding(.horizontal, 20)
            }
        }
        Tools()
        AdSlot(kind: .banner, placement: "home")
        Categories()
        let confirmed = d.products.filter { $0.bestTotal != nil }.sorted { ($0.bestTotal ?? 0) < ($1.bestTotal ?? 0) }
        if !confirmed.isEmpty {
            SectionHeader(title: t("أسعار مؤكدة شامل الشحن", "Confirmed prices, shipping included"), action: t("الكل", "All")) { router.select(.search) }
                .padding(.leading, 20).padding(.trailing, 12).padding(.top, 22).padding(.bottom, 10)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(Array(confirmed.prefix(10))) { p in ProductTile(p: p) { router.push(.product(p.id)) } }
                }
                .padding(.horizontal, 20)
            }
        }
        SectionHeader(title: t("وصل حديثاً", "Just added")).padding(.horizontal, 20).padding(.top, 24).padding(.bottom, 10)
        if d.products.isEmpty {
            EmptyState(icon: Ic.search, title: t("لسه مفيش منتجات", "No products yet"),
                       bodyText: t("أول ما المتاجر تتضاف هتلاقي أسعارها هنا.", "As stores are added their prices appear here."))
        }
        ForEach(Array(d.products.prefix(12).enumerated()), id: \.element.id) { i, p in
            ProductRow(p: p) { router.push(.product(p.id)) }.padding(.horizontal, 20).padding(.vertical, 5).reveal(i)
            if i == 5 { AdSlot(kind: .inline, placement: "home") }
        }
    }
}

// MARK: - Home pieces

/// The signature panel: every store is a blip; the amber blip is the lowest confirmed price.
private struct RadarHero: View {
    var d: HomeData
    @State private var pulse = false
    var body: some View {
        var blips = d.stores.enumerated().map { i, _ in Blip(angle: Double((i * 137 + 20) % 360), distance: 0.35 + Double(i % 3) * 0.22) }
        if d.products.contains(where: { $0.bestTotal != nil }) { blips.append(Blip(angle: 48, distance: 0.62, color: PR.amber, big: true)) }
        return HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Circle().fill(PR.signal).frame(width: 8, height: 8).opacity(pulse ? 1 : 0.3)
                    Text(t("الرادار شغّال", "Radar live")).font(.labelM).foregroundStyle(PR.signalDeep)
                }
                .padding(.bottom, 8)
                stat(d.stores.count, t("متجر بنراقبه", "stores watched"))
                stat(d.products.count, t("منتج", "products"))
                stat(d.products.reduce(0) { $0 + $1.offers }, t("عرض سعر", "price offers"))
            }
            Spacer()
            RadarScope(blips: blips).frame(width: 150, height: 150)
        }
        .padding(18)
        .background(PR.white)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).stroke(PR.line))
        .shadow(color: PR.signal.opacity(0.18), radius: 14, y: 6)
        .padding(.horizontal, 20).padding(.vertical, 8)
        .onAppear { if !Motion.reduced { withAnimation(.easeInOut(duration: 0.9).repeatForever()) { pulse = true } } else { pulse = true } }
    }
    private func stat(_ n: Int, _ label: String) -> some View {
        HStack(alignment: .lastTextBaseline, spacing: 6) {
            Text(Fmt.number(n)).font(.headline).foregroundStyle(PR.ink).contentTransition(.numericText())
            Text(label).font(.bodyS).foregroundStyle(PR.inkSoft)
        }
    }
}

/// Live rates; tapping opens the gold & currency page.
struct MarketTicker: View {
    var m: MarketResponse
    var action: () -> Void
    var body: some View {
        let k21 = m.gold.karats.first { $0.karat == 21 }
        var items: [(String, String, Decimal?)] = []
        if let k21 { items.append((t("دهب ٢١", "Gold 21K"), Fmt.money(k21.egpPerGram), k21.changePct)) }
        items.append((t("الجنيه الدهب", "Gold pound"), Fmt.money(m.gold.goldPoundEgp), m.gold.changePct))
        for c in m.currencies.prefix(6) { items.append((c.code, Fmt.money(c.egp), c.changePct)) }
        return Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: Ic.gold).foregroundStyle(PR.amberDeep)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 22) {
                        ForEach(Array(items.enumerated()), id: \.offset) { _, it in
                            HStack(spacing: 6) {
                                Text(it.0).font(.labelM).foregroundStyle(PR.amberDeep)
                                Text(it.1).font(.labelL).foregroundStyle(PR.ink)
                                if let p = it.2, p != 0 {
                                    Text((p > 0 ? "▲ " : "▼ ") + (Fmt.pct(p) ?? "")).font(.labelS).foregroundStyle(p > 0 ? PR.signalDeep : PR.danger)
                                }
                            }
                        }
                    }
                }
                .allowsHitTesting(false)
            }
            .padding(.horizontal, 12).padding(.vertical, 12)
            .background(PR.amberSoft).clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(Pressable()).padding(.horizontal, 20).padding(.vertical, 8)
    }
}

/// Entry to the advisor: a gradient card with the domains floating.
private struct AdvisorBanner: View {
    var action: () -> Void
    @State private var float = false
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                Label(t("المستشار", "The advisor"), systemImage: Ic.compass).font(.labelL).foregroundStyle(PR.amber)
                Text(t("مش عارف تشتري إيه؟ قولّي محتاج إيه وأنا أرشّحلك وأقولك ليه.", "Not sure what to buy? Tell me what you need; I'll pick and explain why."))
                    .font(.titleM).foregroundStyle(PR.onAccent).multilineTextAlignment(.leading)
                HStack(spacing: 8) {
                    ForEach(Array([Ic.gold, Ic.gpu, Ic.phone, Ic.car, Ic.shirt, Ic.music].enumerated()), id: \.offset) { i, icon in
                        Image(systemName: icon).font(.system(size: 17)).foregroundStyle(PR.onAccent).frame(width: 40, height: 40)
                            .background(.white.opacity(0.14)).clipShape(RoundedRectangle(cornerRadius: 13))
                            .offset(y: float ? -3 : 3)
                            .animation(Motion.reduced ? nil : .easeInOut(duration: 1.1 + Double(i) * 0.13).repeatForever(autoreverses: true), value: float)
                    }
                }
                .padding(.top, 4)
            }
            .padding(18).frame(maxWidth: .infinity, alignment: .leading)
            .background(LinearGradient(colors: [PR.hero, PR.heroEnd], startPoint: .topLeading, endPoint: .bottomTrailing))
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .buttonStyle(Pressable()).padding(.horizontal, 20).padding(.vertical, 10)
        .onAppear { float = true }
    }
}

private struct Tools: View {
    @Environment(Router.self) private var router
    struct Tool: Identifiable {
        var icon: String
        var bg: Color
        var fg: Color
        var title: String
        var sub: String
        var go: Route? = nil
        var tab: Tab? = nil
        var id: String { title }
    }
    var body: some View {
        let tools = [
            Tool(icon: Ic.car, bg: Color(0xFDEDE7, 0x3A1C10), fg: Color(0xC2521F, 0xFF9466), title: t("دوّر على عربية", "Find a car"), sub: t("بالميزانية والسنة", "By budget and year"), go: .cars),
            Tool(icon: Ic.cpu, bg: PR.signalSoft, fg: PR.signalDeep, title: t("جمّع PC", "Build a PC"), sub: t("قولنا ميزانيتك", "Tell us your budget"), go: .pc),
            Tool(icon: Ic.gold, bg: PR.amberSoft, fg: PR.amberDeep, title: t("الدهب والعملات", "Gold & FX"), sub: t("أسعار ومحوّل", "Rates and converter"), tab: .market),
            Tool(icon: Ic.basket, bg: PR.skySoft, fg: PR.sky, title: t("السلة الذكية", "Smart basket"), sub: t("أرخص خطة شراء", "Cheapest buying plan"), tab: .basket),
            Tool(icon: Ic.wallet, bg: PR.amberWash, fg: PR.amberDeep, title: t("محفظتي", "My wallet"), sub: t("دهبك وتحويشة العملات", "Your gold and savings"), go: .wallet),
            Tool(icon: Ic.bell, bg: PR.signalSoft, fg: PR.signalDeep, title: t("نبّهني بالسعر", "Rate alerts"), sub: t("الدهب والدولار · Pro", "Gold and dollar · Pro"), go: .marketAlerts),
        ]
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
            ForEach(tools) { tool in
                Panel(padding: 14, action: { if let r = tool.go { router.push(r) } else if let tb = tool.tab { router.select(tb) } }) {
                    VStack(alignment: .leading, spacing: 2) {
                        IconTile(icon: tool.icon, bg: tool.bg, fg: tool.fg, size: 42, iconSize: 19).padding(.bottom, 8)
                        Text(tool.title).font(.titleS).foregroundStyle(PR.ink)
                        Text(tool.sub).font(.bodyS).foregroundStyle(PR.inkSoft).lineLimit(1)
                    }
                }
            }
        }
        .padding(.horizontal, 20).padding(.vertical, 10)
    }
}

private struct Categories: View {
    @Environment(Router.self) private var router
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: t("تصفّح الأقسام", "Browse")).padding(.horizontal, 20).padding(.top, 18)
            ChipRow {
                ForEach([Category.phones, .laptops, .audio, .tablets, .cars, .pcParts, .fashion, .music]) { c in
                    Chip(categoryLabel(c), selected: false, icon: categoryIcon(c)) {
                        if c == .cars { router.push(.cars) } else { router.push(.search(category: c.rawValue, query: "", part: nil)) }
                    }
                }
            }
        }
    }
}

struct DealTile: View {
    var deal: Deal
    var action: () -> Void
    var body: some View {
        let p = deal.summary
        Panel(padding: 12, action: action) {
            VStack(alignment: .leading, spacing: 0) {
                ZStack(alignment: .topLeading) {
                    ProductImage(category: p.category, part: p.specs.str("part"), imageURL: p.imageUrl, size: 110, radius: 14)
                        .frame(maxWidth: .infinity).frame(height: 110)
                    DropBadge(deal: deal).padding(6)
                }
                Text(p.title).font(.wafi(15, .semibold)).foregroundStyle(PR.ink).lineLimit(2).frame(height: 42, alignment: .top).padding(.top, 10)
                PriceText(value: deal.currentMin, font: .titleM, color: PR.signalDeep).padding(.top, 6)
                Text(Fmt.money(deal.median)).font(.labelM).strikethrough().foregroundStyle(PR.inkFaint)
            }
        }
        .frame(width: 176)
    }
}

struct DropBadge: View {
    var deal: Deal
    var body: some View {
        Badge("▼ " + (Fmt.pct(deal.dropPct) ?? ""), .signal)
    }
}
