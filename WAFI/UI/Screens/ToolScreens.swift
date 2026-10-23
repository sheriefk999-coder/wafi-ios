import SwiftUI

private func dec(_ s: String) -> Decimal? {
    let c = s.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: "")
    return c.isEmpty ? nil : Decimal(string: c, locale: Locale(identifier: "en_US_POSIX"))
}

// MARK: - Installment calculator

struct InstallmentScreen: View {
    @Environment(AppState.self) private var app
    @State private var price = ""
    @State private var down = ""
    @State private var busy = false
    @State private var err: String?
    @State private var result: InstallmentResult?

    var body: some View {
        Screen(title: t("حاسبة التقسيط", "Installment")) {
            VStack(spacing: 14) {
                PRField(label: t("سعر المنتج (كاش)", "Cash price"), text: $price, icon: Ic.tag, error: err, keyboard: .numberPad, placeholder: "50000")
                PRField(label: t("مقدّم (اختياري)", "Down payment (optional)"), text: $down, icon: Ic.wallet, keyboard: .numberPad, placeholder: "0")
                PRButton(busy ? t("بيحسب…", "Calculating…") : t("احسب الأقساط", "Calculate"), icon: Ic.card, enabled: !busy) { Task { await calc() } }

                if let res = result {
                    HStack {
                        Text(t("بتموّل ", "Financing ") + Fmt.money(res.financed)).font(.bodyM).foregroundStyle(PR.inkSoft)
                        Spacer()
                    }
                    ForEach(res.plans, id: \.months) { pl in
                        Panel {
                            HStack(alignment: .center) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\(pl.months) " + t("شهر", "months")).font(.titleS).foregroundStyle(PR.ink)
                                    Text(pl.extraVsCash == 0 ? t("من غير فوايد", "0% — no extra")
                                         : t("زيادة عن الكاش ", "extra over cash ") + Fmt.money(pl.extraVsCash) + " (\(fmtPct(pl.markupPct)))")
                                        .font(.bodyS).foregroundStyle(pl.extraVsCash == 0 ? PR.signalDeep : PR.inkSoft)
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text(Fmt.money(pl.monthly) + t(" /شهر", "/mo")).font(.titleM).foregroundStyle(PR.ink)
                                    Text(t("إجمالي ", "total ") + Fmt.money(pl.total)).font(.labelS).foregroundStyle(PR.inkFaint)
                                }
                            }
                        }
                    }
                    Text(Lang.isArabic ? res.noteAr : res.noteEn).font(.bodyS).foregroundStyle(PR.inkFaint)
                }
            }
            .padding(20)
        }
    }

    private func calc() async {
        guard let p = dec(price), p > 0 else { err = t("اكتب سعر صحيح", "Enter a valid price"); return }
        busy = true; err = nil
        do { result = try await app.api.installment(price: p, down: dec(down) ?? 0) }
        catch { err = t("حصل خطأ، جرّب تاني", "Something went wrong, try again") }
        busy = false
    }
}

// MARK: - Gold piece calculator

struct GoldCalcScreen: View {
    @Environment(AppState.self) private var app
    @State private var grams = ""
    @State private var karat = 21
    @State private var making = ""
    @State private var monthly = ""
    @State private var busy = false
    @State private var err: String?
    @State private var result: GoldCalcResult?

    var body: some View {
        Screen(title: t("حاسبة الدهب", "Gold calculator")) {
            VStack(alignment: .leading, spacing: 14) {
                PRField(label: t("الوزن بالجرام", "Weight (grams)"), text: $grams, icon: Ic.gold, error: err, keyboard: .decimalPad, placeholder: "10")
                Text(t("العيار", "Karat")).font(.labelM).foregroundStyle(PR.inkSoft)
                HStack(spacing: 8) {
                    ForEach([24, 22, 21, 18, 14], id: \.self) { k in
                        Chip("\(k)", selected: karat == k) { karat = k }
                    }
                }
                PRField(label: t("المصنعية للجرام (اختياري)", "Making / gram (optional)"), text: $making, icon: Ic.gear, keyboard: .numberPad, placeholder: "80")
                PRField(label: t("لو هتدخّر شهرياً (اختياري)", "Monthly saving (optional)"), text: $monthly, icon: Ic.wallet, keyboard: .numberPad, placeholder: "5000")
                PRButton(busy ? t("بيحسب…", "Calculating…") : t("احسب السعر", "Calculate"), icon: Ic.gold, enabled: !busy) { Task { await calc() } }

                if let r = result {
                    Panel {
                        VStack(spacing: 8) {
                            row(t("سعر الجرام عيار \(r.karat)", "Gram price (\(r.karat)k)"), Fmt.money(r.pricePerGram))
                            row(t("قيمة الذهب", "Metal value"), Fmt.money(r.metalValue))
                            row(t("المصنعية", "Making"), Fmt.money(r.making))
                            Divider()
                            HStack {
                                Text(t("الإجمالي", "Total")).font(.titleS).foregroundStyle(PR.ink)
                                Spacer()
                                Text(Fmt.money(r.total)).font(.titleM).foregroundStyle(PR.amberDeep)
                            }
                        }
                    }
                    if let s = r.savings {
                        Panel(background: PR.paper, border: PR.paper) {
                            Text(t("هتوصله في ", "You'll reach it in ") + "\(s.months) " + t("شهر", "months") +
                                 t(" وإنت بتدخّر ", " saving ") + Fmt.money(s.monthly) + t(" شهرياً", "/mo"))
                                .font(.bodyM).foregroundStyle(PR.signalDeep)
                        }
                    }
                    Text(Lang.isArabic ? r.noteAr : r.noteEn).font(.bodyS).foregroundStyle(PR.inkFaint)
                }
            }
            .padding(20)
        }
    }

    @ViewBuilder private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(.bodyS).foregroundStyle(PR.inkSoft)
            Spacer()
            Text(value).font(.bodyM).foregroundStyle(PR.ink)
        }
    }

    private func calc() async {
        guard let g = dec(grams), g > 0 else { err = t("اكتب وزن صحيح", "Enter a valid weight"); return }
        busy = true; err = nil
        do { result = try await app.api.goldCalc(grams: g, karat: karat, makingPerGram: dec(making) ?? 0, monthlySaving: dec(monthly)) }
        catch { err = t("حصل خطأ، جرّب تاني", "Something went wrong, try again") }
        busy = false
    }
}

private func fmtPct(_ v: Double) -> String { String(format: "%.1f%%", v) }
