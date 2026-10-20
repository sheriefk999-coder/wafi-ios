import SwiftUI
import VisionKit

private let sorts: [(String, String, String)] = [
    ("relevance", "الأنسب", "Best match"), ("price_asc", "الأرخص", "Lowest price"),
    ("price_desc", "الأغلى", "Highest price"), ("newest", "الأحدث", "Newest"),
]

/// Results, analysis and suggestions for one filter; reloads (debounced) whenever the filter changes.
@MainActor
@Observable
final class SearchModel {
    var filter: ProductFilter
    var results: Load<[ProductSummary]> = .loading
    var analysis: SearchAnalysis?
    var suggest = SuggestResponse()
    private var job: Task<Void, Never>?
    private var suggestJob: Task<Void, Never>?

    init(_ f: ProductFilter) { filter = f }

    func update(_ change: (inout ProductFilter) -> Void) {
        var f = filter
        change(&f)
        guard f != filter else { return }
        let typed = f.query != filter.query
        filter = f
        reload(debounce: typed)
        if typed { loadSuggestions() }
    }

    func reload(debounce: Bool = false) {
        job?.cancel()
        let f = filter
        job = Task {
            if debounce { try? await Task.sleep(for: .milliseconds(350)) }
            if Task.isCancelled { return }
            if mustSignIn(f) { analysis = nil; results = .err(.http(status: 401, code: "sign_in_required")); return }
            if results.value == nil { results = .loading }
            let api = AppState.shared.api
            async let a = try? api.analysis(f)
            let r = await load { try await api.products(f) }
            if Task.isCancelled { return }
            results = r
            analysis = await a
        }
    }

    /// A typed search while signed out, when the console requires an account: show the sign-in wall, don't call.
    private func mustSignIn(_ f: ProductFilter) -> Bool {
        let app = AppState.shared
        return !f.query.trimmingCharacters(in: .whitespaces).isEmpty && !app.isSignedIn && app.config.searchRequiresAccount
    }

    private func loadSuggestions() {
        suggestJob?.cancel()
        let q = filter.query.trimmingCharacters(in: .whitespaces)
        guard q.count >= 2, !mustSignIn(filter) else { suggest = SuggestResponse(); return }
        suggestJob = Task {
            try? await Task.sleep(for: .milliseconds(200))
            if Task.isCancelled { return }
            if let s = try? await AppState.shared.api.suggest(q), !Task.isCancelled { suggest = s }
        }
    }
}

struct SortRow: View {
    var sort: String
    var count: Int?
    var onSort: (String) -> Void
    var inStock: Bool?
    var onStock: (Bool) -> Void = { _ in }
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ChipRow {
                if let inStock { Chip(t("المتوفر بس", "In stock only"), selected: inStock, icon: Ic.check) { onStock(!inStock) } }
                ForEach(sorts, id: \.0) { s in Chip(t(s.1, s.2), selected: sort == s.0) { onSort(s.0) } }
            }
            if let count {
                Text(t("\(Fmt.number(count)) نتيجة", "\(count) results")).font(.labelM).foregroundStyle(PR.inkSoft).padding(.horizontal, 20)
            }
        }
        .padding(.top, 6)
    }
}

/// The result list shared by search and cars: loading, error, empty, or rows with an inline ad.
struct Results<Row: View>: View {
    var res: Load<[ProductSummary]>
    var retry: () -> Void
    @ViewBuilder var row: (ProductSummary) -> Row
    var body: some View {
        switch res {
        case .loading: LoadingList(rows: 5).padding(.horizontal, 20).padding(.top, 8)
        case .err(let e):
            if e.needsSignIn {
                SignInWall()
            } else if e.isQuota {
                QuotaWall(error: e, onReady: retry)
            } else {
                EmptyState(icon: Ic.server, title: t("البحث وقف", "Search stopped"), bodyText: e.message, action: t("حاول تاني", "Try again"), onAction: retry)
                    .padding(.top, 24)
            }
        case .ok(let items):
            if items.isEmpty {
                EmptyState(icon: Ic.search, title: t("مفيش نتايج", "No results"),
                           bodyText: t("جرّب كلمة تانية أو شيل بعض الفلاتر.", "Try another word or remove some filters.")).padding(.top, 24)
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { i, p in
                        row(p).reveal(i % 8)
                        if i == 5 || (i > 5 && (i - 5) % 12 == 0) { AdSlot(kind: .inline, placement: "search") }
                    }
                }
            }
        }
    }
}

