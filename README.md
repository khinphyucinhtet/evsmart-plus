# EVSmart+

EVSmart+ is a Flutter and Firebase final-year prototype for electric vehicle safety, emergency response, charging support, and connected dashboards.

The project is designed around one main idea:

- an EV driver may need more than a normal car app after an accident
- the system should understand EV-related risk such as battery condition, charging dependency, and EV-specific roadside support
- serious cases should appear quickly on responder dashboards

This repository contains the mobile app, the Flutter web app/PWA, and a separate lightweight static dashboard.

## What The App Does

EVSmart+ can:

- show a driver-focused EV dashboard
- simulate EV connection and cloud updates
- monitor or simulate impact events
- trigger manual alert or SOS flows
- send Level 4 and Level 5 emergency cases to responder dashboards
- help the user find nearby EV charging stations
- help the user contact nearby hospitals or EV technicians
- let the driver send messages and vehicle photos
- let ambulance responders accept, travel to, arrive at, and close cases
- show hospital and insurance visibility through dashboards
- run as a Flutter web app for demos and hosting

## Main User Roles

The project mainly revolves around these roles:

- Driver
- Ambulance or health responder
- Hospital dashboard viewer
- Insurance dashboard viewer

Technician support is included too, but it is mostly handled as nearby workshop listings plus AI-style chat instead of a fully separate technician account flow.

## High-Level System Flow

Here is the main story of the app in simple English:

1. The EV driver opens the app and connects the EV demo.
2. The driver dashboard shows battery, range, temperature, tire, location, and cloud sync style information.
3. If the phone detects a strong impact, or the user triggers a manual alert, EVSmart+ creates an alert.
4. Level 1 to Level 3 cases can stay as lower-severity records, service support, or insurance visibility.
5. Level 4 and Level 5 cases are treated as serious emergency cases.
6. Those serious cases are saved to Firebase Realtime Database.
7. Ambulance and hospital views read the same Firebase data and update in real time.
8. The ambulance responder can press `Going`, submit a response form, watch trip progress, press `Arrived`, and then submit a final report.
9. The final report updates the shared case information for dashboards.
10. The driver can also use charging support, nearby hospitals, nearby EV technicians, messages, and rewards.

## EV IoT Data Flow

The app explains EV data like this:

1. Sensor input:
Battery, tire, GPS, impact, and temperature data are collected.

2. Gateway processing:
A gateway such as ESP32, OBD-II reader, CAN reader, or BMS bridge can process raw data.

3. Cloud sync:
The app simulates regular sync to Firebase for live monitoring.

4. Intelligent action:
The system decides whether the case is a normal update, a service issue, or a real emergency.

For this prototype, much of the EV data is simulated in Flutter, but the product story is that real EV sensors or EV gateway hardware could send the same data.

## Mobile App Sections

### Driver App

The main driver experience includes:

- `home_driver.dart`
- `charge.dart`
- `alert.dart`
- `noti.dart`
- `rewards.dart`
- `report_problem.dart`
- `user_message.dart`
- `message_conversation_page.dart`

What these pages do:

- `home_driver.dart`
Shows the main EV dashboard, EV connection popup, support cards, sensor cards, IoT architecture view, and action shortcuts.

- `charge.dart`
Shows nearby EV charging station content and map-related charging support.

- `alert.dart`
Handles manual alert testing, impact severity flows, countdown confirmation, and emergency simulation.

- `noti.dart`
Shows driver notifications, alert history, and message-style event cards.

- `rewards.dart`
Shows rewards, donation options, check-in logic, and demo engagement content.

- `report_problem.dart`
Shows the EVSmart+ support chat UI with report issue flow, problem form, and quick support topics.

- `user_message.dart`
Acts as the driver inbox entry point for health assist and technician assist.

- `message_conversation_page.dart`
Shows actual conversation threads and supports photo sending.

### Ambulance / Health Responder App

The main responder experience includes:

