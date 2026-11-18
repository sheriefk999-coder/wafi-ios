import SwiftUI

// The live engine, on screen. Everything here is a price a shop's own page showed a moment ago: one card per
// product, every shop that sells it underneath, and the price history that says whether now is a good time.
// A product with no current price is not shown at all — there are no estimates in this part of the app.

// MARK: - the card

/// A product card: picture, name, rating, "from <price>", how far it has come down, and a heart.
struct LiveProductCard: View {
    var group: LiveGroup
    var watched: Bool
    var onOpen: () -> Void
    var onWatch: () -> Void

    var body: some View {
        Panel(padding: 12, action: onOpen) {
            HStack(alignment: .top, spacing: 12) {
                LiveImage(url: group.image, size: 88)
                VStack(alignment: .leading, spacing: 3) {
                    Text(group.title).font(.titleS).foregroundStyle(PR.ink)
                        .lineLimit(2).multilineTextAlignment(.leading)
                    HStack(spacing: 6) {
                        if let r = group.rating { Stars(rating: r, count: group.ratingCount) }
                        if group.isUsed { Badge(t("مستعمل", "Used"), .amber) }
                        if group.stale { Badge(t("محتاج تأكيد", "Needs confirming"), .neutral) }
                    }
                    Spacer(minLength: 0)
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        VStack(alignment: .leading, spacing: 0) {
                            Text(t("يبدأ من", "From")).font(.labelS).foregroundStyle(PR.inkSoft)
                            PriceText(value: group.priceFrom, font: .titleM)
                        }
                        if let d = group.dropPct { TrendPill(pct: Decimal(d)) }
                        Spacer(minLength: 0)
                    }
                    Text(storesLine).font(.labelS).foregroundStyle(PR.inkSoft).lineLimit(1)
                }
                .frame(minHeight: 88, alignment: .top)
                Button(action: onWatch) {
                    Image(systemName: watched ? Ic.heartFill : Ic.heart)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(watched ? PR.danger : PR.inkFaint)
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(Pressable())
                .accessibilityLabel(watched ? t("إلغاء المتابعة", "Stop watching") : t("تابع السعر", "Watch the price"))
            }
        }
    }

    private var storesLine: String {
        let n = Fmt.number(group.stores)
        let shops = group.stores == 1 ? t("متجر واحد", "1 shop") : t("\(n) متاجر", "\(n) shops")
        guard let best = group.bestStore else { return shops }
        return shops + "  ·  " + t("الأرخص \(best)", "cheapest at \(best)")
    }
}

/// A product photo from a shop, on white so every logo and background looks the same.
struct LiveImage: View {
    var url: String?
    var size: CGFloat
    var radius: CGFloat?

    init(url: String?, size: CGFloat, radius: CGFloat? = nil) {
        self.url = url; self.size = size; self.radius = radius
    }

    var body: some View {
        ZStack {
            PR.paper
            if let s = url, s.hasPrefix("https://"), let u = URL(string: s) {
                AsyncImage(url: u) { phase in
                    if let img = phase.image {
                        img.resizable().scaledToFit().padding(size * 0.06)
                    } else if phase.error != nil {
                        Image(systemName: Ic.other).font(.system(size: size * 0.3)).foregroundStyle(PR.inkFaint)
                    } else {
                        ProgressView().tint(PR.inkFaint)
                    }
                }
            } else {
                Image(systemName: Ic.other).font(.system(size: size * 0.3)).foregroundStyle(PR.inkFaint)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: radius ?? size * 0.18, style: .continuous))
    }
}

struct Stars: View {
    var rating: Double
    var count: Int?
    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "star.fill").font(.system(size: 10)).foregroundStyle(PR.amber)
            Text(String(format: "%.1f", rating)).font(.labelS).foregroundStyle(PR.ink)
            if let c = count, c > 0 { Text("(\(Fmt.number(c)))").font(.labelS).foregroundStyle(PR.inkFaint) }
        }
    }
}

// MARK: - search results

