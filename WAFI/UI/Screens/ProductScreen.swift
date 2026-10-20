import SwiftUI

struct ProductScreen: View {
    var id: String
    @Environment(AppState.self) private var app
    @Environment(Router.self) private var router
    @State private var state: Load<ProductDetail> = .loading
    @State private var watched = false
    @State private var targetSheet = false
    @State private var proNeeded = false

    var body: some View {
        VStack(spacing: 0) {
            TopBar(title: "", onBack: { router.back() }) {
                if let d = state.value {
                    ShareLink(item: d.product.title + (d.best.map { " — " + Fmt.money($0.total) } ?? "")) {
                        Image(systemName: Ic.share).foregroundStyle(PR.ink).frame(width: 44, height: 44)
                    }
                    .accessibilityLabel(t("مشاركة", "Share"))
                    Button {
                        if !app.isSignedIn { router.push(.signIn) } else if watched { unwatch() } else { targetSheet = true }
                    } label: {
                        Image(systemName: watched ? Ic.heartFill : Ic.heart).foregroundStyle(watched ? PR.danger : PR.ink)
                            .frame(width: 44, height: 44).contentTransition(.symbolEffect(.replace))
                    }
                    .accessibilityLabel(t("متابعة السعر", "Watch price"))
                }
            }
            switch state {
            case .loading: ScrollView { LoadingList(rows: 6).padding(20) }
            case .err(let e):
                EmptyState(icon: Ic.info, title: t("مقدرناش نفتح المنتج", "Couldn't open this product"), bodyText: e.message,
                           action: t("حاول تاني", "Try again")) { Task { await reload() } }
                    .frame(maxHeight: .infinity)
            case .ok(let d):
                ProductBody(d: d)
                    .safeAreaInset(edge: .bottom) { AddBar { q in app.addToBasket(d.product.summary, qty: q) } }
            }
        }
        .background(PR.white)
        .task { if state.value == nil { await reload() } }
        .sheet(isPresented: $targetSheet) {
            if let d = state.value {
                TargetSheet(d: d) { target in targetSheet = false; watch(target) }
                    .presentationDetents([.medium, .large])
            }
        }
        .alert(t("وصلت للحد المجاني", "You've reached the free limit"), isPresented: $proNeeded) {
            Button(t("شوف برو", "See Pro")) { router.push(.pro) }
            Button(t("بعدين", "Later"), role: .cancel) {}
        } message: {
            let limit = app.config.freeWatchLimit
            Text(t("النسخة المجانية بتتابع لحد \(Fmt.number(limit)) منتجات. مع برو تابع براحتك ومن غير إعلانات.",
                   "The free plan watches up to \(limit) products. With Pro, watch as many as you like, with no ads."))
        }
    }

    private func reload() async {
        state = await load { try await app.api.product(id) }
        if app.isSignedIn, let list = try? await app.api.watchlist() { watched = list.contains { $0.productId == id } }
    }

    private func watch(_ target: Decimal?) {
        watched = true
        Task {
            do {
                try await app.api.watch(id, target: target)
                app.toast = t("هنبلّغك لما السعر ينزل", "We'll tell you when the price drops")
                if !Push.shared.hasAsked { _ = await Push.shared.requestPermission(); await Push.shared.registerIfSignedIn() }
            } catch let e as APIError {
                watched = false
                if e.code == "pro_required" { proNeeded = true } else { app.toast = e.message }
            } catch { watched = false }
        }
    }

    private func unwatch() {
        watched = false
        Task { do { try await app.api.unwatch(id) } catch { watched = true } }
    }
}

private struct ProductBody: View {
    var d: ProductDetail
    @Environment(AppState.self) private var app
    @Environment(Router.self) private var router

