import SwiftUI

// MARK: - Radar

/// A blip on the radar: angle in degrees (0 = top, clockwise), distance 0..1 from the centre.
struct Blip: Hashable { var angle: Double; var distance: Double; var color: Color = PR.signal; var big = false }

/// The WAFI scope: rings, crosshair and a rotating sweep. Each blip lights up as the beam passes it.
struct RadarScope: View {
    var blips: [Blip]
    var ring: Color = PR.ink.opacity(0.10)
    var beam: Color = PR.signal
    var period: Double = 3.6
    var animated = !Motion.reduced

    var body: some View {
        TimelineView(.animation(paused: !animated)) { tl in
            let sweep = animated ? (tl.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: period) / period) * 360 : 60
            Canvas { ctx, size in
                let r = min(size.width, size.height) / 2
                let c = CGPoint(x: size.width / 2, y: size.height / 2)
                for i in 1...4 {
                    let rr = r * CGFloat(i) / 4
                    ctx.stroke(Path(ellipseIn: CGRect(x: c.x - rr, y: c.y - rr, width: rr * 2, height: rr * 2)), with: .color(ring), lineWidth: 1)
                }
                var cross = Path()
                cross.move(to: CGPoint(x: c.x - r, y: c.y)); cross.addLine(to: CGPoint(x: c.x + r, y: c.y))
                cross.move(to: CGPoint(x: c.x, y: c.y - r)); cross.addLine(to: CGPoint(x: c.x, y: c.y + r))
                ctx.stroke(cross, with: .color(ring), lineWidth: 1)
                // beam: a wedge fading behind the leading edge
                let lead = Angle(degrees: sweep - 90)
                var wedge = Path()
                wedge.move(to: c)
                wedge.addArc(center: c, radius: r, startAngle: lead - .degrees(70), endAngle: lead, clockwise: false)
                wedge.closeSubpath()
                ctx.fill(wedge, with: .conicGradient(Gradient(stops: [.init(color: .clear, location: 0), .init(color: beam.opacity(0.35), location: 70.0 / 360)]),
                                                     center: c, angle: lead - .degrees(70)))
                var edge = Path()
                edge.move(to: c)
                let lr: Double = lead.radians
                edge.addLine(to: CGPoint(x: c.x + r * CGFloat(Foundation.cos(lr)), y: c.y + r * CGFloat(Foundation.sin(lr))))
                ctx.stroke(edge, with: .color(beam.opacity(0.9)), lineWidth: 2)
                for b in blips {
                    let since = ((sweep - b.angle).truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360)
                    let glow = max(0.15, min(1, 1 - since / 300))
                    let a: Double = (b.angle - 90) * Double.pi / 180
                    let rd: CGFloat = r * CGFloat(b.distance)
                    let p = CGPoint(x: c.x + rd * CGFloat(Foundation.cos(a)), y: c.y + rd * CGFloat(Foundation.sin(a)))
                    let dot: CGFloat = b.big ? 6 : 4
                    let halo = dot * 3 * (0.6 + glow)
                    ctx.fill(Path(ellipseIn: CGRect(x: p.x - halo, y: p.y - halo, width: halo * 2, height: halo * 2)), with: .color(b.color.opacity(0.18 * glow)))
                    ctx.fill(Path(ellipseIn: CGRect(x: p.x - dot, y: p.y - dot, width: dot * 2, height: dot * 2)), with: .color(b.color.opacity(glow)))
                }
                ctx.fill(Path(ellipseIn: CGRect(x: c.x - 3, y: c.y - 3, width: 6, height: 6)), with: .color(beam))
            }
        }
    }
}

