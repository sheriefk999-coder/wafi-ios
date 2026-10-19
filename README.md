# WAFI for iPhone

**Know More. Pay Smarter.** — the iPhone app of WAFI: compare full prices (shipping included) across the
stores of your country, follow gold and currencies, keep a wallet of your gold and savings, and get advice.

- SwiftUI, iOS 17+, Arabic first (RTL) with English.
- Same server as the Android app (FastAPI). Sign in with Apple + email, StoreKit 2 for Pro, Firebase push, AdMob.
- The Xcode project is generated from `project.yml` with [XcodeGen](https://github.com/yonaskolb/XcodeGen).

## Build on a Mac

```bash
brew install xcodegen
xcodegen generate
open WAFI.xcodeproj
```

Run on a simulator against a local server: Debug builds talk to `http://127.0.0.1:8000`
(Account → Server address changes it at runtime).

## CI (no Mac needed)

`.github/workflows/ios.yml` runs on GitHub's macOS machines on every push to `main`:
builds, runs the unit tests, and takes screenshots of every screen against `ci/mock_api.py`
(responses recorded from a real server by `ci/record_fixtures.py`). Results go to the `ci-out` branch
(`SUMMARY.md`, logs, `shots/`). Run the workflow by hand with **upload** ticked to send a build to TestFlight
(needs the App Store Connect secrets listed in the iOS guide).
