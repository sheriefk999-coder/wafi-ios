# ملفات App Store — WAFI للآيفون

كل اللي App Store Connect هيطلبه منك، مترتب بنفس ترتيب الشاشات هناك. اللي عليه **(إنت)** محتاج حسابك.

## محتويات الفولدر

| الملف | بتعمل بيه إيه |
|---|---|
| `metadata/ar-SA/*.txt` و`metadata/en-US/*.txt` | الاسم، العنوان الفرعي، الوصف، الكلمات المفتاحية، النص الترويجي، ملاحظات الإصدار، والروابط. انسخ كل ملف في الخانة اللي بنفس اسمه. كلهم في حدود عدد الحروف. |
| `icon/AppIcon-1024.png` | أيقونة المتجر 1024×1024، من غير شفافية. هي نفسها الموجودة جوه التطبيق. |
| `screenshots/ar/` و`screenshots/en/` | صور الآيفون 6.9 بوصة (1320×2868)، مطلّعة من التطبيق نفسه على الماك السحابي. |
| `iap/subscriptions.md` | إعداد اشتراكات WAFI Pro (الشهري والسنوي) بالحرف. |
| `review/review_notes_en.txt` | ملاحظات المراجعة (App Review Information) جاهزة للنسخ. |
| `privacy/app-privacy-answers.md` | إجابات استبيان الخصوصية (App Privacy) خانة خانة. |

> **مهم:** في كل الملفات بدّل `api.YOUR-DOMAIN` بدومين الخادم بتاعك.

---

## ١. قبل ما تبدأ (إنت)

1. **Apple Developer Program**: اشترك من developer.apple.com/programs بـ 99 دولار في السنة.
   - **فرد (Individual):** اسمك الشخصي هو اللي هيظهر كبائع في المتجر.
   - **شركة (Organization):** اسم الشركة هو اللي بيظهر، بس محتاج رقم D-U-N-S (مجاني بس بياخد أيام).
2. **App Store Connect ← Business ← Agreements:** وقّع **Paid Apps Agreement** وكمّل بيانات البنك والضرايب. من غيرها الاشتراكات مش هتشتغل.

## ٢. الـ Bundle ID وصلاحياته (إنت)

1. افتح **Certificates, Identifiers & Profiles ← Identifiers ← +** واختار **App IDs ← App**.
2. اكتب الـ Bundle ID: `com.wafi.app` (Explicit).
3. فعّل الصلاحيات دي:
   - **Push Notifications**
   - **Sign in with Apple**
   - **In-App Purchase** (بتبقى مفعّلة لوحدها)
4. **مفتاح الإشعارات:** من **Keys ← +** اعمل مفتاح **Apple Push Notifications service (APNs)** ونزّل ملف الـ `.p8`.
   - الملف ده بيترفع على **Firebase ← Project settings ← Cloud Messaging ← Apple app configuration**، مع الـ Key ID والـ Team ID.
   - في نفس مشروع Firebase ضيف تطبيق iOS بنفس الـ Bundle ID.
   - من لوحة أدمن WAFI ← Integrations ← Apple ارفع ملف `GoogleService-Info.plist`، أو اكتب الـ App ID والـ API key بإيدك.

## ٣. إنشاء التطبيق في App Store Connect (إنت)

افتح **Apps ← + ← New App** واملا الخانات دي:

| الخانة | القيمة |
|---|---|
| Platforms | iOS |
| Name | `WAFI — Know More. Pay Smarter.` (٣٠ حرف بالظبط، وده الحد الأقصى) |
| Primary Language | Arabic |
| Bundle ID | `com.wafi.app` |
| SKU | `wafi-ios-001` |
| User Access | Full Access |

## ٤. App Information

| الخانة | القيمة |
|---|---|
| Subtitle | من `subtitle.txt` لكل لغة |
| Category | Primary: **Shopping**، Secondary: **Finance** |
| Content Rights | **Yes, it contains third-party content** ← وأكّد إن عندك حق عرضه. المقصود أسماء المنتجات وأسعار المتاجر وصورها. |
| Age Rating | جاوب **None / No** على كل الأسئلة. النتيجة **4+**. |
| License Agreement | سيبه على **Apple's Standard License Agreement** |

**ملاحظات على أسئلة Age Rating:**
- **Unrestricted Web Access = No:** روابط المتاجر بتفتح في Safari، مش متصفح جوه التطبيق.
- **Advertising = Yes:** في إعلانات في النسخة المجانية.
- **Gambling / Contests / User-Generated Content = No.**

## ٥. Pricing and Availability

- **السعر:** Free.
- **الدول:** أي دولة، بس التطبيق مخدوم أساساً في مصر والسعودية والإمارات والكويت وقطر. تقدر تبدأ بيهم بس.

## ٦. App Privacy

اتبع `privacy/app-privacy-answers.md` خانة خانة.

- **Privacy Policy URL:** `https://api.YOUR-DOMAIN/legal/privacy`. الصفحة دي بيطلّعها الخادم بالعربي والإنجليزي، وبتغطي الآيفون وSign in with Apple وإن التطبيق مش بيطلب إذن التتبّع (ATT).