// MARK: - Discover

struct SearchScreen: View {
    @Environment(AppState.self) private var app
    @Environment(Router.self) private var router
    @State private var model: SearchModel
    @State private var scanning = false
    @FocusState private var focused: Bool

    init(initial: ProductFilter) { _model = State(initialValue: SearchModel(initial)) }

    var body: some View {
        let f = model.filter
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text(t("اكتشف", "Discover")).font(.headline).foregroundStyle(PR.ink).padding(.horizontal, 20).padding(.top, 16).padding(.bottom, 10)
                searchBox
                if !f.query.trimmingCharacters(in: .whitespaces).isEmpty { QuotaHint(left: app.searchLeft) }
                if focused && f.query.trimmingCharacters(in: .whitespaces).count >= 2 && (!model.suggest.products.isEmpty || !model.suggest.brands.isEmpty) {
                    suggestions
                }
                if f.query.isEmpty && f.brand == nil && !app.recent.isEmpty { recent }
                if let b = f.brand {
                    Chip(b + "  ✕", selected: true, icon: Ic.tag) { model.update { $0.brand = nil } }.padding(.horizontal, 20).padding(.top, 8)
                }
                ChipRow {
                    Chip(t("الكل", "All"), selected: f.category == nil) { model.update { $0.category = nil; $0.part = nil } }
                    ForEach([Category.phones, .laptops, .audio, .tablets, .pcParts, .cars, .fashion, .music, .other]) { c in
                        Chip(categoryLabel(c), selected: f.category == c.rawValue, icon: categoryIcon(c)) { model.update { $0.category = c.rawValue; $0.part = nil } }
                    }
                }
                .padding(.vertical, 8)
                if f.category == Category.pcParts.rawValue {
                    ChipRow {
                        ForEach(["cpu", "gpu", "motherboard", "ram", "storage", "psu", "case"], id: \.self) { p in
                            Chip(partLabel(p), selected: f.part == p, icon: partIcon(p)) { model.update { $0.part = $0.part == p ? nil : p } }
                        }
                    }
                }
                SortRow(sort: f.sort, count: model.results.value?.count, onSort: { s in model.update { $0.sort = s } },
                        inStock: f.inStock, onStock: { v in model.update { $0.inStock = v } })
                if let a = model.analysis, model.results.value != nil, a.priced > 0 {
                    SearchAnalysisCard(a: a)
                }
                Results(res: model.results, retry: { model.reload() }) { p in
                    ProductRow(p: p) { router.push(.product(p.id)) }.padding(.horizontal, 20).padding(.vertical, 5)
                }
            }
            .padding(.bottom, 90)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(PR.white)
        .task {
            if model.results.value == nil { model.reload() }
        }
        .onChange(of: app.isSignedIn) { _, signedIn in
            // back from signing in: run the search that was waiting
            if signedIn, case .err(let e) = model.results, e.needsSignIn { model.reload() }
        }
        .onAppear {
            if let seed = SearchSeed.shared.next { SearchSeed.shared.next = nil; model.update { $0 = seed } }
        }
        .task(id: model.results.value?.count) {
            // remember a search once it found something and the user stopped typing
            try? await Task.sleep(for: .seconds(1.5))
            if !(model.results.value ?? []).isEmpty { app.remember(model.filter.query) }
        }
        .sheet(isPresented: $scanning) {
            BarcodeScanner { code in
                scanning = false
                model.update { $0.query = code; $0.category = nil; $0.part = nil }
                app.remember(code)
            }
            .ignoresSafeArea()
        }
    }

    private var searchBox: some View {
        HStack(spacing: 10) {
            Image(systemName: Ic.search).foregroundStyle(PR.inkSoft)
            TextField(t("اسم المنتج، الماركة، أو الباركود", "Product, brand or barcode"),
                      text: Binding(get: { model.filter.query }, set: { v in model.update { $0.query = String(v.prefix(100)) } }))
                .font(.bodyL).foregroundStyle(PR.ink).submitLabel(.search).focused($focused)
                .autocorrectionDisabled()
                .accessibilityIdentifier("search.field")
            if !model.filter.query.isEmpty {
                Button { model.update { $0.query = "" } } label: { Image(systemName: Ic.close).foregroundStyle(PR.inkSoft).frame(width: 36, height: 36) }
                    .accessibilityLabel(t("مسح", "Clear"))
            }
            if DataScannerViewController.isSupported {
                Button { scanning = true } label: { Image(systemName: Ic.barcode).foregroundStyle(PR.ink).frame(width: 40, height: 40) }
                    .accessibilityLabel(t("امسح باركود", "Scan barcode"))
            }
        }
        .padding(.horizontal, 14).frame(height: 54)
        .background(PR.paper).clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .padding(.horizontal, 20)
    }

    private var suggestions: some View {
        Panel(padding: 6) {
            VStack(spacing: 0) {
                ForEach(model.suggest.brands, id: \.brand) { b in
                    SuggestRow(icon: Ic.tag, title: b.brand, sub: t("\(Fmt.number(b.products)) منتج", "\(b.products) products")) {
                        model.update { $0.query = ""; $0.brand = b.brand }; focused = false
                    }
                }
                ForEach(model.suggest.products) { sp in
                    SuggestRow(icon: categoryIcon(Category.from(sp.category)), title: Lang.isArabic ? sp.titleAr : sp.titleEn, sub: sp.brand) {
                        app.remember(model.filter.query); focused = false; router.push(.product(sp.id))
                    }
                }
            }
        }
        .padding(.horizontal, 20).padding(.vertical, 6)
    }

    private var recent: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(t("آخر بحث", "Recent")).font(.labelL).foregroundStyle(PR.inkSoft)
                Spacer()
                Button(t("مسح", "Clear")) { app.recent = [] }.font(.labelM).foregroundStyle(PR.signalDeep)
            }
            .padding(.leading, 20).padding(.trailing, 16).padding(.top, 10)
            ChipRow { ForEach(app.recent, id: \.self) { q in Chip(q, selected: false, icon: Ic.refresh) { model.update { $0.query = q } } } }
        }
    }
}

