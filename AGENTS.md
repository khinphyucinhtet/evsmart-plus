# AGENTS.md

This file explains how coding agents, including Codex, should work in this repository.

It also acts as a project guide, so the app structure, system flow, and platform behavior are described in simple English.

## Project Summary

EVSmart+ is a Flutter and Firebase final-year prototype for:

- EV safety monitoring
- impact detection and manual emergency alerts
- ambulance and hospital response flow
- charging support
- nearby hospital and technician assistance
- messaging and support chat
- rewards and donation demo features
- web and dashboard presentation

The app is EV-focused, not a general car app.

Its main difference is that it combines:

- EV battery and vehicle monitoring
- EV-specific roadside help
- charging-aware support
- emergency escalation for serious impact cases

## Repository Context

- Main app source: `lib/`
- Main screens: `lib/screens/`
- Services: `lib/services/`
- Shared widgets: `lib/widgets/`
- Android native files: `android/`
- Assets: `assets/`
- Tests: `test/`
- Standalone dashboard: `static_dashboard/`

## Current Project Size

Current file counts:

- Total Dart files in `lib/`: 57
- Screen-related Dart files in `lib/screens/`: 42
- Service Dart files in `lib/services/`: 9
- Shared widget Dart files in `lib/widgets/`: 4
- Kotlin files in `android/`: 4
- Asset files in `assets/`: 18
- Static dashboard files in `static_dashboard/`: 6

## Main Technologies

- Flutter
- Dart
- Firebase Realtime Database
- Firebase Auth
- Firebase Messaging
- Shared Preferences
- Geolocator
- Flutter Map
- Google Maps support
- URL Launcher
- Sensors Plus
- Image Picker
- Flutter Local Notifications
- Kotlin for Android native integration
- HTML, CSS, and JavaScript for the static dashboard

## Product Scope

EVSmart+ is built around these main roles:

- EV driver
- ambulance or health responder
- hospital dashboard viewer
- insurance dashboard viewer

Technician support is included too, but it is mainly handled through nearby EV workshop listings and AI-style assistance instead of a full technician login product.

## What The App Can Do

The full project can:

- show a live-style EV dashboard
- simulate EV connection and cloud sync
- detect or simulate impact events
- run manual emergency alert flows
- escalate serious alerts to responder dashboards
- show nearby charging stations
- help the user contact hospitals and EV technicians
- support image sending inside message conversations
- guide ambulance responders through going, arriving, and report submission
- provide dashboard visibility for hospital and insurance roles
- run as a Flutter mobile app and Flutter web app
- provide a separate static dashboard website

## System Flow In Simple English

This is the main app flow:

1. The driver opens the app and connects the EV demo.
2. The home page shows EV data such as battery, range, temperature, tires, cloud state, and location.
3. The user can trigger a manual alert, or the phone can simulate an impact through the accelerometer.
4. The app decides the impact severity level.
5. Lower severity levels can remain as records, warnings, or service cases.
6. Level 4 and Level 5 are treated as serious emergency cases.
7. These serious cases are saved into Firebase Realtime Database.
8. Ambulance and hospital dashboards read the same Firebase data.
9. The responder accepts the case and begins the response flow.
10. The responder can submit ETA, team details, arrival, and final handover report.
11. The updated case remains visible to dashboards and logs.

## EV Data Story

The project explains EV data like this:

1. Sensor input:
Battery, tire, GPS, impact, and temperature data are collected.

2. Gateway processing:
An EV gateway such as ESP32, OBD-II, CAN, or BMS bridge can process the data.

3. Cloud sync:
The data is pushed to Firebase for monitoring.

4. Intelligent action:
The system decides whether the case is normal, service-related, or emergency-related.

For the prototype, much of this is simulated in Flutter, but the explanation is suitable for final-year project presentation.

## Important Screens

### Driver-Side Screens

