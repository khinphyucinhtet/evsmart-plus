# EVSmart+

EVSmart+ is a Flutter and Firebase final-year prototype for EV safety monitoring, impact-driven emergency response, charging support, connected messaging, and live dashboard reporting.

The project is built around two connected systems:

- a driver and responder app for EV users, ambulance staff, and operational workflows
- a government-style accident analytics and AI report dashboard that turns collected EV incident data into summaries, hotspot views, and recommendations

## Live Links

- Netlify Flutter web app: [https://evsmartplus.netlify.app/](https://evsmartplus.netlify.app/)
- GitHub Pages dashboard: [https://khinphyucinhtet.github.io/ev_smart_plus_dashboard/?role=hospital](https://khinphyucinhtet.github.io/ev_smart_plus_dashboard/?role=hospital)

## System Overview

### 1. EV Driver And Responder App

This is the main Flutter product. It supports:

- EV dashboard simulation
- EV connection flow
- battery, tire, temperature, GPS, and sync-style monitoring
- impact detection and manual alerts
- ambulance responder workflow
- nearby charging station support
- nearby hospital and technician assistance
- support messaging and image sending
- rewards and donation demo flows

### 2. Accident Report And Government Dashboard

This is the analytics/reporting side of the project. It uses EV incident data gathered from the app to show:

- hospital dashboard mode
- insurance dashboard mode
- `Accidents Report` mode
- district hotspot maps
- most affected districts
- severity and peak-hour breakdowns
- AI report generator and suggestion cards
- government-style operational summaries

The hosted version of this dashboard is maintained in the sibling repo:

- `C:\Users\user\AndroidStudioProjects\ev_smart_plus_dashboard`

This repository also contains an in-project static dashboard copy in:

- `static_dashboard/`

## Main Idea

EVSmart+ is not a general car app.

It focuses on EV-specific incident handling where the system needs to consider:

- impact severity
- EV battery condition
- charging dependency
- location context
- roadside support availability
- responder readiness
- dashboard visibility for hospitals, insurance viewers, and report audiences

## Technologies Used

### Flutter App

- Flutter
- Dart
- Firebase Core
- Firebase Auth
- Firebase Realtime Database
- Firebase Messaging
- Shared Preferences
- Geolocator
- Flutter Map
- Google Maps Flutter
- URL Launcher
- Sensors Plus
- Image Picker
- HTTP
- Flutter TTS
- Local Auth
- Flutter Local Notifications

### Native / Web

- Kotlin for Android-native impact monitoring
- HTML, CSS, and JavaScript for the static dashboard
- Leaflet for dashboard mapping
- html2canvas and jsPDF for report/export features in the hosted dashboard

## Repository Structure

- `lib/`
  Main Flutter source code.
- `lib/screens/`
  Screen-level UI such as driver, responder, and dashboard pages.
- `lib/services/`
  Firebase access, impact logic, notifications, assist data, AI helpers, and web monitoring.
- `lib/widgets/`
  Reusable widgets shared by multiple screens.
- `android/`
  Android-native Kotlin files for impact monitoring and app integration.
- `assets/images/`
  App image assets and icons.
- `test/`
  Flutter tests.
- `web/`
  Flutter web shell files.
- `static_dashboard/`
  Lightweight static dashboard copy stored inside this repo.
- `build/web/`
  Generated Flutter web output after running a web build.

## Important Screens And What They Do

### Driver Experience

- `lib/screens/home_driver.dart`
  Main EV dashboard with EV connection popup, sensor cards, support sections, and quick actions.
- `lib/screens/charge.dart`
  Charging support page with nearby charger and map-related content.
- `lib/screens/alert.dart`
  Manual emergency alert and severity flow.
- `lib/screens/noti.dart`
  Driver notifications and alert history.
- `lib/screens/rewards.dart`
  Rewards, check-in, donation, and mission demo content.
- `lib/screens/report_problem.dart`
  Support chatbot and problem-reporting screen.
- `lib/screens/user_message.dart`
  Messaging inbox entry point.
- `lib/screens/message_conversation_page.dart`
  Actual message thread UI with image support.
- `lib/screens/nearby_assist_map.dart`
  Nearby hospital and EV technician assist map.
- `lib/screens/view_profile.dart`
  Driver profile page.
- `lib/screens/edit_profile.dart`
  Driver profile editing page.

### Ambulance / Health Responder Experience

- `lib/screens/health_home.dart`
  Main responder home with live incident feed and active case summary.
- `lib/screens/ambulance_response_form_page.dart`
  Dispatch response form shown after `Going`.
- `lib/screens/ambulance_trip_progress.dart`
  Trip progress simulation until arrival.
- `lib/screens/ambulance_driver_messages.dart`
  Responder-side messages and support entry.
- `lib/screens/ambulance_profile.dart`
  Responder profile page.
- `lib/screens/ambulance_driver_edit_profile.dart`
  Responder profile editing page.
- `lib/screens/dashboard_ambulance_driver.dart`
  Dashboard-style responder summary.

### Dashboard / Shared Monitoring Experience

- `lib/screens/dashboard_router.dart`
  Role-aware dashboard routing.
- `lib/screens/ambulance_dashboard.dart`
  Ambulance dashboard presentation.
- `lib/screens/insurance_dashboard.dart`
  Insurance dashboard presentation.
- `lib/widgets/dashboard_layout.dart`
  Shared dashboard shell layout.
- `lib/widgets/dashboard_notification_feed.dart`
  Shared dashboard feed UI.

## Important Services

- `lib/services/app_repository.dart`
  Main shared Firebase repository and one of the most important files in the project.
- `lib/services/impact_detection_service.dart`
  Flutter-side impact detection and emergency callback logic.
- `lib/services/android_background_impact_service.dart`
  Bridge from Flutter to the Android native foreground service.
- `lib/services/assist_directory.dart`
  Nearby hospital and EV technician data.
- `lib/services/notification_service.dart`
  Notification logic.
- `lib/services/voice_assistant_service.dart`
  Voice assistant support logic.
- `lib/services/gemini_ai_service.dart`
  Optional Gemini-powered support enhancement.
- `lib/services/gemini_service.dart`
  Additional Gemini helper service logic.
- `lib/services/web_monitoring_service.dart`
  Web-side monitoring support.

## Native Android Files

Important native files include:

- `android/app/src/main/kotlin/com/evsmart/plus/evsmart_plus/MainActivity.kt`
- `android/app/src/main/kotlin/com/evsmart/plus/evsmart_plus/ImpactForegroundService.kt`
- `android/app/src/main/kotlin/com/evsmart/plus/evsmart_plus/ImpactAlertActivity.kt`
- `android/app/src/main/kotlin/com/evsmart/plus/evsmart_plus/ImpactMonitorControlActivity.kt`

These handle:

- Android app startup
- background impact listening
- emergency popup behavior
- pause/resume monitoring controls

## Firebase Data Paths

Main Firebase Realtime Database paths used by the project:

- `alerts`
- `notifications`
- `message_threads`
- `vehicles`
- `ambulance_profiles`
- `technician_profiles`
- `charging_stations`

## End-To-End Data Flow

1. The EV driver connects the EV demo and views vehicle-style telemetry.
2. The app continuously collects or simulates EV data such as impact, battery, GPS, and temperature.
3. If an impact event or manual alert occurs, EVSmart+ classifies the case severity.
4. Level 4 and Level 5 incidents are written to Firebase as serious emergency cases.
5. Hospital, insurance, and responder interfaces read the same live data.
6. The responder can accept the incident, submit dispatch details, arrive, and complete a final report.
7. The analytics/report dashboard continues aggregating the EV user data to show district hotspots, top affected areas, severity distribution, and AI-style report suggestions.

## Main User Flows

### Driver Flow

1. Open app
2. Connect EV
3. View EV status cards
4. Trigger manual alert or simulate impact
5. Use charging support, messaging, or nearby assist

### Responder Flow

1. View nearby case
2. Press `Going`
3. Fill response form
4. Watch trip progress
5. Press `Arrived`
6. Submit final report

### Government / Report Flow

1. Open hosted dashboard
2. Switch to `Accidents Report`
3. Review Selangor risk overview and district ranking
4. Check severity, trend, and peak-hour cards
5. Generate AI report and suggestions for dashboard planning

## Web Experiences

### Flutter Web App

The Flutter web app is mostly the same product story as the APK, but used more for simulation, hosted presentation, and browser access.

Useful for:

- demos
- manual alert simulation
- support and messaging walkthroughs
- dashboard access in web form

Build output:

- `build/web`

### Static Dashboard

The static dashboard is a lighter dashboard-only experience built with HTML, CSS, and JavaScript.

Useful for:

- hospital view
- insurance view
- accident report analytics
- lightweight public/project presentation

## Platform Notes

### Android

Best for the full prototype because it supports:

- accelerometer simulation
- foreground-service monitoring
- stronger background behavior
- emergency popup style interactions

### Web / PWA

Best for:

- hosted demo links
- Netlify sharing
- dashboard-style presentation
- simulation of the same product story as the APK

But web does not behave exactly like the Android-native background monitoring experience.

## Shared UI

Reusable UI files include:

- `lib/screens/app_header.dart`
- `lib/screens/app_footer.dart`
- `lib/widgets/info_card.dart`
- `lib/widgets/severity_badge.dart`
- `lib/widgets/dashboard_layout.dart`
- `lib/widgets/dashboard_notification_feed.dart`

## Run Commands

```bash
flutter pub get
flutter analyze
flutter test
flutter run
flutter build web --release
```

Optional Gemini run:

```bash
flutter run --dart-define=GEMINI_API_KEY=YOUR_KEY
```

Optional model override:

```bash
flutter run --dart-define=GEMINI_API_KEY=YOUR_KEY --dart-define=GEMINI_MODEL=gemini-2.5-flash
```

## Hosting

### Netlify Flutter Web App

Build:

```bash
flutter build web --release
```

Publish directory:

- `build/web`

Hosted link:

- [https://evsmartplus.netlify.app/](https://evsmartplus.netlify.app/)

### GitHub Pages Dashboard

Hosted link:

- [https://khinphyucinhtet.github.io/ev_smart_plus_dashboard/?role=hospital](https://khinphyucinhtet.github.io/ev_smart_plus_dashboard/?role=hospital)

The deployed files for that site are in the separate repo:

- `C:\Users\user\AndroidStudioProjects\ev_smart_plus_dashboard`

## Local Static Dashboard Test

```bash
cd static_dashboard
python -m http.server 8088
```

Example role links:

- `index.html?role=hospital`
- `index.html?role=insurance`

## Recommended Demo Script

1. Open the Android app and allow location, notifications, and impact-related permissions.
2. Open the driver home page.
3. Press `Connect EV`.
4. Show battery, range, temperature, cloud sync, GPS, and impact cards.
5. Trigger a manual alert or impact simulation.
6. Show Firebase alert creation and live data flow.
7. Open the responder side and show nearby incident visibility.
8. Press `Going`, fill the form, and show trip progress.
9. Submit the final responder report.
10. Open the hosted dashboard and show how the same EV user data appears in hospital/insurance/report views.
11. Open `Accidents Report` and generate the AI-style analytics summary.

## Known Limitations

- Accelerometer input is used as an IoT-style demo signal rather than a real EV crash sensor.
- Some workflows are prototype/demo flows rather than production-ready emergency systems.
- Android popup behavior can vary by device and OS restrictions.
- Web and iPhone/PWA do not replicate Android-native background monitoring exactly.
- Gemini should remain optional and must not be hardcoded.

## Summary

EVSmart+ combines EV monitoring, impact handling, ambulance workflow, nearby support, messaging, charging support, and dashboard analytics in one Firebase-connected prototype. The Flutter app and the government-style report dashboard are designed to tell the same data story from different user viewpoints.