@MainActor
@Observable
final class LiveSearchModel {
    var query = ""
    var groups: [LiveGroup] = []
    var coverage: LiveCoverage?
    var understood: LiveUnderstood?
    var notice: String?
    var pending = false
    var loading = false
    var error: APIError?
    var watched: Set<String> = []
    private var task: Task<Void, Never>?

    /// Runs the search, then — while the server is still asking the slower shops — asks once more for the
    /// fuller answer. The `pending` flag on the response is what says more is coming.
    func run(_ api: API, query q: String) {
        let text = q.trimmingCharacters(in: .whitespaces)
        guard text.count >= 2 else { return }
        task?.cancel()
        query = text
        loading = groups.isEmpty
        error = nil
        task = Task { [weak self] in
            guard let self else { return }
            do {
                var res = try await api.liveSearch(text)
                if Task.isCancelled { return }
                apply(res)
                var tries = 0
                while res.pending, tries < 4, !Task.isCancelled {
                    tries += 1
                    try? await Task.sleep(for: .seconds(3))
                    if Task.isCancelled { return }
                    res = try await api.liveSearch(text)
                    apply(res)
                }
            } catch let e as APIError {
                loading = false
                pending = false
                error = e
            } catch {
                loading = false
                pending = false
            }
        }
    }

    func loadWatches(_ api: API) {
        Task { [weak self] in
            if let items = try? await api.liveWatches() { self?.watched = Set(items.map(\.key)) }
        }
    }

    /// The heart on a card: watch this product's price, or stop watching it.
    func toggleWatch(_ api: API, _ g: LiveGroup) {
        let on = !watched.contains(g.key)
        if on { watched.insert(g.key) } else { watched.remove(g.key) }
        Task { [weak self] in
            do {
                if on {
                    try await api.liveWatch(key: g.key, query: self?.query ?? "", title: g.title,
                                            image: g.image, target: nil, price: g.priceFrom)
                } else {
                    try await api.liveUnwatch(key: g.key)
                }
            } catch {
                if on { self?.watched.remove(g.key) } else { self?.watched.insert(g.key) }
            }
        }
    }

    private func apply(_ res: LiveSearchResponse) {
        groups = res.groups
        coverage = res.coverage
        understood = res.understood
        notice = res.notes
        pending = res.pending
        loading = false
    }
}

/// Live results for one search: the products, then an honest line about what was covered.
struct LiveResultsView: View {
    var query: String
    @Environment(AppState.self) private var app
    @Environment(Router.self) private var router
    @State private var model = LiveSearchModel()

