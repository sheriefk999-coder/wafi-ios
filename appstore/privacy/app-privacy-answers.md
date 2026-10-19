# App Privacy — answers for App Store Connect

**Do you or your third-party partners collect data from this app?** → **Yes**

Answer each data type below; anything not listed → not collected.
"Linked to the user's identity" = Yes when it's tied to the WAFI account. **Tracking = No for everything** (the app never requests App Tracking Transparency).

## Collected by WAFI itself

| Category → Data type | Purposes | Linked to identity | Used for tracking |
|---|---|---|---|
| Contact Info → **Email Address** | App Functionality | Yes | No |
| Contact Info → **Name** | App Functionality | Yes | No |
| Identifiers → **User ID** | App Functionality | Yes | No |
| Identifiers → **Device ID** (push token; random install id for guest limits) | App Functionality | Yes | No |
| Purchases → **Purchase History** (App Store subscription state) | App Functionality | Yes | No |
| Search History → **Search History** (counted for the free plan's limit, kept 3 days) | App Functionality | Yes | No |
| User Content → **Other User Content** (watchlist, target prices, rate alerts) | App Functionality | Yes | No |

## Collected by Google Mobile Ads (AdMob) — free plan only

Check Google's current "Data disclosure" page for the Google Mobile Ads SDK before submitting and match it. At the time of writing it lists:

| Category → Data type | Purposes | Linked | Tracking |
|---|---|---|---|
| Location → **Coarse Location** (from IP) | Third-Party Advertising, Analytics | No | No |
| Identifiers → **Device ID** | Third-Party Advertising, Analytics | No | No |
| Usage Data → **Product Interaction**, **Advertising Data** | Third-Party Advertising, Analytics | No | No |
| Diagnostics → **Crash Data**, **Performance Data** | Analytics | No | No |

(If you later add an App Tracking Transparency prompt, "Device ID" and "Advertising Data" become "Used for tracking: Yes". The app does not do that today.)

## Not collected
Health, financial info, precise location, contacts, photos, audio, browsing history, sensitive info.
"My Wallet" (gold and savings) stays on the phone and is never sent to the server.