/// The WAFI mark: a ribbon W whose last stroke ends in a price tag (drawn as vectors, any size).
struct WafiMark: View {
    var body: some View {
        Canvas { ctx, size in
            let k = min(size.width, size.height) / 512
            ctx.scaleBy(x: k, y: k)
            ctx.translateBy(x: -9, y: 14)
            func line(_ a: CGPoint, _ b: CGPoint) -> Path { Path { p in p.move(to: a); p.addLine(to: b) } }
            func grad(_ a: CGPoint, _ b: CGPoint, _ c1: UInt32, _ c2: UInt32) -> GraphicsContext.Shading {
                .linearGradient(Gradient(colors: [Color(hex: c1), Color(hex: c2)]), startPoint: a, endPoint: b)
            }
            let round = StrokeStyle(lineWidth: 78, lineCap: .round, lineJoin: .round)
            let p1 = CGPoint(x: 78, y: 168), p2 = CGPoint(x: 170, y: 360), p3 = CGPoint(x: 262, y: 200)
            let p4 = CGPoint(x: 338, y: 356), p5 = CGPoint(x: 432, y: 150)
            ctx.stroke(line(p1, p2), with: grad(p1, p2, 0x2A74FF, 0x0A3FD0), style: StrokeStyle(lineWidth: 78, lineCap: .butt))
            ctx.stroke(line(p3, p4), with: grad(p3, p4, 0x0B3CC4, 0x1557F0), style: round)
            var shadow = ctx
            shadow.addFilter(.shadow(color: Color(hex: 0x041A55).opacity(0.3), radius: 7, x: -4, y: 6))
            shadow.stroke(line(p2, p3), with: grad(p2, p3, 0x0E52E8, 0x43A6FF), style: round)
            let tag = Path { p in
                p.move(to: CGPoint(x: 405.6, y: 138)); p.addLine(to: CGPoint(x: 458.4, y: 162)); p.addLine(to: CGPoint(x: 475, y: 125.6))
                p.addLine(to: CGPoint(x: 457.7, y: 93.6)); p.addLine(to: CGPoint(x: 422.2, y: 101.6)); p.closeSubpath()
            }
            let tagShade = grad(p4, CGPoint(x: 470, y: 100), 0x1259F2, 0x3A98FF)
            shadow.drawLayer { l in
                l.stroke(line(p4, p5), with: tagShade, style: round)
                l.fill(tag, with: tagShade)
                l.stroke(tag, with: tagShade, style: StrokeStyle(lineWidth: 20, lineJoin: .round))
            }
            ctx.fill(Path(ellipseIn: CGRect(x: 434.9, y: 105.2, width: 24, height: 24)), with: .color(.white))
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityLabel("WAFI")
    }
}

/// The mark on its navy tile, for headers.
struct RadarMark: View {
    var size: CGFloat = 36
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.3, style: .continuous)
                .fill(RadialGradient(colors: [Color(hex: 0x16367A), Color(hex: 0x0A1A42), Color(hex: 0x050C22)],
                                     center: .init(x: 0.52, y: 0.4), startRadius: 0, endRadius: size * 0.8))
            WafiMark().frame(width: size * 0.84, height: size * 0.84)
        }
        .frame(width: size, height: size)
    }
}

enum Motion {
    /// Off for "Reduce Motion" and for screenshot runs.
    static var reduced: Bool { UIAccessibility.isReduceMotionEnabled || ProcessInfo.processInfo.arguments.contains("-WAFI_SCREENSHOTS") }
}

// MARK: - Surfaces

/// White panel with a hairline border. Shadows are kept for floating things.
struct Panel<Content: View>: View {
    var padding: CGFloat = 16
    var radius: CGFloat = 18
    var background: Color = PR.white
    var border: Color = PR.line
    var action: (() -> Void)?
    @ViewBuilder var content: () -> Content

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        let inner = content().padding(padding).frame(maxWidth: .infinity, alignment: .leading)
            .background(background).clipShape(shape).overlay(shape.stroke(border, lineWidth: 1))
        if let action {
            Button(action: action) { inner }.buttonStyle(Pressable())
        } else {
            inner
        }
    }
}

/// A small press-down scale so taps feel physical.
struct Pressable: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
            .contentShape(Rectangle())
    }
}

extension View {
    func pressable(_ action: @escaping () -> Void) -> some View {
        Button(action: action) { self }.buttonStyle(Pressable())
    }
}

// MARK: - Buttons & chips

enum BtnKind { case primary, dark, outline, ghost, gold }

struct PRButton: View {
    var title: String
    var kind: BtnKind = .primary
    var icon: String?
    var loading = false
    var enabled = true
    var height: CGFloat = 54
    var action: () -> Void