private struct SuggestRow: View {
    var icon: String
    var title: String
    var sub: String
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon).font(.system(size: 15)).foregroundStyle(PR.inkSoft).frame(width: 20)
                Text(title).font(.bodyM).foregroundStyle(PR.ink).lineLimit(1)
                Spacer()
                Text(sub).font(.labelS).foregroundStyle(PR.inkFaint).lineLimit(1)
            }
            .padding(.horizontal, 12).padding(.vertical, 10).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// Camera barcode reader (VisionKit). Returns the first code it reads.
struct BarcodeScanner: UIViewControllerRepresentable {
    var onCode: (String) -> Void
    func makeUIViewController(context: Context) -> DataScannerViewController {
        let vc = DataScannerViewController(recognizedDataTypes: [.barcode()], qualityLevel: .balanced, isHighlightingEnabled: true)
        vc.delegate = context.coordinator
        try? vc.startScanning()
        return vc
    }
    func updateUIViewController(_ vc: DataScannerViewController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(onCode: onCode) }
    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        var onCode: (String) -> Void
        var done = false
        init(onCode: @escaping (String) -> Void) { self.onCode = onCode }
        func dataScanner(_ s: DataScannerViewController, didAdd items: [RecognizedItem], allItems: [RecognizedItem]) {
            guard !done else { return }
            for item in items {
                if case .barcode(let b) = item, let v = b.payloadStringValue, !v.isEmpty {
                    done = true
                    s.stopScanning()
                    onCode(String(v.prefix(64)))
                    return
                }
            }
        }
    }
}

// MARK: - Price analysis card