    var body: some View {
        let p = d.product
        let inCompare = app.compare.contains { $0.id == p.id }
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if p.imageUrl != nil {
                    ProductImage(category: p.category, part: p.specs.str("part"), imageURL: p.imageUrl, size: 220, radius: 24)
                        .frame(maxWidth: .infinity).frame(height: 220).padding(.horizontal, 20).padding(.vertical, 4)
                }
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 14) {
                        if p.imageUrl == nil { ProductImage(category: p.category, part: p.specs.str("part"), imageURL: nil, size: 72).frame(width: 72, height: 72) }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(p.title).font(.headlineS).foregroundStyle(PR.ink)
                            Text("\(p.brand) \(p.model)").font(.bodyM).foregroundStyle(PR.inkSoft)
                        }
                    }
                    HStack(spacing: 6) {
                        ForEach([p.storage, p.ram, p.color].filter { !$0.isEmpty }, id: \.self) { Badge($0) }
                        if p.condition != "new" { Badge(p.condition == "used" ? t("مستعمل", "Used") : t("مجدّد", "Refurbished"), .amber) }
                    }
                    HStack(spacing: 8) {
                        Chip(inCompare ? t("في المقارنة", "In compare") : t("قارن", "Compare"), selected: inCompare, icon: inCompare ? Ic.check : Ic.exchange) {
                            if !app.toggleCompare(p.summary) {
                                let n = app.compareLimit
                                app.toast = n >= 4 ? t("المقارنة فيها ٤ منتجات. شيل واحد الأول.", "Compare holds 4 products. Remove one first.")
                                    : t("المجاني بيقارن \(Fmt.number(n)) منتجات. مع Pro قارن لحد ٤.", "The free plan compares \(n) products. Pro compares up to 4.")
                            }
                        }
                        if app.compare.count >= 2 {
                            Button(t("افتح المقارنة (\(Fmt.number(app.compare.count)))", "Open compare (\(app.compare.count))")) { router.push(.compare) }
                                .font(.labelL).foregroundStyle(PR.signalDeep)
                        }
                    }
                    .padding(.top, 2)
                }
                .padding(.horizontal, 20)
                BestPrice(d: d)
                if let u = d.usedNew { UsedNewCard(u: u) }
                InsightCard(i: d.insight)
                if let l = d.lens { PriceLensCard(l: l) }
                if !["fashion", "other"].contains(p.category) { TradeInCard(toId: p.id, category: p.category) }
                HistoryCard(lows: d.dailyLows, limitDays: d.historyLimitDays)
                SpecsCard(s: p.specs)
                SectionHeader(title: t("كل العروض", "All offers") + " (\(Fmt.number(d.offers.count)))")
                    .padding(.horizontal, 20).padding(.top, 22).padding(.bottom, 4)
                Text(t("مرتّبة بالسعر الشامل. العروض الأقدم من \(Fmt.number(d.freshHours)) ساعة مش بتدخل في المقارنة.",
                       "Ranked by full price. Offers older than \(d.freshHours) hours aren't counted as cheapest."))
                    .font(.bodyS).foregroundStyle(PR.inkSoft).padding(.horizontal, 20).padding(.bottom, 6)
                ForEach(d.offers) { o in OfferRow(o: o, best: d.best?.offerId == o.id) }
                AdSlot(kind: .inline, placement: "product").padding(.top, 10)
            }
            .padding(.bottom, 24)
        }
    }
}

