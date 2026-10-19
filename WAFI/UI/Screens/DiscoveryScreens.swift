import SwiftUI

// MARK: - Price drops

struct DealsScreen: View {
    @Environment(AppState.self) private var app
    @Environment(Router.self) private var router
    @State private var category: String?
    @State private var state: Load<[Deal]> = .loading

    var body: some View {
        VStack(spacing: 0) {
            TopBar(title: t("نزلت أسعارها", "Price drops"), subtitle: t("أقل من سعرها المعتاد، بنفس قاعدة صفحة المنتج", "Below their typical price, same rule as the product page"),
                   onBack: { router.back() })
            ChipRow {
                Chip(t("الكل", "All"), selected: category == nil) { category = nil }
                ForEach([Category.phones, .laptops, .audio, .tablets, .pcParts, .cars, .fashion, .music]) { c in
                    Chip(categoryLabel(c), selected: category == c.rawValue, icon: categoryIcon(c)) { category = c.rawValue }
                }
            }
            .padding(.vertical, 6)
            ScrollView {
                switch state {
                case .loading: LoadingList(rows: 5).padding(20)
                case .err(let e):
                    EmptyState(icon: Ic.chart, title: t("مقدرناش نجيب العروض", "Couldn't load deals"), bodyText: e.message, action: t("حاول تاني", "Try again")) {
                        Task { await reload() }
                    }
                    .padding(.top, 30)
                case .ok(let deals) where deals.isEmpty:
                    EmptyState(icon: Ic.chart, title: t("مفيش نزول أسعار دلوقتي", "No price drops right now"),
                               bodyText: t("بنحسب ده من تاريخ السعر، فبيظهر بعد أسبوعين من متابعة المنتج.", "This comes from price history, so it shows after two weeks of tracking."))
                        .padding(.top, 30)
                case .ok(let deals):
                    LazyVStack(spacing: 0) {
                        AdSlot(kind: .banner, placement: "deals")
                        ForEach(Array(deals.enumerated()), id: \.element.id) { i, d in DealRow(d: d).reveal(i % 8) }
                    }
                    .padding(.bottom, 24)
                }
            }
        }
        .background(PR.white)
        .task(id: category) { await reload() }
    }

    private func reload() async {
        let cat = category
        let r = await load { try await app.api.deals(category: cat, limit: 30) }
        if cat == category { state = r }
    }
}

private struct DealRow: View {
    var d: Deal
    @Environment(Router.self) private var router
    var body: some View {
        let p = d.summary
        Panel(padding: 12, action: { router.push(.product(d.id)) }) {
            HStack(spacing: 12) {
                ProductImage(category: p.category, part: p.specs.str("part"), imageURL: p.imageUrl, size: 64).frame(width: 64, height: 64)
                VStack(alignment: .leading, spacing: 2) {
                    Text(p.title).font(.titleS).foregroundStyle(PR.ink).lineLimit(2)
                    HStack(spacing: 8) {
                        PriceText(value: d.currentMin, font: .titleM, color: PR.signalDeep)
                        Text(Fmt.money(d.median)).font(.bodyS).strikethrough().foregroundStyle(PR.inkFaint)
                    }
                    if d.verdict == "lowest_observed" { Text(t("أقل سعر سجّلناه", "Lowest we've recorded")).font(.labelS).foregroundStyle(PR.signalDeep) }
                }
                Spacer(minLength: 0)
                DropBadge(deal: d)
            }
        }
        .padding(.horizontal, 20).padding(.vertical, 5)
    }
}

// MARK: - Compare

struct CompareScreen: View {
    @Environment(AppState.self) private var app
    @Environment(Router.self) private var router
    @State private var state: Load<CompareResponse>?

