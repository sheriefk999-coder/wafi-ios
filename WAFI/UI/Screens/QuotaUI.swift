import SwiftUI

/// "٤ س ١٢ د" / "4h 12m".
func formatWait(_ seconds: Int) -> String {
    let s = max(0, seconds), h = s / 3600, m = (s % 3600) / 60, sec = s % 60
    if h > 0 { return t("\(Fmt.number(h)) س \(Fmt.number(m)) د", "\(h)h \(m)m") }
    if m > 0 { return t("\(Fmt.number(m)) د \(Fmt.number(sec)) ث", "\(m)m \(sec)s") }
    return t("\(Fmt.number(sec)) ث", "\(sec)s")
}

/// "١٥ كل ٨ ساعات" / "15 per 8h"; 0 = unlimited.
func perWindow(_ r: QuotaRule) -> String {
    if r.limit <= 0 { return t("من غير حد", "Unlimited") }
    let unit = (3...10).contains(r.windowHours) ? "ساعات" : "ساعة"
    return t("\(Fmt.number(r.limit)) كل \(Fmt.number(r.windowHours)) \(unit)", "\(r.limit) per \(r.windowHours)h")
}

/// Shown instead of results when a free quota is used up: what happened, a live countdown until it frees up,
/// and the way out (Pro). When the countdown ends, [onReady] lets the screen try again.
struct QuotaWall: View {
    var error: APIError
    var onReady: () -> Void = {}
    @Environment(Router.self) private var router
    @State private var left = 0

    var body: some View {
        let q = error.quota
        let limit = q?.limit ?? 0
        let (title, text): (String, String) = {
            switch q?.kind {
            case "assistant": return (t("خلصت رسايل المساعد المجانية", "You've used your free assistant messages"),
                                      t("المجاني فيه \(Fmt.number(limit)) رسايل. مع Pro اسأل براحتك.", "The free plan includes \(limit) messages. With Pro, ask as much as you like."))
            case "advisor": return (t("خلصت ترشيحات المستشار المجانية", "You've used your free advisor picks"),
                                    t("المجاني فيه \(Fmt.number(limit)) ترشيحات. مع Pro رشّح براحتك.", "The free plan includes \(limit) picks. With Pro, there's no limit."))
            default: return (t("خلصت عمليات البحث المجانية", "You've used your free searches"),
                             t("المجاني فيه \(Fmt.number(limit)) عملية بحث. مع Pro دوّر من غير حد.", "The free plan includes \(limit) searches. With Pro, search without limits."))
            }
        }()
        VStack(spacing: 8) {
            Image(systemName: "clock").font(.system(size: 32, weight: .medium)).foregroundStyle(.white)
            Text(title).font(.titleL).foregroundStyle(.white).multilineTextAlignment(.center)
            Text(text).font(.bodyM).foregroundStyle(.white.opacity(0.78)).multilineTextAlignment(.center)
            if left > 0 {
                Text(t("تقدر تكمل تاني بعد", "You can continue in")).font(.labelM).foregroundStyle(.white.opacity(0.65)).padding(.top, 4)
                Text(formatWait(left)).font(.headline).foregroundStyle(.white).contentTransition(.numericText()).monospacedDigit()
            }
            PRButton(t("اشترك في Pro", "Get Pro"), kind: .gold, icon: Ic.crown) { router.push(.pro) }.padding(.top, 6)
        }
        .padding(22)
        .frame(maxWidth: .infinity)
        .background(LinearGradient(colors: [PR.hero, PR.heroEnd], startPoint: .topLeading, endPoint: .bottomTrailing))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .padding(.horizontal, 20).padding(.vertical, 12)
        .task(id: error) {
            left = q?.retryIn ?? 0
            guard left > 0 else { return }
            while left > 0 {
                try? await Task.sleep(for: .seconds(1))
                if Task.isCancelled { return }
                left -= 1
            }
            onReady()
        }
    }
}