- `home_driver.dart`
- `charge.dart`
- `alert.dart`
- `noti.dart`
- `rewards.dart`
- `report_problem.dart`
- `user_message.dart`
- `message_conversation_page.dart`
- `nearby_assist_map.dart`
- `view_profile.dart`
- `edit_profile.dart`

What they do:

- `home_driver.dart`
Main EV dashboard, EV connection popup, sensor cards, support cards, smart services, and quick actions.

- `charge.dart`
Charging support page with nearby chargers and map-related content.

- `alert.dart`
Manual alert page, severity flow, countdown, and emergency simulation.

- `noti.dart`
Driver notification page with alert history and message-style cards.

- `rewards.dart`
Rewards, donation, check-in, and mission demo page.

- `report_problem.dart`
Support chatbot page for app help and problem reporting.

- `user_message.dart`
Driver inbox entry for health and technician assist.

- `message_conversation_page.dart`
Actual support chat conversation page with optional image sending.

- `nearby_assist_map.dart`
Nearby hospitals or technicians with call, navigate, and message actions.

### Responder-Side Screens

- `health_home.dart`
- `ambulance_response_form_page.dart`
- `ambulance_trip_progress.dart`
- `ambulance_driver_messages.dart`
- `ambulance_profile.dart`
- `ambulance_driver_edit_profile.dart`
- `dashboard_ambulance_driver.dart`

What they do:

- `health_home.dart`
Responder home page with ambulance status, nearby accident notifications, active case, and case log.

- `ambulance_response_form_page.dart`
Response form shown after the responder presses `Going`.

- `ambulance_trip_progress.dart`
Dispatch progress simulation until arrival.

- `ambulance_driver_messages.dart`
Responder messaging entry with nearby hospitals and support access.

- `ambulance_profile.dart`
Responder profile page.

- `dashboard_ambulance_driver.dart`
Dashboard-style responder summary page.

### Dashboard Screens

- `dashboard_router.dart`
- `ambulance_dashboard.dart`
- `insurance_dashboard.dart`
- `lib/widgets/dashboard_layout.dart`
- `lib/widgets/dashboard_notification_feed.dart`

These support:

- hospital dashboard view
- ambulance dashboard view
- insurance dashboard view
- notification feed style presentation

## Main Services

The `lib/services/` folder currently contains 9 service files.

Important ones:

- `app_repository.dart`
Main Firebase read and write layer. This is one of the most important files in the project.

- `impact_detection_service.dart`
Handles Flutter-side impact detection and emergency callbacks.

- `android_background_impact_service.dart`
Connects Flutter to the native Android foreground monitoring service.

- `assist_directory.dart`
Stores nearby hospital and EV technician directory data.

- `notification_service.dart`
Handles notification logic.

- `voice_assistant_service.dart`
Voice assistant or voice-related logic where used.

- `gemini_ai_service.dart`
Optional Gemini-powered chat or support enhancement when a key is provided.

- `web_monitoring_service.dart`
Web-related monitoring support.

## Native Android Files

Android-native impact support is handled through Kotlin files.

Important files:

- `android/app/src/main/kotlin/com/evsmart/plus/evsmart_plus/ImpactForegroundService.kt`
- `android/app/src/main/kotlin/com/evsmart/plus/evsmart_plus/ImpactAlertActivity.kt`
- `android/app/src/main/kotlin/com/evsmart/plus/evsmart_plus/ImpactMonitorControlActivity.kt`

These files are used for:

- true background monitoring on Android
- outside-app alert popup behavior
- pause or resume monitoring controls

## Firebase Data Paths

Main Firebase paths include:

- `alerts`
- `notifications`
- `message_threads`
- `vehicles`
- `ambulance_profiles`
- `technician_profiles`
- `charging_stations`

How the data works:

