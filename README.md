# SOPCheck mobile (Capacitor 7) - NOT SUBMITTED

- App id: `com.pocketappstudio.sopcheck` (placeholder until Slade confirms). Name "SOPCheck".
- `npm run build:www` builds the static SOPCheck app at the root path with `NEXT_PUBLIC_NATIVE=1` and vendors Pyodide, the Python wheels and Tesseract OCR (about 55 MB), so the app starts and parses **offline**. `npx cap sync` copies it into ios/ and android/.
- Native additions (beyond a web wrapper, for App Store guideline 4.2): camera "Scan a paper SOP" with on-device OCR, built into a checklist; camera capture for task photos; haptics on check-off, publish and parse; offline banner via Network plugin; push-ready (`registerPush()` in `frontend/lib/native.ts`, only on a user action, never required); native splash screen and icons.
- Android debug APK: `source /home/box/android/env.sh && npm run android:debug` (output `android/app/build/outputs/apk/debug/app-debug.apk`).
- iOS: `.github/workflows/ios.yml` + `fastlane/Fastfile` reuse the Buck Ledger/Hubs pipeline (macOS GitHub runner, App Store Connect API key secrets). Manual trigger only.
- Today the app runs the **demo backend inside the app** (sample data, per device). A production build needs a hosted API (`NEXT_PUBLIC_API_BASE`), see ../docs/MOBILE_PLAN.md.
