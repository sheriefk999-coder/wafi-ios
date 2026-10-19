import SwiftUI

/// A product's picture, or its category icon on a soft tint when there is no photo.
struct ProductImage: View {
    var category: String
    var part: String?
    var imageURL: String?
    var size: CGFloat = 56
    var radius: CGFloat? = nil
    var body: some View {
        let cat = Category.from(category)
        let tint = categoryTint(cat)
        ZStack {
            tint.bg
            Image(systemName: cat == .pcParts ? partIcon(part) : categoryIcon(cat))
                .font(.system(size: size * 0.42, weight: .regular)).foregroundStyle(tint.fg)
            if let s = imageURL, s.hasPrefix("https://"), let u = URL(string: s) {
                AsyncImage(url: u) { phase in
                    if let img = phase.image { img.resizable().scaledToFit().padding(size * 0.08).frame(maxWidth: .infinity, maxHeight: .infinity).background(Color.white) }
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: radius ?? size * 0.28, style: .continuous))
    }
}

/// The small line under a product: which store, when we saw the price, and whether it's in stock.
struct OfferMeta: View {
    var store: String?
    var seenAt: String?
    var inStock: Bool?
    var compact = false
    var body: some View {
        let seen = compact ? nil : Fmt.seen(seenAt)
        let text = [store, seen].compactMap { $0 }.joined(separator: "  ·  ")
        if !(text.isEmpty && inStock == nil) {
            HStack(spacing: 4) {
                if !text.isEmpty { Text(text).foregroundStyle(PR.inkFaint).lineLimit(1) }
                if let inStock {
                    if !text.isEmpty { Text("·").foregroundStyle(PR.inkFaint) }
                    Circle().fill(inStock ? PR.signal : PR.danger).frame(width: 5, height: 5)
                    Text(inStock ? t("متوفر", "In stock") : t("مش متوفر", "Out of stock")).foregroundStyle(inStock ? PR.signalDeep : PR.danger)
                }
            }
            .font(.wafi(11, .regular))
        }
    }
}

struct ProductRow: View {
    var p: ProductSummary
    var action: () -> Void
    var body: some View {
        Panel(padding: 12, action: action) {
            HStack(spacing: 12) {
                ProductImage(category: p.category, part: p.specs.str("part"), imageURL: p.imageUrl, size: 56).frame(width: 56, height: 56)
                VStack(alignment: .leading, spacing: 2) {
                    Text(p.title).font(.titleS).foregroundStyle(PR.ink).lineLimit(2).multilineTextAlignment(.leading)
                    Text(p.subtitle).font(.bodyS).foregroundStyle(PR.inkSoft).lineLimit(1)
                    OfferMeta(store: p.bestStore, seenAt: p.bestSeenAt, inStock: p.inStock)
                    HStack(spacing: 8) {
                        PriceText(value: p.displayPrice, font: .titleM, color: p.bestTotal != nil ? PR.ink : PR.inkSoft,
                                  fallback: t("لا يوجد سعر حالي", "No current price"))
                        if p.bestTotal != nil { Badge(t("شامل الشحن", "incl. shipping"), .signal) }
                        else if p.minPrice != nil { Badge(t("بدون الشحن", "before shipping")) }
                    }
                    .padding(.top, 4)
                }
                Spacer(minLength: 0)
                if p.offers > 1 {
                    VStack(spacing: 0) {
                        Text(Fmt.number(p.offers)).font(.titleM).foregroundStyle(PR.ink)
                        Text(t("متجر", "stores")).font(.labelS).foregroundStyle(PR.inkSoft)
                    }
                }
            }
        }
    }
}

/// Compact card for horizontal carousels.
struct ProductTile: View {
    var p: ProductSummary
    var rank: Int?
    var action: () -> Void
    var body: some View {
        Panel(padding: 12, action: action) {
            VStack(alignment: .leading, spacing: 0) {
                ZStack(alignment: .topLeading) {
                    ProductImage(category: p.category, part: p.specs.str("part"), imageURL: p.imageUrl, size: 110, radius: 14)
                        .frame(maxWidth: .infinity).frame(height: 106)
                    if rank == 0 { Badge(t("الأرخص", "Lowest"), .amber, icon: Ic.bolt).padding(6) }
                }
                Text(p.title).font(.wafi(15, .semibold)).foregroundStyle(PR.ink).lineLimit(2).frame(height: 42, alignment: .top).padding(.top, 10)
                PriceText(value: p.displayPrice, font: .titleM).padding(.top, 6)
                Text(p.bestTotal != nil ? t("شامل الشحن", "incl. shipping") : t("قبل الشحن", "before shipping")).font(.labelS).foregroundStyle(PR.inkSoft)
                OfferMeta(store: p.bestStore, seenAt: p.bestSeenAt, inStock: p.inStock, compact: true).padding(.top, 4)
            }
        }
        .frame(width: 168)
    }
}