private struct BestPrice: View {
    var d: ProductDetail
    var body: some View {
        let best = d.best
        let bestOffer = d.offers.first { $0.id == best?.offerId }
        VStack(alignment: .leading, spacing: 6) {
            Text(best != nil ? t("أرخص سعر شامل دلوقتي", "Lowest full price now") : t("مفيش سعر مؤكد دلوقتي", "No confirmed price right now"))
                .font(.labelL).foregroundStyle(PR.inkSoft)
            AnimatedMoney(value: best?.total ?? d.offers.first?.price, font: .display, color: best != nil ? PR.ink : PR.inkSoft)
            HStack(spacing: 6) {
                if best != nil {
                    Badge(t("شامل الشحن والرسوم", "Shipping & fees included"), .signal, icon: Ic.check)
                    if let o = bestOffer { Badge(o.storeName, .amber, icon: Ic.store) }
                } else {
                    Badge(t("السعر قبل الشحن", "Price before shipping"))
                }
            }
            if let o = bestOffer {
                OfferMeta(store: nil, seenAt: o.observedAt, inStock: o.availability == "in_stock" ? true : o.availability == "out_of_stock" ? false : nil)
            }
            if let b = best, b.eligibleCount > 1 {
                Text(t("قارنّا \(Fmt.number(b.eligibleCount)) متجر عندهم المنتج متوفر", "Compared \(b.eligibleCount) stores with it in stock"))
                    .font(.bodyS).foregroundStyle(PR.inkSoft)
            }
        }
        .padding(18).frame(maxWidth: .infinity, alignment: .leading)
        .background(PR.white)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(PR.line))
        .shadow(color: PR.signal.opacity(0.18), radius: 12, y: 4)
        .padding(.horizontal, 20).padding(.vertical, 16)
    }
}

