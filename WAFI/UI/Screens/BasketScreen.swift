import SwiftUI

struct BasketScreen: View {
    @Environment(AppState.self) private var app
    @Environment(Router.self) private var router
    @State private var plan: Load<BasketResponse>?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(t("السلة الذكية", "Smart basket")).font(.headline).foregroundStyle(PR.ink)
                        Text(t("حط اللي عايز تشتريه، وإحنا نقولك أرخص طريقة تشتريه بيها.", "Add what you want; we find the cheapest way to buy it."))
                            .font(.bodyS).foregroundStyle(PR.inkSoft)
                    }
                    Spacer()
                    if !app.basket.isEmpty {
                        Button { withAnimation { app.basket = []; plan = nil } } label: {
                            Image(systemName: Ic.trash).foregroundStyle(PR.inkSoft).frame(width: 44, height: 44)
                        }
                        .accessibilityLabel(t("فضّي السلة", "Empty basket"))
                    }
                }
                .padding(.leading, 20).padding(.trailing, 8).padding(.top, 16).padding(.bottom, 4)

                if app.basket.isEmpty {
                    EmptyState(icon: Ic.basket, title: t("سلتك فاضية", "Your basket is empty"),
                               bodyText: t("ضيف منتجات من صفحة أي منتج، أو جمّع PC وضيفه كله مرة واحدة.", "Add products from any product page, or build a PC and add it all at once."),
                               action: t("تصفّح المنتجات", "Browse products")) { router.select(.search) }
                        .padding(.top, 30)
                }
                ForEach(app.basket) { l in
                    LineRow(l: l)
                }
                if !app.basket.isEmpty {
                    let est = app.basket.compactMap { l in l.price.map { $0 * Decimal(l.qty) } }.reduce(0, +)
                    HStack {
                        Text(t("تقدير مبدئي", "Rough estimate")).font(.bodyM).foregroundStyle(PR.inkSoft)
                        Spacer()
                        PriceText(value: est, font: .titleM)
                    }
                    .padding(.horizontal, 20).padding(.vertical, 12)
                    PRButton(t("احسب أرخص خطة", "Find the cheapest plan"), kind: .dark, icon: Ic.sparkle, loading: plan?.isLoading == true) {
                        Task { await compute() }
                    }
                    .padding(.horizontal, 20)
                }
                switch plan {
                case nil: EmptyView()
                case .loading: LoadingList(rows: 3).padding(20)
                case .err(let e):
                    if e.code == "pro_required" {
                        EmptyState(icon: Ic.crown, title: t("السلة أكبر من المجاني", "The basket is over the free size"),
                                   bodyText: t("المجاني بيحسب أرخص خطة لحد \(Fmt.number(e.quota?.limit ?? 8)) منتجات. شيل منتج أو اشترك في Pro (لحد ١٥).",
                                               "The free plan plans up to \(e.quota?.limit ?? 8) products. Remove one or get Pro (up to 15)."),
                                   action: t("شوف Pro", "See Pro")) { router.push(.pro) }
                            .padding(.top, 20)
                    } else {
                        EmptyState(icon: Ic.info, title: t("مقدرناش نحسب", "Couldn't compute"), bodyText: e.message, action: t("حاول تاني", "Try again")) {
                            Task { await compute() }
                        }
                        .padding(.top, 20)
                    }
                case .ok(let b): PlanResult(b: b).transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
            .padding(.bottom, 90)
        }
        .background(PR.white)
        .onChange(of: app.basket) { _, _ in plan = nil }
    }

    private func compute() async {
        plan = .loading
        let lines = app.basket.map { BasketLineIn(productId: $0.productId, qty: $0.qty) }
        let r = await load { try await app.api.basket(lines) }
        withAnimation { plan = r }
    }
}

private struct LineRow: View {
    var l: BasketLine
    @Environment(AppState.self) private var app
    @Environment(Router.self) private var router
    var body: some View {
        Panel(padding: 12, action: { router.push(.product(l.productId)) }) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(l.title).font(.titleS).foregroundStyle(PR.ink).lineLimit(2)
                    PriceText(value: l.price, font: .bodyM, color: PR.inkSoft)
                }
                Spacer(minLength: 0)
                QtyStepper(value: l.qty) { app.setQty(l.productId, $0) }
            }
        }
        .padding(.horizontal, 20).padding(.vertical, 5)
    }
}

