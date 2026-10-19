import SwiftUI
import UIKit

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        MainActor.assumeIsolated {
            Push.shared.start()
            Billing.shared.start()
        }
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        MainActor.assumeIsolated { Push.shared.didRegister(deviceToken: deviceToken) }
    }
}

@main
struct WAFIApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @State private var app = AppState.shared
    @State private var router = Router()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(app)
                .environment(router)
                .environment(\.layoutDirection, Lang.isArabic ? .rightToLeft : .leftToRight)
                .environment(\.locale, Lang.locale)
                .preferredColorScheme(app.theme == .system ? nil : (app.theme == .dark ? .dark : .light))
                .tint(PR.signal)
                .task {
                    await app.refreshConfig()
                    await app.refreshCountries()
                    if app.isSignedIn {
                        await app.refreshMe()
                        await Push.shared.registerIfSignedIn()
                        await Billing.shared.syncEntitlements()
                    }
                    Ads.shared.start()
                }
        }
    }
}

struct RootView: View {
    @Environment(AppState.self) private var app
    @Environment(Router.self) private var router
    @State private var countryDone = false

    var body: some View {
        @Bindable var router = router
        let cfg = app.config
        ZStack {
            if let m = cfg.maintenance {
                Blocker(icon: Ic.gear, title: t("بنحسّن الرادار", "We're improving the radar"), text: Lang.isArabic ? m.ar : m.en, action: nil, onAction: {})
            } else if cfg.minVersionCode > AppInfo.build {
                Blocker(icon: Ic.refresh, title: t("لازم تحدّث التطبيق", "Please update the app"),
                        text: t("النسخة دي قديمة ومش هتشتغل صح. حدّثها من App Store.", "This version is too old to work properly. Update it from the App Store."),
                        action: t("حدّث دلوقتي", "Update now")) {
                    if let s = cfg.storeUrl, let u = URL(string: s) { UIApplication.shared.open(u) }
                }
            } else if !app.onboardingDone {
                OnboardingScreen()
            } else if !app.countryChosen && !countryDone {
                CountryPickerScreen(firstRun: true) { countryDone = true }
            } else {
                MainTabs()
                    .id(app.catalogEpoch)          // a new country is a new catalog: every screen reloads
            }
            if let msg = app.toast {
                VStack { Spacer(); ToastView(text: msg).padding(.bottom, 96) }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .task { try? await Task.sleep(for: .seconds(2.2)); withAnimation { app.toast = nil } }
            }
        }
        .animation(.easeOut(duration: 0.25), value: app.toast)
        .onChange(of: app.pendingRoute) { _, r in
            guard let r else { return }
            if r == .marketAlerts { router.tab = .market }
            router.push(r)
            app.pendingRoute = nil
        }
    }
}

enum AppInfo {
    static var build: Int { Int(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1") ?? 1 }
    static var version: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0" }
}

struct MainTabs: View {
    @Environment(AppState.self) private var app
    @Environment(Router.self) private var router

    var body: some View {
        @Bindable var router = router
        TabView(selection: Binding(get: { router.tab }, set: { router.select($0) })) {
            stack(.home) { HomeScreen() }
                .tabItem { Label(t("الرئيسية", "Home"), systemImage: Ic.home) }.tag(Tab.home)
            stack(.search) { SearchScreen(initial: SearchSeed.shared.next ?? ProductFilter()) }
                .tabItem { Label(t("اكتشف", "Discover"), systemImage: Ic.search) }.tag(Tab.search)
            stack(.market) { MarketScreen() }
                .tabItem { Label(t("الدهب", "Gold"), systemImage: Ic.gold) }.tag(Tab.market)
            stack(.basket) { BasketScreen() }
                .tabItem { Label(t("السلة", "Basket"), systemImage: Ic.basket) }.tag(Tab.basket)
                .badge(app.basket.reduce(0) { $0 + $1.qty })
            stack(.account) { AccountScreen() }
                .tabItem { Label(t("حسابي", "Account"), systemImage: Ic.user) }.tag(Tab.account)
        }
        .overlay(alignment: .bottom) { CompareBar() }
        .task { await LaunchScript.run(app: app, router: router) }
    }

    private func stack<V: View>(_ t: Tab, @ViewBuilder root: () -> V) -> some View {
        NavigationStack(path: router.binding(t)) {
            root().toolbar(.hidden, for: .navigationBar).wafiDestinations()
        }
    }
}

/// The floating "compare N products" pill while 2+ products are picked.
struct CompareBar: View {
    @Environment(AppState.self) private var app
    @Environment(Router.self) private var router
    var body: some View {
        if app.compare.count >= 2, router.paths[router.tab]?.last != .compare {
            Button { router.push(.compare) } label: {
                Label(t("قارن \(Fmt.number(app.compare.count)) منتجات", "Compare \(app.compare.count) products"), systemImage: Ic.exchange)
                    .font(.labelL).foregroundStyle(PR.onAccent)
                    .padding(.horizontal, 18).padding(.vertical, 12)
                    .background(PR.hero).clipShape(Capsule())
                    .shadow(color: .black.opacity(0.2), radius: 10, y: 4)
            }
            .buttonStyle(Pressable())
            .padding(.bottom, 64)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}

/// Full-screen message set from the admin console (maintenance, forced update).
struct Blocker: View {
    var icon: String
    var title: String
    var text: String
    var action: String?
    var onAction: () -> Void
    var body: some View {
        VStack(spacing: 16) {
            RadarScope(blips: [Blip(angle: 40, distance: 0.6, color: PR.amber, big: true)]).frame(width: 160, height: 160)
            IconTile(icon: icon, bg: PR.signalSoft, fg: PR.signalDeep, size: 56, iconSize: 26)
            Text(title).font(.headline).foregroundStyle(PR.ink).multilineTextAlignment(.center)
            Text(text).font(.bodyL).foregroundStyle(PR.inkSoft).multilineTextAlignment(.center)
            if let action { PRButton(action, action: onAction).padding(.top, 8) }
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(PR.white)
    }
}
