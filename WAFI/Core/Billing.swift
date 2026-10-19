import Foundation
import StoreKit

/// WAFI Pro through the App Store (StoreKit 2). Every verified transaction goes to the server, which checks
/// Apple's signature again and turns Pro on for the account; prices come from App Store Connect.
@MainActor
@Observable
final class Billing {
    static let shared = Billing()

    enum State: Equatable { case loading, unavailable, ready([ProductInfo]) }
    struct ProductInfo: Equatable, Identifiable {
        var id: String
        var price: String
        var period: String      // "P1M" / "P1Y"
        var trial: String?
    }

    var state: State = .loading
    var busy = false
    var message: String?
    @ObservationIgnored private var products: [String: StoreKit.Product] = [:]
    @ObservationIgnored private var updates: Task<Void, Never>?

    func start() {
        updates?.cancel()
        updates = Task.detached { [weak self] in
            for await result in Transaction.updates {
                await self?.handle(result)
            }
        }
    }

    func load() async {
        let cfg = AppState.shared.config.pro
        state = .loading
        do {
            let list = try await StoreKit.Product.products(for: [cfg.monthlyId, cfg.yearlyId])
            products = Dictionary(uniqueKeysWithValues: list.map { ($0.id, $0) })
            let infos = list.sorted { a, _ in a.id == cfg.monthlyId }.map { p -> ProductInfo in
                let unit = p.subscription?.subscriptionPeriod.unit
                let period = unit == .year ? "P1Y" : unit == .week ? "P1W" : "P1M"
                let trial = p.subscription?.introductoryOffer.flatMap { o -> String? in
                    o.paymentMode == .freeTrial ? "\(o.period.value) \(o.period.unit == .day ? t("يوم", "days") : o.period.unit == .week ? t("أسبوع", "weeks") : t("شهر", "months"))" : nil
                }
                return ProductInfo(id: p.id, price: p.displayPrice, period: period, trial: trial)
            }
            state = infos.isEmpty ? .unavailable : .ready(infos)
        } catch {
            state = .unavailable
        }
    }

    func buy(_ id: String) async {
        guard let p = products[id] else { return }
        busy = true
        defer { busy = false }
        do {
            var opts: Set<StoreKit.Product.PurchaseOption> = []
            if let uid = AppState.shared.me?.userId, let u = UUID(uuidString: uid) { opts.insert(.appAccountToken(u)) }
            switch try await p.purchase(options: opts) {
            case .success(let result): await handle(result)
            case .pending: message = t("الشرا مستني موافقة. هيتفعّل لوحده.", "Purchase pending approval. It will turn on by itself.")
            case .userCancelled: break
            @unknown default: break
            }
        } catch {
            message = t("الشرا ما كملش. حاول تاني.", "The purchase didn't go through. Try again.")
        }
    }

    func restore() async {
        busy = true
        defer { busy = false }
        try? await AppStore.sync()
        await syncEntitlements()
        message = AppState.shared.isPro ? t("Pro اتفعّل ✓", "Pro is on ✓") : t("مفيش اشتراك على حساب Apple ده.", "No subscription on this Apple account.")
    }

    /// On launch and after sign-in: tell the server about subscriptions this Apple account already has.
    func syncEntitlements() async {
        guard AppState.shared.isSignedIn else { return }
        for await result in Transaction.currentEntitlements { await send(result) }
        await AppState.shared.refreshMe()
    }

    private func handle(_ result: VerificationResult<Transaction>) async {
        await send(result)
        if case .verified(let tx) = result { await tx.finish() }
        await AppState.shared.refreshMe()
    }

    private func send(_ result: VerificationResult<Transaction>) async {
        guard case .verified(let tx) = result, tx.productType == .autoRenewable, AppState.shared.isSignedIn else { return }
        var renewal: String?
        if let status = try? await tx.subscriptionStatus, case .verified = status.renewalInfo {
            renewal = status.renewalInfo.jwsRepresentation
        }
        do {
            _ = try await AppState.shared.api.verifyAppStore(signedTransaction: result.jwsRepresentation, renewal: renewal)
        } catch let e as APIError where e.code == "purchase_in_use" {
            message = t("الاشتراك ده مربوط بحساب WAFI تاني.", "This subscription belongs to another WAFI account.")
        } catch {}
    }
}