    init(_ title: String, kind: BtnKind = .primary, icon: String? = nil, loading: Bool = false, enabled: Bool = true,
         height: CGFloat = 54, action: @escaping () -> Void) {
        self.title = title; self.kind = kind; self.icon = icon; self.loading = loading; self.enabled = enabled
        self.height = height; self.action = action
    }

    var body: some View {
        let (bg, fg, border): (Color, Color, Color) = {
            switch kind {
            case .primary: return (PR.signal, PR.onAccent, PR.signal)
            case .dark: return (PR.hero, PR.onAccent, PR.hero)
            case .outline: return (PR.white, PR.ink, PR.line)
            case .ghost: return (.clear, PR.ink, .clear)
            case .gold: return (PR.amber, Color(hex: 0x0B1633), PR.amber)
            }
        }()
        Button(action: { if enabled && !loading { action() } }) {
            HStack(spacing: 8) {
                if loading {
                    ProgressView().tint(fg)
                } else {
                    if let icon { Image(systemName: icon).font(.system(size: 17, weight: .semibold)) }
                    Text(title).font(.labelL)
                }
            }
            .foregroundStyle(enabled ? fg : PR.inkFaint)
            .frame(maxWidth: .infinity, minHeight: height)
            .padding(.horizontal, 20)
            .background(enabled ? bg : PR.line)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(enabled ? border : PR.line))
        }
        .buttonStyle(Pressable())
        .disabled(!enabled || loading)
    }
}

struct Chip: View {
    var text: String
    var selected: Bool
    var icon: String?
    var action: () -> Void

    init(_ text: String, selected: Bool, icon: String? = nil, action: @escaping () -> Void) {
        self.text = text; self.selected = selected; self.icon = icon; self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon { Image(systemName: icon).font(.system(size: 14, weight: .medium)) }
                Text(text).font(.labelM).lineLimit(1)
            }
            .foregroundStyle(selected ? PR.onAccent : PR.ink)
            .padding(.horizontal, 14).padding(.vertical, 9)
            .background(selected ? PR.hero : PR.white)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(selected ? PR.hero : PR.line))
            .animation(.easeOut(duration: 0.18), value: selected)
        }
        .buttonStyle(Pressable())
    }
}

enum Tone { case signal, amber, danger, neutral, sky }

struct Badge: View {
    var text: String
    var tone: Tone = .neutral
    var icon: String?
    init(_ text: String, _ tone: Tone = .neutral, icon: String? = nil) { self.text = text; self.tone = tone; self.icon = icon }
    var body: some View {
        let (bg, fg): (Color, Color) = {
            switch tone {
            case .signal: return (PR.signalSoft, PR.signalDeep)
            case .amber: return (PR.amberSoft, PR.amberDeep)
            case .danger: return (PR.dangerSoft, PR.danger)
            case .neutral: return (PR.paper, PR.inkSoft)
            case .sky: return (PR.skySoft, PR.sky)
            }
        }()
        HStack(spacing: 4) {
            if let icon { Image(systemName: icon).font(.system(size: 11, weight: .semibold)) }
            Text(text).font(.labelS).lineLimit(1)
        }
        .foregroundStyle(fg)
        .padding(.horizontal, 8).padding(.vertical, 3)
        .background(bg)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

/// Rounded icon tile for categories, tools and parts.
struct IconTile: View {
    var icon: String
    var bg: Color = PR.paper
    var fg: Color = PR.ink
    var size: CGFloat = 44
    var iconSize: CGFloat = 20
    var body: some View {
        Image(systemName: icon)
            .font(.system(size: iconSize, weight: .medium))
            .foregroundStyle(fg)
            .frame(width: size, height: size)
            .background(bg)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.32, style: .continuous))
    }
}

struct SectionHeader: View {
    var title: String
    var action: String?
    var onAction: (() -> Void)?
    var body: some View {
        HStack {
            Text(title).font(.titleL).foregroundStyle(PR.ink)
            Spacer()
            if let action, let onAction {
                Button(action, action: onAction).font(.labelM).foregroundStyle(PR.signalDeep)
            }
        }
    }
}

