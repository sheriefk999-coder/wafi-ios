import SwiftUI

// MARK: - Account tab

struct AccountScreen: View {
    @Environment(AppState.self) private var app
    @Environment(Router.self) private var router

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text(t("حسابي", "Account")).font(.headline).foregroundStyle(PR.ink).padding(.horizontal, 20).padding(.top, 16).padding(.bottom, 12)
                if let u = app.user { signedIn(u) } else { guest }
                if app.config.pro.enabled || app.isPro { ProCard().padding(.top, 14) }
                VStack(spacing: 0) {
                    ItemRow(icon: Ic.heart, title: t("المنتجات اللي بتابعها", "Watchlist")) { router.push(app.isSignedIn ? .watchlist : .signIn) }
                    ItemRow(icon: Ic.bell, title: t("التنبيهات", "Alerts")) { router.push(app.isSignedIn ? .alerts : .signIn) }
                    ItemRow(icon: Ic.wallet, title: t("محفظتي", "My wallet"), value: t("دهبك وتحويشة العملات", "Your gold and savings")) { router.push(.wallet) }
                    ItemRow(icon: Ic.basket, title: t("السلة الذكية", "Smart basket")) { router.select(.basket) }
                }
                .modifier(RowGroup())
                .padding(.top, 14)
                if app.config.features.advisor {
                    ItemRow(icon: Ic.compass, title: t("المستشار", "Advisor"), value: t("قولّه محتاج إيه، يرشّحلك ويقولك ليه", "Tell it what you need; it picks and explains")) {
                        router.push(.advisor)
                    }
                    .modifier(RowGroup())
                }
                VStack(spacing: 0) {
                    ItemRow(icon: Ic.globe, title: t("البلد", "Country"), value: "\(app.country.flag) \(app.country.name) · \(app.country.currency)") { router.push(.country) }
                    ItemRow(icon: Ic.gear, title: t("الإعدادات", "Settings"), value: t("المظهر، التنبيهات، اللغة، الخصوصية", "Theme, alerts, language, privacy")) { router.push(.settings) }
                    if app.isSignedIn {
                        ItemRow(icon: Ic.shield, title: t("الأمان والحساب", "Security & account"), value: t("الإيميل، كلمة السر، حذف الحساب", "Email, password, delete account")) { router.push(.security) }
                    }
                    #if DEBUG
                    ItemRow(icon: Ic.server, title: t("عنوان الخادم", "Server address"), value: app.serverURL.absoluteString, ltr: true) { router.push(.server) }
                    #endif
                    ItemRow(icon: Ic.info, title: t("عن التطبيق", "About"), value: "WAFI — Know More. Pay Smarter. · " + t("نسخة", "Version") + " \(AppInfo.version) (\(AppInfo.build))")
                }
                .modifier(RowGroup())
                if app.isSignedIn {
                    ItemRow(icon: Ic.logout, title: t("تسجيل الخروج", "Sign out"), danger: true) { Task { await app.signOut() } }
                        .modifier(RowGroup())
                }
            }
            .padding(.bottom, 90)
        }
        .background(PR.paper)
        .task { if app.isSignedIn { await app.refreshMe() } }
    }

    private func signedIn(_ u: SessionUser) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Panel(radius: 22) {
                HStack(spacing: 14) {
                    Text(String((u.name ?? u.email).prefix(1)).uppercased()).font(.headlineS).foregroundStyle(.white)
                        .frame(width: 56, height: 56)
                        .background(LinearGradient(colors: [PR.signal, PR.sky], startPoint: .topLeading, endPoint: .bottomTrailing)).clipShape(Circle())
                    VStack(alignment: .leading, spacing: 2) {
                        Text(u.name ?? t("بدون اسم", "No name")).font(.titleM).foregroundStyle(PR.ink)
                        Text(u.email).font(.bodyS).foregroundStyle(PR.inkSoft).lineLimit(1).environment(\.layoutDirection, .leftToRight)
                    }
                    Spacer()
                    if app.isPro { Badge("Pro", .amber, icon: Ic.crown) } else { Badge((app.me?.roleValue ?? .contributor).label, .signal) }
                }
            }
            if let me = app.me, !me.emailVerified {
                Button { router.push(.security) } label: {
                    HStack(spacing: 10) {
                        Image(systemName: Ic.mail).foregroundStyle(PR.amberDeep)
                        Text(t("أكّد إيميلك عشان توصلك التنبيهات عليه", "Verify your email to get alerts there")).font(.bodyM).foregroundStyle(PR.amberDeep)
                        Spacer()
                        Image(systemName: Ic.forward).foregroundStyle(PR.amberDeep)
                    }
                    .padding(14).background(PR.amberSoft).clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(Pressable())
            }
        }
        .padding(.horizontal, 20)
    }

    private var guest: some View {
        Panel(radius: 22) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    RadarMark(size: 48)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(t("إنت داخل كضيف", "You're browsing as a guest")).font(.titleM).foregroundStyle(PR.ink)
                        Text(t("سجّل عشان تتابع الأسعار وتوصلك التنبيهات.", "Sign in to follow prices and get alerts.")).font(.bodyS).foregroundStyle(PR.inkSoft)
                    }
                }
                HStack(spacing: 10) {
                    PRButton(t("تسجيل الدخول", "Sign in"), height: 48) { router.push(.signIn) }
                    PRButton(t("حساب جديد", "Sign up"), kind: .outline, height: 48) { router.push(.signUp) }
                }
            }
        }
        .padding(.horizontal, 20)
    }
}