private struct InsightCard: View {
    var i: Insight
    var body: some View {
        let w = i.windowDays ?? 0
        let pct = i.percent.map { Fmt.number(abs($0), decimals: 1) } ?? ""
        let (tone, icon, title, text): (Tone, String, String, String) = {
            switch i.status {
            case "ok":
                switch i.verdict {
                case "lowest_observed": return (.signal, Ic.bolt, t("أقل سعر شفناه", "Lowest we've seen"), t("ده أقل سعر سجّلناه في آخر \(Fmt.number(w)) يوم.", "The lowest price recorded in the last \(w) days."))
                case "below_typical": return (.signal, Ic.chart, t("أقل من المعتاد", "Below typical"), t("أقل من متوسط آخر \(Fmt.number(w)) يوم بـ \(pct)٪.", "\(pct)% under the \(w)-day median."))
                case "above_typical": return (.amber, Ic.chart, t("أعلى من المعتاد", "Above typical"), t("لو مش مستعجل، استنى. السعر أعلى من متوسطه بـ \(pct)٪.", "If you can wait, wait: \(pct)% over its median."))
                default: return (.neutral, Ic.chart, t("سعر طبيعي", "Typical price"), t("السعر قريب من متوسط آخر \(Fmt.number(w)) يوم.", "Close to its \(w)-day median."))
                }
            case "insufficient_history":
                return (.sky, Ic.info, t("بنجمع تاريخ السعر", "Collecting price history"),
                        t("محتاجين \(Fmt.number(i.requiredDays ?? 0)) يوم من الأسعار عشان نقولك السعر ده كويس ولا لأ (عندنا \(Fmt.number(i.days ?? 0))).",
                          "We need \(i.requiredDays ?? 0) days of prices to judge this one (we have \(i.days ?? 0))."))
            default:
                return (.neutral, Ic.info, t("مفيش سعر حالي", "No current price"), t("مفيش عرض متوفر حالياً نقارن بيه.", "No in-stock offer to compare right now."))
            }
        }()
        Panel {
            HStack(alignment: .top, spacing: 10) {
                Badge(title, tone, icon: icon)
                Text(text).font(.bodyM).foregroundStyle(PR.ink).frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 20)
    }
}

private struct HistoryCard: View {
    var lows: [DailyLow]
    var limitDays: Int?
    @Environment(Router.self) private var router
    var body: some View {
        Panel {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(t("تاريخ السعر", "Price history")).font(.titleM).foregroundStyle(PR.ink)
                    Spacer()
                    if let limitDays { Text(t("آخر \(Fmt.number(limitDays)) يوم", "Last \(limitDays) days")).font(.labelS).foregroundStyle(PR.inkFaint) }
                }
                if limitDays != nil {
                    // the free plan sees a month; the verdict above still uses the whole history
                    Button { router.push(.pro) } label: {
                        HStack(spacing: 8) {
                            Image(systemName: Ic.crown).font(.system(size: 13)).foregroundStyle(PR.amberDeep)
                            Text(t("شوف تاريخ سنة كاملة مع Pro", "See a full year with Pro")).font(.labelM).foregroundStyle(PR.amberDeep)
                            Spacer()
                            Image(systemName: Ic.forward).font(.system(size: 12)).foregroundStyle(PR.amberDeep)
                        }
                        .padding(.horizontal, 12).padding(.vertical, 9).background(PR.amberWash).clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(Pressable())
                }
                if lows.count < 2 {
                    Text(t("لسه بنسجّل. الرسم هيظهر بعد يومين من الأسعار.", "Still recording. The chart appears after two days of prices."))
                        .font(.bodyS).foregroundStyle(PR.inkSoft)
                } else {
                    AreaChart(values: lows.map { NSDecimalNumber(decimal: $0.price).doubleValue }, color: PR.signal).frame(height: 150)
                    HStack {
                        stat(t("أقل", "Low"), Fmt.money(lows.map(\.price).min() ?? 0), PR.signalDeep)
                        stat(t("أعلى", "High"), Fmt.money(lows.map(\.price).max() ?? 0), PR.ink)
                        stat(t("الفترة", "Period"), t("\(Fmt.number(lows.count)) يوم", "\(lows.count) days"), PR.ink)
                    }
                }
            }
        }
        .padding(.horizontal, 20).padding(.vertical, 12)
    }
    private func stat(_ l: String, _ v: String, _ c: Color) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(l).font(.labelS).foregroundStyle(PR.inkSoft)
            Text(v).font(.titleS).foregroundStyle(c).lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Every spec we know how to name, in a fixed order.
func specRows(_ s: Specs) -> [(String, String)] {
    var r: [(String, String)] = []
    func num(_ k: String) -> String? {
        guard let v = s[k] else { return nil }
        if let d = v.double { return d == d.rounded() ? Fmt.number(Int(d)) : Fmt.number(d, decimals: 1) }
        return v.string
    }
    if let v = s.str("instrument") { r.append((t("الآلة", "Instrument"), instrumentLabel(v))) }
    if let v = s.flag("electric") { r.append((t("النوع", "Type"), v ? t("كهربا", "Electric") : t("أكوستيك", "Acoustic"))) }
    if let v = s.int("strings") { r.append((t("عدد الأوتار", "Strings"), Fmt.number(v))) }
    if let v = s.int("keys") { r.append((t("عدد المفاتيح", "Keys"), Fmt.number(v))) }
    if let v = s.str("level") { r.append((t("المستوى", "Level"), levelLabel(v))) }
    if let v = s.int("year") { r.append((t("سنة الصنع", "Year"), "\(v)")) }
    if let v = s.int("km") { r.append((t("الكيلومترات", "Mileage"), Fmt.number(v) + t(" كم", " km"))) }
    if let v = s.str("transmission") { r.append((t("ناقل الحركة", "Transmission"), transmissionLabel(v))) }
    if let v = s.str("fuel") { r.append((t("الوقود", "Fuel"), fuelLabel(v))) }
    if let v = s.str("part") { r.append((t("النوع", "Type"), partLabel(v))) }
    if let v = s.str("socket") { r.append((t("السوكت", "Socket"), v)) }
    if let v = s.str("ram_type") { r.append((t("نوع الرامات", "Memory type"), v)) }
    if let v = s.int("capacity_gb") { r.append((t("السعة", "Capacity"), "\(v) GB")) }
    if let v = s.int("watts") { r.append((t("القدرة", "Wattage"), "\(v) W")) }
    if let v = s.int("tdp") { r.append(("TDP", "\(v) W")) }
    if let v = s.flag("igpu") { r.append((t("كارت شاشة مدمج", "Integrated graphics"), v ? t("أيوه", "Yes") : t("لأ", "No"))) }
    if let v = s.int("seats") { r.append((t("عدد الكراسي", "Seats"), Fmt.number(v))) }
    if let v = num("fuel_l_100km") { r.append((t("الاستهلاك", "Fuel use"), v + t(" لتر/١٠٠ كم", " L/100 km"))) }
    if let v = s.int("camera_mp") { r.append((t("الكاميرا", "Camera"), Fmt.number(v) + t(" ميجابكسل", " MP"))) }
    if let v = s.int("battery_mah") { r.append((t("البطارية", "Battery"), Fmt.number(v) + t(" مللي أمبير", " mAh"))) }
    if let v = s.int("chip_score") { r.append((t("الأداء", "Performance"), Fmt.number(v) + "/100")) }
    if let v = num("screen_in") { r.append((t("الشاشة", "Screen"), v + "\"")) }
    if let v = s.int("warmth") {
        let names = [t("خفيف", "Light"), t("دفا خفيف", "Some"), t("دافي", "Warm"), t("دافي جداً", "Very warm")]
        r.append((t("الدفا", "Warmth"), names.indices.contains(v) ? names[v] : "\(v)"))
    }
    if let v = s.str("material") { r.append((t("الخامة", "Material"), v)) }
    if let a = s["sizes"]?.array { r.append((t("المقاسات", "Sizes"), a.compactMap(\.string).joined(separator: " · "))) }
    return r
}

private struct SpecsCard: View {
    var s: Specs
    var body: some View {
        let rows = specRows(s)
        if !rows.isEmpty {
            Panel {
                VStack(alignment: .leading, spacing: 10) {
                    Text(t("المواصفات", "Specifications")).font(.titleM).foregroundStyle(PR.ink)
                    ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                        HStack {
                            Text(row.0).font(.bodyM).foregroundStyle(PR.inkSoft)
                            Spacer()
                            Text(row.1).font(.titleS).foregroundStyle(PR.ink)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }
}

private struct OfferRow: View {
    var o: Offer
    var best: Bool
    var body: some View {
        let out = o.availability == "out_of_stock"
        Panel(background: best ? PR.amberWash : PR.white, border: best ? PR.amber : PR.line) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: Ic.store).foregroundStyle(PR.ink)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(o.storeName).font(.titleS).foregroundStyle(PR.ink)
                        if let s = Fmt.seen(o.observedAt) { Text(t("آخر تحديث ", "Updated ") + s).font(.labelS).foregroundStyle(PR.inkFaint) }
                    }
                    Spacer()
                    if best { Badge(t("أفضل سعر", "Best price"), .amber, icon: Ic.bolt) }
                    if o.sponsored { Badge(t("إعلان", "Ad")) }
                }
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 2) {
                        PriceText(value: o.total, font: .titleL, color: out ? PR.inkFaint : PR.ink)
                        Text(o.shippingFree ? t("شحن مجاني", "Free shipping")
                             : o.shipping != nil ? t("منها شحن ", "incl. shipping ") + Fmt.money(o.shipping!) : t("الشحن مش معروف", "Shipping unknown"))
                            .font(.bodyS).foregroundStyle(o.shipping == nil && !o.shippingFree ? PR.amberDeep : PR.inkSoft)
                    }
                    Spacer()
                    PRButton(t("زيارة المتجر", "Visit store"), kind: .outline, icon: Ic.external, height: 40) {
                        if o.url.hasPrefix("https://") { openURL(o.url) }      // never open non-HTTPS store links
                    }
                    .fixedSize()
                }
                HStack(spacing: 6) {
                    switch o.availability {
                    case "in_stock": Badge(t("متوفر", "In stock"), .signal)
                    case "out_of_stock": Badge(t("غير متوفر", "Out of stock"), .danger)
                    default: Badge(t("التوفر مش مؤكد", "Availability unknown"))
                    }
                    if !o.fresh { Badge(t("سعر قديم", "Old price"), .amber) }
                    if !o.warranty.isEmpty { Badge(o.warranty, .sky, icon: Ic.shield) }
                }
            }
        }
        .padding(.horizontal, 20).padding(.vertical, 5)
    }
}

