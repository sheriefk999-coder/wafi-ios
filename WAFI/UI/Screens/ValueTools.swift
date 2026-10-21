import SwiftUI

/// A tinted panel with an icon tile and title — the look shared by the value tools.
struct ValuePanel<Content: View>: View {
    var icon: String
    var title: String
    var tint: Color
    var wash: Color
    var action: (() -> Void)? = nil
    @ViewBuilder var content: () -> Content
    var body: some View {
        Panel(radius: 22, background: wash, border: tint.opacity(0.45), action: action) {
            HStack(alignment: .top, spacing: 12) {
                IconTile(icon: icon, bg: PR.white, fg: tint, size: 34, iconSize: 17)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.titleS).foregroundStyle(tint)
                    content()
                }
            }
        }
        .padding(.horizontal, 20).padding(.vertical, 6)
    }
}

private func vText(_ s: String) -> some View { Text(s).font(.bodyM).foregroundStyle(PR.ink) }
private func vNote(_ s: String) -> some View { Text(s).font(.labelS).foregroundStyle(PR.inkSoft) }
private func pct(_ v: Decimal) -> String { (v > 0 ? "+" : "") + Fmt.number(v, decimals: 1) + "٪" }

// MARK: - product page

/// The same product in the other condition: "available used for X — save Y" or "Y cheaper than new".
struct UsedNewCard: View {
    var u: UsedNew
    @Environment(Router.self) private var router
    var body: some View {
        if let used = u.used {
            ValuePanel(icon: Ic.tag, title: t("متوفر مستعمل", "Available used"), tint: PR.signalDeep, wash: PR.signalSoft, action: { router.push(.product(used.productId)) }) {
                let kind = used.condition == "refurb" ? t("متجدّد", "refurbished") : t("مستعمل", "used")
                vText(t("نفس المنتج \(kind) بـ ", "The same product \(kind) for ") + Fmt.money(used.price) + t(" — توفّر ", " — you save ")
                     + Fmt.money(used.saving) + " (\(Fmt.number(used.savingPct))٪)")
                vNote(t("المستعمل قرارك — اتأكد من الحالة والضمان. اضغط تشوف العروض.", "Buying used is your call — check condition and warranty. Tap to see offers."))
            }
        } else if let n = u.new {
            ValuePanel(icon: Ic.tag, title: t("أرخص من الجديد", "Cheaper than new"), tint: PR.signalDeep, wash: PR.signalSoft, action: { router.push(.product(n.productId)) }) {
                vText(t("الجديد منه بـ ", "New, it costs ") + Fmt.money(n.price) + t("، يعني المستعمل ده بيوفّرلك ", ", so this one saves you ")
                     + Fmt.money(n.saving) + " (\(Fmt.number(n.savingPct))٪).")
                vNote(t("اضغط تشوف الجديد", "Tap to see the new one"))
            }
        }
    }
}

/// The price through the dollar and 21k gold, and how it moved in pounds vs dollars over ~a month.
struct PriceLensCard: View {
    var l: PriceLens
    var body: some View {
        ValuePanel(icon: Ic.globe, title: t("السعر بعين الدولار والدهب", "The price in dollars and gold"), tint: PR.amberDeep, wash: PR.amberWash) {
            let grams = l.gold21Grams.map { t(" · ≈ \(Fmt.number($0, decimals: 1)) جرام دهب عيار ٢١", " · ≈ \(Fmt.number($0, decimals: 1)) g of 21k gold") } ?? ""
            vText("≈ $" + Fmt.number(l.usd) + grams)
            if let e = l.egpChangePct, let u = l.usdChangePct {
                vText(t("من شهر: بالجنيه \(pct(e)) · بالدولار \(pct(u))", "Over a month: \(pct(e)) in EGP · \(pct(u)) in USD"))
                if abs(NSDecimalNumber(decimal: u - e).doubleValue) >= 3 {
                    vNote(u < e ? t("يعني السعر الحقيقي نزل أكتر من اللي باين بالجنيه.", "So in real terms it fell more than the pound price shows.")
                                : t("يعني السعر الحقيقي طلع أكتر من اللي باين بالجنيه.", "So in real terms it rose more than the pound price shows."))
                }
            } else {
                vNote(t("بنحسب بسعر الدولار والدهب النهارده.", "At today's dollar and gold rates."))
            }
        }
    }
}

/// "Selling your old one?" — pick what you own, get its used market value and the upgrade's net cost.
struct TradeInCard: View {
    var toId: String
    var category: String
    @Environment(AppState.self) private var app
    @Environment(Router.self) private var router
    @State private var open = false
    var body: some View {
        VStack(spacing: 0) {
            ValuePanel(icon: Ic.exchange, title: t("هتبيع القديم؟", "Selling your old one?"), tint: PR.sky, wash: PR.skySoft, action: { open.toggle() }) {
                vText(t("اختار اللي معاك ونقولك بيتباع مستعمل بكام، والفرق اللي هتدفعه فعلاً.", "Pick what you own: we'll show what it sells for used and what the upgrade really costs."))
            }
            .accessibilityIdentifier("tradeInCard")
            // opens right under the card, so it stays with the product (same as Android)
            if open {
                Panel(radius: 22, background: PR.white, border: PR.sky.opacity(0.45)) {
                    TradeInSheet(toId: toId, category: category, guestBlocked: !app.isSignedIn && app.config.searchRequiresAccount) {
                        router.push(.signIn)
                    }
                }
                .padding(.horizontal, 20).padding(.vertical, 4)
            }
        }
    }
}