    var body: some View {
        VStack(spacing: 12) {
            if model.loading && model.groups.isEmpty {
                LoadingList(rows: 4)
            } else if let e = model.error, model.groups.isEmpty {
                LiveErrorView(error: e, signIn: { router.push(.signIn) }) { model.run(app.api, query: query) }
            } else if model.groups.isEmpty {
                EmptyState(icon: Ic.search,
                           title: t("مفيش منتج بسعر حالي", "No product with a live price"),
                           bodyText: t("مفيش متجر عارض سعر للحاجة دي دلوقتي. جرّب اسم أقرب للموديل.",
                                       "No shop is showing a price for this right now. Try the model's exact name."))
            } else {
                if model.pending {
                    HStack(spacing: 8) {
                        ProgressView().tint(PR.signal).scaleEffect(0.8)
                        Text(t("بندوّر في متاجر تانية…", "Still asking more shops…")).font(.labelM).foregroundStyle(PR.inkSoft)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                ForEach(Array(model.groups.enumerated()), id: \.element.key) { i, g in
                    LiveProductCard(group: g, watched: model.watched.contains(g.key),
                                    onOpen: { router.push(.liveProduct(key: g.key, query: model.query)) },
                                    onWatch: { model.toggleWatch(app.api, g) })
                        .reveal(i)
                }
                if let c = model.coverage { CoverageNote(coverage: c) }
                if let n = model.notice {
                    Text(n).font(.labelS).foregroundStyle(PR.inkFaint).multilineTextAlignment(.leading)
                }
            }
        }
        .task(id: query) {
            model.run(app.api, query: query)
            model.loadWatches(app.api)
        }
        .task(id: model.groups.count) {
            // remember a search once it actually found products
            try? await Task.sleep(for: .seconds(1.5))
            if !model.groups.isEmpty { app.remember(query) }
        }
    }
}

/// What this search saw, and what it didn't. Never "we searched everything".
struct CoverageNote: View {
    var coverage: LiveCoverage
    @State private var open = false

    var body: some View {
        Panel(padding: 12, background: PR.paper, border: .clear) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: Ic.broadcast).font(.system(size: 12)).foregroundStyle(PR.inkSoft)
                    Text(coverage.sentence).font(.labelS).foregroundStyle(PR.inkSoft)
                        .lineLimit(2).multilineTextAlignment(.leading)
                    Spacer(minLength: 0)
                }
                if !coverage.reasons.isEmpty {
                    Button(action: { withAnimation(.easeOut(duration: 0.2)) { open.toggle() } }) {
                        Text(open ? t("إخفاء التفاصيل", "Hide details") : t("إيه اللي فاتنا؟", "What did we miss?"))
                            .font(.labelS).foregroundStyle(PR.signalDeep)
                    }
                    if open {
                        ForEach(coverage.reasons, id: \.self) { r in
                            Text("· " + r).font(.labelS).foregroundStyle(PR.inkFaint)
                                .multilineTextAlignment(.leading).frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            }
        }
    }
}

struct LiveErrorView: View {
    var error: APIError
    var signIn: () -> Void
    var retry: () -> Void
    var body: some View {
        if error.needsSignIn {
            EmptyState(icon: Ic.user, title: t("محتاج تسجيل دخول", "Sign in to search"),
                       bodyText: t("البحث اللايف محتاج حساب.", "Live search needs an account."),
                       action: t("تسجيل الدخول", "Sign in"), onAction: signIn)
        } else {
            EmptyState(icon: Ic.info,
                       title: error.isQuota ? t("خلصت عمليات البحث المجانية", "Free searches are used up")
                                            : t("مش قادرين ندوّر دلوقتي", "Can't search right now"),
                       bodyText: t("جرّب تاني بعد لحظة.", "Try again in a moment."),
                       action: t("حاول تاني", "Try again"), onAction: retry)
        }
    }
}

// MARK: - the product page

@MainActor
@Observable
final class LiveProductModel {
    var product: LiveProductResponse?
    var loading = true
    var error: APIError?
    var watch: LiveWatch?
    var watching = false

    func load(_ api: API, key: String, query: String) async {
        loading = product == nil
        error = nil
        do {
            let p = try await api.liveProduct(key: key, query: query)
            product = p
            watching = p.watch != nil
            watch = p.watch
        } catch let e as APIError {
            error = e
        } catch {}
        loading = false
    }

    func setWatch(_ api: API, key: String, query: String, target: Decimal?) async {
        guard let p = product else { return }
        do {
            try await api.liveWatch(key: key, query: query, title: p.title ?? "", image: p.image,
                                    target: target, price: p.offers.first?.price)
            watching = true
        } catch {}
    }

    func stopWatch(_ api: API, key: String) async {
        do { try await api.liveUnwatch(key: key); watching = false } catch {}
    }
}

/// One product: the big picture, the specs, and three tabs — every shop's price, the price history, the specs.
struct LiveProductScreen: View {
    var key: String
    var query: String
    @Environment(AppState.self) private var app
    @Environment(Router.self) private var router
    @State private var model = LiveProductModel()
    @State private var tab = 0
    @State private var askTarget = false
    @State private var target = ""