/// The Pro door on the account tab, with what Pro adds.
private struct ProCard: View {
    @Environment(AppState.self) private var app
    @Environment(Router.self) private var router
    var body: some View {
        Button { router.push(.pro) } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    IconTile(icon: Ic.crown, bg: PR.signal, fg: .white, size: 44, iconSize: 21)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(app.isPro ? t("إنت مشترك في WAFI Pro", "You're on Pro") : "WAFI Pro").font(.titleM).foregroundStyle(.white)
                        Text(t("كل حاجة من غير حد، ومن غير إعلانات", "Everything unlimited, no ads")).font(.bodyS).foregroundStyle(.white.opacity(0.75))
                    }
                    Spacer()
                    Image(systemName: Ic.forward).foregroundStyle(.white)
                }
                if !app.isPro {
                    LazyVGrid(columns: [GridItem(.flexible(), alignment: .leading), GridItem(.flexible(), alignment: .leading)], spacing: 6) {
                        perk(Ic.search, t("بحث من غير حد", "Unlimited search"))
                        perk(Ic.sparkle, t("المساعد والمستشار براحتك", "Unlimited assistant"))
                        perk(Ic.heart, t("تابع منتجات من غير حد", "Unlimited watchlist"))
                        perk(Ic.gold, t("تنبيه الدهب والدولار", "Gold & dollar alerts"))
                        perk(Ic.chart, t("تاريخ سعر سنة كاملة", "A year of price history"))
                        perk(Ic.shield, t("من غير إعلانات", "No ads"))
                    }
                }
            }
            .padding(18)
            .background(
                ZStack(alignment: .trailing) {
                    LinearGradient(colors: [PR.hero, PR.heroEnd], startPoint: .leading, endPoint: .trailing)
                    WafiMark().frame(width: 120).opacity(0.18).offset(x: 20, y: -10)
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(Pressable())
        .padding(.horizontal, 20)
    }
    private func perk(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 12, weight: .semibold)).foregroundStyle(Color(hex: 0x8AB4FF))
            Text(text).font(.labelM).foregroundStyle(.white.opacity(0.9)).lineLimit(1).minimumScaleFactor(0.85)
        }
    }
}

/// A white rounded group of rows.
struct RowGroup: ViewModifier {
    func body(content: Content) -> some View {
        VStack(spacing: 0) { content }
            .padding(.vertical, 4)
            .background(PR.white)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(PR.line))
            .padding(.horizontal, 20).padding(.vertical, 6)
    }
}

