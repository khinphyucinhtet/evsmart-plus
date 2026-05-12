# AGENTS.md

This file explains how coding agents, including Codex, should work in this repository.

It also acts as a practical project guide, so the app structure, system summary, role flows, and platform behavior are described in simple English.

## Project Summary

EVSmart+ is a Flutter and Firebase final-year prototype focused on EV safety, emergency response, and connected monitoring.

The project is not a general car app.

Its core idea is that EV incidents should be handled using EV-aware context such as:

- battery condition
- impact severity
- charging dependency
- roadside support access
- ambulance and hospital coordination
- live reporting for government-style monitoring

## Two Connected Systems

EVSmart+ currently works as two connected systems that share the same incident story.

### System 1: EV Driver And Responder App

This is the Flutter app used as:

- Android mobile app
- Flutter web app
- presentation build for hosted demo use

It covers:

- EV driver dashboard
- EV connection simulation
- impact detection and manual alerts
- charging support
- nearby hospital and technician access
- messaging
- ambulance responder workflow
- hospital and insurance visibility

### System 2: Government / Analytics Report Dashboard

This is the accident analytics and AI-style reporting system that turns collected EV incident data into dashboard summaries and strategic report views.

It covers:

- hospital dashboard mode
- insurance dashboard mode
- `Accidents Report` mode
- hotspot map overview
- district risk ranking
- severity and peak-hour analysis
- AI report generator and suggestion cards
- government-style report preview and export/share flow

Important deployment note:

- the in-repo lightweight dashboard version lives in `static_dashboard/`
- the currently hosted GitHub Pages dashboard is maintained in the sibling repo `C:\Users\user\AndroidStudioProjects\ev_smart_plus_dashboard`

Hosted links:

- GitHub Pages dashboard: `https://khinphyucinhtet.github.io/ev_smart_plus_dashboard/?role=hospital`
- Netlify Flutter web app: `https://evsmartplus.netlify.app/`

## Repository Context

Main locations in this repository:

- `lib/`
  Flutter source
- `lib/screens/`
  app pages and screen-level UI
- `lib/services/`
  shared business logic, Firebase access, impact logic, assist data, and notifications
- `lib/widgets/`
  reusable widgets
- `android/`
  Android-native integration
- `assets/images/`
  app image assets
- `test/`
  Flutter tests
- `web/`
  Flutter web shell files
- `static_dashboard/`
  bundled static dashboard copy for simple HTML/CSS/JS hosting
- `build/web/`
  generated Flutter web output after build

## Main Technologies

Flutter-side technologies used by the project include:

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

Native and web technologies used include:

- Kotlin for Android integration
- HTML
- CSS
- JavaScript
- Leaflet for dashboard map rendering
- html2canvas and jsPDF for report/export features in the hosted dashboard

## Product Roles

The product is organized around these roles:

- EV driver
- ambulance or health responder
- hospital dashboard viewer
- insurance dashboard viewer
- government-style report viewer in `Accidents Report`

Technician support is included, but it is mainly handled through nearby workshop listings and AI-style support messaging rather than a fully separate technician login product.

## System Flow In Simple English

This is the main shared story across the app and the dashboard:

1. The EV driver opens the app and connects the EV demo.
2. The app shows EV status such as battery, range, temperature, tires, location, and sync state.
3. The phone can simulate or detect an impact event, or the user can trigger a manual alert.
4. EVSmart+ classifies the incident severity.
5. Low-severity cases can remain as monitoring, warnings, support, or service-related records.
6. Level 4 and Level 5 cases are treated as serious emergency incidents.
7. The app sends structured incident data to Firebase Realtime Database.
8. Responder, hospital, insurance, and report dashboards read from the same data source.
9. Ambulance responders can accept the case, submit dispatch details, simulate travel progress, arrive, and close the case with a final report.
10. The report system continues using the collected EV incident data to show district risk, severity trends, and AI-style dashboard recommendations.

## Data Story

The project explains EV data as a continuous collection and reporting pipeline:

1. Sensor input:
Battery, GPS, tire, impact, and temperature data are collected or simulated.

2. Gateway processing:
An EV gateway such as ESP32, CAN, BMS bridge, or OBD-II reader can process the raw data.

3. Cloud sync:
Structured updates are pushed to Firebase.

4. Operational response:
The app decides whether the update is routine, service-related, or emergency-related.

5. Dashboard intelligence:
The reporting dashboard aggregates collected EV incident data into hotspot maps, top districts, severity breakdowns, peak windows, and AI report content.

