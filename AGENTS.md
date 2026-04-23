# AGENTS.md

This file defines how coding agents (including Codex) should operate in this repository.

## Project Context
- Stack: Flutter/Dart app with Android, iOS, Web, Linux, macOS, and Windows targets.
- Main app source: `lib/`
- Assets: `assets/`
- Tests: `test/`

## EVSmart+ Product Scope
- EVSmart+ is a final-year EV accident-response and monitoring prototype.
- The main mobile experience is the EV driver app with impact detection, EV status simulation, charging station finder, nearby hospital/technician support, and emergency alerts.
- The main emergency workflow is Level 4/5 impact detection syncing to hospital/ambulance dashboards through Firebase Realtime Database.
- Insurance receives broader incident/support visibility, including all impact levels and technician support activity.
- Technician support is not a full registered technician app role. It is handled through nearby EV workshop listings and AI-style chat from the driver message flow.
- Hospital/health support can be opened from messages and also receives emergency Level 4/5 cases through dashboards.
- Android background impact detection uses a native foreground service and full-screen/high-priority notification fallback.
- Gemini AI is optional. It is used only when `GEMINI_API_KEY` is supplied through `--dart-define`; otherwise local rule-based replies remain active.

## Why This Is EV-Focused
- EVSmart+ is not presented as a generic car safety app. Its unique angle is EV battery safety, EV charging dependency, EV-specialist roadside support, and connected emergency routing.
- The driver home emphasizes battery state of charge, estimated range, battery temperature, battery voltage/current, battery health, charging state, inverter/motor status, tire status, GPS, cloud sync, and impact sensor state.
- For the final-year prototype, EV data can be explained as coming from external IoT sensors, an OBD-II/CAN reader, or a Battery Management System gateway. The app simulates this by syncing cloud data every 15 seconds.
- The most important EV safety reason is the high-voltage traction battery. After impact, the system can discuss battery overheating, smoke/fire risk, charging state, range, specialist technician support, and whether emergency routing is needed.
- Charging station finder and EV technician assist are part of the same story: EV drivers need charging-aware recovery and EV-trained workshops, not only normal mechanic support.

## Full App Usage Report
- Login/Register: users enter through the normal app authentication flow. The product direction is simplified so driver and ambulance/hospital responder flows are the important demo roles; technician is not treated as a full app user role.
- Menu: the side menu links to the main user areas such as Home, Charge, Alert, Notifications, Rewards, Profile, Settings/support pages, and responder pages where applicable.
- Driver Home: shows the EV safety dashboard. Pressing `Connect EV` now goes directly to the `EV Connected` confirmation popup, explaining vehicle selected, connection method, sensors connected, cloud connected, and 15-second refresh interval.
- EV Monitoring: the dashboard shows simulated EV sensor/cloud data such as battery, tire, GPS, impact, estimated range, drive mode, cloud connection, battery overview, and vehicle health.
- Search and Voice: the search bar supports typed search and Google speech-to-text voice input. Gemini can improve short command responses when a `GEMINI_API_KEY` is provided; local rules still work offline.
- Charging Map: `charge.dart` shows nearby EV charging stations and supports map-style browsing for charging-related demo needs.
- Alert Page: `alert.dart` supports manual impact/emergency testing. It keeps the manual flow but uses the same emergency countdown style for severe actions.
- Automatic Impact Detection: Flutter accelerometer logic and Android native foreground service monitor impact. Level 4/5 severe alerts are routed to hospital/ambulance dashboards, while lower levels can still be logged for insurance/demo review.
- Background Monitoring: Android uses a foreground service for true background monitoring. When Android allows it, full-screen/high-priority alerts can appear outside the app. The notification can also open pause controls to reduce false alarms.
- Notifications: `noti.dart` shows driver notifications and alert history with selectable/deleteable notification-style cards.
- Rewards: `rewards.dart` remains a demo engagement/rewards area and can support presentation/demo activity logs.
- Messages: `user_message.dart` is the driver messaging entry. Users can choose nearby Health Assist or Technician Assist from messages.
- Nearby Health Assist: the map/list flow can show nearby healthcare or hospital responders with address, contact, distance, call, navigate, and message actions.
- Nearby Technician Assist: technicians are realistic EV workshops/roadside providers from the assist directory, sorted by nearby location where possible. Users can call, navigate, or open AI-style chat.
- Technician AI Chat: technician chat does not require a real technician account. It behaves like an EV workshop assistant, gives short practical responses, asks for damage/battery/tire/location details, can acknowledge vehicle-condition photos, and logs activity to Firebase/insurance.
- Hospital Chat: hospital/health conversations can reply with emergency-focused guidance and support image sending through the shared conversation page.
- Insurance Visibility: insurance dashboard receives broader logs including all impact levels, technician support requests, messages, image submissions, and support case updates.
- Ambulance Home: `health_home.dart` receives nearby Level 3+ accident notifications. Level 3 is for contact/check-first. Level 4/5 is emergency response.
- Ambulance Going Flow: when the ambulance responder presses `Going`, the quick response form asks for ETA, ambulance unit, contact number, team size, and note. Submitting sends the form to Firebase and hospital dashboard, then opens a dedicated ambulance dispatch progress screen.
- Ambulance Dispatch Progress: the progress screen simulates the trip to the EV user with a 0% to 100% progress bar. Once complete, the responder presses `Arrived` and returns safely to `health_home.dart`.
- Ambulance Active Case: after the dispatch progress screen completes, the case card changes into `Arrived` state. The responder can still use Map/Chat and then press `Submit Report` for the patient and scene handover form.
- Ambulance Report Flow: the arrival report captures patient/pax count, condition, severity, and handover notes. Submitting updates the hospital dashboard, shows a nearest-hospital confirmation popup, and closes the active case.
- Hospital Dashboard: hospital dashboard is notification-focused and should show Level 4/5 emergency cases plus ambulance Going/Arrived/report updates in real time.
- Insurance Dashboard: insurance dashboard is notification-focused and should show all support/incident visibility needed for monitoring and final-year demo explanation.
- Static Web Dashboard: `static_dashboard/` can be hosted separately as simple HTML/CSS/JS connected to Firebase, so the dashboard can be opened from a normal web link without `flutter run -d chrome`.

