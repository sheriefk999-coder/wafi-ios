import SwiftUI
import UIKit

/// WAFI's visual language: a white instrument panel (or a navy night one). Ink text, one signal green for
/// "this is the best price / price went down", amber only for the best-price tag and gold.
/// Every colour adapts to light/dark by itself.
enum PR {
    static let white = Color(0xFFFFFF, 0x0F1A33)
    static let paper = Color(0xF5F8FE, 0x070E20)
    static let line = Color(0xE3EAF5, 0x1E2C4A)
    static let ink = Color(0x0B1633, 0xEAF0FB)
    static let inkSoft = Color(0x5A6A86, 0xA4B2CB)
    static let inkFaint = Color(0x97A3B8, 0x6C7C99)
    static let signal = Color(0x1463F3, 0x4C8DFF)
    static let signalSoft = Color(0xE8F0FE, 0x13265A)
    static let signalDeep = Color(0x0B4FD1, 0x8AB4FF)
    static let amber = Color(0xF2A516, 0xF6B73C)
    static let amberSoft = Color(0xFFF4DA, 0x3A2C0C)
    static let amberDeep = Color(0x9A6200, 0xFFCB66)
    static let amberWash = Color(0xFFFCF3, 0x221B0C)
    static let danger = Color(0xD64545, 0xFF6B6B)
    static let dangerSoft = Color(0xFDECEC, 0x3D1A1E)
    static let sky = Color(0x2E9BFF, 0x5CB6FF)
    static let skySoft = Color(0xE6F4FF, 0x0F2A48)
    static let hero = Color(0x0A1633, 0x0B1A3E)
    static let heroEnd = Color(0x0F2E7A, 0x163A8C)
    static let shimmer = Color(0xE8EEF8, 0x17233F)
    static let goldA = Color(0xFFF6DC, 0x2E2208)
    static let goldB = Color(0xFFE6A3, 0x4A360B)
    static let goldC = Color(0xF7C95A, 0x6E4F10)
    static let violet = Color(0x6A4CE0, 0x9C86FF)
    static let violetSoft = Color(0xEFEAFE, 0x231B45)
    static let music = Color(0x8B3FD9, 0xC08BFF)
    static let musicSoft = Color(0xF3E8FD, 0x2C1645)
    static let onAccent = Color.white
}

extension Color {
    /// A colour with a light and a dark value.
    init(_ light: UInt32, _ dark: UInt32) {
        self = Color(UIColor { tc in
            let v = tc.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: CGFloat((v >> 16) & 0xFF) / 255, green: CGFloat((v >> 8) & 0xFF) / 255, blue: CGFloat(v & 0xFF) / 255, alpha: 1)
        })
    }
    init(hex: UInt32) { self.init(hex, hex) }
}

/// IBM Plex Sans Arabic, bundled (same face as the Android app). Scales with Dynamic Type.
extension Font {
    enum W { case regular, medium, semibold, bold }
    static func wafi(_ size: CGFloat, _ w: W = .regular, relativeTo style: Font.TextStyle = .body) -> Font {
        let name: String
        switch w {
        case .regular: name = "IBMPlexSansArabic-Regular"
        case .medium: name = "IBMPlexSansArabic-Medium"
        case .semibold: name = "IBMPlexSansArabic-SemiBold"
        case .bold: name = "IBMPlexSansArabic-Bold"
        }
        return .custom(name, size: size, relativeTo: style)
    }
    // the type scale (same as Android's)
    static let display = wafi(32, .bold, relativeTo: .largeTitle)
    static let headline = wafi(22, .bold, relativeTo: .title)
    static let headlineS = wafi(19, .semibold, relativeTo: .title2)
    static let titleL = wafi(18, .semibold, relativeTo: .title3)
    static let titleM = wafi(16, .semibold, relativeTo: .headline)
    static let titleS = wafi(14, .semibold, relativeTo: .subheadline)
    static let bodyL = wafi(16, .regular, relativeTo: .body)
    static let bodyM = wafi(15, .regular, relativeTo: .body)
    static let bodyS = wafi(13, .regular, relativeTo: .footnote)
    static let labelL = wafi(15, .semibold, relativeTo: .callout)
    static let labelM = wafi(13, .medium, relativeTo: .caption)
    static let labelS = wafi(11, .medium, relativeTo: .caption2)
}