1. A user action, EV update, alert, or chat starts from Flutter.
2. The app prepares structured data like severity, location, report text, or message payload.
3. `app_repository.dart` reads or writes Firebase data.
4. Driver, responder, hospital, and insurance pages listen to those updates.
5. The UI refreshes in real time.

## Web App And Dashboard

This repository contains two web experiences.

### Flutter Web App

The full app can be compiled for web using:

- `flutter build web --release`

The output folder is:

- `build/web`

This is the folder used for Netlify or other static hosting.

The Flutter web app is good for:

- presentation
- hosted demo links
- manual alert flows
- support UI
- dashboard access

### Standalone Static Dashboard

The `static_dashboard/` folder is a separate HTML/CSS/JavaScript dashboard.

It is useful when:

- you only want dashboard-style display
- you do not want to load the full Flutter app
- you want a lightweight web dashboard for hospital or insurance roles

## Platform Behavior

### Android

Android is the best platform for the full demo because it supports:

- accelerometer simulation
- foreground service monitoring
- high-priority or full-screen emergency alerts
- better background behavior

### Web

Web is useful for:

- hosting on Netlify
- project presentation
- PWA-style access
- manual flows and dashboards

But web does not behave the same as Android background monitoring.

### iPhone / PWA

The Flutter web app can still run as a PWA, but it does not support the same Android-native background service features.

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

This helps keep the footer consistent across normal phones and foldable devices.

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

## Background Monitoring Notes

EVSmart+ supports Android background monitoring through a native foreground service.

This means:

- the app can continue listening for impact-related events when not fully open
- emergency behavior depends partly on Android device settings
- pause and resume controls are included to reduce battery use and false alerts

This feature is Android-specific.

## Demo Flow

Recommended demo flow:

1. Open the Android app.
2. Allow location, notifications, and monitoring permissions.
3. Open the driver home page.
4. Press `Connect EV`.
5. Show battery, tire, cloud sync, GPS, and impact cards.
6. Trigger a manual alert or impact simulation.
7. Show the countdown and Firebase alert creation.
8. Open the ambulance side.
9. Show nearby accident notifications.
10. Press `Going`.
11. Fill the response form.
12. Show trip progress.
13. Press `Arrived`.
14. Submit the final report.
15. Show the dashboard update.
16. Open nearby support or support chat if needed.

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
- Keep methods and widgets readable.
- Use null-safe Dart.
- Add comments only when the intent is not obvious.
- Avoid unrelated formatting churn.
- Prefer strong typing over loose dynamic code when practical.

## Validation Conventions

Use the smallest useful validation set:

- `flutter analyze`
- `flutter test`
- `flutter build web --release` for web-related changes

If platform-specific code changes, run the relevant platform check when possible.

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
- `chore: ...`
- `refactor: ...`
- `test: ...`
- `docs: ...`

Keep commits focused and specific.

## File Scope Guidance

- UI pages: `lib/screens/`
- Shared widgets: `lib/widgets/`
- Services and Firebase-related logic: `lib/services/`
- Android native files: `android/`
- Standalone dashboard: `static_dashboard/`

## Web Hosting Guide

### Full Flutter Web App

Build:

```bash
flutter build web --release
```

Upload:

- `build/web`

For Netlify:

- Build command: `flutter build web --release`
- Publish directory: `build/web`

### Static Dashboard

To test locally:

```bash
cd static_dashboard
python -m http.server 8088
```

Example role links:

- `index.html?role=hospital`
- `index.html?role=insurance`

## Known Limitations

- Phone accelerometer is used as an IoT-style demo signal.
- Some flows are prototype or presentation flows rather than production-ready business logic.
- Android popup behavior can vary by device and OS restriction.
- Web and iPhone/PWA do not support Android native background monitoring in the same way.
- Gemini must not be hardcoded; use `--dart-define`.

## Definition Of Done

A task is done when:

- the requested change is implemented
- relevant checks pass, or failures are explained
- the diff is focused and reviewable
- the final response clearly explains the impact and next steps
