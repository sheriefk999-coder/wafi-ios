import SwiftUI

private let startersAr = ["عايز موبايل في حدود ٢٠ ألف", "أرخص لابتوب", "جمّعلي PC بـ ٦٠ ألف للألعاب",
                          "عربية مستعملة تحت ١ مليون", "الدهب عيار ٢١ بكام", "١٠٠ دولار بكام", "إيه العروض النهارده؟"]
private let startersEn = ["A phone around EGP 20K", "Cheapest laptop", "Build a gaming PC for 60K",
                          "Used car under 1 million", "Gold 21K price", "100 dollars in EGP", "Today's deals"]

private enum ChatMsg: Identifiable {
    case user(UUID, String)
    case bot(UUID, AssistantResponse)
    case failed(UUID, APIError, String)
    var id: UUID { switch self { case .user(let i, _), .bot(let i, _), .failed(let i, _, _): return i } }
}

/// Re-reads a card item (decoded as loose JSON) as a typed model.
private func typed<T: Decodable>(_ items: [[String: JSONValue]], as: T.Type) -> [T] {
    items.compactMap { item in
        guard let d = try? JSONEncoder().encode(item) else { return nil }
        return try? JSONDecoder().decode(T.self, from: d)
    }
}

struct AssistantScreen: View {
    @Environment(AppState.self) private var app
    @Environment(Router.self) private var router
    @State private var msgs: [ChatMsg] = []
    @State private var typing = false
    @State private var input = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 0) {
            TopBar(title: t("مساعد WAFI", "WAFI assistant"), subtitle: t("بيدوّر في كل المتاجر بالسعر الشامل", "Searches every store by full price"), onBack: { router.back() }) {
                if !msgs.isEmpty {
                    Button { msgs = [] } label: { Image(systemName: Ic.refresh).foregroundStyle(PR.inkSoft).frame(width: 44, height: 44) }
                        .accessibilityLabel(t("محادثة جديدة", "New chat"))
                }
            }
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        welcome
                        ForEach(Array(msgs.enumerated()), id: \.element.id) { i, m in
                            Group {
                                switch m {
                                case .user(_, let text): userBubble(text)
                                case .bot(_, let r): BotAnswer(r: r, isLast: i == msgs.count - 1) { send($0) }
                                case .failed(_, let e, let retry):
                                    if e.isQuota {
                                        QuotaWall(error: e).padding(.horizontal, -20)
                                    } else {
                                        BotBubble {
                                            VStack(alignment: .leading, spacing: 8) {
                                                Text(e.message).font(.bodyM).foregroundStyle(PR.danger)
                                                PRButton(t("جرّب تاني", "Try again"), kind: .outline, icon: Ic.refresh, height: 40) { send(retry) }.fixedSize()
                                            }
                                        }
                                    }
                                }
                            }
                            .id(m.id)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                        }
                        if typing { BotBubble { TypingDots() }.id("typing") }
                    }
                    .padding(16)
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: msgs.count) { _, _ in
                    if let id = msgs.last?.id { withAnimation { proxy.scrollTo(id, anchor: .bottom) } }
                }
                .onChange(of: typing) { _, v in if v { withAnimation { proxy.scrollTo("typing", anchor: .bottom) } } }
            }
            inputBar
        }
        .background(PR.white)
        .onAppear {
            if let m = LaunchScript.assistantMessage { LaunchScript.assistantMessage = nil; send(m) }
        }
    }

    private var welcome: some View {
        VStack(spacing: 6) {
            RadarScope(blips: [Blip(angle: 45, distance: 0.6, color: PR.amber, big: true), Blip(angle: 200, distance: 0.75), Blip(angle: 300, distance: 0.4)])
                .frame(width: 96, height: 96)
            Text(t("قولّي عايز إيه وميزانيتك", "Tell me what you want and your budget")).font(.titleL).foregroundStyle(PR.ink)
            Text(t("بفهم العامية والأرقام العربي. كل سعر بقولهولك جاي من المتاجر نفسها.", "I understand everyday language. Every price I give comes from the stores."))
                .font(.bodyS).foregroundStyle(PR.inkSoft).multilineTextAlignment(.center)
            if !app.isPro && app.config.quotas.assistant.limit > 0 {
                Text(t("المجاني: \(perWindow(app.config.quotas.assistant)) · Pro من غير حد", "Free: \(perWindow(app.config.quotas.assistant)) · unlimited with Pro"))
                    .font(.labelS).foregroundStyle(PR.inkFaint)
            }
            if msgs.isEmpty {
                FlowChips(items: Lang.isArabic ? startersAr : startersEn) { send($0) }.padding(.top, 12)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func userBubble(_ text: String) -> some View {
        HStack {
            Spacer(minLength: 40)
            Text(text).font(.bodyL).foregroundStyle(.white)
                .padding(.horizontal, 16).padding(.vertical, 11)
                .background(PR.hero)
                .clipShape(UnevenRoundedRectangle(topLeadingRadius: 20, bottomLeadingRadius: 20, bottomTrailingRadius: 6, topTrailingRadius: 20, style: .continuous))
        }
    }

    private var inputBar: some View {
        HStack(spacing: 8) {
            TextField(t("اكتب سؤالك…", "Ask anything…"), text: Binding(get: { input }, set: { input = String($0.prefix(300)) }), axis: .vertical)
                .lineLimit(1...4).font(.bodyL).foregroundStyle(PR.ink).focused($focused).submitLabel(.send)
                .onSubmit { send(input) }
                .padding(.horizontal, 16).padding(.vertical, 12)
                .background(PR.paper).clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .accessibilityIdentifier("assistant.input")
            let enabled = !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !typing
            Button { send(input) } label: {
                Image(systemName: Lang.isArabic ? "arrow.left" : "arrow.right").font(.system(size: 19, weight: .semibold)).foregroundStyle(.white)
                    .frame(width: 48, height: 48).background(enabled ? PR.signal : PR.line).clipShape(Circle())
            }
            .disabled(!enabled)
            .accessibilityLabel(t("إرسال", "Send"))
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .background(PR.white.shadow(.drop(color: .black.opacity(0.05), radius: 6, y: -2)))
    }

    private func send(_ raw: String) {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !typing else { return }
        input = ""
        withAnimation { msgs.append(.user(UUID(), text)) }
        typing = true
        Task {
            do {
                let r = try await app.api.assistant(text, lang: Lang.code)
                withAnimation { msgs.append(.bot(UUID(), r)) }
            } catch let e as APIError {
                withAnimation { msgs.append(.failed(UUID(), e, text)) }
            } catch {
                withAnimation { msgs.append(.failed(UUID(), .network(nil), text)) }
            }
            typing = false
        }
    }
}

private struct BotBubble<C: View>: View {
    @ViewBuilder var content: () -> C
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: Ic.sparkle).font(.system(size: 15)).foregroundStyle(PR.amber)
                .frame(width: 32, height: 32).background(PR.hero).clipShape(RoundedRectangle(cornerRadius: 10))
            content()
                .padding(.horizontal, 14).padding(.vertical, 11)
                .background(PR.paper)
                .clipShape(UnevenRoundedRectangle(topLeadingRadius: 6, bottomLeadingRadius: 20, bottomTrailingRadius: 20, topTrailingRadius: 20, style: .continuous))
            Spacer(minLength: 24)
        }
    }
}

