import SwiftUI
import AuthenticationServices

private func validEmail(_ s: String) -> Bool {
    s.trimmingCharacters(in: .whitespaces).range(of: "^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$", options: .regularExpression) != nil
}

/// Sign in with Apple (Apple requires it next to any other social sign-in) and email + password.
struct AppleButton: View {
    var onDone: () -> Void
    @Environment(AppState.self) private var app
    @Environment(\.colorScheme) private var scheme
    @State private var error: String?
    var body: some View {
        VStack(spacing: 6) {
            SignInWithAppleButton(.continue) { req in
                req.requestedScopes = [.fullName, .email]
            } onCompletion: { result in
                switch result {
                case .success(let auth):
                    guard let cred = auth.credential as? ASAuthorizationAppleIDCredential,
                          let data = cred.identityToken, let token = String(data: data, encoding: .utf8) else { return }
                    let name = [cred.fullName?.givenName, cred.fullName?.familyName].compactMap { $0 }.joined(separator: " ")
                    Task {
                        do {
                            let s = try await app.api.appleSignIn(identityToken: token, name: name)
                            await app.signedIn(s)
                            onDone()
                        } catch let e as APIError { error = e.message } catch { self.error = APIError.network(nil).message }
                    }
                case .failure(let e):
                    if (e as? ASAuthorizationError)?.code != .canceled { error = t("الدخول بـ Apple ما كملش. جرّب تاني.", "Sign in with Apple didn't finish. Try again.") }
                }
            }
            .signInWithAppleButtonStyle(scheme == .dark ? .white : .black)
            .frame(height: 52)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            if let error { Text(error).font(.bodyS).foregroundStyle(PR.danger) }
        }
    }
}

private struct OrDivider: View {
    var body: some View {
        HStack(spacing: 10) {
            Rectangle().fill(PR.line).frame(height: 1)
            Text(t("أو بالإيميل", "or with email")).font(.labelM).foregroundStyle(PR.inkFaint)
            Rectangle().fill(PR.line).frame(height: 1)
        }
    }
}

private struct AuthHeader: View {
    var title: String
    var sub: String
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                RadarMark(size: 40)
                Text("WAFI").font(.wafi(20, .bold)).tracking(2).foregroundStyle(PR.ink)
            }
            .padding(.bottom, 10)
            Text(title).font(.headline).foregroundStyle(PR.ink)
            Text(sub).font(.bodyM).foregroundStyle(PR.inkSoft)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct SignInScreen: View {
    @Environment(AppState.self) private var app
    @Environment(Router.self) private var router
    @State private var email = ""
    @State private var password = ""
    @State private var tried = false
    @State private var busy = false
    @State private var error: String?

    var body: some View {
        Screen(title: "") {
            VStack(spacing: 14) {
                AuthHeader(title: t("أهلاً بيك تاني", "Welcome back"), sub: t("سجّل دخولك عشان تتابع الأسعار وتوصلك التنبيهات.", "Sign in to follow prices and get alerts."))
                if app.config.features.appleSignIn {
                    AppleButton { router.enterApp() }
                    OrDivider()
                }
                PRField(label: t("الإيميل", "Email"), text: $email, icon: Ic.mail, error: tried && !validEmail(email) ? t("اكتب إيميل صحيح", "Enter a valid email") : nil,
                        keyboard: .emailAddress, ltr: true, content: .username)
                PRField(label: t("كلمة السر", "Password"), text: $password, icon: Ic.lock, secure: true, ltr: true, content: .password)
                if let error { Text(error).font(.bodyS).foregroundStyle(PR.danger).frame(maxWidth: .infinity, alignment: .leading) }
                PRButton(t("تسجيل الدخول", "Sign in"), loading: busy) { Task { await submit() } }
                HStack {
                    Button(t("نسيت كلمة السر؟", "Forgot password?")) { router.push(.forgot) }
                    Spacer()
                    Button(t("حساب جديد", "Create account")) { router.push(.signUp) }
                }
                .font(.labelL).foregroundStyle(PR.signalDeep)
            }
            .padding(20)
        }
    }

    private func submit() async {
        tried = true
        guard validEmail(email), !password.isEmpty else { return }
        busy = true; error = nil
        defer { busy = false }
        do {
            let s = try await app.api.login(email: email.trimmingCharacters(in: .whitespaces), password: password)
            await app.signedIn(s)
            router.enterApp()
        } catch let e as APIError { error = e.message } catch { self.error = APIError.network(nil).message }
    }
}

struct SignUpScreen: View {
    @Environment(AppState.self) private var app
    @Environment(Router.self) private var router
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var tried = false
    @State private var busy = false
    @State private var error: String?

    var body: some View {
        Screen(title: "") {
            VStack(spacing: 14) {
                AuthHeader(title: t("حساب جديد", "Create your account"), sub: t("تابع أسعار اللي عايزه وخلّي الرادار يبلّغك أول ما تنزل.", "Follow what you want to buy; the radar tells you when it drops."))
                if app.config.features.appleSignIn {
                    AppleButton { router.enterApp() }
                    OrDivider()
                }
                PRField(label: t("الاسم", "Name"), text: Binding(get: { name }, set: { name = String($0.prefix(60)) }), icon: Ic.user, content: .name)
                PRField(label: t("الإيميل", "Email"), text: $email, icon: Ic.mail, error: tried && !validEmail(email) ? t("اكتب إيميل صحيح", "Enter a valid email") : nil,
                        keyboard: .emailAddress, ltr: true, content: .username)
                PRField(label: t("كلمة السر (١٠ حروف على الأقل)", "Password (10+ characters)"), text: Binding(get: { password }, set: { password = String($0.prefix(128)) }),
                        icon: Ic.lock, error: tried && password.count < 10 ? t("١٠ حروف على الأقل", "At least 10 characters") : nil, secure: true, ltr: true, content: .newPassword)
                if let error { Text(error).font(.bodyS).foregroundStyle(PR.danger).frame(maxWidth: .infinity, alignment: .leading) }
                PRButton(t("اعمل الحساب", "Create account"), loading: busy) { Task { await submit() } }
                Text(t("بإنشاء حساب إنت موافق على شروط الاستخدام وسياسة الخصوصية.", "By creating an account you agree to the terms and privacy policy."))
                    .font(.bodyS).foregroundStyle(PR.inkFaint).multilineTextAlignment(.center)
            }
            .padding(20)
        }
    }

