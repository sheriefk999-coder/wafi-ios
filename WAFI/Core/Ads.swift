import SwiftUI
import UIKit
import GoogleMobileAds
import UserMessagingPlatform

/// AdMob for free accounts only. Ad unit ids come from the admin console; the AdMob App ID is in Info.plist.
/// Consent (GDPR) is asked through Google's UMP form when the user's region needs it.
@MainActor
final class Ads {
    static let shared = Ads()
    private(set) var ready = false

    var appConfigured: Bool {
        let id = Bundle.main.object(forInfoDictionaryKey: "GADApplicationIdentifier") as? String ?? ""
        return !id.isEmpty && !id.contains("3940256099942544")     // Google's sample id = not set up
    }

    func start() {
        guard appConfigured, !ProcessInfo.processInfo.arguments.contains("-WAFI_SCREENSHOTS") else { return }
        let params = UMPRequestParameters()
        UMPConsentInformation.sharedInstance.requestConsentInfoUpdate(with: params) { [weak self] _ in
            Task { @MainActor in
                if let root = UIApplication.shared.connectedScenes.compactMap({ ($0 as? UIWindowScene)?.keyWindow?.rootViewController }).first {
                    try? await UMPConsentForm.loadAndPresentIfRequired(from: root)
                }
                if UMPConsentInformation.sharedInstance.canRequestAds {
                    GADMobileAds.sharedInstance().start(completionHandler: nil)
                    self?.ready = true
                }
            }
        }
    }
}

extension Ads {
    /// Some regions (EEA/UK) must offer a way to change the consent later (Settings → Ad privacy options).
    var privacyOptionsRequired: Bool {
        UMPConsentInformation.sharedInstance.privacyOptionsRequirementStatus == .required
    }

    func showPrivacyOptions() {
        guard let root = UIApplication.shared.connectedScenes.compactMap({ ($0 as? UIWindowScene)?.keyWindow?.rootViewController }).first else { return }
        UMPConsentForm.presentPrivacyOptionsForm(from: root) { _ in }
    }
}

enum AdKind { case banner, inline }

/// An ad slot that hides itself for Pro, when ads are off, on a switched-off screen, or when nothing loads.
struct AdSlot: View {
    var kind: AdKind = .banner
    var placement: String
    @Environment(AppState.self) private var app
    @State private var failed = false

    /// Screenshot runs show a labelled placeholder (or nothing, with -WAFI_NO_ADS for store images).
    private var preview: Bool { ProcessInfo.processInfo.arguments.contains("-WAFI_SCREENSHOTS") }
    private var hidden: Bool { ProcessInfo.processInfo.arguments.contains("-WAFI_NO_ADS") }
    private var unit: String? { kind == .banner ? app.config.ads.bannerId : (app.config.ads.inlineId ?? app.config.ads.bannerId) }

    var body: some View {
        if hidden || app.isPro || app.config.ads.placements[placement] == false || failed {
            EmptyView()
        } else if preview || (Ads.shared.appConfigured && app.config.ads.enabled && unit != nil) {
            VStack(alignment: .leading, spacing: 4) {
                Text(t("إعلان", "Ad")).font(.wafi(11, .medium)).foregroundStyle(PR.inkFaint)
                Group {
                    if preview {
                        Text(t("مساحة إعلان", "Ad space") + (kind == .banner ? " · 320×50" : " · 300×250"))
                            .font(.wafi(13, .medium)).foregroundStyle(PR.inkFaint)
                    } else {
                        BannerAd(unit: unit!, kind: kind) { failed = true }
                    }
                }
                .frame(maxWidth: .infinity, minHeight: kind == .banner ? 56 : 250)
                .background(PR.paper)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(PR.line))
            }
            .padding(.horizontal, 20).padding(.vertical, 6)
        }
    }
}

private struct BannerAd: UIViewRepresentable {
    var unit: String
    var kind: AdKind
    var onFail: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onFail: onFail) }

    func makeUIView(context: Context) -> GADBannerView {
        let width = UIScreen.main.bounds.width - 40
        let v = GADBannerView(adSize: kind == .banner ? GADCurrentOrientationAnchoredAdaptiveBannerAdSizeWithWidth(width) : GADAdSizeMediumRectangle)
        v.adUnitID = unit
        v.delegate = context.coordinator
        v.rootViewController = UIApplication.shared.connectedScenes.compactMap { ($0 as? UIWindowScene)?.keyWindow?.rootViewController }.first
        v.load(GADRequest())
        return v
    }

    func updateUIView(_ uiView: GADBannerView, context: Context) {}

    final class Coordinator: NSObject, GADBannerViewDelegate {
        let onFail: () -> Void
        init(onFail: @escaping () -> Void) { self.onFail = onFail }
        func bannerView(_ bannerView: GADBannerView, didFailToReceiveAdWithError error: Error) { onFail() }
    }
}