private struct TypingDots: View {
    @State private var on = false
    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<3) { i in
                Circle().fill(PR.inkSoft).frame(width: 8, height: 8).opacity(on ? 1 : 0.25)
                    .animation(.easeInOut(duration: 0.5).repeatForever().delay(Double(i) * 0.16), value: on)
            }
        }
        .frame(height: 20)
        .onAppear { on = true }
    }
}

/// Chips that wrap onto as many lines as they need.
struct FlowChips: View {
    var items: [String]
    var onPick: (String) -> Void
    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(items, id: \.self) { s in
                Button { onPick(s) } label: {
                    HStack(spacing: 6) {
                        Image(systemName: Ic.sparkle).font(.system(size: 12)).foregroundStyle(PR.signalDeep)
                        Text(s).font(.labelM).foregroundStyle(PR.ink).lineLimit(1)
                    }
                    .padding(.horizontal, 14).padding(.vertical, 9)
                    .background(PR.white).clipShape(Capsule()).overlay(Capsule().stroke(PR.line))
                }
                .buttonStyle(Pressable())
            }
        }
    }
}

/// Left-to-right (or right-to-left) wrapping layout.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxW = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowH: CGFloat = 0, widest: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x > 0 && x + s.width > maxW { y += rowH + spacing; x = 0; rowH = 0 }
            x += s.width + spacing; rowH = max(rowH, s.height); widest = max(widest, x - spacing)
        }
        return CGSize(width: min(widest, maxW), height: y + rowH)
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowH: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x > bounds.minX && x + s.width > bounds.maxX { y += rowH + spacing; x = bounds.minX; rowH = 0 }
            v.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(s))
            x += s.width + spacing; rowH = max(rowH, s.height)
        }
    }
}

private struct BotAnswer: View {
    var r: AssistantResponse
    var isLast: Bool
    var onPick: (String) -> Void
    @Environment(AppState.self) private var app
    @Environment(Router.self) private var router