/// The screen header used everywhere (the system navigation bar is hidden for a calmer look).
struct TopBar<Trailing: View>: View {
    var title: String
    var subtitle: String?
    var onBack: (() -> Void)?
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(spacing: 4) {
            if let onBack {
                Button(action: onBack) {
                    Image(systemName: Ic.back).font(.system(size: 19, weight: .semibold)).foregroundStyle(PR.ink).frame(width: 44, height: 44)
                }
                .accessibilityLabel(t("رجوع", "Back"))
            } else { Spacer().frame(width: 12) }
            VStack(alignment: .leading, spacing: 0) {
                Text(title).font(.titleL).foregroundStyle(PR.ink).lineLimit(1)
                if let subtitle { Text(subtitle).font(.bodyS).foregroundStyle(PR.inkSoft).lineLimit(1) }
            }
            Spacer(minLength: 0)
            trailing()
        }
        .padding(.horizontal, 8).frame(minHeight: 56)
        .background(PR.white)
    }
}

extension TopBar where Trailing == EmptyView {
    init(title: String, subtitle: String? = nil, onBack: (() -> Void)? = nil) {
        self.init(title: title, subtitle: subtitle, onBack: onBack) { EmptyView() }
    }
}

// MARK: - Fields

struct PRField: View {
    var label: String
    @Binding var text: String
    var icon: String?
    var error: String?
    var keyboard: UIKeyboardType = .default
    var secure = false
    var ltr = false
    var placeholder: String?
    var content: UITextContentType?
    @FocusState private var focused: Bool
    @State private var reveal = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.labelM).foregroundStyle(focused ? PR.ink : PR.inkSoft)
            HStack(spacing: 10) {
                if let icon { Image(systemName: icon).foregroundStyle(error != nil ? PR.danger : PR.inkSoft) }
                Group {
                    if secure && !reveal {
                        SecureField(placeholder ?? "", text: $text)
                    } else {
                        TextField(placeholder ?? "", text: $text)
                    }
                }
                .font(.bodyL).foregroundStyle(PR.ink)
                .keyboardType(keyboard)
                .textContentType(content)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(keyboard != .default || secure)
                .environment(\.layoutDirection, ltr ? .leftToRight : (Lang.isArabic ? .rightToLeft : .leftToRight))
                .focused($focused)
                if secure {
                    Button { reveal.toggle() } label: { Image(systemName: reveal ? Ic.eyeOff : Ic.eye).foregroundStyle(PR.inkSoft) }
                        .accessibilityLabel(reveal ? t("إخفاء", "Hide") : t("إظهار", "Show"))
                }
            }
            .padding(.horizontal, 14).frame(minHeight: 52)
            .background(PR.white)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(error != nil ? PR.danger : (focused ? PR.ink : PR.line), lineWidth: focused ? 1.5 : 1))
            if let error { Text(error).font(.bodyS).foregroundStyle(PR.danger).transition(.opacity) }
        }
        .animation(.easeOut(duration: 0.15), value: error)
    }
}

// MARK: - States

struct EmptyState: View {
    var icon: String
    var title: String
    var bodyText: String
    var action: String?
    var onAction: (() -> Void)?
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon).font(.system(size: 32)).foregroundStyle(PR.inkSoft)
                .frame(width: 88, height: 88).background(PR.paper).clipShape(Circle())
            Text(title).font(.titleM).foregroundStyle(PR.ink).multilineTextAlignment(.center).padding(.top, 8)
            Text(bodyText).font(.bodyM).foregroundStyle(PR.inkSoft).multilineTextAlignment(.center)
            if let action, let onAction {
                PRButton(action, kind: .dark, height: 48, action: onAction).frame(maxWidth: 260).padding(.top, 12)
            }
        }
        .frame(maxWidth: .infinity).padding(28)
    }
}

struct Shimmer: ViewModifier {
    @State private var x: CGFloat = -1
    func body(content: Content) -> some View {
        content.overlay(
            GeometryReader { g in
                LinearGradient(colors: [PR.paper, PR.shimmer, PR.paper], startPoint: .leading, endPoint: .trailing)
                    .frame(width: g.size.width * 0.8)
                    .offset(x: x * g.size.width)
            }
        )
        .clipped()
        .onAppear { if !Motion.reduced { withAnimation(.linear(duration: 1.3).repeatForever(autoreverses: false)) { x = 1.4 } } }
    }
}

