import SwiftUI
import Observation

enum Tab: String, CaseIterable, Hashable { case home, search, market, basket, account }

/// Every screen you can push.
enum Route: Hashable {
    case product(String)
    case search(category: String?, query: String, part: String?)
    case cars, pc, pro, watchlist, alerts, server, deals, compare, assistant
    case signIn, signUp, forgot, security, settings
    case advisor, goldAdvisor, pcAdvisor, picks(String)
    case installment, goldCalc
    case wallet, marketAlerts, country
}

/// One navigation stack per tab; screens push and pop through this.
@MainActor
@Observable
final class Router {
    var tab: Tab = .home
    var paths: [Tab: [Route]] = [:]

    func push(_ r: Route) {
        // the search tab opens at its root instead of stacking a second search
        if case .search(let cat, let q, let part) = r, tab != .search {
            tab = .search
            paths[.search] = []
            SearchSeed.shared.next = ProductFilter(query: q, category: cat, part: part)
            return
        }
        paths[tab, default: []].append(r)
    }

    func back() { if !(paths[tab]?.isEmpty ?? true) { paths[tab]?.removeLast() } }

    func select(_ t: Tab) {
        if tab == t { paths[t] = [] }     // tapping the current tab returns to its root
        tab = t
    }

    func binding(_ t: Tab) -> Binding<[Route]> {
        Binding(get: { self.paths[t] ?? [] }, set: { self.paths[t] = $0 })
    }

    /// After sign-in: leave the auth screens.
    func enterApp() { paths[tab] = (paths[tab] ?? []).filter { ![.signIn, .signUp, .forgot].contains($0) } }
}

/// A filter handed to the search tab when another screen asks for a search.
@MainActor
final class SearchSeed {
    static let shared = SearchSeed()
    var next: ProductFilter?
}

extension View {
    /// Every pushable screen, for any NavigationStack.
    func wafiDestinations() -> some View {
        navigationDestination(for: Route.self) { r in
            Group {
                switch r {
                case .product(let id): ProductScreen(id: id)
                case .search(let c, let q, let p): SearchScreen(initial: ProductFilter(query: q, category: c, part: p))
                case .cars: CarsScreen()
                case .pc: PcBuilderScreen()
                case .pro: ProScreen()
                case .watchlist: WatchlistScreen()
                case .alerts: AlertsScreen()
                case .server: ServerScreen()
                case .deals: DealsScreen()
                case .compare: CompareScreen()
                case .assistant: AssistantScreen()
                case .signIn: SignInScreen()
                case .signUp: SignUpScreen()
                case .forgot: ForgotPasswordScreen()
                case .security: SecurityScreen()
                case .settings: SettingsScreen()
                case .advisor: AdvisorHubScreen()
                case .goldAdvisor: GoldAdvisorScreen()
                case .pcAdvisor: PcAdvisorScreen()
                case .picks(let kind): PicksAdvisorScreen(kind: kind)
                case .installment: InstallmentScreen()
                case .goldCalc: GoldCalcScreen()
                case .wallet: WalletScreen()
                case .marketAlerts: MarketAlertsScreen()
                case .country: CountryPickerScreen(firstRun: false)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}