- `health_home.dart`
- `ambulance_response_form_page.dart`
- `ambulance_trip_progress.dart`
- `ambulance_driver_messages.dart`
- `ambulance_profile.dart`
- `ambulance_driver_edit_profile.dart`
- `dashboard_ambulance_driver.dart`

What these pages do:

- `health_home.dart`
Shows nearby emergency feed, active case, case log, location summary, and responder status.

- `ambulance_response_form_page.dart`
Collects ETA, unit, contact, team size, and notes before dispatch.

- `ambulance_trip_progress.dart`
Simulates the ambulance trip from 0 percent to 100 percent until arrival.

- `ambulance_driver_messages.dart`
Provides the responder chat inbox with nearby hospitals and technician-related assist entry.

- `ambulance_profile.dart`
Shows the responder profile page.

- `dashboard_ambulance_driver.dart`
Provides a dashboard-style responder summary page.

### Web Dashboards

The project has dashboard-related Flutter pages and a standalone static dashboard:

- `dashboard_router.dart`
- `ambulance_dashboard.dart`
- `insurance_dashboard.dart`
- `lib/widgets/dashboard_layout.dart`
- `lib/widgets/dashboard_notification_feed.dart`
- `static_dashboard/`

The dashboards are mainly for:

- hospital monitoring
- ambulance response visibility
- insurance visibility
- notification-style case review

## Web App And Static Dashboard

This repository contains two different web experiences.

### 1. Flutter Web App

This is the full EVSmart+ app compiled for the browser.

It includes:

- driver pages
- responder-related pages
- shared Flutter UI
- same theme and logic as the mobile app where supported

Important note:

- Android-only background monitoring does not behave the same way on web
- the web build is more suitable for location-first demo flows, manual alert actions, dashboard access, and presentation use

The Flutter web build output is:

- `build/web`

This is the folder you upload to Netlify.

### 2. Static Dashboard

This is a separate HTML/CSS/JavaScript dashboard in:

- `static_dashboard/`

It is lighter than the Flutter app and is useful when you only want a dashboard webpage without loading the whole Flutter application.

It can be hosted separately on:

- GitHub Pages
- Netlify
- Firebase Hosting
- any static host

## Firebase Data Flow

The main Firebase Realtime Database paths used by the project are:

- `alerts`
- `notifications`
- `message_threads`
- `vehicles`
- `ambulance_profiles`
- `technician_profiles`
- `charging_stations`

How the data moves:

1. The user triggers an alert, sends a message, opens support, or updates EV-related state.
2. Flutter screens prepare structured data such as severity, location, timestamps, status, and notes.
3. `lib/services/app_repository.dart` reads and writes most shared Firebase data.
4. Ambulance, hospital, and insurance views listen to the same Firebase data.
5. The UI refreshes automatically through streams and repository calls.

## Main Services

The app currently has 9 Dart service files in `lib/services/`.

Important ones are:

- `app_repository.dart`
Main Firebase and shared app data layer.

- `impact_detection_service.dart`
Flutter-side impact detection using accelerometer input and emergency callbacks.

- `android_background_impact_service.dart`
Flutter bridge to the native Android foreground service.

- `assist_directory.dart`
Stores nearby hospital and EV technician style data used in support flows.

- `notification_service.dart`
Handles notification-related logic.

- `voice_assistant_service.dart`
Supports voice-related assistant features where used.

- `gemini_ai_service.dart`
Optional Gemini-powered replies when a key is supplied.

- `web_monitoring_service.dart`
Web-related monitoring support.

## Native Android Side

The Android side includes 4 Kotlin files.

These handle Android-specific features such as:

- background impact monitoring
- foreground service behavior
- outside-app emergency alert display
- pause or resume control activity

Important native files:

- `android/app/src/main/kotlin/com/evsmart/plus/evsmart_plus/ImpactForegroundService.kt`
- `android/app/src/main/kotlin/com/evsmart/plus/evsmart_plus/ImpactAlertActivity.kt`
- `android/app/src/main/kotlin/com/evsmart/plus/evsmart_plus/ImpactMonitorControlActivity.kt`

## Current Codebase Size