private struct TradeInSheet: View {
    var toId: String
    var category: String
    var guestBlocked: Bool
    var onSignIn: () -> Void
    @State private var q = ""
    @State private var hits: [SuggestProduct] = []
    @State private var result: TradeIn?
    @State private var busy = false
    @State private var failed = false
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
                Text(t("فرق التغيير", "Upgrade cost")).font(.titleM).foregroundStyle(PR.ink)
                if guestBlocked {
                    vText(t("سجّل حسابك المجاني الأول عشان تدوّر على جهازك.", "Sign in with a free account first to look up your device."))
                    PRButton(t("دخول / حساب جديد", "Sign in / create account"), action: onSignIn)
                } else if let r = result {
                    resultView(r)
                } else {
                    PRField(label: t("اكتب اسم اللي معاك (مثلاً iPhone 13)", "Type what you own (e.g. iPhone 13)"), text: $q, icon: Ic.search)
                    if busy { vNote(t("بنحسب…", "Working it out…")) }
                    if failed { vNote(t("مقدرناش نحسب دلوقتي، جرّب تاني.", "Couldn't work it out right now, try again.")) }
                    ForEach(hits) { h in
                        Button { pick(h) } label: {
                            HStack(spacing: 10) {
                                Image(systemName: Ic.phone).foregroundStyle(PR.inkSoft)
                                Text(Lang.isArabic ? h.titleAr : h.titleEn).font(.bodyM).foregroundStyle(PR.ink)
                                Spacer()
                            }
                            .padding(12).background(PR.paper).clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(Pressable())
                    }
                }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .task(id: q) {
            let s = q.trimmingCharacters(in: .whitespaces)
            guard s.count >= 2, !guestBlocked else { hits = []; return }
            try? await Task.sleep(for: .milliseconds(250))
            if Task.isCancelled { return }
            if let r = try? await AppState.shared.api.suggest(s) {
                hits = Array(r.products.filter { $0.id != toId && $0.category == category }.prefix(6))
            }
        }
    }

    private func pick(_ h: SuggestProduct) {
        busy = true; failed = false
        Task {
            do { result = try await AppState.shared.api.tradeIn(from: h.id, to: toId) } catch { failed = true }
            busy = false
        }
    }

    @ViewBuilder private func resultView(_ r: TradeIn) -> some View {
        let from = Lang.isArabic ? r.from.titleAr : r.from.titleEn
        let to = Lang.isArabic ? r.to.titleAr : r.to.titleEn
        if r.status == "ok", let resale = r.resale, let net = r.netCost {
            vNote(from + " → " + to)
            Panel(radius: 18, background: PR.signalSoft, border: PR.signal) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack { Text(t("بيتباع مستعمل حوالي", "Sells used for about")).foregroundStyle(PR.inkSoft); Spacer(); Text(Fmt.money(resale.median)).foregroundStyle(PR.ink) }
                    vNote(t("من \(Fmt.number(r.listings)) عرض: ", "From \(r.listings) listings: ") + Fmt.money(resale.low) + " – " + Fmt.money(resale.high))
                    if let p = r.to.price {
                        HStack { Text(t("سعر الجديد", "The new one")).foregroundStyle(PR.inkSoft); Spacer(); Text(Fmt.money(p)).foregroundStyle(PR.ink) }
                    }
                    HStack {
                        Text(t("الفرق اللي هتدفعه", "You'd pay the difference")).font(.titleS).foregroundStyle(PR.signalDeep)
                        Spacer()
                        Text(Fmt.money(net)).font(.titleM).foregroundStyle(PR.signalDeep)
                    }
                }
            }
            vNote(Lang.isArabic ? r.noteAr : r.noteEn)
        } else {
            vText(t("لسه مفيش عروض مستعمل لـ \(from) نقيس عليها.", "There are no used listings for \(from) to go by yet."))
        }
        PRButton(t("جرّب جهاز تاني", "Try another device"), kind: .outline) { result = nil }
    }
}

// MARK: - advisor

