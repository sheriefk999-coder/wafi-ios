# WAFI Pro — App Store subscriptions

Subscription group: **WAFI Pro** (reference name), display name ar «WAFI Pro», en «WAFI Pro».

| Product ID | Reference name | Duration | Suggested price* | Display name (ar / en) | Description (ar / en) |
|---|---|---|---|---|---|
| `pro_monthly` | WAFI Pro Monthly | 1 month | Tier ≈ EGP 99 / SAR 14.99 | WAFI Pro شهري / WAFI Pro Monthly | بحث وتنبيهات من غير حدود ومن غير إعلانات / Unlimited search & alerts, no ads |
| `pro_yearly` | WAFI Pro Yearly | 1 year | Tier ≈ EGP 799 / SAR 119.99 | WAFI Pro سنوي / WAFI Pro Yearly | سنة كاملة بسعر أقل، من غير إعلانات / A full year for less, no ads |

*Prices are your choice; Apple converts them per country. Descriptions must be ≤ 55 characters.

- Optional introductory offer: **1 week free** on both (the app shows "First 1 week free" automatically).
- Review screenshot for each product: use `screenshots/ar/21_pro.png` (the Pro screen).
- Review notes per product: "Unlocks unlimited search, assistant and advisor, gold & dollar alerts, a year of price history, unlimited wallet and watchlist, and removes ads."
- The IDs must match the admin console → Integrations → Apple: `ios_pro_monthly_id` = `pro_monthly`, `ios_pro_yearly_id` = `pro_yearly` (the defaults).
- App Store Server Notifications (Version 2), both Production and Sandbox URLs:
  `https://api.YOUR-DOMAIN/billing/apple/notifications`
- Agreements, Tax, and Banking → the **Paid Apps** agreement must be active before subscriptions can be sold.