    var body: some View {
        VStack(spacing: 0) {
            TopBar(title: t("المنتج", "Product"), onBack: { router.back() }) {
                Button(action: toggleWatch) {
                    Image(systemName: model.watching ? Ic.heartFill : Ic.heart)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(model.watching ? PR.danger : PR.ink).frame(width: 44, height: 44)
                }
                .accessibilityLabel(t("تابع السعر", "Watch the price"))
            }
            ScrollView {
                VStack(spacing: 14) {
                    if model.loading && model.product == nil {
                        LoadingList(rows: 3)
                    } else if let p = model.product {
                        header(p)
                        tabs
                        switch tab {
                        case 1: history(p)
                        case 2: specs(p)
                        default: shops(p)
                        }
                        trackButton(p)
                    } else if let e = model.error {
                        EmptyState(icon: Ic.info,
                                   title: e.status == 404 ? t("المنتج ده مش محفوظ", "This product has expired")
                                                          : t("مش قادرين نجيب المنتج", "Couldn't load the product"),
                                   bodyText: t("ابحث عنه تاني وهيتحدّث بأسعار النهاردة.",
                                               "Search for it again and it comes back with today's prices."),
                                   action: t("ابحث تاني", "Search again"),
                                   onAction: { router.push(.search(category: nil, query: query, part: nil)) })
                    }
                }
                .padding(16)
                .padding(.bottom, 90)          // clear of the floating tab bar
            }
        }
        .background(PR.paper)
        .navigationBarBackButtonHidden(true)
        .task(id: key) { await model.load(app.api, key: key, query: query) }
        .alert(t("سعر تحب نبلّغك عنده", "Tell me at this price"), isPresented: $askTarget) {
            TextField(t("السعر", "Price"), text: $target).keyboardType(.numberPad)
            Button(t("فعّل", "Set")) {
                let v = Decimal(string: target.filter { $0.isNumber || $0 == "." })
                Task { await model.setWatch(app.api, key: key, query: query, target: v) }
            }
            Button(t("أي نزول", "Any drop")) { Task { await model.setWatch(app.api, key: key, query: query, target: nil) } }
            Button(t("إلغاء", "Cancel"), role: .cancel) {}
        } message: {
            Text(t("وافي شادو هيفضل يراقب المنتج ويبعتلك لما السعر ينزل.",
                   "Wafi Shadow keeps watching this product and tells you when the price drops."))
        }
    }

    private func toggleWatch() {
        if model.watching {
            Task { await model.stopWatch(app.api, key: key) }
        } else {
            askTarget = true
        }
    }

