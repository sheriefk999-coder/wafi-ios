import SwiftUI

/// Loading state shared by every screen.
enum Load<T> {
    case loading
    case ok(T)
    case err(APIError)
    var value: T? { if case .ok(let v) = self { return v }; return nil }
    var isLoading: Bool { if case .loading = self { return true }; return false }
}

func load<T>(_ f: () async throws -> T) async -> Load<T> {
    do { return .ok(try await f()) }
    catch let e as APIError { return .err(e) }
    catch { return .err(.network(error.localizedDescription)) }
}

extension APIError {
    /// What went wrong and what to do, in the app's voice.
    var message: String {
        switch self {
        case .network: return t("مش قادرين نوصل للخادم. اتأكد من النت أو عنوان الخادم.", "Can't reach the server. Check your connection or the server address.")
        case .timeout: return t("الخادم اتأخر في الرد. جرّب تاني.", "The server took too long. Try again.")
        case .parse: return t("الخادم رجّع رد مش متوقع.", "The server sent an unexpected response.")
        case .http(let status, let code, _):
            switch code {
            case "invalid_credentials": return t("الإيميل أو كلمة السر مش صح.", "Email or password is incorrect.")
            case "too_many_attempts": return t("محاولات كتير غلط. الحساب مقفول ١٥ دقيقة للحماية.", "Too many failed attempts. The account is locked for 15 minutes.")
            case "email_taken": return t("الإيميل ده عليه حساب بالفعل. سجّل دخول بيه.", "That email already has an account. Sign in instead.")
            case "not_enabled": return t("الميزة دي مش مفعّلة على الخادم ده.", "This isn't enabled on this server.")
            case "rate_limited": return t("طلبات كتير ورا بعض. استنى دقيقة وجرّب تاني.", "Too many requests. Wait a minute and try again.")
            case "market_unavailable": return t("أسعار الدهب والعملات مش متاحة دلوقتي. جرّب بعد شوية.", "Gold and currency prices aren't available right now. Try again shortly.")
            case "invalid_code": return t("الكود غلط أو انتهى.", "The code is wrong or expired.")
            case "account_disabled": return t("الحساب ده متوقف.", "This account is disabled.")
            case "email_required": return t("لازم تسمح بمشاركة الإيميل مع WAFI.", "Please share your email with WAFI.")
            case "quota_exceeded": return t("خلصت المحاولات المجانية دلوقتي. استنى شوية أو اشترك في Pro.", "You've used the free allowance for now. Wait a bit or get Pro.")
            case "pro_required": return t("الميزة دي في Pro.", "This is a Pro feature.")
            default:
                switch status {
                case 401: return t("لازم تسجّل دخول الأول.", "Please sign in first.")
                case 403: return t("مش مسموح لحسابك بده.", "Your account can't do this.")
                case 404: return t("مش موجود.", "Not found.")
                case 422: return t("راجع البيانات اللي دخلتها.", "Check the details you entered.")
                default: return t("حصل خطأ في الخادم (\(status)).", "Server error (\(status)).")
                }
            }
        }
    }
}

extension Role {
    var label: String {
        switch self {
        case .anon: return t("زائر", "Guest")
        case .viewer: return t("مشاهد", "Viewer")
        case .contributor: return t("عضو", "Member")
        case .editor: return t("محرر", "Editor")
        case .owner: return t("مالك", "Owner")
        }
    }
}

/// The standard screen body: a white background, our TopBar and a scrolling column.
struct Screen<Content: View>: View {
    var title: String
    var subtitle: String?
    var back = true
    @ViewBuilder var content: () -> Content
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(spacing: 0) {
            TopBar(title: title, subtitle: subtitle, onBack: back ? { dismiss() } : nil)
            ScrollView { VStack(spacing: 0) { content() }.padding(.bottom, 32) }
                .scrollDismissesKeyboard(.interactively)
        }
        .background(PR.white)
        .toolbar(.hidden, for: .navigationBar)
    }
}

/// A horizontally scrolling row of chips with the standard side padding.
struct ChipRow<Content: View>: View {
    @ViewBuilder var content: () -> Content
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) { content() }.padding(.horizontal, 20).padding(.vertical, 4)
        }
    }
}

/// The gold-washed upsell used where a Pro feature starts.
struct ProUpsell: View {
    var title: String
    var text: String
    @Environment(Router.self) private var router
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("WAFI Pro", systemImage: Ic.crown).font(.labelL).foregroundStyle(Color(hex: 0x4A3300))
            Text(title).font(.titleL).foregroundStyle(Color(hex: 0x2B1D00))
            Text(text).font(.bodyM).foregroundStyle(Color(hex: 0x4A3300))
            PRButton(t("اشترك في Pro", "Get Pro"), kind: .dark, icon: Ic.crown, height: 46) { router.push(.pro) }.frame(maxWidth: 220).padding(.top, 6)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LinearGradient(colors: [Color(hex: 0xFFF6DC), Color(hex: 0xFFE6A3), Color(hex: 0xF7C95A)], startPoint: .topLeading, endPoint: .bottomTrailing))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .padding(.horizontal, 20).padding(.vertical, 8)
    }
}

func openURL(_ s: String?) {
    guard let s, let u = URL(string: s) else { return }
    UIApplication.shared.open(u)
}