    var body: some View {
        let products = r.cards.first { $0.type == "products" }.map { typed($0.items, as: ProductSummary.self) } ?? []
        VStack(alignment: .leading, spacing: 10) {
            BotBubble { Text(r.reply).font(.bodyL).foregroundStyle(PR.ink) }
            ForEach(Array(r.cards.enumerated()), id: \.offset) { _, c in
                card(c, products: products).padding(.leading, 40)
            }
            if isLast && !r.suggestions.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(r.suggestions, id: \.self) { s in
                            Button { onPick(s) } label: {
                                Text(s).font(.labelM).foregroundStyle(PR.ink).padding(.horizontal, 12).padding(.vertical, 8)
                                    .background(PR.white).clipShape(Capsule()).overlay(Capsule().stroke(PR.line))
                            }
                        }
                    }
                    .padding(.leading, 40)
                }
            }
        }
    }

    @ViewBuilder private func card(_ c: AssistantCard, products: [ProductSummary]) -> some View {
        switch c.type {
        case "products":
            VStack(spacing: 8) { ForEach(products) { p in ProductRow(p: p) { router.push(.product(p.id)) } } }
        case "compare_hint":
            if products.count >= 2 {
                PRButton(t("قارن بينهم", "Compare them"), kind: .outline, icon: Ic.exchange, height: 42) {
                    app.compare = []
                    for p in products.prefix(app.compareLimit) { app.toggleCompare(p) }
                    router.push(.compare)
                }
                .fixedSize()
            }
        case "deals":
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) { ForEach(typed(c.items, as: Deal.self)) { d in DealTile(deal: d) { router.push(.product(d.id)) } } }
            }
        case "gold":
            if let g = c.gold { goldAnswer(g, karat: c.karat ?? 21) }
        case "currency":
            Panel(radius: 20, action: { router.select(.market) }) {
                HStack(spacing: 12) {
                    Text(c.code ?? "").font(.labelL).foregroundStyle(PR.ink).frame(width: 46, height: 46).background(PR.paper).clipShape(RoundedRectangle(cornerRadius: 14))
                    VStack(alignment: .leading, spacing: 2) {
                        AnimatedMoney(value: c.result, font: .headlineS)
                        if let r = c.egp, let code = c.code { Text("1 \(code) = " + Fmt.money(r)).font(.bodyS).foregroundStyle(PR.inkSoft).environment(\.layoutDirection, .leftToRight) }
                    }
                }
            }
        case "pc_build":
            if let b = c.build { pcBuild(b) }
        default:
            EmptyView()
        }
    }

    private func goldAnswer(_ g: GoldPrices, karat: Int) -> some View {
        Button { router.select(.market) } label: {
            VStack(alignment: .leading, spacing: 6) {
                Text(t("عيار \(Fmt.number(karat))", "\(karat)K")).font(.labelL).foregroundStyle(PR.amberDeep)
                AnimatedMoney(value: g.karats.first { $0.karat == karat }?.egpPerGram, font: .headline)
                HStack(spacing: 14) {
                    ForEach(g.karats.filter { $0.karat != karat }.prefix(3), id: \.karat) { k in
                        VStack(alignment: .leading, spacing: 0) {
                            Text(t("عيار \(Fmt.number(k.karat))", "\(k.karat)K")).font(.labelS).foregroundStyle(PR.ink.opacity(0.65))
                            PriceText(value: k.egpPerGram, font: .labelL)
                        }
                    }
                }
            }
            .padding(16).frame(maxWidth: .infinity, alignment: .leading)
            .background(LinearGradient(colors: [PR.goldA, PR.goldB, PR.goldC], startPoint: .topLeading, endPoint: .bottomTrailing))
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(Pressable())
    }

    private func pcBuild(_ b: PcBuild) -> some View {
        Panel(radius: 20) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    AnimatedMoney(value: b.total, font: .headlineS)
                    Spacer()
                    Badge(b.withinBudget ? t("في الميزانية", "In budget") : t("أعلى من الميزانية", "Over budget"), b.withinBudget ? .signal : .amber)
                }
                ForEach(b.parts, id: \.productId) { p in
                    HStack {
                        Text(partLabel(p.part)).font(.labelM).foregroundStyle(PR.inkSoft).frame(width: 84, alignment: .leading)
                        Text(p.titleEn).font(.bodyS).foregroundStyle(PR.ink).lineLimit(1)
                        Spacer()
                        Text(Fmt.money(p.price)).font(.labelM).foregroundStyle(PR.ink)
                    }
                }
                HStack(spacing: 8) {
                    PRButton(t("للسلة", "To basket"), icon: Ic.basket, height: 42) {
                        for p in b.parts { app.addToBasket(ProductSummary(id: p.productId, brand: "", model: "", category: "pc_parts", titleAr: p.titleAr, titleEn: p.titleEn, bestTotal: p.price)) }
                        router.select(.basket)
                    }
                    PRButton(t("عدّل", "Adjust"), kind: .outline, icon: Ic.cpu, height: 42) { router.push(.pc) }
                }
            }
        }
    }
}