## Important Feature Files
- `lib/screens/home_driver.dart`: EV driver home, EV connection simulation, battery/vehicle health UI, impact handling, SOS/demo buttons.
- `lib/screens/alert.dart`: alert/manual impact page and incident controls.
- `lib/services/impact_detection_service.dart`: Flutter accelerometer impact detection and background permission prompt.
- `lib/services/android_background_impact_service.dart`: Flutter bridge to native Android foreground service.
- `android/app/src/main/kotlin/com/evsmart/plus/evsmart_plus/ImpactForegroundService.kt`: native Android background impact monitoring.
- `android/app/src/main/kotlin/com/evsmart/plus/evsmart_plus/ImpactAlertActivity.kt`: outside-app accident warning popup.
- `android/app/src/main/kotlin/com/evsmart/plus/evsmart_plus/ImpactMonitorControlActivity.kt`: pause/resume background monitoring controls.
- `lib/screens/health_home.dart`: ambulance/health responder feed, nearby location card, Going/Arrived/report flow, and hospital dashboard updates.
- `lib/screens/ambulance_trip_progress.dart`: ambulance dispatch progress screen shown after `Going` form submission.
- `lib/screens/user_message.dart`: driver inbox and Health Assist/Technician Assist entry point.
- `lib/screens/message_conversation_page.dart`: chat thread page and vehicle photo sending.
- `lib/screens/nearby_assist_map.dart`: nearby hospital/technician map, call, navigate, message actions.
- `lib/services/app_repository.dart`: main Firebase repository, alerts, notifications, conversations, dashboard logging, fallback chatbot rules.
- `lib/services/gemini_ai_service.dart`: optional Gemini AI short replies for chats and voice/search fallback.
- `lib/services/assist_directory.dart`: static hospital and EV technician/workshop directory.
- `lib/screens/dashboard_router.dart`: Flutter web dashboard router.
- `lib/widgets/dashboard_layout.dart`: Flutter web dashboard shell.
- `lib/widgets/dashboard_notification_feed.dart`: Flutter web notification-style cards and dashboard filtering.
- `static_dashboard/`: standalone HTML/CSS/JS Firebase dashboard for GitHub Pages or other static hosting.

## Firebase Data Paths
- `alerts`: impact alerts, manual SOS alerts, ambulance response data, patient/report updates.
- `notifications`: dashboard notifications, support updates, hospital/insurance feed updates.
- `message_threads`: driver/hospital/technician conversations.
- `vehicles`: EV profile/status data.
- `ambulance_profiles`: ambulance/health responder profile data.
- `technician_profiles`: legacy profile path kept for compatibility, but technician support is normally simulated through nearby listings and AI chat.
- `charging_stations`: EV charging station data used by charging map.

