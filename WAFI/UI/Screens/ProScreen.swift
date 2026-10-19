import SwiftUI

/// WAFI Pro through the App Store. Prices and trials come from App Store Connect; the purchase is verified by
/// the server before the app shows Pro. Apple requires a restore button and links to the terms and privacy policy.
struct ProScreen: View {
    @Environment(AppState.self) private var app
    @Environment(Router.self) private var router
    @State private var billing = Billing.shared
    @State private var chosen: String?
    @State private var glow = false

    var body: some View {
        VStack(spacing: 0) {
            TopBar(title: "", onBack: { router.back() })
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    hero
                    if !app.isPro { FreeVsPro() }
                    plans
                    if let m = billing.message {
                        Text(m).font(.bodyM).foregroundStyle(app.isPro ? PR.signalDeep : PR.amberDeep)
                    }
                    legal
                }
                .padding(.horizontal, 20).padding(.bottom, 16)
            }
            bottomButton.padding(20).background(PR.white)
        }
        .background(PR.white)
        .task { await billing.load() }
    }

    private var hero: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                Badge(app.isPro ? t("مشترك", "Active") : "Pro", .amber, icon: Ic.crown)
                Text(t("رادار من غير حدود،\nومن غير إعلانات", "An unlimited radar,\nwith no ads")).font(.headline).foregroundStyle(.white)
                Text(t("دوّر واسأل وتابع براحتك، والرادار يراقبلك وإنت نايم.", "Search, ask and watch freely; the radar keeps watch while you sleep."))
                    .font(.bodyM).foregroundStyle(.white.opacity(0.78))
            }
            Spacer(minLength: 0)
            WafiMark().frame(width: 96, height: 96).scaleEffect(glow ? 1.04 : 0.96)
                .animation(Motion.reduced ? nil : .easeInOut(duration: 1.8).repeatForever(autoreverses: true), value: glow)
        }
        .padding(22)
        .background(LinearGradient(colors: [PR.hero, PR.heroEnd, Color(hex: 0x1463F3)], startPoint: .topLeading, endPoint: .bottomTrailing))
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .onAppear { glow = true }
    }

    @ViewBuilder private var plans: some View {
        switch billing.state {
        case .loading:
            VStack(spacing: 10) { Skeleton(height: 76); Skeleton(height: 76) }
        case .unavailable:
            Panel(background: PR.paper, border: PR.paper) {
                HStack(spacing: 12) {
                    IconTile(icon: Ic.info, bg: PR.white, fg: PR.inkSoft, size: 40, iconSize: 19)
                    Text(t("الاشتراك متاح من App Store. اتأكد إنك داخل بـ Apple ID على الآيفون وإن المشتريات مسموحة.",
                           "Subscriptions come from the App Store. Make sure you're signed in with an Apple ID and purchases are allowed."))
                        .font(.bodyM).foregroundStyle(PR.inkSoft)
                }
            }
        case .ready(let list):
            VStack(spacing: 10) {
                let pick = chosen ?? list.last?.id
                ForEach(list) { p in
                    let sel = p.id == pick
                    Panel(radius: 20, background: sel ? PR.signalSoft : PR.white, border: sel ? PR.signal : PR.line, action: { chosen = p.id }) {
                        HStack(spacing: 12) {
                            Circle().stroke(sel ? PR.signal : PR.line, lineWidth: 2).frame(width: 22, height: 22)
                                .overlay(Circle().fill(sel ? PR.signal : .clear).frame(width: 11, height: 11))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(p.period == "P1Y" ? t("سنوي", "Yearly") : p.period == "P1W" ? t("أسبوعي", "Weekly") : t("شهري", "Monthly"))
                                    .font(.titleM).foregroundStyle(PR.ink)
                                Text(p.trial.map { t("أول \($0) ببلاش", "First \($0) free") } ?? t("تقدر تلغي في أي وقت", "Cancel any time"))
                                    .font(.bodyS).foregroundStyle(p.trial != nil ? PR.signalDeep : PR.inkSoft)
                            }
                            Spacer()
                            Text(p.price).font(.titleL).foregroundStyle(PR.ink)
                        }
                    }
                }
                Text(t("الاشتراك بيتجدد تلقائياً لحد ما تلغيه من إعدادات الآيفون ← Apple ID ← الاشتراكات، قبل نهاية المدة بـ ٢٤ ساعة على الأقل. الدفع من حساب Apple بتاعك.",
                       "Renews automatically unless cancelled in iPhone Settings → Apple ID → Subscriptions at least 24 hours before the period ends. Payment is charged to your Apple ID."))
                    .font(.bodyS).foregroundStyle(PR.inkFaint)
            }
        }
    }

    private var legal: some View {
        HStack(spacing: 16) {
            Button(t("استرجاع المشتريات", "Restore purchases")) { Task { await billing.restore() } }
            Button(t("الشروط", "Terms")) { openURL(app.serverURL.absoluteString + "/legal/terms") }
            Button(t("الخصوصية", "Privacy")) { openURL(app.serverURL.absoluteString + "/legal/privacy") }
        }
        .font(.labelM).foregroundStyle(PR.signalDeep)
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder private var bottomButton: some View {
        if app.isPro {
            PRButton(t("إنت مشترك في WAFI Pro ✓", "You're on Pro ✓"), kind: .outline) { router.back() }
        } else if !app.isSignedIn {
            PRButton(t("سجّل دخول عشان تشترك", "Sign in to subscribe"), kind: .dark) { router.push(.signIn) }
        } else {
            let ready: [Billing.ProductInfo] = { if case .ready(let l) = billing.state { return l }; return [] }()
            PRButton(t("اشترك", "Subscribe"), icon: Ic.crown, loading: billing.busy, enabled: !ready.isEmpty) {
                guard let id = chosen ?? ready.last?.id else { return }
                Task { await billing.buy(id) }
            }
        }
    }
}
