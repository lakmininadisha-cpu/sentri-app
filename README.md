# Sentri — AI-Powered Smart Lifestyle Companion

Sentri is a Flutter mobile application built for the CMP7003 Emerging Mobile Applications module (MSc IT). At its core, Sentri is a proactive lost-item assistant that predicts where a belonging is likely to be based on your own location history, and warns you before you leave without it — rather than only helping after something's already missing.

Built around this core feature are four supporting pillars sharing the same context engine: environmental awareness (weather), health tracking (steps, water, activity), family sharing (tracking a dependent's belongings), and productivity insights.

## Key Features

### Lost & Found
- Full item registration — photo, category, priority, colour tag, notes, family assignment
- On-device photo category suggestion via Google ML Kit
- Location check-ins with a rule-based prediction heuristic (recency + frequency scoring)
- Live map view of an item's last known location
- Nearby Items screen — sorts the full item list by live distance from the user
- Search, filter (category/priority/person), and sort
- Proactive "before you leave" alerts, combined with weather warnings
- Bluetooth Low Energy proximity tracking (qualitative near/far indicator)

### AI-Powered Features
- **Voice assistant** — natural language item lookup powered by the Gemini API, reasoning over the user's full item list to resolve indirect phrasing (e.g. "where's my computer" correctly resolving to "Laptop"), with automatic fallback to keyword matching if the API is unavailable
- **AI-generated weekly insights** — Gemini-generated observations on the user's tracked-item statistics
- **On-device camera recognition** — Google ML Kit image labelling, entirely on-device (no images transmitted anywhere)

### Lifestyle Modules
- Weather: current conditions plus a 5-day forecast, with a persisted °C/°F toggle
- Health: accelerometer-based inactivity nudges, daily step counting (pedometer), water-intake logging with a daily goal, and a 7-day history chart
- Family sharing: lightweight sub-profiles for tracking a dependent's belongings, no second account required
- Routines & Reminders: a unified schedule-aware model for daily tasks, health reminders, and one-off events
- Productivity: weekly summary statistics and AI-generated insights

### Account & Settings
- Email/password and Google Sign-In authentication
- Biometric app-lock
- Profile editing, password change (with re-authentication)
- Full account deletion (clears every Firestore collection, then the Auth account)
- Notification and unit preferences
- Language switching (English / Sinhala, currently covering Settings, Login, and Home)

### First-Time User Experience
- Custom app icon and native splash screen
- Onboarding walkthrough shown once after signup
- Permission-priming screens explaining why location access is needed

## Tech Stack

| Category | Technology |
|---|---|
| Framework | Flutter (Dart) |
| Backend | Firebase (Authentication, Cloud Firestore) |
| AI / ML | Google Gemini API, Google ML Kit (on-device image labelling) |
| Location | Geolocator, flutter_map |
| Sensors | sensors_plus (accelerometer), pedometer |
| State Management | Provider |
| Local Storage | shared_preferences |
| Notifications | flutter_local_notifications |
| Other | speech_to_text, flutter_tts, flutter_blue_plus, local_auth, google_sign_in |

## Architecture

Sentri is built around a shared Context & Behaviour Engine that feeds five feature modules (Lost & Found, Environment, Health, Productivity, Family), each communicating only with the engine and Firestore — never directly with one another. Authentication and language state are managed centrally via the Provider package (an Observer-pattern implementation). A shared UI component library (gradient headers, cards, empty states, loading skeletons) is reused consistently across all screens.

## Getting Started

### Prerequisites
- Flutter SDK (^3.12.2 or compatible)
- Android Studio with an configured emulator or a physical Android device
- A Firebase project (Firestore + Authentication enabled)

### Setup

1. Clone the repository:
https://github.com/lakmininadisha-cpu/sentri-app.git

2. Install dependencies:

3. Configure Firebase:
   - Create a Firebase project at https://console.firebase.google.com
   - Enable Authentication (Email/Password + Google Sign-In) and Cloud Firestore
   - Run `flutterfire configure` to generate `lib/firebase_options.dart`
   - Publish the Firestore Security Rules (see `firestore.rules` if included, or the report's Security section)

4. Add your own API keys (see below)

5. Run the app:

## API Keys

This repository does not include real API keys, for security reasons — they have been replaced with placeholder text in the following files:

- `lib/services/gemini_service.dart` — Gemini API key
- `lib/services/weather_service.dart` — OpenWeatherMap API key

To run the app with full functionality (voice assistant, AI insights, weather), replace the placeholder values with your own keys:

- **Gemini API key** (free): https://aistudio.google.com/apikey
- **OpenWeatherMap API key** (free): https://openweathermap.org/api

All other features — item tracking, camera recognition, location prediction, family sharing, routines, biometric lock, and more — work without any additional setup once Firebase is configured.

## Known Limitations

- The Android emulator does not provide a real Bluetooth radio, step sensor, or camera, so those features are code-complete but only partially demonstrable without physical hardware
- Language support currently covers three screens (Settings, Login, Home) rather than the full application
- Location prediction and Bluetooth proximity are rule-based heuristics rather than trained models, chosen deliberately for explainability and to work from a user's very first data point

## Project Structure
lib/
├── main.dart
├── models/ # Data models (Item, FamilyProfile, Routine)
├── screens/ # All UI screens
├── services/ # Business logic (location, weather, Gemini, notifications, etc.)
├── state/ # Provider-based app state (AuthState, LanguageState)
└── widgets/ # Shared, reusable UI components


## Author

Built by [Nadishika Lakmini] ([CL/MSCIT/28/11]) for CMP7003 — Emerging Mobile Applications, MSc IT.