## ٧. الاشتراكات (WAFI Pro)

اتبع `iap/subscriptions.md`.

- **Product IDs:** `pro_monthly` و`pro_yearly`.
- **App Store Server Notifications V2:**
  - افتح **App Information ← App Store Server Notifications**.
  - حط الرابط ده في Production وSandbox الاتنين: `https://api.YOUR-DOMAIN/billing/apple/notifications`

## ٨. نسخة 1.0 (iOS App ← 1.0 Prepare for Submission)

| الخانة | منين |
|---|---|
| Screenshots (iPhone 6.9") | `screenshots/ar` للعربي و`screenshots/en` للإنجليزي. لحد ١٠ صور، والترتيب المقترح تحت. |
| Promotional Text | `promotional_text.txt` |
| Description | `description.txt` (آخره فيه روابط الخصوصية والـ EULA، وده مطلوب عشان الاشتراكات) |
| Keywords | `keywords.txt` |
| Support URL | `https://api.YOUR-DOMAIN/support` |
| Marketing URL | اختياري |
| Version / Copyright | `1.0.0` / `2026 <اسمك أو اسم الشركة>` |
| Build | اختار الـ build اللي رفعه GitHub Actions (القسم ٩) |
| App Review Information | Sign-in required = **Yes**، وحط إيميل وباسورد الحساب التجريبي، وانسخ `review/review_notes_en.txt` في Notes |
| Version Release | Manually release (عشان تختار إمتى ينزل) |
| In-App Purchases and Subscriptions | ضيف `pro_monthly` و`pro_yearly` مع أول نسخة |

**ترتيب الصور المقترح:**
1. الرئيسية
2. البحث مع تحليل الأسعار
3. المنتج
4. الدهب
5. محفظتي
6. المستشار
7. المساعد
8. المقارنة
9. السلة
10. Pro

**الحساب التجريبي للمراجع:**
1. سجّل حساب جديد بإيميل زي `review@YOUR-DOMAIN`.
2. من لوحة الأدمن ← Users فعّله **Pro لمدة ٣٠ يوم**، عشان المراجع يشوف كل حاجة من غير حدود.

## ٩. رفع الـ build من غير ماك (GitHub Actions ← TestFlight)

1. **(إنت)** افتح App Store Connect ← **Users and Access ← Integrations ← App Store Connect API ← Team Keys ← +**:
   - الاسم: `WAFI CI`
   - الصلاحية: **App Manager**
   - نزّل ملف الـ `.p8`، واحفظ الـ **Key ID** والـ **Issuer ID**.
2. **(إنت)** في GitHub افتح الريبو ← **Settings ← Secrets and variables ← Actions ← New repository secret**، وضيف:

   | Secret | القيمة |
   |---|---|
   | `ASC_KEY_ID` | الـ Key ID |
   | `ASC_ISSUER_ID` | الـ Issuer ID |
   | `ASC_KEY_P8` | محتوى ملف الـ `.p8` كله (من `-----BEGIN PRIVATE KEY-----` لآخره) |
   | `APPLE_TEAM_ID` | الـ Team ID (من developer.apple.com ← Membership) |
   | `WAFI_API_URL` | `https://api.YOUR-DOMAIN` |
   | `ADMOB_IOS_APP_ID` | اختياري: App ID بتاع AdMob للآيفون (`ca-app-pub-…~…`). من غيره الإعلانات بتفضل مقفولة. |

3. افتح **Actions ← iOS ← Run workflow**، علّم على **upload**، واضغط Run.
4. بعد ١٠ لـ ٣٠ دقيقة الـ build بيظهر في **TestFlight**. رقمه بيزيد لوحده مع كل تشغيل.
5. جرّبه على موبايلك من تطبيق **TestFlight**، وبعدين اختاره في نسخة 1.0 (القسم ٨) واضغط **Add for Review**.

## ١٠. حاجات بتتسبب في رفض التطبيق، ومحلولة

| القاعدة | الحل الموجود |
|---|---|
| 4.8 تسجيل الدخول | التطبيق فيه Sign in with Apple جنب الإيميل، ومفيش جوجل على الآيفون |
| 5.1.1(v) حذف الحساب | من جوه التطبيق: الحساب ← الأمان والحساب ← حذف الحساب |
| 3.1.2 الاشتراكات | شاشة Pro فيها: السعر والمدة من StoreKit، واسترجاع المشتريات، وروابط الشروط (EULA) والخصوصية، ونص التجديد التلقائي. والوصف فيه الروابط كمان. |
| 2.1 الحساب التجريبي | حساب Pro في ملاحظات المراجعة |
| 5.1.2 الخصوصية | Privacy manifest جوه التطبيق، ومفيش طلب تتبّع، والإشعارات بتتطلب بس لما المستخدم يتابع سعر |
| Export compliance | `ITSAppUsesNonExemptEncryption = NO` في Info.plist (HTTPS بس)، فمش هيسألك |
| 2.3.10 | مفيش ذكر لأندرويد أو Google Play في الوصف ولا الصور |
