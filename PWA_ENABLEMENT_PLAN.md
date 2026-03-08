## PWA Enablement Plan for EVSmart+ (Flutter Web, Firebase Hosting)

### Summary
Build an installable, production-ready PWA from the existing codebase with an online-first UX, full web parity for key features, and Firebase Hosting deployment.  
Launch acceptance will require `Auth + Charge Map + Edit Profile (including photo)` on web, plus explicit update prompting when a new service worker is available.

### Implementation Changes
1. **Web/PWA foundation hardening**
- Update `web/manifest.json` and `web/index.html` branding metadata to EVSmart+ production values (name, short name, description, theme/background colors, icons, start URL).
- Ensure icon set includes valid 192/512 and maskable variants (re-generate from app icon if needed).
- Keep standalone display mode and portrait orientation unless platform constraints require fallback.

2. **Cross-platform abstraction for web parity**
- Introduce a small platform service layer (Dart interfaces + platform-specific implementations) for:
  - `VoiceSearchService`: method channel on mobile, browser speech API implementation on web.
  - `ProfileImageService`: remove `dart:io` dependency; use `XFile.readAsBytes()` cross-platform.
  - `LocationPermissionService`: unify permission flow; on web, replace app/settings deep-link actions with browser-appropriate guidance and re-request flow.
- Refactor feature call sites (`global_search`, `edit_profile`, `charge`) to consume services instead of direct platform APIs.

3. **Feature-specific web fixes**
- **Voice search**: keep current command-routing behavior; web implementation returns recognized text to the existing handler, with clear timeout/error messaging.
- **Edit profile photo**: migrate file-byte read logic to web-safe path; preserve base64 upload behavior to Realtime Database.
- **Charge map/geolocation**: retain live location + station sorting; handle denied/blocked permissions with non-breaking UI state and retry action.
- Verify Firebase Auth + Realtime Database web behavior remains intact with existing `firebase_options.dart`.

4. **Service worker and update prompt UX**
- Keep Flutter-generated service worker for shell caching.
- Add custom update detection in web bootstrap/registration path:
  - detect `waiting` service worker,
  - surface a visible “New version available” prompt,
  - on confirm, post `skipWaiting`, then reload once controller changes.
- Do not force reload automatically; user-triggered refresh only.

5. **Firebase Hosting deployment configuration**
- Extend `firebase.json` (preserving existing FlutterFire config) with `hosting`:
  - `public: build/web`
  - SPA rewrite `** -> /index.html`
  - cache headers tuned for Flutter web assets
  - no-cache for `index.html` and service worker artifacts.
- Add deploy/runbook documentation to README:
  - build command,
  - Firebase deploy command,
  - HTTPS/domain prerequisites.

### Public Interfaces / API Changes
- Add internal platform service contracts used by UI/features:
  - `VoiceSearchService.startListening(...)`
  - `ProfileImageService.pickAndReadBytes(...)`
  - `LocationPermissionService.requestAndTrack(...)`
- No backend API/schema changes; Firebase usage remains same.
- Web runtime behavior changes:
  - new update prompt surface,
  - new voice implementation path on web (replacing web failure fallback).

### Test Plan
1. **Static/quality checks**
- `flutter analyze`
- `flutter test`

2. **Web build + PWA validation**
- `flutter build web --release`
- Serve built app over HTTPS-equivalent local host and verify:
  - manifest is valid,
  - service worker registers,
  - install prompt appears on supported browsers.

3. **MVP flow acceptance**
- Auth: register/login/logout works on web.
- Charge map: map renders, geolocation permission flow works, station search/sort/navigation link works.
- Edit profile: image pick + base64 update persists correctly.

4. **Update flow acceptance**
- Deploy v1, open app, deploy v2, confirm update prompt appears and refresh installs v2 only after user action.

5. **Cross-browser smoke**
- Chrome/Edge desktop (primary), Android Chrome.
- Safari iOS add-to-home-screen sanity check for install/open behavior.

### Assumptions and Defaults Chosen
- Scope target: **Installable online-first**.
- Unsupported/native gaps are solved with **full web parity**, not feature removal.
- Hosting target: **Firebase Hosting SPA**.
- Update strategy: **Prompt user to refresh** (no forced reload).
- If browser speech recognition is unavailable, voice feature degrades with explicit user feedback while preserving typed search path.