    private func header(_ p: LiveProductResponse) -> some View {
        Panel {
            VStack(alignment: .leading, spacing: 10) {
                LiveImage(url: p.image, size: 220, radius: 16).frame(maxWidth: .infinity)
                Text(p.title ?? "").font(.titleL).foregroundStyle(PR.ink)
                HStack(spacing: 8) {
                    if let r = p.rating { Stars(rating: r, count: nil) }
                    if let v = p.variant, !v.isEmpty { Badge(v, .signal) }
                }
                if let best = sound(p).first {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        PriceText(value: best.payable, font: .wafi(28, .bold))
                        Text(t("في \(best.store)", "at \(best.store)")).font(.bodyS).foregroundStyle(PR.inkSoft)
                    }
                    if let d = p.history?.changeVsPrev, abs(d) >= 0.5 { TrendPill(pct: Decimal(d)) }
                }
                if !p.specs.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(p.specs, id: \.self) { s in
                                Text(s).font(.labelS).foregroundStyle(PR.ink)
                                    .padding(.horizontal, 10).padding(.vertical, 5)
                                    .background(PR.paper).clipShape(Capsule())
                            }
                        }
                    }
                }
            }
        }
    }

    private var tabs: some View {
        HStack(spacing: 6) {
            ForEach(Array([t("قارن الأسعار", "Compare prices"), t("تاريخ السعر", "Price history"),
                           t("المواصفات", "Specifications")].enumerated()), id: \.offset) { i, label in
                Chip(label, selected: tab == i) { withAnimation(.easeOut(duration: 0.2)) { tab = i } }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Every shop, cheapest first. The one we stand behind carries the badge; a doubtful price says so.
    private func shops(_ p: LiveProductResponse) -> some View {
        VStack(spacing: 10) {
            ForEach(Array(p.offers.enumerated()), id: \.element.id) { i, o in
                LiveOfferRow(offer: o, best: i == 0 && !o.doubtful)
            }
            if p.offers.isEmpty {
                Text(t("مفيش متجر عارض سعر دلوقتي.", "No shop is showing a price right now."))
                    .font(.bodyS).foregroundStyle(PR.inkSoft)
            }
        }
    }

    private func history(_ p: LiveProductResponse) -> some View {
        Panel {
            VStack(alignment: .leading, spacing: 10) {
                if let h = p.history, h.enough, h.points.count >= 2 {
                    AreaChart(values: h.points.map { NSDecimalNumber(decimal: $0.price).doubleValue },
                              color: PR.signalDeep)
                        .frame(height: 140)
                    HStack {
                        stat(t("أقل سعر", "Lowest"), h.lowest)
                        Spacer()
                        stat(t("المتوسط", "Average"), h.average)
                        Spacer()
                        stat(t("أعلى سعر", "Highest"), h.highest)
                    }
                    if let text = h.text {
                        Text(text).font(.bodyS).foregroundStyle(PR.ink)
                            .padding(10).frame(maxWidth: .infinity, alignment: .leading)
                            .background(PR.signalSoft).clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    if let d = p.deal?.text {
                        Text(d).font(.labelM).foregroundStyle(p.deal?.genuine == true ? PR.signalDeep : PR.amberDeep)
                    }
                    Text(t("\(Fmt.number(h.days)) يوم من القراءات", "\(Fmt.number(h.days)) days of readings"))
                        .font(.labelS).foregroundStyle(PR.inkFaint)
                } else {
                    Text(t("بدأنا نسجّل السعر — الاتجاه هيظهر مع الأيام.",
                           "Tracking has started — the trend appears as the days pass."))
                        .font(.bodyS).foregroundStyle(PR.inkSoft)
                }
            }
        }
    }

    private func stat(_ label: String, _ value: Money?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.labelS).foregroundStyle(PR.inkSoft)
            PriceText(value: value, font: .titleS)
        }
    }

    private func specs(_ p: LiveProductResponse) -> some View {
        Panel {
            VStack(alignment: .leading, spacing: 8) {
                if p.specs.isEmpty {
                    Text(t("المتاجر مكتبتش مواصفات للمنتج ده.", "The shops published no specifications for this one."))
                        .font(.bodyS).foregroundStyle(PR.inkSoft)
                } else {
                    ForEach(p.specs, id: \.self) { s in
                        HStack(spacing: 8) {
                            Image(systemName: Ic.check).font(.system(size: 11, weight: .bold)).foregroundStyle(PR.signalDeep)
                            Text(s).font(.bodyM).foregroundStyle(PR.ink)
                            Spacer(minLength: 0)
                        }
                    }
                }
            }
        }
    }

    private func trackButton(_ p: LiveProductResponse) -> some View {
        VStack(spacing: 8) {
            PRButton(model.watching ? t("بنتابع السعر لك", "Wafi Shadow is watching")
                                    : t("تابع السعر مع وافي شادو", "Track price with Wafi Shadow"),
                     kind: model.watching ? .outline : .dark,
                     icon: model.watching ? Ic.check : Ic.bell) { toggleWatch() }
            if let tp = model.watch?.targetPrice {
                Text(t("هنبلّغك لما ينزل لـ \(Fmt.money(tp))", "We'll tell you when it reaches \(Fmt.money(tp))"))
                    .font(.labelS).foregroundStyle(PR.inkSoft)
            }
        }
    }

    private func sound(_ p: LiveProductResponse) -> [LiveOffer] {
        let ok = p.offers.filter { !$0.doubtful }
        return ok.isEmpty ? p.offers : ok
    }
}

/// One shop's row: who, how much, in stock or not, how the price was established, and a way to open it.
struct LiveOfferRow: View {
    var offer: LiveOffer
    var best: Bool
    @Environment(\.openURL) private var openURL

    var body: some View {
        Panel(padding: 12, action: { if let u = URL(string: offer.url) { openURL(u) } }) {
            HStack(spacing: 12) {
                LiveImage(url: offer.logo, size: 40)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(offer.store).font(.titleS).foregroundStyle(PR.ink).lineLimit(1)
                        if best { Badge(t("أرخص سعر", "Best price"), .signal, icon: Ic.bolt) }
                    }
                    HStack(spacing: 6) {
                        if let s = offer.inStock {
                            Circle().fill(s ? PR.signal : PR.danger).frame(width: 5, height: 5)
                            Text(s ? t("متوفر", "In stock") : t("مش متوفر", "Out of stock"))
                                .font(.labelS).foregroundStyle(s ? PR.signalDeep : PR.danger)
                        }
                        if let v = verification { Text("·").font(.labelS).foregroundStyle(PR.inkFaint); Text(v).font(.labelS).foregroundStyle(PR.inkFaint) }
                    }
                    if offer.doubtful {
                        Text(t("السعر ده بعيد عن باقي المتاجر — اتأكد منه في المتجر",
                               "This price is far from the other shops — check it on the shop"))
                            .font(.labelS).foregroundStyle(PR.amberDeep).lineLimit(2).multilineTextAlignment(.leading)
                    }
                }
                Spacer(minLength: 0)
                VStack(alignment: .trailing, spacing: 2) {
                    PriceText(value: offer.price, font: .titleM, color: offer.doubtful ? PR.inkSoft : PR.ink)
                    if let total = offer.total, total != offer.price {
                        Text(t("\(Fmt.money(total)) بالشحن", "\(Fmt.money(total)) with delivery"))
                            .font(.labelS).foregroundStyle(PR.inkSoft)
                    } else if best {
                        // said once, on the row people act on, instead of under every shop
                        Text(t("الشحن مش مكتوب", "delivery not stated")).font(.labelS).foregroundStyle(PR.inkFaint)
                    }
                    if let d = offer.discountPct, d >= 1 { Badge("−" + String(format: "%.0f", d) + "%", .amber) }
                }
            }
        }
    }

    /// How this price was established, in words a shopper understands.
    private var verification: String? {
        switch offer.priceStatus {
        case "VERIFIED": return t("سعر مؤكد من الصفحة", "confirmed on the page")
        case "PARTIALLY_VERIFIED": return t("من بيانات الصفحة", "from the page's own data")
        case "STALE": return t("محتاج تأكيد", "needs confirming")
        case "UNVERIFIED": return t("مقروء من نص الصفحة", "read from the page text")
        default: return nil
        }
    }
}