struct ItemRow: View {
    var icon: String
    var title: String
    var value: String?
    var danger = false
    var ltr = false
    var action: (() -> Void)?
    var body: some View {
        let row = HStack(spacing: 12) {
            IconTile(icon: icon, bg: danger ? PR.dangerSoft : PR.paper, fg: danger ? PR.danger : PR.ink, size: 38, iconSize: 18)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.titleS).foregroundStyle(danger ? PR.danger : PR.ink)
                if let value {
                    Text(value).font(.bodyS).foregroundStyle(PR.inkSoft).lineLimit(1)
                        .environment(\.layoutDirection, ltr ? .leftToRight : (Lang.isArabic ? .rightToLeft : .leftToRight))
                }
            }
            Spacer(minLength: 0)
            if !danger && action != nil { Image(systemName: Ic.forward).font(.system(size: 13, weight: .semibold)).foregroundStyle(PR.inkFaint) }
        }
        .padding(.horizontal, 14).padding(.vertical, 12).contentShape(Rectangle())
        if let action { Button(action: action) { row }.buttonStyle(.plain) } else { row }
    }
}

// MARK: - Watchlist

struct WatchlistScreen: View {
    @Environment(AppState.self) private var app
    @Environment(Router.self) private var router
    @State private var state: Load<[WatchItem]> = .loading
    var body: some View {
        VStack(spacing: 0) {
            TopBar(title: t("بتابعها", "Watchlist"), subtitle: t("هنبلّغك لما السعر يوصل للي إنت عايزه", "We'll tell you when the price hits your target"), onBack: { router.back() })
            ScrollView {
                switch state {
                case .loading: LoadingList(rows: 4).padding(20)
                case .err(let e):
                    EmptyState(icon: Ic.heart, title: t("مقدرناش نجيب القايمة", "Couldn't load your list"), bodyText: e.message, action: t("حاول تاني", "Try again")) {
                        Task { await reload() }
                    }
                    .padding(.top, 30)
                case .ok(let items) where items.isEmpty:
                    EmptyState(icon: Ic.heart, title: t("مش بتتابع حاجة لسه", "You're not watching anything yet"),
                               bodyText: t("اضغط على القلب في صفحة أي منتج، وهنتابعلك سعره.", "Tap the heart on any product and we'll watch its price."),
                               action: t("تصفّح", "Browse")) { router.select(.search) }
                        .padding(.top, 30)
                case .ok(let items):
                    LazyVStack(spacing: 0) {
                        if !app.isPro {
                            Text(t("بتتابع \(Fmt.number(items.count)) من \(Fmt.number(app.config.freeWatchLimit)) في المجاني", "\(items.count) of \(app.config.freeWatchLimit) on the free plan"))
                                .font(.labelM).foregroundStyle(PR.inkFaint).frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 20).padding(.bottom, 4)
                        }
                        ForEach(items) { w in row(w) }
                    }
                    .padding(.vertical, 8)
                }
            }
        }
        .background(PR.white)
        .task { await reload() }
    }

    private func row(_ w: WatchItem) -> some View {
        Panel(action: { router.push(.product(w.productId)) }) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(Lang.isArabic ? w.titleAr : w.titleEn).font(.titleS).foregroundStyle(PR.ink).lineLimit(2)
                    PriceText(value: w.bestTotal, font: .titleM, fallback: t("مفيش سعر مؤكد", "No confirmed price"))
                    HStack(spacing: 6) {
                        if let tg = w.target { Badge(t("هدفك ", "Target ") + Fmt.money(tg), .sky) }
                        if w.targetReached { Badge(t("وصل للهدف!", "Target reached!"), .signal, icon: Ic.bolt) }
                    }
                }
                Spacer()
                Button {
                    Task { try? await app.api.unwatch(w.productId); await reload() }
                } label: { Image(systemName: Ic.heartFill).foregroundStyle(PR.danger).frame(width: 44, height: 44) }
                    .accessibilityLabel(t("إلغاء المتابعة", "Unwatch"))
            }
        }
        .padding(.horizontal, 20).padding(.vertical, 5)
    }

    private func reload() async {
        let r = await load { try await app.api.watchlist() }
        if r.value != nil || state.value == nil { state = r }
    }
}

// MARK: - Alerts