/// "تحليل الأسعار" above the results: the best match's chart, how many results moved in 30 days, and today's range.
/// Recorded prices only, no forecast.
struct SearchAnalysisCard: View {
    var a: SearchAnalysis
    @Environment(Router.self) private var router
    var body: some View {
        Panel(padding: 16, radius: 22) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    IconTile(icon: Ic.trend, bg: PR.skySoft, fg: PR.sky, size: 36, iconSize: 17)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(t("تحليل الأسعار", "Price analysis")).font(.titleM).foregroundStyle(PR.ink)
                        Text(t("آخر \(Fmt.number(30)) يوم · \(Fmt.number(a.products)) منتج · \(Fmt.number(a.inStock)) متوفر",
                               "Last 30 days · \(a.products) products · \(a.inStock) in stock")).font(.labelS).foregroundStyle(PR.inkSoft)
                    }
                    Spacer()
                    if let c = a.avgChange30d { TrendPill(pct: c) }
                }
                if let f = a.focus, f.series.count >= 2 {
                    Button { router.push(.product(f.id)) } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(Lang.isArabic ? f.titleAr : f.titleEn).font(.labelL).foregroundStyle(PR.ink).lineLimit(1)
                                Spacer()
                                if let c = f.change30d { TrendPill(pct: c) }
                            }
                            AreaChart(values: f.series.map { NSDecimalNumber(decimal: $0.price).doubleValue },
                                      color: (f.change30d ?? 0) <= 0 ? PR.signal : PR.danger).frame(height: 86)
                            HStack {
                                stat(t("دلوقتي", "Now"), f.current)
                                stat(t("أقل سعر", "Lowest"), f.low90)
                                stat(t("أعلى سعر", "Highest"), f.high90)
                            }
                        }
                        .padding(12).background(PR.paper).clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .buttonStyle(Pressable())
                }
                if a.tracked > 0 {
                    HStack(spacing: 8) {
                        count(Ic.minus, a.dropped, t("نزلوا", "dropped"), PR.signalSoft, PR.signalDeep)
                        count(Ic.plus, a.rose, t("طلعوا", "rose"), PR.dangerSoft, PR.danger)
                        count(Ic.check, a.flat, t("ثابتين", "steady"), PR.paper, PR.inkSoft)
                    }
                } else {
                    Text(t("لسه بنسجّل تاريخ الأسعار للنتايج دي. التحليل هيكمل مع الأيام.",
                           "Still recording price history for these results; the analysis fills in over the coming days."))
                        .font(.bodyS).foregroundStyle(PR.inkSoft)
                }
                if let lo = a.min, let hi = a.max {
                    HStack {
                        Text(t("الأسعار النهارده", "Prices today")).font(.labelM).foregroundStyle(PR.inkSoft)
                        Spacer()
                        Text(Fmt.compact(lo) + " ← " + Fmt.compact(hi)).font(.labelL).foregroundStyle(PR.ink)
                    }
                }
                if let b = a.biggestDrop {
                    Button { router.push(.product(b.id)) } label: {
                        HStack(spacing: 8) {
                            Image(systemName: Ic.bolt).font(.system(size: 13)).foregroundStyle(PR.signalDeep)
                            Text(t("أكبر نزول: ", "Biggest drop: ") + (Lang.isArabic ? b.titleAr : b.titleEn)).font(.labelM).foregroundStyle(PR.signalDeep).lineLimit(1)
                            Spacer()
                            Text("▼ " + (Fmt.pct(b.changePct) ?? "")).font(.labelL).foregroundStyle(PR.signalDeep)
                        }
                        .padding(.horizontal, 12).padding(.vertical, 9).background(PR.signalSoft).clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(Pressable())
                }
            }
        }
        .padding(.horizontal, 20).padding(.vertical, 8)
    }

    private func stat(_ label: String, _ v: Decimal?) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(label).font(.labelS).foregroundStyle(PR.inkSoft)
            Text(v.map { Fmt.money($0) } ?? "—").font(.labelL).foregroundStyle(PR.ink).lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func count(_ icon: String, _ n: Int, _ label: String, _ bg: Color, _ fg: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon).font(.system(size: 11, weight: .bold))
            Text(Fmt.number(n)).font(.titleS)
            Text(label).font(.labelS)
        }
        .foregroundStyle(fg)
        .padding(.horizontal, 10).padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(bg).clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Cars

private let carBrands = ["Toyota", "Hyundai", "Kia", "Nissan", "Chevrolet", "MG", "Chery", "BYD", "Renault", "Peugeot", "Skoda", "Mercedes", "BMW"]
private let carMax: Double = 5_000_000

struct CarsScreen: View {
    @Environment(Router.self) private var router
    @State private var model = SearchModel(ProductFilter(category: Category.cars.rawValue, sort: "price_asc"))
    @State private var low: Double = 0
    @State private var high: Double = carMax
    @State private var expanded = true