/// Line icons from SF Symbols, by role.
enum Ic {
    static let home = "house", search = "magnifyingglass", gold = "circle.hexagongrid", basket = "basket", user = "person"
    static let phone = "iphone", laptop = "laptopcomputer", headphones = "headphones", tablet = "ipad", car = "car"
    static let cpu = "cpu", gpu = "rectangle.3.group", board = "square.grid.3x3", ram = "memorychip", storage = "internaldrive"
    static let power = "bolt.batteryblock", caseIc = "pc", other = "shippingbox", exchange = "arrow.left.arrow.right"
    static let heart = "heart", heartFill = "heart.fill", bell = "bell", shield = "checkmark.shield", bolt = "bolt.fill"
    static let chart = "chart.xyaxis.line", gear = "gearshape", logout = "rectangle.portrait.and.arrow.right", card = "creditcard"
    static let wallet = "wallet.pass", store = "storefront", truck = "shippingbox", filter = "line.3.horizontal.decrease"
    static let back = "chevron.backward", forward = "chevron.forward", close = "xmark", plus = "plus", minus = "minus"
    static let trash = "trash", check = "checkmark", eye = "eye", eyeOff = "eye.slash", mail = "envelope", lock = "lock"
    static let sparkle = "sparkles", gamepad = "gamecontroller", film = "film", code = "chevron.left.forwardslash.chevron.right"
    static let briefcase = "briefcase", share = "square.and.arrow.up", external = "arrow.up.forward.square", refresh = "arrow.clockwise"
    static let globe = "globe", info = "info.circle", crown = "crown", server = "server.rack", gauge = "gauge.with.dots.needle.33percent"
    static let barcode = "barcode.viewfinder", mic = "mic", tag = "tag", shirt = "tshirt", camera = "camera", battery = "battery.100"
    static let broadcast = "dot.radiowaves.left.and.right", family = "figure.2.and.child.holdinghands", leaf = "leaf", snow = "snowflake"
    static let moon = "moon", sun = "sun.max", monitor = "display", compass = "safari", music = "music.note", trend = "chart.line.uptrend.xyaxis"
    static let calendar = "calendar"
}

func categoryIcon(_ c: Category) -> String {
    switch c {
    case .phones: return Ic.phone
    case .laptops: return Ic.laptop
    case .audio: return Ic.headphones
    case .tablets: return Ic.tablet
    case .cars: return Ic.car
    case .pcParts: return Ic.cpu
    case .fashion: return Ic.shirt
    case .music: return Ic.music
    case .other: return Ic.other
    }
}

func partIcon(_ p: String?) -> String {
    switch p {
    case "cpu": return Ic.cpu
    case "gpu": return Ic.gpu
    case "motherboard": return Ic.board
    case "ram": return Ic.ram
    case "storage": return Ic.storage
    case "psu": return Ic.power
    case "case": return Ic.caseIc
    default: return Ic.other
    }
}

/// Each category gets a soft tint so a product without a photo still reads at a glance.
func categoryTint(_ c: Category) -> (bg: Color, fg: Color) {
    switch c {
    case .phones: return (PR.skySoft, PR.sky)
    case .laptops: return (PR.violetSoft, PR.violet)
    case .audio: return (PR.amberSoft, PR.amberDeep)
    case .tablets: return (Color(0xE6F6FB, 0x0D2E3A), Color(0x0E7C9E, 0x5CC8EA))
    case .cars: return (Color(0xFDEDE7, 0x3A1C10), Color(0xC2521F, 0xFF9466))
    case .pcParts: return (PR.signalSoft, PR.signalDeep)
    case .fashion: return (Color(0xFCE8F3, 0x3A1029), Color(0xC2287A, 0xFF7CC0))
    case .music: return (PR.musicSoft, PR.music)
    case .other: return (PR.paper, PR.inkSoft)
    }
}