struct AlertsScreen: View {
    @Environment(AppState.self) private var app
    @Environment(Router.self) private var router
    @State private var state: Load<[AlertItem]> = .loading
    var body: some View {
        VStack(spacing: 0) {
            TopBar(title: t("التنبيهات", "Alerts"), onBack: { router.back() }) {
                Button { router.push(.marketAlerts) } label: { Image(systemName: Ic.gold).foregroundStyle(PR.amberDeep).frame(width: 44, height: 44) }
                    .accessibilityLabel(t("تنبيهات الدهب والدولار", "Gold & dollar alerts"))
            }
            ScrollView {
                switch state {
                case .loading: LoadingList(rows: 4).padding(20)
                case .err(let e):
                    EmptyState(icon: Ic.bell, title: t("مقدرناش نجيب التنبيهات", "Couldn't load alerts"), bodyText: e.message, action: t("حاول تاني", "Try again")) {
                        Task { await reload() }
                    }
                    .padding(.top, 30)
                case .ok(let items) where items.isEmpty:
                    EmptyState(icon: Ic.bell, title: t("مفيش تنبيهات", "No alerts"),
                               bodyText: t("لما سعر منتج بتتابعه يوصل لهدفك، هيظهر هنا.", "When a watched product hits your target, it shows up here."))
                        .padding(.top, 30)
                case .ok(let items):
                    LazyVStack(spacing: 0) { ForEach(items) { a in row(a) } }.padding(.vertical, 8)
                }
            }
        }
        .background(PR.white)
        .task { await reload() }
    }

    private func row(_ a: AlertItem) -> some View {
        let unread = a.readAt == nil
        return Panel(background: unread ? PR.signalSoft : PR.white, border: unread ? PR.signalSoft : PR.line, action: {
            Task { try? await app.api.markAlertRead(a.id) }
            router.push(.product(a.productId))
        }) {
            HStack(spacing: 10) {
                if unread { Circle().fill(PR.signal).frame(width: 8, height: 8) }
                VStack(alignment: .leading, spacing: 2) {
                    Text(Lang.isArabic ? a.titleAr : a.titleEn).font(.titleS).foregroundStyle(PR.ink)
                    Text(t("السعر نزل لـ ", "Price dropped to ") + Fmt.money(a.total)).font(.bodyM).foregroundStyle(PR.signalDeep)
                    if let s = Fmt.seen(a.createdAt) { Text(s).font(.labelS).foregroundStyle(PR.inkFaint) }
                }
                Spacer()
                Image(systemName: Ic.forward).foregroundStyle(PR.inkFaint)
            }
        }
        .padding(.horizontal, 20).padding(.vertical, 5)
    }

    private func reload() async {
        let r = await load { try await app.api.alerts().items }
        if r.value != nil || state.value == nil { state = r }
    }
}

// MARK: - Server address

struct ServerScreen: View {
    @Environment(AppState.self) private var app
    @State private var text = ""
    @State private var invalid = false
    @State private var status: Bool?
    @State private var checking = false
    var body: some View {
        Screen(title: t("عنوان الخادم", "Server address")) {
            VStack(alignment: .leading, spacing: 14) {
                Panel {
                    HStack(spacing: 10) {
                        Circle().fill(status == true ? PR.signal : status == false ? PR.danger : PR.inkFaint).frame(width: 10, height: 10)
                        Text(checking ? t("بنختبر الاتصال…", "Testing connection…") : status == true ? t("متصل", "Connected") : status == false ? t("غير متصل", "Not connected") : "")
                            .font(.titleS).foregroundStyle(PR.ink)
                        Spacer()
                        PRButton(t("اختبر", "Test"), kind: .outline, loading: checking, height: 40) { Task { await test() } }.fixedSize()
                    }
                }
                PRField(label: t("رابط الـ API", "API URL"), text: $text, icon: Ic.server, error: invalid ? t("رابط مش صحيح (لازم يبدأ بـ https://)", "Invalid URL (must start with https://)") : nil,
                        keyboard: .URL, ltr: true)
                Text(t("للتجربة على الماك: http://127.0.0.1:8000 في المحاكي. على الموبايل الحقيقي لازم https.",
                       "For testing on a Mac: http://127.0.0.1:8000 in the Simulator. Real phones need https."))
                    .font(.bodyS).foregroundStyle(PR.inkSoft)
                HStack(spacing: 10) {
                    PRButton(t("حفظ", "Save"), kind: .dark) { save() }
                    PRButton(t("الافتراضي", "Default"), kind: .outline) {
                        UserDefaults.standard.removeObject(forKey: "wafi.server")
                        let d = Bundle.main.object(forInfoDictionaryKey: "WAFIAPIBaseURL") as? String ?? ""
                        if let u = URL(string: d) { app.useServer(u); UserDefaults.standard.removeObject(forKey: "wafi.server"); text = d }
                        Task { await test() }
                    }
                }
            }
            .padding(20)
        }
        .onAppear { text = app.serverURL.absoluteString }
        .task { await test() }
    }