    var body: some View {
        let ids = app.compare.map(\.id)
        VStack(spacing: 0) {
            TopBar(title: t("مقارنة", "Compare"), subtitle: t("\(Fmt.number(ids.count)) من \(Fmt.number(app.compareLimit))", "\(ids.count) of \(app.compareLimit)"),
                   onBack: { router.back() }) {
                if !ids.isEmpty {
                    Button { app.compare = [] } label: { Image(systemName: Ic.trash).foregroundStyle(PR.inkSoft).frame(width: 44, height: 44) }
                        .accessibilityLabel(t("مسح الكل", "Clear all"))
                }
            }
            switch state {
            case nil:
                EmptyState(icon: Ic.exchange, title: t("اختار منتجين على الأقل", "Pick at least two products"),
                           bodyText: t("من صفحة أي منتج اضغط «قارن»، وارجع هنا تشوفهم جنب بعض.", "Tap “Compare” on any product page, then come back to see them side by side."),
                           action: t("تصفّح", "Browse")) { router.push(.search(category: nil, query: "", part: nil)) }
                    .frame(maxHeight: .infinity)
            case .loading: ScrollView { LoadingList(rows: 4).padding(20) }
            case .err(let e):
                EmptyState(icon: Ic.info, title: t("مقدرناش نقارن", "Couldn't compare"), bodyText: e.message,
                           action: e.code == "pro_required" ? t("شوف Pro", "See Pro") : nil) { router.push(.pro) }
                    .frame(maxHeight: .infinity)
            case .ok(let r): CompareTable(r: r)
            }
        }
        .background(PR.white)
        .task(id: ids) {
            guard ids.count >= 2 else { state = nil; return }
            if state?.value == nil { state = .loading }
            state = await load { try await app.api.compare(ids: ids) }
        }
    }
}

private let colW: CGFloat = 150, labelW: CGFloat = 96, rowH: CGFloat = 44, headH: CGFloat = 212

private struct CompareTable: View {
    var r: CompareResponse
    @Environment(AppState.self) private var app
    @Environment(Router.self) private var router
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if !r.sameCategory {
                    Text(t("المنتجات من أقسام مختلفة، فبعض المواصفات مش هتتقارن.", "These are from different categories, so some specs won't line up."))
                        .font(.bodyS).foregroundStyle(PR.amberDeep).padding(.horizontal, 20).padding(.vertical, 6)
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 8) {
                        VStack(alignment: .leading, spacing: 0) {
                            Spacer().frame(height: headH)
                            ForEach(Array(labels.enumerated()), id: \.offset) { _, l in
                                Text(l).font(.labelM).foregroundStyle(PR.inkSoft).lineLimit(2).frame(width: labelW, height: rowH, alignment: .leading)
                            }
                        }
                        ForEach(r.items) { p in column(p) }
                    }
                    .padding(.horizontal, 12)
                }
            }
            .padding(.bottom, 24)
        }
    }

    private var labels: [String] {
        [t("أفضل سعر شامل", "Best full price"), t("المتاجر", "Stores"), t("الماركة", "Brand"), t("الذاكرة", "Storage"),
         t("الرامات", "RAM"), t("اللون", "Colour")] + r.specKeys.map(specLabel)
    }

    private func column(_ p: ProductSummary) -> some View {
        let cheapest = p.id == r.cheapestId
        return VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                ZStack(alignment: .topTrailing) {
                    ProductImage(category: p.category, part: p.specs.str("part"), imageURL: p.imageUrl, size: 96, radius: 12)
                        .frame(maxWidth: .infinity).frame(height: 96)
                    Button { app.toggleCompare(p) } label: {
                        Image(systemName: Ic.close).font(.system(size: 11, weight: .bold)).foregroundStyle(PR.inkSoft)
                            .frame(width: 26, height: 26).background(PR.white).clipShape(Circle()).overlay(Circle().stroke(PR.line))
                    }
                    .accessibilityLabel(t("شيل", "Remove"))
                }
                Text(p.title).font(.labelL).foregroundStyle(PR.ink).lineLimit(3)
                Spacer(minLength: 0)
                if cheapest { Badge(t("الأرخص", "Cheapest"), .amber, icon: Ic.bolt) }
                Button(t("افتح المنتج", "Open")) { router.push(.product(p.id)) }.font(.labelM).foregroundStyle(PR.signalDeep)
            }
            .padding(10).frame(height: headH)
            cell { PriceText(value: p.bestTotal, font: .titleS, color: cheapest ? PR.amberDeep : PR.ink) }
            cell { Text(Fmt.number(p.offers)).font(.bodyM).foregroundStyle(PR.ink) }
            cell { Text(p.brand).font(.bodyM).foregroundStyle(PR.ink).lineLimit(1) }
            cell { Text(p.storage.isEmpty ? "—" : p.storage).font(.bodyM).foregroundStyle(PR.ink) }
            cell { Text(p.ram.isEmpty ? "—" : p.ram).font(.bodyM).foregroundStyle(PR.ink) }
            cell { Text(p.color.isEmpty ? "—" : p.color).font(.bodyM).foregroundStyle(PR.ink).lineLimit(1) }
            ForEach(r.specKeys, id: \.self) { k in cell { Text(specValue(k, p)).font(.bodyM).foregroundStyle(PR.ink).lineLimit(1) } }
        }
        .frame(width: colW)
        .background(cheapest ? PR.amberWash : PR.white)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(cheapest ? PR.amber : PR.line))
    }

    private func cell<V: View>(@ViewBuilder _ v: () -> V) -> some View {
        v().frame(maxWidth: .infinity, alignment: .leading).frame(height: rowH).padding(.horizontal, 10)
    }
}