private struct PlanResult: View {
    var b: BasketResponse
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let rec = b.recommended {
                PlanCard(plan: rec, b: b, recommended: true)
            } else {
                Panel(background: PR.amberSoft, border: PR.amberSoft) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(t("مفيش خطة كاملة دلوقتي", "No complete plan right now")).font(.titleS).foregroundStyle(PR.amberDeep)
                        Text(t("في منتجات مش متوفرة حالياً، أو متجر مش معروف تكلفة الشحن عنده. مش هنقترح خطة مش متأكدين من إجماليها.",
                               "Some products aren't in stock, or a store's shipping cost is unknown. We won't suggest a plan whose total we can't confirm."))
                            .font(.bodyM).foregroundStyle(PR.ink)
                    }
                }
                if let s = b.singleStore.first { PlanCard(plan: s, b: b, recommended: false) }
            }
            if !b.unavailableProducts.isEmpty {
                Text(t("مش متوفر: ", "Unavailable: ") + b.unavailableProducts.map { id in b.products[id].map { Lang.isArabic ? $0.titleAr : $0.titleEn } ?? id }.joined(separator: "، "))
                    .font(.bodyS).foregroundStyle(PR.danger)
            }
        }
        .padding(20)
    }
}

private struct PlanCard: View {
    var plan: BasketPlan
    var b: BasketResponse
    var recommended: Bool
    var body: some View {
        Panel(radius: 22, border: recommended ? PR.signal : PR.line) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(recommended ? t("الخطة اللي ننصحك بيها", "Recommended plan") : t("خطة ناقصة (للعلم بس)", "Incomplete plan (for reference)"))
                        .font(.titleM).foregroundStyle(PR.ink)
                    Spacer()
                    if recommended && b.optimal { Badge(t("أرخص خطة ممكنة", "Cheapest possible"), .signal, icon: Ic.check) }
                }
                Badge(plan.kind == "single_store" ? t("من متجر واحد", "One store") : t("مقسّمة على \(Fmt.number(plan.stores.count)) متاجر", "Split across \(plan.stores.count) stores"), .sky)
                ForEach(plan.stores, id: \.storeId) { s in
                    Divider().overlay(PR.line)
                    HStack(spacing: 10) {
                        IconTile(icon: Ic.store, size: 36, iconSize: 17)
                        Text(s.storeName).font(.titleS).foregroundStyle(PR.ink)
                        Spacer()
                        if plan.shippingUnknown.contains(s.storeId) { Badge(t("الشحن مش معروف", "Shipping unknown"), .amber) }
                        if plan.belowMinOrder.contains(s.storeId) { Badge(t("أقل من الحد الأدنى", "Below minimum order"), .amber) }
                    }
                    ForEach(s.lines, id: \.productId) { l in
                        HStack {
                            Text("\(l.qty) × " + (b.products[l.productId].map { Lang.isArabic ? $0.titleAr : $0.titleEn } ?? ""))
                                .font(.bodyS).foregroundStyle(PR.inkSoft).lineLimit(1)
                            Spacer()
                            Text(Fmt.money(l.unitPrice)).font(.bodyS).foregroundStyle(PR.ink)
                        }
                        .padding(.leading, 46)
                    }
                }
                Divider().overlay(PR.line)
                row(t("المنتجات", "Items"), plan.subtotal)
                row(t("الشحن", "Shipping"), plan.shipping)
                HStack {
                    Text(t("الإجمالي", "Total")).font(.titleM).foregroundStyle(PR.ink)
                    Spacer()
                    AnimatedMoney(value: plan.total, font: .headlineS)
                }
                if recommended {
                    Text(t("الشراء بيتم من المتاجر نفسها: افتح كل منتج واضغط «زيارة المتجر».", "You buy from the stores themselves: open each product and tap “Visit store”."))
                        .font(.bodyS).foregroundStyle(PR.inkSoft)
                }
            }
        }
    }
    private func row(_ l: String, _ v: Decimal) -> some View {
        HStack { Text(l).font(.bodyM).foregroundStyle(PR.inkSoft); Spacer(); PriceText(value: v, font: .bodyM) }
    }
}