    private func save() {
        let raw = text.trimmingCharacters(in: .whitespaces).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let u = URL(string: raw), let scheme = u.scheme, u.host != nil,
              scheme == "https" || (scheme == "http" && ["127.0.0.1", "localhost"].contains(u.host!) ) else { invalid = true; return }
        invalid = false
        app.useServer(u)
        Task { await test(); await app.refreshConfig() }
    }

    private func test() async {
        checking = true
        status = await app.api.health()
        checking = false
    }
}

// MARK: - Settings

struct SettingsScreen: View {
    @Environment(AppState.self) private var app
    @Environment(Router.self) private var router
    @State private var prefs: Preferences?
    @State private var pushAllowed = true

    var body: some View {
        Screen(title: t("الإعدادات", "Settings")) {
            VStack(alignment: .leading, spacing: 0) {
                title(t("البلد", "Country"))
                ItemRow(icon: Ic.globe, title: "\(app.country.flag) \(app.country.name)",
                        value: t("المتاجر والأسعار بـ\(app.country.symbolAr). دوس عشان تغيّر.", "Stores and prices in \(app.country.currency). Tap to change.")) {
                    router.push(.country)
                }
                .modifier(RowGroup())
                title(t("المظهر", "Appearance"))
                HStack(spacing: 8) {
                    themeChip(.light, Ic.sun, t("فاتح", "Light"))
                    themeChip(.dark, Ic.moon, t("غامق", "Dark"))
                    themeChip(.system, Ic.phone, t("زي الموبايل", "System"))
                }
                .padding(.horizontal, 20)
                title(t("التنبيهات", "Notifications"))
                VStack(spacing: 0) {
                    if !pushAllowed {
                        HStack {
                            ItemRow(icon: Ic.bell, title: t("اسمح بالإشعارات", "Allow notifications"), value: t("عشان يوصلك لما السعر ينزل", "So price drops reach you"))
                            PRButton(t("اسمح", "Allow"), height: 38) {
                                Task {
                                    if Push.shared.hasAsked { openURL(UIApplication.openSettingsURLString) }
                                    else { pushAllowed = await Push.shared.requestPermission(); await Push.shared.registerIfSignedIn() }
                                }
                            }
                            .fixedSize().padding(.trailing, 12)
                        }
                    }
                    if !app.isSignedIn {
                        HStack {
                            ItemRow(icon: Ic.user, title: t("سجّل دخول عشان تظبط التنبيهات", "Sign in to set up alerts"))
                            PRButton(t("دخول", "Sign in"), kind: .outline, height: 38) { router.push(.signIn) }.fixedSize().padding(.trailing, 12)
                        }
                    } else if let p = prefs {
                        toggle(Ic.bell, t("إشعارات على الموبايل", "Push notifications"), p.pushAlerts) { var n = p; n.pushAlerts = $0; save(n) }
                        toggle(Ic.mail, t("تنبيهات على الإيميل", "Email alerts"), p.emailAlerts) { var n = p; n.emailAlerts = $0; save(n) }
                        toggle(Ic.tag, t("ملخص العروض كل أسبوع", "Weekly deals digest"), p.dealsDigest) { var n = p; n.dealsDigest = $0; save(n) }
                    } else {
                        LoadingList(rows: 2).padding(12)
                    }
                }
                .modifier(RowGroup())
                title(t("اللغة والخصوصية", "Language & privacy"))
                VStack(spacing: 0) {
                    ItemRow(icon: Ic.globe, title: t("اللغة", "Language"), value: t("عربي / English — من إعدادات الآيفون", "Arabic / English — in iPhone Settings")) {
                        openURL(UIApplication.openSettingsURLString)
                    }
                    if Ads.shared.privacyOptionsRequired {
                        ItemRow(icon: Ic.shield, title: t("خيارات خصوصية الإعلانات", "Ad privacy options")) { Ads.shared.showPrivacyOptions() }
                    }
                    ItemRow(icon: Ic.info, title: t("سياسة الخصوصية", "Privacy policy")) { openURL(app.serverURL.absoluteString + "/legal/privacy") }
                    ItemRow(icon: Ic.info, title: t("شروط الاستخدام", "Terms of use")) { openURL(app.serverURL.absoluteString + "/legal/terms") }
                    if let mail = app.config.supportEmail {
                        ItemRow(icon: Ic.mail, title: t("كلّمنا", "Contact us"), value: mail, ltr: true) { openURL("mailto:\(mail)") }
                    }
                }
                .modifier(RowGroup())
            }
            .padding(.bottom, 20)
        }
        .task {
            pushAllowed = await Push.shared.permissionGranted()
            if app.isSignedIn { prefs = try? await app.api.preferences() }
        }
    }