Current project counts:

- Total Dart files in `lib/`: 57
- Screen-related Dart files in `lib/screens/`: 42
- Service Dart files in `lib/services/`: 9
- Shared widget Dart files in `lib/widgets/`: 4
- Kotlin files in `android/`: 4
- Asset files in `assets/`: 18
- Static dashboard files in `static_dashboard/`: 6

## Shared UI Structure

Some reusable UI files already exist:

- `lib/screens/app_header.dart`
- `lib/screens/app_footer.dart`
- `lib/widgets/info_card.dart`
- `lib/widgets/severity_badge.dart`
- `lib/widgets/dashboard_layout.dart`
- `lib/widgets/dashboard_notification_feed.dart`

The main driver footer is now shared across:

- `home_driver.dart`
- `charge.dart`
- `alert.dart`
- `noti.dart`
- `rewards.dart`

This helps keep the bottom navigation consistent across more device sizes, including narrow devices and foldable screens.

## Important Feature Highlights

### EV Connection Demo

The driver can press `Connect EV` and see a connected popup showing:

- selected EV
- connection method
- connected sensor types
- cloud sync status
- refresh interval

### Impact Detection

The project supports:

- phone accelerometer simulation
- manual impact testing
- Android background monitoring

Level 4 and Level 5 are the most important emergency levels.

### Ambulance Response Flow

The responder flow is:

1. View nearby case
2. Press `Going`
3. Fill response form
4. Watch trip progress
5. Press `Arrived`
6. Submit final report
7. Close the case

### Support And Messaging

The app supports:

- nearby hospitals
- nearby EV technicians
- technician AI-style support chat
- hospital messaging
- support chatbot for reporting app problems

### Rewards And Donations

The rewards area is included for:

- daily demo activity
- check-in points
- mission progress
- donation causes

## Platform Notes

### Android

Best platform for the full prototype because it supports:

- background impact monitoring
- foreground service
- emergency-style notification behavior
- better device integration for the demo

### iPhone / PWA

The app can still run as a web app or PWA, but:

- it does not support the same Android native background service flow
- some notification or continuous monitoring behavior may be limited

### Web

Good for:

- demo hosting
- presentation sharing
- dashboard access
- lightweight manual alert or support flows

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

## Netlify Deployment

To deploy the full Flutter web app to Netlify:

1. Run:

```bash
flutter build web --release
```

2. Upload:

- `build/web`

Do not upload:

- the project root
- only the `web/` source folder

Recommended Netlify settings:

- Build command: `flutter build web --release`
- Publish directory: `build/web`

## Static Dashboard Local Test

To test the static dashboard:

```bash
cd static_dashboard
python -m http.server 8088
```

Then open:

- `http://localhost:8088`

Example role links:

- Hospital: `index.html?role=hospital`
- Insurance: `index.html?role=insurance`

## Demo Script

1. Open the app and allow location, notification, and impact-related permissions.
2. Open the driver home page.
3. Press `Connect EV`.
4. Show battery, range, cloud sync, and sensor cards.
5. Trigger a manual alert or impact flow.
6. Show how the alert goes to Firebase.
7. Open the ambulance side and show nearby emergency notifications.
8. Press `Going` and submit the response form.
9. Let the trip progress screen reach arrival.
10. Press `Arrived`.
11. Submit the responder report.
12. Show the hospital or insurance dashboard updating.
13. Open support messages or nearby technician help.
14. Show charging support or rewards if needed.

## Current Limitations

- Accelerometer data is used as an IoT-style demo signal, not a real EV crash sensor.
- Android background popups can depend on device settings and OS restrictions.
- Web and iPhone/PWA do not behave the same as Android background service mode.
- Gemini AI is optional and should not be hardcoded in source.
- Some flows are prototype or demo flows rather than production-ready systems.

## Summary

EVSmart+ is a connected EV safety and emergency-response prototype. It combines EV monitoring, impact handling, nearby help, ambulance workflow, messaging, charging support, rewards, and dashboards inside one Firebase-connected Flutter project.