For the prototype, much of the sensor data is simulated in Flutter, but the system explanation is intended to match a future real EV/IoT architecture.

## Important Screens

### Driver-Side Screens

- `home_driver.dart`
  Main EV dashboard with EV connection UI, sensor cards, support cards, smart services, and quick actions.
- `charge.dart`
  Charging support page with nearby charger content and map-related support.
- `alert.dart`
  Manual alert page with severity flow, countdown, and emergency simulation.
- `noti.dart`
  Driver notification history and message-style updates.
- `rewards.dart`
  Rewards, donation, check-in, and mission demo page.
- `report_problem.dart`
  Support chatbot and app issue reporting page.
- `user_message.dart`
  Driver inbox entry for health and technician assist.
- `message_conversation_page.dart`
  Thread-level conversation page with optional image sending.
- `nearby_assist_map.dart`
  Nearby hospitals and technicians with call, navigate, and message actions.
- `view_profile.dart`
  Driver profile display.
- `edit_profile.dart`
  Driver profile editing.

### Responder-Side Screens

- `health_home.dart`
  Main responder home with ambulance status, nearby incident feed, active case, and case log.
- `ambulance_response_form_page.dart`
  Response form shown after `Going`.
- `ambulance_trip_progress.dart`
  Dispatch/travel progress simulation until arrival.
- `ambulance_driver_messages.dart`
  Responder messaging entry.
- `ambulance_profile.dart`
  Responder profile page.
- `ambulance_driver_edit_profile.dart`
  Responder profile editing.
- `dashboard_ambulance_driver.dart`
  Dashboard-style summary for responder activity.

### Dashboard / Report Screens

- `dashboard_router.dart`
  Entry router for dashboard roles.
- `ambulance_dashboard.dart`
  Ambulance dashboard presentation page.
- `insurance_dashboard.dart`
  Insurance dashboard presentation page.
- `lib/widgets/dashboard_layout.dart`
  Shared dashboard shell.
- `lib/widgets/dashboard_notification_feed.dart`
  Shared notification-style dashboard feed.

## Main Services

Important service files:

- `app_repository.dart`
  Main Firebase read/write layer and one of the most important files in the project.
- `impact_detection_service.dart`
  Flutter-side impact detection and callbacks.
- `android_background_impact_service.dart`
  Flutter bridge to the Android-native foreground service.
- `assist_directory.dart`
  Nearby hospital and EV technician directory data.
- `notification_service.dart`
  Notification behavior and related logic.
- `voice_assistant_service.dart`
  Voice assistant support.
- `gemini_ai_service.dart`
  Optional Gemini-powered support behavior when a key is provided.
- `gemini_service.dart`
  Additional Gemini-related helper logic.
- `web_monitoring_service.dart`
  Web-specific monitoring support.

## Native Android Files

Important Android-native files:

- `android/app/src/main/kotlin/com/evsmart/plus/evsmart_plus/MainActivity.kt`
- `android/app/src/main/kotlin/com/evsmart/plus/evsmart_plus/ImpactForegroundService.kt`
- `android/app/src/main/kotlin/com/evsmart/plus/evsmart_plus/ImpactAlertActivity.kt`
- `android/app/src/main/kotlin/com/evsmart/plus/evsmart_plus/ImpactMonitorControlActivity.kt`

These support:

- Android app startup
- true background monitoring
- emergency popup behavior outside the app
- pause/resume impact monitoring controls

## Firebase Data Paths

Main Firebase paths used by the project include:

- `alerts`
- `notifications`
- `message_threads`
- `vehicles`
- `ambulance_profiles`
- `technician_profiles`
- `charging_stations`

How the data moves:

1. The user triggers an alert, sends a message, updates support state, or simulates EV telemetry.
2. Flutter prepares structured data such as severity, location, timestamps, notes, and status.
3. `app_repository.dart` writes or reads the shared Firebase data.
4. Driver, responder, hospital, insurance, and report views listen to those updates.
5. The UI refreshes in real time across the connected systems.

## Web Experiences

This repository contains two web experiences.

### Flutter Web App

The Flutter web app is the hosted simulation-friendly version of the main app.

It is useful for:

- project presentation
- hosted demonstrations
- driver and responder flow simulation
- manual alert and support flows
- web/PWA access

Build output:

- `build/web`

Hosted example:

- `https://evsmartplus.netlify.app/`

### Static Dashboard