    private func title(_ s: String) -> some View {
        Text(s).font(.labelL).foregroundStyle(PR.inkSoft).padding(.horizontal, 24).padding(.top, 18).padding(.bottom, 4)
    }

    private func themeChip(_ m: ThemeMode, _ icon: String, _ label: String) -> some View {
        let sel = app.theme == m
        return Button { withAnimation { app.theme = m } } label: {
            VStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 20))
                Text(label).font(.labelM)
            }
            .foregroundStyle(sel ? PR.signalDeep : PR.ink)
            .frame(maxWidth: .infinity).padding(.vertical, 14)
            .background(sel ? PR.signalSoft : PR.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(sel ? PR.signal : PR.line))
        }
        .buttonStyle(Pressable())
    }

    private func toggle(_ icon: String, _ label: String, _ on: Bool, _ set: @escaping (Bool) -> Void) -> some View {
        HStack {
            ItemRow(icon: icon, title: label)
            Toggle("", isOn: Binding(get: { on }, set: set)).labelsHidden().tint(PR.signal).padding(.trailing, 14)
        }
    }

    private func save(_ p: Preferences) {
        prefs = p
        Task { if let saved = try? await app.api.savePreferences(p) { prefs = saved } }
    }
}

// MARK: - Security & account

struct SecurityScreen: View {
    @Environment(AppState.self) private var app
    @Environment(Router.self) private var router
    @State private var code = ""
    @State private var codeSent = false
    @State private var busy: String?
    @State private var errors: [String: String] = [:]
    @State private var cur = ""
    @State private var new = ""
    @State private var changed = false
    @State private var askDelete = false
    @State private var delPw = ""