    private func submit() async {
        tried = true
        guard validEmail(email), password.count >= 10 else { return }
        busy = true; error = nil
        defer { busy = false }
        do {
            let s = try await app.api.register(name: name.trimmingCharacters(in: .whitespaces), email: email.trimmingCharacters(in: .whitespaces), password: password)
            await app.signedIn(s)
            router.enterApp()
        } catch let e as APIError { error = e.message } catch { self.error = APIError.network(nil).message }
    }
}

struct ForgotPasswordScreen: View {
    @Environment(AppState.self) private var app
    @Environment(Router.self) private var router
    @State private var step = 0           // 0 email, 1 code + new password, 2 done
    @State private var email = ""
    @State private var code = ""
    @State private var pw = ""
    @State private var tried = false
    @State private var busy = false
    @State private var error: String?

    var body: some View {
        Screen(title: t("نسيت كلمة السر", "Forgot password")) {
            VStack(alignment: .leading, spacing: 14) {
                switch step {
                case 0:
                    header(Ic.mail, t("هنبعتلك كود", "We'll email you a code"),
                           t("اكتب إيميل حسابك وهيوصلك كود من ٦ أرقام صالح ١٥ دقيقة.", "Enter your account email and you'll get a 6-digit code, valid for 15 minutes."))
                    PRField(label: t("الإيميل", "Email"), text: $email, icon: Ic.mail, error: tried && !validEmail(email) ? t("اكتب إيميل صحيح", "Enter a valid email") : nil,
                            keyboard: .emailAddress, ltr: true, content: .username)
                    errorText
                    PRButton(t("ابعت الكود", "Send code"), loading: busy) {
                        tried = true
                        guard validEmail(email) else { return }
                        run { try await app.api.forgotPassword(email: email.trimmingCharacters(in: .whitespaces)); step = 1; tried = false }
                    }
                case 1:
                    header(Ic.lock, t("اكتب الكود وكلمة سر جديدة", "Enter the code and a new password"),
                           t("لو الإيميل عليه حساب بكلمة سر، الكود اتبعت عليه. بص في الـ Spam كمان.", "If this email has a password account, the code is on its way. Check spam too."))
                    PRField(label: t("الكود", "Code"), text: Binding(get: { code }, set: { code = String($0.filter(\.isNumber).prefix(6)) }), icon: Ic.lock,
                            error: tried && code.count != 6 ? t("الكود ٦ أرقام", "The code has 6 digits") : nil, keyboard: .numberPad, ltr: true, content: .oneTimeCode)
                    PRField(label: t("كلمة السر الجديدة", "New password"), text: Binding(get: { pw }, set: { pw = String($0.prefix(128)) }), icon: Ic.lock,
                            error: tried && pw.count < 10 ? t("١٠ حروف على الأقل", "At least 10 characters") : nil, secure: true, ltr: true, content: .newPassword)
                    errorText
                    PRButton(t("غيّر كلمة السر", "Change password"), loading: busy) {
                        tried = true
                        guard code.count == 6, pw.count >= 10 else { return }
                        run(map: ["invalid_code": t("الكود غلط أو انتهى، اطلب كود جديد.", "Wrong or expired code; ask for a new one.")]) {
                            try await app.api.resetPassword(email: email.trimmingCharacters(in: .whitespaces), code: code, newPassword: pw); step = 2
                        }
                    }
                    PRButton(t("ابعت كود تاني", "Send another code"), kind: .ghost) {
                        run { try await app.api.forgotPassword(email: email.trimmingCharacters(in: .whitespaces)) }
                    }
                default:
                    header(Ic.check, t("اتغيرت كلمة السر", "Password changed"),
                           t("سجّل دخول بكلمة السر الجديدة. خرّجناك من كل الأجهزة التانية عشان الأمان.", "Sign in with your new password. We signed you out everywhere else for safety."))
                    PRButton(t("تسجيل الدخول", "Sign in")) { router.back() }
                }
            }
            .padding(20)
            .animation(.easeOut(duration: 0.2), value: step)
        }
    }

    @ViewBuilder private var errorText: some View {
        if let error { Text(error).font(.bodyS).foregroundStyle(PR.danger) }
    }

    private func header(_ icon: String, _ title: String, _ sub: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            IconTile(icon: icon, bg: PR.signalSoft, fg: PR.signalDeep, size: 52, iconSize: 24)
            Text(title).font(.headlineS).foregroundStyle(PR.ink)
            Text(sub).font(.bodyM).foregroundStyle(PR.inkSoft)
        }
    }

    private func run(map: [String: String] = [:], _ f: @escaping () async throws -> Void) {
        busy = true; error = nil
        Task {
            defer { busy = false }
            do { try await f() }
            catch let e as APIError { error = e.code.flatMap { map[$0] } ?? e.message }
            catch { self.error = APIError.network(nil).message }
        }
    }
}