    var body: some View {
        let f = model.filter
        VStack(spacing: 0) {
            TopBar(title: t("دوّر على عربية", "Find a car"), subtitle: t("جديدة ومستعملة، بالسعر الشامل", "New and used, by full price"), onBack: { router.back() }) {
                Button { withAnimation { expanded.toggle() } } label: { Image(systemName: Ic.filter).foregroundStyle(PR.ink).frame(width: 44, height: 44) }
                    .accessibilityLabel(t("الفلاتر", "Filters"))
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if expanded {
                        Panel(padding: 16, radius: 22) {
                            VStack(alignment: .leading, spacing: 12) {
                                Text(t("الحالة", "Condition")).font(.labelL).foregroundStyle(PR.ink)
                                HStack(spacing: 8) {
                                    Chip(t("الكل", "All"), selected: f.condition == nil) { model.update { $0.condition = nil } }
                                    Chip(t("زيرو", "New"), selected: f.condition == "new") { model.update { $0.condition = "new" } }
                                    Chip(t("مستعملة", "Used"), selected: f.condition == "used") { model.update { $0.condition = "used" } }
                                }
                                HStack {
                                    Text(t("الميزانية", "Budget")).font(.labelL).foregroundStyle(PR.ink)
                                    Spacer()
                                    Text(Fmt.compact(Decimal(low)) + " – " + (high >= carMax ? t("مفتوح", "any") : Fmt.compact(Decimal(high))))
                                        .font(.labelL).foregroundStyle(PR.signalDeep)
                                }
                                VStack(spacing: 0) {
                                    Slider(value: $low, in: 0...carMax, step: 50_000, onEditingChanged: { if !$0 { apply() } })
                                    Slider(value: $high, in: 0...carMax, step: 50_000, onEditingChanged: { if !$0 { apply() } })
                                }
                                .tint(PR.signal)
                                Text(t("الماركة", "Brand")).font(.labelL).foregroundStyle(PR.ink)
                            }
                        }
                        .padding(.horizontal, 20).padding(.vertical, 6)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                    ChipRow {
                        Chip(t("كل الماركات", "All brands"), selected: f.brand == nil) { model.update { $0.brand = nil } }
                        ForEach(carBrands, id: \.self) { b in Chip(b, selected: f.brand == b) { model.update { $0.brand = $0.brand == b ? nil : b } } }
                    }
                    SortRow(sort: f.sort, count: model.results.value?.count, onSort: { s in model.update { $0.sort = s } })
                    Results(res: model.results, retry: { model.reload() }) { p in CarCard(p: p) { router.push(.product(p.id)) } }
                }
                .padding(.bottom, 32)
            }
        }
        .background(PR.white)
        .task { if model.results.value == nil { model.reload() } }
    }

    private func apply() {
        if low > high { swap(&low, &high) }
        model.update {
            $0.minPrice = low > 0 ? Decimal(low) : nil
            $0.maxPrice = high < carMax ? Decimal(high) : nil
        }
    }
}

private struct CarCard: View {
    var p: ProductSummary
    var action: () -> Void
    var body: some View {
        Panel(padding: 14, radius: 22, action: action) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    ProductImage(category: p.category, imageURL: p.imageUrl, size: 64).frame(width: 64, height: 64)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(p.title).font(.titleM).foregroundStyle(PR.ink).lineLimit(2)
                        Text("\(p.brand) \(p.model)" + (p.color.isEmpty ? "" : " · \(p.color)")).font(.bodyS).foregroundStyle(PR.inkSoft)
                    }
                    Spacer()
                    Badge(p.condition == "new" ? t("زيرو", "New") : t("مستعملة", "Used"), p.condition == "new" ? .signal : .neutral)
                }
                HStack(spacing: 6) {
                    if let y = p.specs.int("year") { Badge("\(y)", .sky) }
                    if let km = p.specs.int("km") { Badge(km == 0 ? t("٠ كم", "0 km") : Fmt.number(km) + t(" كم", " km"), .neutral, icon: Ic.gauge) }
                    if let tr = p.specs.str("transmission") { Badge(transmissionLabel(tr)) }
                    if let fu = p.specs.str("fuel") { Badge(fuelLabel(fu)) }
                }
                HStack {
                    PriceText(value: p.displayPrice, font: .headlineS, fallback: t("السعر عند الطلب", "Price on request"))
                    Spacer()
                    if p.offers > 1 { Text(t("\(Fmt.number(p.offers)) معرض", "\(p.offers) dealers")).font(.labelM).foregroundStyle(PR.inkSoft) }
                }
                OfferMeta(store: p.bestStore, seenAt: p.bestSeenAt, inStock: p.inStock)
            }
        }
        .padding(.horizontal, 20).padding(.vertical, 6)
    }
}