    var body: some View {
        Screen(title: t("الأمان والحساب", "Security & account")) {
            VStack(spacing: 12) {
                Panel {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            VStack(alignment: .leading, spacing: 0) {
                                Text(t("الإيميل", "Email")).font(.titleS).foregroundStyle(PR.ink)
                                Text(app.user?.email ?? "").font(.bodyS).foregroundStyle(PR.inkSoft).environment(\.layoutDirection, .leftToRight)
                            }
                            Spacer()
                            if app.me?.emailVerified == true { Badge(t("متأكد", "Verified"), .signal, icon: Ic.check) } else { Badge(t("مش متأكد", "Unverified"), .amber) }
                        }
                        if app.me?.emailVerified != true {
                            Text(t("أكّد إيميلك عشان توصلك تنبيهات الأسعار عليه.", "Verify your email to get price alerts by email.")).font(.bodyS).foregroundStyle(PR.inkSoft)
                            if !codeSent {
                                PRButton(t("ابعتلي كود تأكيد", "Send me a code"), kind: .outline, loading: busy == "send", height: 46) {
                                    run("send") { try await app.api.sendVerifyCode(); codeSent = true }
                                }
                            } else {
                                PRField(label: t("الكود اللي وصلك", "The code you got"), text: Binding(get: { code }, set: { code = String($0.filter(\.isNumber).prefix(6)) }),
                                        icon: Ic.lock, keyboard: .numberPad, ltr: true, content: .oneTimeCode)
                                err("verify")
                                PRButton(t("تأكيد", "Verify"), loading: busy == "verify", enabled: code.count == 6, height: 46) {
                                    run("verify", map: ["invalid_code": t("الكود غلط أو انتهى.", "Wrong or expired code.")]) {
                                        try await app.api.verifyEmail(code: code); await app.refreshMe()
                                    }
                                }
                            }
                        }
                    }
                }
                if app.me?.hasPassword == true {
                    Panel {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(t("تغيير كلمة السر", "Change password")).font(.titleS).foregroundStyle(PR.ink)
                            if changed {
                                Text(t("اتغيرت ✓ وخرّجنا الأجهزة التانية.", "Changed ✓ Other devices were signed out.")).font(.bodyM).foregroundStyle(PR.signalDeep)
                            } else {
                                PRField(label: t("كلمة السر الحالية", "Current password"), text: $cur, icon: Ic.lock, secure: true, ltr: true, content: .password)
                                PRField(label: t("الجديدة (١٠ حروف على الأقل)", "New (10+ characters)"), text: Binding(get: { new }, set: { new = String($0.prefix(128)) }),
                                        icon: Ic.lock, secure: true, ltr: true, content: .newPassword)
                                err("password")
                                PRButton(t("غيّر", "Change"), loading: busy == "password", enabled: !cur.isEmpty && new.count >= 10, height: 46) {
                                    run("password", map: ["invalid_credentials": t("كلمة السر الحالية غلط.", "Current password is wrong.")]) {
                                        try await app.api.changePassword(current: cur, new: new); changed = true
                                    }
                                }
                            }
                        }
                    }
                }
                Panel(background: PR.dangerSoft, border: PR.dangerSoft) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(t("حذف الحساب", "Delete account")).font(.titleS).foregroundStyle(PR.danger)
                        Text(t("بيمسح الإيميل والاسم والمتابعة والتنبيهات والإعدادات نهائياً. اشتراك Pro لازم تلغيه من إعدادات الآيفون ← Apple ID ← الاشتراكات.",
                               "Permanently deletes your email, name, watchlist, alerts and settings. Cancel Pro in iPhone Settings → Apple ID → Subscriptions."))
                            .font(.bodyS).foregroundStyle(PR.ink)
                        PRButton(t("احذف حسابي", "Delete my account"), kind: .outline, height: 46) { askDelete = true }
                    }
                }
            }
            .padding(20)
        }
        .sheet(isPresented: $askDelete) {
            VStack(alignment: .leading, spacing: 12) {
                Text(t("متأكد؟", "Are you sure?")).font(.headlineS).foregroundStyle(PR.ink)
                Text(t("مفيش رجوع بعد الحذف.", "This can't be undone.")).font(.bodyM).foregroundStyle(PR.inkSoft)
                if app.me?.hasPassword == true {
                    PRField(label: t("كلمة السر للتأكيد", "Password to confirm"), text: $delPw, icon: Ic.lock, secure: true, ltr: true, content: .password)
                }
                err("delete")
                PRButton(t("احذف نهائياً", "Delete permanently"), kind: .dark, loading: busy == "delete") {
                    run("delete", map: ["invalid_credentials": t("كلمة السر غلط.", "Wrong password.")]) {
                        try await app.api.deleteAccount(password: delPw)
                        await Push.shared.unregister()
                        app.clearSession()
                        askDelete = false
                        router.back()
                    }
                }
                PRButton(t("لأ", "Cancel"), kind: .ghost) { askDelete = false }
            }
            .padding(24)
            .presentationDetents([.medium])
            .background(PR.white)
        }
        .task { await app.refreshMe() }
    }

    @ViewBuilder private func err(_ key: String) -> some View {
        if let e = errors[key] { Text(e).font(.bodyS).foregroundStyle(PR.danger) }
    }

    private func run(_ key: String, map: [String: String] = [:], _ f: @escaping () async throws -> Void) {
        busy = key; errors[key] = nil
        Task {
            defer { busy = nil }
            do { try await f() }
            catch let e as APIError { errors[key] = e.code.flatMap { map[$0] } ?? e.message }
            catch { errors[key] = APIError.network(nil).message }
        }
    }
}