## Manual Run Guide
- Install packages: `flutter pub get`
- Analyze: `flutter analyze`
- Run tests: `flutter test`
- Run Android app: `flutter run`
- Run with Gemini AI enabled: `flutter run --dart-define=GEMINI_API_KEY=YOUR_KEY`
- Optional Gemini model override: `flutter run --dart-define=GEMINI_API_KEY=YOUR_KEY --dart-define=GEMINI_MODEL=gemini-2.5-flash`
- Build debug APK: `flutter build apk --debug`
- Build Flutter web/PWA: `flutter build web --release`

## Web Hosting Guide
- Flutter web build output is `build/web`.
- Host `build/web` on Firebase Hosting, Vercel, Netlify, GitHub Pages, or any static server.
- Standalone dashboard is in `static_dashboard/` and does not require Flutter build.
- To test standalone dashboard locally:
  - `cd static_dashboard`
  - `python -m http.server 8088`
  - open `http://localhost:8088`
- Static dashboard role links:
  - Hospital: `index.html?role=hospital`
  - Insurance: `index.html?role=insurance`
- Static dashboard depends on Firebase Realtime Database rules allowing access to `alerts` and `notifications`.

## Demo Script
1. Open the Android app and allow location, notification, and background impact permissions.
2. On driver home, press `Connect EV` and show the `EV Connected` confirmation popup.
3. Show EV battery, tire, motor, inverter, GPS, cloud sync, and impact monitoring cards.
4. Trigger manual SOS or simulate Level 4/5 impact.
5. Wait for the 10-second countdown unless canceling as a false alarm.
6. Confirm Level 4/5 appears on hospital dashboard.
7. Open health/ambulance user and show the `Location is on` nearby accident feed.
8. Press `Going`, submit ETA/unit/contact/team form, and show the dispatch progress screen.
9. Wait for progress to reach 100%, press `Arrived`, and return to `health_home.dart`.
10. Press `Submit Report`, then send patient/pax condition, severity, and handover notes.
11. Show the nearest-hospital confirmation popup.
12. Refresh or watch hospital dashboard update in real time.
13. Open Messages, choose Technician Assist, select nearby EV workshop, send message/photo, and show AI-style workshop replies.
14. Open Insurance dashboard and show all impact/support logs.

## Known Demo Limitations
- Phone accelerometer is used as an IoT impact-sensor simulation.
- Android background popups can be restricted by device/OS settings, so full-screen/high-priority notification is the reliable fallback.
- iOS/PWA cannot run the Android native foreground impact service.
- Gemini keys must not be hardcoded in source files. Use `--dart-define` for demos or a backend proxy for production.
- Static dashboards can only read/write Firebase when database rules allow it.

## Core Workflow
1. Read relevant files first and keep changes scoped to the user request.
2. Prefer minimal, targeted edits over broad refactors.
3. Preserve existing architecture and naming unless the task explicitly asks to change it.
4. Run validation commands after edits when possible.
5. Summarize what changed, why, and any follow-up actions.

## Coding Conventions
- Follow Flutter and Dart style from `analysis_options.yaml`.
- Keep widgets and methods focused and readable.
- Add comments only where intent is non-obvious.
- Do not introduce unrelated dependency or formatting churn.
- Prefer null-safe, strongly typed Dart code.

## Validation Conventions
Run the smallest useful validation set for the change:
- `flutter analyze`
- `flutter test`
- If platform-specific code changed, run the relevant target build/test command.

If a command cannot run, report the reason clearly.

## Git Conventions
- Use Conventional Commits:
  - `feat: ...`
  - `fix: ...`
  - `chore: ...`
  - `refactor: ...`
  - `test: ...`
  - `docs: ...`
- Keep commit messages specific and imperative.
- Avoid mixing unrelated changes in one commit.

## Safety Rules
- Never delete or rewrite large sections unless requested.
- Never run destructive git commands (for example `reset --hard`) unless explicitly requested.
- Do not modify secrets, keys, or CI/release settings unless the task requires it.
- Ask for confirmation before significant architectural or dependency changes.

## File Scope Guidance
- UI screens/pages: `lib/screens/`
- Shared UI components: keep near usage or in existing shared locations.
- Firebase setup and generated options: update only when integration changes are requested.
- Generated platform files: avoid manual edits unless required by the task.

## Definition of Done
- Requested change is implemented.
- Relevant checks pass (or failures are explained).
- Diff is clean, focused, and reviewable.
- Final response includes impact and any next steps.
