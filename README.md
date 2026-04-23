# EVSmart+

EVSmart+ is a Flutter and Firebase emergency assistance platform for electric vehicles. The system connects EV drivers, ambulance responders, technicians, and insurance monitoring through realtime impact detection, SOS dispatch, accident logging, and web analytics dashboards.

## Implemented Modules

- EV driver mobile application with home, charge map, alerts, notifications, rewards, profile, and search navigation
- Accelerometer-based impact detection using `sensors_plus`
- SOS countdown confirmation with cancellation support
- Firebase Realtime Database storage for alerts, notifications, accident reports, users, vehicles, charging stations, ambulance profiles, and technician profiles
- Ambulance mobile dashboard with dispatch acceptance, patient status updates, and hospital notification flow
- Technician mobile dashboard with service acceptance, navigation, and repair status updates
- Flutter web dashboards for insurance analytics, ambulance monitoring, technician monitoring, and AI insights
- Charging station map using OpenStreetMap with realistic seeded markers, search suggestions, station details, and route launch

## Main Firebase Collections

- `users`
- `vehicles`
- `alerts`
- `ambulance_profiles`
- `technician_profiles`
- `charging_stations`
- `accident_reports`
- `notifications`

## Development Commands

```bash
flutter pub get
flutter analyze
flutter test
flutter build web --release
```

## Firebase Hosting Deployment

1. Build the web app:

```bash
flutter build web --release
```

2. Deploy to Firebase Hosting:

```bash
firebase deploy --only hosting
```

The hosting configuration is already prepared in [firebase.json](./firebase.json) with SPA rewrites and cache headers.

## Netlify Deployment

A [netlify.toml](./netlify.toml) file is included for SPA deployment.

Typical Netlify build settings:

- Build command: `flutter build web --release`
- Publish directory: `build/web`

## PWA Notes

- `web/manifest.json` is branded for EVSmart+
- `web/index.html` includes a loading shell and update banner for service worker refreshes
- Flutter web build output can be installed as a standalone PWA on supported browsers

## Current Validation Status

- `dart analyze` passes without errors or warnings
- Remaining items, if any, should be runtime/device-specific Firebase configuration checks or content/data validation in your live backend