/// Pick when to be alerted: any drop, a percentage below today's best, or an exact price.
private struct TargetSheet: View {
    var d: ProductDetail
    var onWatch: (Decimal?) -> Void
    @State private var choice = 5          // 0 = any drop, 5/10/15 = percent, -1 = custom
    @State private var custom = ""
    var body: some View {
        let now = d.best?.total ?? d.offers.first?.total
        var options: [(Int, String)] = [(0, t("أي نزول في السعر", "Any price drop"))]
        if let now { for pct in [5, 10, 15] { options.append((pct, t("لما ينزل \(Fmt.number(pct))٪ (", "When it drops \(pct)% (") + Fmt.money(pctBelow(now, pct)) + ")")) } }
        options.append((-1, t("سعر أحدده أنا", "A price I choose")))
        let target: Decimal? = choice == 0 ? nil : choice == -1 ? parseDecimal(custom).flatMap { $0 > 0 ? $0 : nil } : now.map { pctBelow($0, choice) }
        return ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text(t("نبلّغك إمتى؟", "When should we tell you?")).font(.headlineS).foregroundStyle(PR.ink).padding(.top, 24)
                if let now { Text(t("أرخص سعر دلوقتي ", "Lowest price now ") + Fmt.money(now)).font(.bodyM).foregroundStyle(PR.inkSoft) }
                ForEach(options, id: \.0) { opt in
                    Panel(padding: 14, background: choice == opt.0 ? PR.signalSoft : PR.white, border: choice == opt.0 ? PR.signal : PR.line, action: { choice = opt.0 }) {
                        Text(opt.1).font(.titleS).foregroundStyle(PR.ink)
                    }
                }
                if choice == -1 {
                    PRField(label: t("السعر المستهدف", "Target price"), text: $custom, icon: Ic.tag, keyboard: .decimalPad, ltr: true)
                }
                PRButton(t("تابع السعر", "Watch price"), icon: Ic.bell, enabled: choice != -1 || target != nil) { onWatch(target) }.padding(.top, 6)
            }
            .padding(.horizontal, 20).padding(.bottom, 28)
        }
        .background(PR.white)
    }
}