/// The advisor's used-vs-new lead line.
struct UsedLeadCard: View {
    var ua: PickUsedAdvice
    @Environment(Router.self) private var router
    var body: some View {
        if let s = ua.stepUp {
            ValuePanel(icon: Ic.bolt, title: t("بنفس ميزانيتك… أعلى فئة", "Same budget, a tier up"), tint: PR.signalDeep, wash: PR.signalSoft,
                       action: { router.push(.product(s.used.productId)) }) {
                let title = Lang.isArabic ? s.titleAr : s.titleEn
                vText(t("\(title) جديد بـ ", "\(title) is ") + Fmt.money(s.newPrice) + t("، بس متوفر مستعمل بـ ", " new, but available used for ")
                     + Fmt.money(s.used.price) + t(" — يدخل في ميزانيتك ويتفوّق على الترشيح الأول.", " — inside your budget and ahead of the top pick."))
                ForEach((Lang.isArabic ? s.reasonsAr : s.reasonsEn).prefix(2), id: \.self) { vNote("• " + $0) }
                vNote(Lang.isArabic ? ua.noteAr : ua.noteEn)
            }
        } else if let s = ua.save {
            ValuePanel(icon: Ic.tag, title: t("فكرة توفير", "A way to save"), tint: PR.signalDeep, wash: PR.signalSoft,
                       action: { router.push(.product(s.used.productId)) }) {
                let title = Lang.isArabic ? s.titleAr : s.titleEn
                vText(t("لو جبت \(title) مستعمل هتوفّر ", "Get \(title) used and save ") + Fmt.money(s.used.saving)
                     + " (\(Fmt.number(s.used.savingPct))٪) — " + Fmt.money(s.used.price) + t(" بدل ", " instead of ") + Fmt.money(s.newPrice) + ".")
                vNote(Lang.isArabic ? ua.noteAr : ua.noteEn)
            }
        }
    }
}

/// Lines under a pick: its used counterpart, or for a used pick its saving vs new, and a car's monthly fuel.
struct PickValueLines: View {
    var p: Pick
    var body: some View {
        if let u = p.used {
            line(Ic.tag, t("متوفر مستعمل بـ ", "Available used for ") + Fmt.money(u.price) + t(" · وفّر ", " · save ") + Fmt.money(u.saving), PR.signalDeep)
        }
        if let n = p.vsNew {
            line(Ic.tag, t("أرخص من الجديد بـ ", "Cheaper than new by ") + Fmt.money(n.saving) + " (\(Fmt.number(n.savingPct))٪)", PR.signalDeep)
        }
        if let r = p.running {
            if r.electric { line(Ic.bolt, t("كهربا: من غير بنزين", "Electric: no fuel bill"), PR.sky) }
            else if let m = r.monthly {
                line(Ic.gauge, t("بنزين ≈ ", "Fuel ≈ ") + Fmt.money(m) + t(" في الشهر (\(Fmt.number(r.kmMonth)) كم)", " a month (\(r.kmMonth) km)"), PR.sky)
            }
        }
    }
    private func line(_ icon: String, _ text: String, _ tint: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).font(.system(size: 12, weight: .bold)).foregroundStyle(tint)
            Text(text).font(.bodyS).foregroundStyle(tint)
        }
    }
}

/// Cars: the yearly fuel gap between the cheapest and dearest pick to run.
struct RunningSummaryCard: View {
    var rs: RunningSummary
    var body: some View {
        if let gap = rs.yearlyGap, gap > 0 {
            ValuePanel(icon: Ic.gauge, title: t("تكلفة التشغيل", "Running cost"), tint: PR.sky, wash: PR.skySoft) {
                let cheap = Lang.isArabic ? rs.cheapestTitleAr : rs.cheapestTitleEn
                let dear = Lang.isArabic ? rs.dearestTitleAr : rs.dearestTitleEn
                vText(t("\(cheap) بتوفّر حوالي ", "\(cheap) saves about ") + Fmt.money(gap) + t(" بنزين في السنة عن \(dear).", " a year in fuel over \(dear)."))
                if let f = rs.fuelPrice {
                    vNote(t("على \(Fmt.number(rs.kmMonth)) كم في الشهر وسعر اللتر \(Fmt.money(f)) — تقدير من الاستهلاك المعلن.",
                            "At \(rs.kmMonth) km a month and \(Fmt.money(f)) a litre — estimated from stated consumption."))
                }
            }
        }
    }
}

// MARK: - search

/// Shown instead of results when a guest searches and the console requires an account.
struct SignInWall: View {
    @Environment(Router.self) private var router
    var body: some View {
        Panel(padding: 20, radius: 24, background: PR.signalSoft, border: PR.signal) {
            VStack(spacing: 10) {
                Image(systemName: "person.crop.circle").font(.system(size: 34, weight: .medium)).foregroundStyle(PR.signalDeep)
                Text(t("سجّل حسابك عشان تبحث", "Sign in to search")).font(.titleL).foregroundStyle(PR.ink).multilineTextAlignment(.center)
                Text(t("حساب مجاني في ثواني: تبحث في كل المتاجر، تتابع الأسعار، ويوصلك تنبيه لما السعر ينزل. الفئات مفتوحة تتصفّحها من غير حساب.",
                       "A free account takes seconds: search every store, watch prices and get alerts when they drop. Categories stay open to browse."))
                    .font(.bodyM).foregroundStyle(PR.inkSoft).multilineTextAlignment(.center)
                PRButton(t("إنشاء حساب مجاني", "Create a free account")) { router.push(.signUp) }
                PRButton(t("عندي حساب — دخول", "I have an account — sign in"), kind: .outline) { router.push(.signIn) }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 20).padding(.vertical, 12)
    }
}