/// "باقيلك ٣ عمليات بحث" under the search box once the free plan is running low.
struct QuotaHint: View {
    var left: Int?
    @Environment(Router.self) private var router
    var body: some View {
        if let left, left <= 5 {
            Button { router.push(.pro) } label: {
                HStack(spacing: 8) {
                    Image(systemName: Ic.search).font(.system(size: 13, weight: .semibold))
                    Text(left == 0 ? t("ده آخر بحث مجاني دلوقتي", "That was your last free search for now")
                                   : t("باقيلك \(Fmt.number(left)) عمليات بحث مجانية", "\(left) free searches left"))
                    Spacer()
                    Text(t("Pro من غير حد", "Unlimited with Pro"))
                }
                .font(.labelM).foregroundStyle(PR.signalDeep)
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(PR.signalSoft).clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(Pressable())
            .padding(.horizontal, 20).padding(.vertical, 6)
        }
    }
}

/// Free vs Pro, with the numbers the owner set in the console.
struct FreeVsPro: View {
    @Environment(AppState.self) private var app
    var body: some View {
        let c = app.config, q = c.quotas
        let unl = t("من غير حد", "Unlimited")
        let rows: [(String, String, String)] = [
            (t("البحث", "Search"), perWindow(q.search), unl),
            (t("المساعد الذكي", "AI assistant"), perWindow(q.assistant), unl),
            (t("ترشيحات المستشار", "Advisor picks"), perWindow(q.advisor), unl),
            (t("قائمة المتابعة", "Watchlist"), t("\(Fmt.number(c.freeWatchLimit)) منتجات", "\(c.freeWatchLimit) products"), unl),
            (t("تاريخ السعر", "Price history"), t("\(Fmt.number(c.freeHistoryDays)) يوم", "\(c.freeHistoryDays) days"), t("سنة", "1 year")),
            (t("محفظتي", "Wallet"), t("\(Fmt.number(c.freeWalletItems)) حاجات", "\(c.freeWalletItems) items"), unl),
            (t("تنبيه الدهب والدولار", "Gold & dollar alerts"), "—", Fmt.number(c.proMarketAlerts)),
            (t("المقارنة", "Compare"), t("\(Fmt.number(q.compareItems)) منتجات", "\(q.compareItems) products"), t("٤ منتجات", "4 products")),
            (t("السلة الذكية", "Smart basket"), t("\(Fmt.number(q.basketItems)) منتجات", "\(q.basketItems) products"), t("١٥ منتج", "15 products")),
            (t("الإعلانات", "Ads"), t("فيه", "Yes"), t("مفيش", "None")),
        ]
        VStack(spacing: 0) {
            HStack {
                Text(t("الميزة", "Feature")).frame(maxWidth: .infinity, alignment: .leading).layoutPriority(1.3)
                Text(t("مجاني", "Free")).frame(maxWidth: .infinity, alignment: .leading)
                Text("Pro").foregroundStyle(PR.signalDeep).frame(width: 96, alignment: .leading)
            }
            .font(.labelM).foregroundStyle(PR.inkSoft)
            .padding(.horizontal, 14).padding(.vertical, 10).background(PR.paper)
            ForEach(Array(rows.enumerated()), id: \.offset) { i, r in
                HStack {
                    Text(r.0).font(.titleS).foregroundStyle(PR.ink).frame(maxWidth: .infinity, alignment: .leading).layoutPriority(1.3)
                    Text(r.1).font(.bodyS).foregroundStyle(PR.inkSoft).frame(maxWidth: .infinity, alignment: .leading)
                    HStack(spacing: 4) {
                        Image(systemName: Ic.check).font(.system(size: 11, weight: .bold)).foregroundStyle(PR.signal)
                        Text(r.2).font(.labelL).foregroundStyle(PR.ink).lineLimit(1).minimumScaleFactor(0.8)
                    }
                    .frame(width: 96, alignment: .leading)
                }
                .padding(.horizontal, 14).padding(.vertical, 10)
                if i < rows.count - 1 { Divider().overlay(PR.line).padding(.horizontal, 14) }
            }
        }
        .background(PR.white)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(PR.line))
    }
}
