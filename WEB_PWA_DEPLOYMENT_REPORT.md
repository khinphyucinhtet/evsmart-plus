# EVSmart+ Web, PWA, and Deployment Report

## Current Web Status

EVSmart+ already has Flutter web support because the repository contains a `web/` folder with:

- `web/index.html`
- `web/manifest.json`
- `web/favicon.png`
- `web/icons/`

The project can be run locally in a browser using:

```powershell
flutter run -d chrome
```

However, the deployable static folder `build/web` was not present when checked. That folder is created only after running:

```powershell
flutter build web --release
```

After the build finishes, the contents of `build/web` are the static website files that can be hosted on Vercel, Netlify, Firebase Hosting, GitHub Pages, AWS Amplify, or any static web server.

## PWA Install Status

The app is configured as a PWA through:

- `web/manifest.json`
- `web/index.html`
- Flutter's generated service worker during `flutter build web`
- Web icons in `web/icons/`

The PWA manifest has been corrected to use the existing web icon files:

- `icons/Icon-192.png`
- `icons/Icon-512.png`
- `icons/Icon-maskable-192.png`
- `icons/Icon-maskable-512.png`

The web page also includes iPhone-friendly metadata:

- `apple-mobile-web-app-capable`
- `apple-mobile-web-app-title`
- `apple-touch-icon`
- `theme-color`
- `manifest.json`

## iPhone Installation Behavior

On iPhone, users can install the hosted web app by:

1. Open the deployed website in Safari.
2. Tap the Share button.
3. Tap `Add to Home Screen`.
4. Open EVSmart+ from the new Home Screen icon.

This gives an app-like PWA experience, but it is still a web app.

## Important iPhone Limitation

The web/PWA version cannot run the Android native foreground service. That means:

- The iPhone PWA can show the dashboard and web app UI.
- The iPhone PWA can access Firebase and web dashboard features.
- The iPhone PWA can be installed to the Home Screen.
- The iPhone PWA cannot provide the same Android background impact detection service.

True background accelerometer impact detection is currently Android-native through:

- `android/app/src/main/kotlin/com/evsmart/plus/evsmart_plus/ImpactForegroundService.kt`
- `lib/services/android_background_impact_service.dart`
- `lib/services/impact_detection_service.dart`

For iPhone background detection, a real iOS native implementation would be needed later.

## Vercel Deployment

This project now includes `vercel.json`.

It tells Vercel:

- Build command: `flutter build web --release`
- Output folder: `build/web`
- SPA rewrite: all routes go to `index.html`
- Cache rules for `index.html`, service worker, and static assets

Deploy using Vercel CLI:

```powershell
npm install -g vercel
vercel login
vercel
```

For production:

```powershell
vercel --prod
```

If Vercel does not have Flutter installed in its build image, use one of these options:

- Build locally with `flutter build web --release`, then deploy `build/web`.
- Use a Vercel build setup that installs Flutter before building.
- Use Firebase Hosting or Netlify, which can also host the generated static files.

## Netlify Status

The repository already contains `netlify.toml`.

It is configured to:

- Run `flutter build web --release`
- Publish `build/web`
- Redirect all routes to `index.html`
- Disable caching for `index.html` and `flutter_service_worker.js`

## Firebase Hosting Status

The repository already contains `firebase.json`.

It is configured to:

- Publish `build/web`
- Redirect all routes to `index.html`
- Apply cache headers for Flutter web assets

Deploy using:

```powershell
firebase login
firebase deploy --only hosting
```

## Recommended Final Demo Setup

Use Android app for:

- Driver app
- Background impact detection
- SOS / Level 4 / Level 5 demo
- Nearby technician chat
- Image upload in technician chat

Use hosted web/PWA for:

- Hospital dashboard
- Insurance dashboard
- Project presentation website
- iPhone Home Screen install demo

## Recommended Build Commands

Android:

```powershell
flutter clean
flutter pub get
flutter run
```

Web:

```powershell
flutter clean
flutter pub get
flutter build web --release
```

Local web preview:

```powershell
flutter run -d chrome
```

Static deployment folder:

```text
build/web
```

## Final Product Summary

EVSmart+ is now a combined mobile app and web dashboard system:

- Android app handles impact detection and driver-side emergency flows.
- Web/PWA handles dashboards and installable browser access.
- Firebase connects alerts, notifications, user profiles, support conversations, and dashboard logs.
- Hospital dashboard focuses on severe Level 4 and Level 5 alerts.
- Insurance dashboard receives broader incident and technician-support visibility.
- Technician support is simulated through nearby provider listings and an AI-style workshop assistant instead of a full technician login role.