private func pctBelow(_ v: Decimal, _ pct: Int) -> Decimal {
    var x = v * Decimal(100 - pct) / 100, r = Decimal()
    NSDecimalRound(&r, &x, 0, .plain)
    return r
}

/// Quantity stepper + "add to basket", pinned to the bottom.
private struct AddBar: View {
    var onAdd: (Int) -> Void
    @State private var qty = 1
    @State private var added = false
    var body: some View {
        HStack(spacing: 12) {
            QtyStepper(value: qty) { qty = min(max($0, 1), 20) }
            PRButton(added ? t("اتضاف للسلة", "Added to basket") : t("أضف للسلة", "Add to basket"),
                     kind: added ? .dark : .primary, icon: added ? Ic.check : Ic.basket) {
                onAdd(qty)
                withAnimation { added = true }
            }
        }
        .padding(.horizontal, 20).padding(.vertical, 12)
        .background(PR.white.shadow(.drop(color: .black.opacity(0.06), radius: 8, y: -2)))
        .task(id: added) { if added { try? await Task.sleep(for: .seconds(1.6)); withAnimation { added = false } } }
    }
}

struct QtyStepper: View {
    var value: Int
    var onChange: (Int) -> Void
    var body: some View {
        HStack(spacing: 0) {
            Button { onChange(value - 1) } label: { Image(systemName: Ic.minus).foregroundStyle(PR.ink).frame(width: 40, height: 40) }
                .accessibilityLabel(t("أقل", "Less"))
            Text(Fmt.number(value)).font(.titleM).foregroundStyle(PR.ink).frame(width: 28).contentTransition(.numericText())
            Button { onChange(value + 1) } label: { Image(systemName: Ic.plus).foregroundStyle(PR.ink).frame(width: 40, height: 40) }
                .accessibilityLabel(t("أكتر", "More"))
        }
        .padding(4)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(PR.line))
        .animation(.easeOut(duration: 0.2), value: value)
    }
}