The in-repo static dashboard exists in:

- `static_dashboard/`

It is useful when:

- only dashboard-style display is needed
- the full Flutter runtime is not needed
- a lightweight hospital/insurance/report page is preferred

The separately hosted production-style dashboard repo is:

- `C:\Users\user\AndroidStudioProjects\ev_smart_plus_dashboard`

Hosted example:

- `https://khinphyucinhtet.github.io/ev_smart_plus_dashboard/?role=hospital`

## Platform Behavior

### Android

Android is the best platform for the full prototype because it supports:

- accelerometer-based impact simulation
- foreground-service monitoring
- better notification and background behavior
- emergency-style alert interaction

### Web / Netlify

Web is useful for:

- hosted demos
- simulation
- presentation access
- dashboard and support viewing

But web does not behave exactly like Android-native background monitoring.

### iPhone / PWA

The web app can run in PWA form, but it does not support the same Android-native monitoring and alert behavior.

## Shared UI Structure

Reusable UI files include:

- `lib/screens/app_header.dart`
- `lib/screens/app_footer.dart`
- `lib/widgets/info_card.dart`
- `lib/widgets/severity_badge.dart`
- `lib/widgets/dashboard_layout.dart`
- `lib/widgets/dashboard_notification_feed.dart`

The shared footer is used by:

- `home_driver.dart`
- `charge.dart`
- `alert.dart`
- `noti.dart`
- `rewards.dart`

## Permissions And Device Features

The project may use:

- internet
- location
- notifications
- vibration
- foreground service
- wake lock
- full-screen intent
- camera or gallery through `image_picker`
- accelerometer through `sensors_plus`

Location is important for:

- nearby charging stations
- nearby hospitals
- nearby technicians
- ambulance case filtering
- maps and navigation

## Demo Flow

Recommended final demo flow:

1. Open the Android app.
2. Allow location, notification, and monitoring permissions.
3. Open the driver home page.
4. Press `Connect EV`.
5. Show battery, tire, cloud sync, GPS, and impact cards.
6. Trigger a manual alert or impact simulation.
7. Show Firebase alert creation.
8. Open the ambulance side and show nearby incidents.
9. Press `Going`.
10. Fill the response form.
11. Show trip progress.
12. Press `Arrived`.
13. Submit the final report.
14. Open the hosted dashboard or `Accidents Report` view.
15. Show that collected EV user data is reflected in hotspot, severity, and AI report sections.

## Coding Agent Workflow

When working in this repository:

1. Read the relevant files first.
2. Keep changes focused on the request.
3. Prefer small edits over broad refactors.
4. Preserve naming and architecture unless the user asks for a change.
5. Run the smallest useful validation after edits.
6. Explain what changed and why.

## Coding Conventions

- Follow Flutter and Dart style from `analysis_options.yaml`.
- Keep widgets and methods readable.
- Use null-safe Dart.
- Add comments only when the intent is not obvious.
- Avoid unrelated formatting churn.
- Prefer strong typing when practical.

## Validation Conventions

Use the smallest useful validation set:

- `flutter analyze`
- `flutter test`
- `flutter build web --release` for web-related changes

If a command cannot run, explain why clearly.

## Safety Rules

- Do not delete large sections unless the user clearly asks.
- Do not run destructive git commands unless explicitly requested.
- Do not change secrets or release settings unless the task requires it.
- Ask before major dependency or architecture changes.

## Git Conventions

Use Conventional Commits:

- `feat: ...`
- `fix: ...`
- `docs: ...`
- `refactor: ...`
- `test: ...`
- `chore: ...`

Keep commits focused and specific.

## File Scope Guidance

- Driver/responder UI pages: `lib/screens/`
- Shared widgets: `lib/widgets/`
- Services and Firebase logic: `lib/services/`
- Android native code: `android/`
- Static dashboard copy: `static_dashboard/`
- Hosted dashboard repo: sibling project `ev_smart_plus_dashboard`

## Known Limitations

- Phone accelerometer input is used as an IoT-style demo signal.
- Some flows are presentation flows rather than production-ready backend processes.
- Android popup behavior can vary by device and OS restrictions.
- Web and iPhone/PWA do not support Android-native background monitoring in the same way.
- Gemini keys must not be hardcoded and should be passed by `--dart-define`.

## Definition Of Done

A task is done when:

- the requested change is implemented
- relevant checks pass, or failures are clearly explained
- the diff is focused and reviewable
- the final response clearly explains the impact and next steps