// MARK: - trending, on the home screen

/// What people found lately with a live price from more than one shop. Nothing here is an estimate, so when
/// the engine has nothing fresh the strip simply isn't drawn.
struct LiveTrendingStrip: View {
    @Environment(AppState.self) private var app
    @Environment(Router.self) private var router
    @State private var items: [LiveTrending] = []

    var body: some View {
        Group {
            if !items.isEmpty {
                SectionHeader(title: t("أسعار لايف من المتاجر", "Live prices from the shops"))
                    .padding(.horizontal, 20).padding(.top, 22).padding(.bottom, 10)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(items) { it in
                            LiveTile(item: it) { router.push(.liveProduct(key: it.key, query: it.q ?? it.title)) }
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
        .task {
            if let got = try? await app.api.liveTrending(limit: 12) { items = got }
        }
    }
}

struct LiveTile: View {
    var item: LiveTrending
    var action: () -> Void
    var body: some View {
        Panel(padding: 12, action: action) {
            VStack(alignment: .leading, spacing: 6) {
                LiveImage(url: item.image, size: 130, radius: 14).frame(maxWidth: .infinity)
                Text(item.title).font(.wafi(15, .semibold)).foregroundStyle(PR.ink)
                    .lineLimit(2).frame(height: 40, alignment: .top).multilineTextAlignment(.leading)
                PriceText(value: item.priceFrom, font: .titleM)
                Text(item.stores == 1 ? t("متجر واحد", "1 shop")
                                      : t("\(Fmt.number(item.stores)) متاجر", "\(Fmt.number(item.stores)) shops"))
                    .font(.labelS).foregroundStyle(PR.inkSoft)
            }
        }
        .frame(width: 168)
    }
}

// MARK: - Wafi Shadow: what this phone is watching

/// The products Wafi Shadow is watching, and the alerts it has already sent. This works for a guest too —
/// the watch belongs to the phone, so nothing here asks anyone to sign in.
struct ShadowSection: View {
    @Environment(AppState.self) private var app
    @Environment(Router.self) private var router
    @State private var watches: [LiveWatch] = []
    @State private var alerts: [LiveNotification] = []
    @State private var loaded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !alerts.isEmpty {
                SectionHeader(title: t("وافي شادو", "Wafi Shadow"))
                ForEach(alerts.prefix(10)) { n in
                    Panel(padding: 12, action: { if let k = n.key { router.push(.liveProduct(key: k, query: n.title ?? "")) } }) {
                        HStack(spacing: 12) {
                            Image(systemName: n.kind == "back_in_stock" ? Ic.store : Ic.bolt)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(n.kind == "target_hit" ? PR.signalDeep : PR.amberDeep)
                                .frame(width: 34, height: 34).background(PR.paper).clipShape(Circle())
                            VStack(alignment: .leading, spacing: 2) {
                                Text(n.headline).font(.titleS).foregroundStyle(PR.ink)
                                Text(n.title ?? "").font(.bodyS).foregroundStyle(PR.inkSoft).lineLimit(1)
                                if let old = n.oldPrice, let new = n.newPrice {
                                    HStack(spacing: 6) {
                                        Text(Fmt.money(old)).font(.labelS).foregroundStyle(PR.inkFaint).strikethrough()
                                        Text(Fmt.money(new)).font(.labelM).foregroundStyle(PR.signalDeep)
                                        if let s = n.store { Text("· " + s).font(.labelS).foregroundStyle(PR.inkFaint) }
                                    }
                                }
                            }
                            Spacer(minLength: 0)
                            if n.isUnread { Circle().fill(PR.signal).frame(width: 7, height: 7) }
                        }
                    }
                }
            }
            if !watches.isEmpty {
                SectionHeader(title: t("بنراقب السعر", "Watching the price")).padding(.top, alerts.isEmpty ? 0 : 10)
                ForEach(watches) { w in
                    Panel(padding: 12, action: { router.push(.liveProduct(key: w.key, query: w.q ?? w.title ?? "")) }) {
                        HStack(spacing: 12) {
                            LiveImage(url: w.image, size: 48)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(w.title ?? "").font(.titleS).foregroundStyle(PR.ink).lineLimit(2)
                                if let tp = w.targetPrice {
                                    Text(t("هدفك \(Fmt.money(tp))", "your target \(Fmt.money(tp))"))
                                        .font(.labelS).foregroundStyle(PR.inkSoft)
                                } else {
                                    Text(t("هنبلّغك عند أي نزول", "we'll tell you on any drop"))
                                        .font(.labelS).foregroundStyle(PR.inkSoft)
                                }
                            }
                            Spacer(minLength: 0)
                            PriceText(value: w.lastPrice, font: .titleS)
                        }
                    }
                }
            }
            if loaded && watches.isEmpty && alerts.isEmpty {
                EmptyState(icon: Ic.bell, title: t("مفيش حاجة بنراقبها", "Nothing being watched"),
                           bodyText: t("دوس على القلب جنب أي منتج، وإحنا نقولك أول ما سعره ينزل.",
                                       "Tap the heart on any product and we'll tell you the moment its price drops."))
            }
        }
        .task { await reload() }
    }

    private func reload() async {
        async let w = try? app.api.liveWatches()
        async let n = try? app.api.liveNotifications(markRead: true)
        watches = await w ?? []
        alerts = await n?.items ?? []
        loaded = true
    }
}