private func specLabel(_ k: String) -> String {
    switch k {
    case "year": return t("السنة", "Year")
    case "km": return t("الكيلومترات", "Mileage")
    case "transmission": return t("ناقل الحركة", "Transmission")
    case "fuel": return t("الوقود", "Fuel")
    case "body": return t("الشكل", "Body")
    case "part": return t("النوع", "Type")
    case "socket": return t("السوكت", "Socket")
    case "ram_type": return t("نوع الرامات", "Memory type")
    case "watts": return t("القدرة", "Wattage")
    case "tdp": return "TDP"
    case "igpu": return t("كارت مدمج", "iGPU")
    case "capacity_gb": return t("السعة", "Capacity")
    case "score": return t("تقييم الأداء", "Performance score")
    case "instrument": return t("الآلة", "Instrument")
    case "level": return t("المستوى", "Level")
    case "strings": return t("الأوتار", "Strings")
    case "keys": return t("المفاتيح", "Keys")
    case "camera_mp": return t("الكاميرا (ميجابكسل)", "Camera (MP)")
    case "battery_mah": return t("البطارية (مللي أمبير)", "Battery (mAh)")
    case "chip_score": return t("الأداء /١٠٠", "Performance /100")
    case "screen_in": return t("الشاشة (بوصة)", "Screen (in)")
    case "seats": return t("الكراسي", "Seats")
    case "fuel_l_100km": return t("الاستهلاك (لتر/١٠٠ كم)", "Fuel (L/100 km)")
    case "warmth": return t("الدفا", "Warmth")
    case "material": return t("الخامة", "Material")
    case "sizes": return t("المقاسات", "Sizes")
    case "electric": return t("كهربا", "Electric")
    default: return k.replacingOccurrences(of: "_", with: " ")
    }
}

private func specValue(_ k: String, _ p: ProductSummary) -> String {
    guard let v = p.specs[k] else { return "—" }
    let raw: String
    switch v {
    case .string(let s): raw = s
    case .number(let n): raw = n == n.rounded() ? String(Int(n)) : String(n)
    case .bool(let b): raw = b ? "true" : "false"
    default: return "—"
    }
    switch k {
    case "transmission": return transmissionLabel(raw)
    case "fuel": return fuelLabel(raw)
    case "part": return partLabel(raw)
    case "instrument": return instrumentLabel(raw)
    case "level": return levelLabel(raw)
    case "igpu", "electric": return raw == "true" ? t("أيوه", "Yes") : t("لأ", "No")
    case "km": return Int(raw).map { Fmt.number($0) + t(" كم", " km") } ?? raw
    case "watts", "tdp": return "\(raw) W"
    case "capacity_gb": return "\(raw) GB"
    case "score": return "\(raw)/100"
    default: return raw
    }
}