struct Skeleton: View {
    var height: CGFloat = 14
    var body: some View {
        RoundedRectangle(cornerRadius: 12).fill(PR.paper).frame(height: height).modifier(Shimmer())
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct LoadingList: View {
    var rows = 4
    var body: some View {
        VStack(spacing: 12) {
            ForEach(0..<rows, id: \.self) { _ in
                HStack(spacing: 12) {
                    Skeleton(height: 56).frame(width: 56)
                    VStack(alignment: .leading, spacing: 8) { Skeleton(height: 14); Skeleton(height: 12).frame(maxWidth: 140) }
                }
            }
        }
        .padding(16)
    }
}

/// Fades and lifts children in, staggered by index.
struct Reveal: ViewModifier {
    var index: Int
    @State private var shown = Motion.reduced
    func body(content: Content) -> some View {
        content.opacity(shown ? 1 : 0).offset(y: shown ? 0 : 14)
            .onAppear { guard !shown else { return }; withAnimation(.easeOut(duration: 0.35).delay(Double(index % 8) * 0.04)) { shown = true } }
    }
}

extension View { func reveal(_ i: Int) -> some View { modifier(Reveal(index: i)) } }

// MARK: - Numbers

struct PriceText: View {
    var value: Decimal?
    var font: Font = .titleM
    var color: Color = PR.ink
    var fallback = "—"
    var body: some View {
        Text(value.map { Fmt.money($0) } ?? fallback).font(font).foregroundStyle(color).lineLimit(1).minimumScaleFactor(0.7)
    }
}

/// A money amount that rolls when it changes; the final frame is the exact value.
struct AnimatedMoney: View {
    var value: Decimal?
    var font: Font
    var color: Color = PR.ink
    var body: some View {
        Text(value.map { Fmt.money($0) } ?? "—")
            .font(font).foregroundStyle(color).lineLimit(1).minimumScaleFactor(0.6)
            .contentTransition(.numericText())
            .animation(.easeOut(duration: 0.6), value: value)
    }
}

/// ▲ / ▼ with the percentage, coloured green for down (cheaper) and red for up.
struct TrendPill: View {
    var pct: Decimal
    var body: some View {
        let down = pct < 0, flat = pct == 0
        let (bg, fg): (Color, Color) = flat ? (PR.paper, PR.inkSoft) : down ? (PR.signalSoft, PR.signalDeep) : (PR.dangerSoft, PR.danger)
        Text((flat ? "" : down ? "▼ " : "▲ ") + (Fmt.pct(pct) ?? ""))
            .font(.labelM).foregroundStyle(fg)
            .padding(.horizontal, 9).padding(.vertical, 3)
            .background(bg).clipShape(Capsule())
    }
}

// MARK: - Charts

/// An area chart that draws itself in; time runs with the reading direction.
struct AreaChart: View {
    var values: [Double]
    var color: Color = PR.amberDeep
    var showDot = true
    @Environment(\.layoutDirection) private var dir
    @State private var progress: CGFloat = Motion.reduced ? 1 : 0

    var body: some View {
        GeometryReader { g in
            let w = g.size.width, h = g.size.height
            let lo = values.min() ?? 0, hi = values.max() ?? 1
            let span = hi - lo > 0 ? hi - lo : 1
            let pts: [CGPoint] = values.enumerated().map { i, v in
                let fx = values.count > 1 ? CGFloat(i) / CGFloat(values.count - 1) * w : 0
                return CGPoint(x: dir == .rightToLeft ? w - fx : fx, y: 8 + CGFloat((hi - v) / span) * (h - 14))
            }
            ZStack {
                if pts.count > 1 {
                    Path { p in p.move(to: pts[0]); pts.dropFirst().forEach { p.addLine(to: $0) }
                        p.addLine(to: CGPoint(x: pts.last!.x, y: h)); p.addLine(to: CGPoint(x: pts[0].x, y: h)); p.closeSubpath() }
                        .fill(LinearGradient(colors: [color.opacity(0.28), color.opacity(0)], startPoint: .top, endPoint: .bottom))
                        .opacity(progress)
                    Path { p in p.move(to: pts[0]); pts.dropFirst().forEach { p.addLine(to: $0) } }
                        .trim(from: 0, to: progress)
                        .stroke(color, style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
                    if showDot && progress >= 1, let e = pts.last {
                        Circle().fill(color.opacity(0.2)).frame(width: 18, height: 18).position(e)
                        Circle().fill(PR.white).frame(width: 10, height: 10).position(e)
                        Circle().fill(color).frame(width: 7, height: 7).position(e)
                    }
                }
            }
            // the chart already runs in the reading direction; don't mirror it again
            .environment(\.layoutDirection, .leftToRight)
        }
        .onAppear { if progress < 1 { withAnimation(.easeOut(duration: 1.1)) { progress = 1 } } }
    }
}

/// Parts of a whole as a ring.
struct Donut: View {
    var shares: [(Double, Color)]
    var thickness: CGFloat = 22
    var body: some View {
        let total = max(shares.map(\.0).reduce(0, +), 0.0001)
        ZStack {
            Circle().stroke(PR.line.opacity(0.5), lineWidth: thickness)
            ForEach(Array(shares.enumerated()), id: \.offset) { i, s in
                let start = shares.prefix(i).map(\.0).reduce(0, +) / total
                Circle().trim(from: start, to: start + s.0 / total)
                    .stroke(s.1, style: StrokeStyle(lineWidth: thickness, lineCap: .butt))
                    .rotationEffect(.degrees(-90))
            }
        }
        .padding(thickness / 2)
    }
}

/// A score 0..100 in a ring.
struct ScoreRing: View {
    var score: Int
    var size: CGFloat = 52
    var color: Color = PR.signal
    var body: some View {
        ZStack {
            Circle().stroke(PR.line, lineWidth: 5)
            Circle().trim(from: 0, to: CGFloat(min(max(score, 0), 100)) / 100)
                .stroke(color, style: StrokeStyle(lineWidth: 5, lineCap: .round)).rotationEffect(.degrees(-90))
            Text(Fmt.number(score)).font(.labelL).foregroundStyle(PR.ink)
        }
        .frame(width: size, height: size)
    }
}

/// A half-circle gauge with a needle at [value] 0..1 (low sits at the start edge).
struct RangeGauge: View {
    var value: Double
    var body: some View {
        GeometryReader { g in
            let w = g.size.width, h = g.size.height
            let c = CGPoint(x: w / 2, y: h * 0.92)
            let r = min(w / 2, h * 0.9) - 10
            ZStack {
                Path { p in p.addArc(center: c, radius: r, startAngle: .degrees(180), endAngle: .degrees(360), clockwise: false) }
                    .stroke(LinearGradient(colors: [PR.signal, PR.amber, PR.danger], startPoint: .leading, endPoint: .trailing),
                            style: StrokeStyle(lineWidth: 12, lineCap: .round))
                let a = Angle(degrees: 180 + 180 * min(max(value, 0), 1))
                Path { p in let ar: Double = a.radians; let rr: CGFloat = r - 14; p.move(to: c); p.addLine(to: CGPoint(x: c.x + rr * CGFloat(Foundation.cos(ar)), y: c.y + rr * CGFloat(Foundation.sin(ar)))) }
                    .stroke(PR.ink, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                Circle().fill(PR.ink).frame(width: 12, height: 12).position(c)
            }
        }
    }
}

struct MeterBar: View {
    var fraction: Double
    var color: Color = PR.signal
    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Capsule().fill(PR.line)
                Capsule().fill(color).frame(width: g.size.width * min(max(fraction, 0), 1))
            }
        }
        .frame(height: 6)
    }
}

// MARK: - Toast

struct ToastView: View {
    var text: String
    var body: some View {
        Text(text).font(.labelL).foregroundStyle(PR.onAccent)
            .padding(.horizontal, 18).padding(.vertical, 12)
            .background(PR.hero).clipShape(Capsule())
            .shadow(color: .black.opacity(0.18), radius: 12, y: 4)
    }
}
