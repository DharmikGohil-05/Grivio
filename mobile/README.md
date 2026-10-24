# GRIVIO Mobile (Flutter)

Neumorphic personal-growth app: goals → milestones → tasks → focus →
progress → reflection, with five AI assist features that are **preview-only**
until the user explicitly confirms. Light, dark and system themes.

## Architecture

```
mobile/lib/
├── main.dart              # entry point + auth-gate router (splash → login / setup / app)
├── core/
│   ├── config/            # AppConfig: API base URL (--dart-define), timeout
│   ├── constants/         # app-wide constants
│   ├── theme/             # app_theme.dart (design tokens) + theme_controller.dart
│   └── utils/             # responsive helpers
├── screens/               # all UI: 5 tabs + detail screens + AI bottom sheets
├── services/              # one service per backend feature + api_client + ai_service
└── widgets/               # neumorphic.dart (design system) + ui_kit.dart (decorations)
```

Layering: screens call services; every service goes through `ApiClient`
(single place for the `Authorization: Bearer` header, 20 s timeout and the
`{ success, message }` → `ApiException` mapping). Models (e.g. `GrivioTask`)
live inside their service files with `fromJson`/`toJson`.

## Screens and navigation

Exactly **five tabs** — Home, Goals, Focus, Progress, Profile
(`screens/main_scaffold.dart`). No AI tab and no chatbot; AI features open as
bottom sheets from the screens they belong to (Task Detail, Goal Detail,
Add Task, Home's "Plan my day", Weekly Review).

Startup routing (`main.dart`): animated splash while the session resolves →
`LoginScreen` (logged out) → `SetupFlowScreen` (first-time setup) →
`MainScaffold` (setup done).

## Theme system

Design tokens live in `core/theme/app_theme.dart`
(`AppColors`, `AppSpacing`, `AppRadius`): ~85–90 % neutral surfaces with
10–15 % accent, paired light/dark tokens, neumorphic shadow pairs.
`ThemeController` (singleton `ChangeNotifier`) persists the user's
Light / Dark / System choice in secure storage and rebuilds the app live.

## API configuration

The backend URL is injected at compile time — no secrets in the app:

```powershell
# Android emulator (host loopback alias):
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:5000/api

# iOS simulator / desktop:
flutter run --dart-define=API_BASE_URL=http://localhost:5000/api

# Physical device: your PC's LAN IP, e.g. http://192.168.1.10:5000/api
```

A development default (`10.0.2.2`) applies when the define is omitted.

## Authentication flow

`services/auth_service.dart` calls `/auth/register` or `/auth/login`, stores
the returned JWT via `flutter_secure_storage` (`auth_storage.dart`), and every
subsequent request attaches it as a Bearer token. `isLoggedIn()` is a local
token-presence check (JWTs are stateless); the next real API call is what
enforces validity — an expired token surfaces as a friendly
"Invalid or expired token" error and the user simply logs in again.

## Main services and models

| Service | Models | Backend feature |
| --- | --- | --- |
| `auth_service`, `profile_service` | `UserProfile` | account, setup, reflections |
| `goal_service` | `Goal`, `Milestone` | goals + milestones (server-computed progress) |
| `task_service` | `GrivioTask`, subtask counts | tasks + subtasks (subtask → task → milestone → goal chain) |
| `focus_service` | `FocusSession` | timer sessions incl. pause/resume and local recovery |
| `progress_service` | stats/trend models | charts data |
| `weekly_review_service` | `WeeklyStats`, `WeeklyReview` | Monday-start weekly reviews |
| `ai_service` | `SubtaskSuggestion`, `TaskImprovement`, `BreakdownProposal`, `DailyPlan`, `AIWeeklyReview` | the five AI features (Groq only via the backend) |

## Running the app

```powershell
cd mobile
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:5000/api
```

The backend must be running (see `../backend/README.md`).

## Tests and analysis

```powershell
flutter analyze     # lints — keep at "No issues found"
flutter test        # widget tests: design system, theme switching, splash→login boot
```

## Common problems

| Symptom | Fix |
| --- | --- |
| `ConnectionException` / "Could not reach the server" | Wrong `API_BASE_URL`. Emulator needs `10.0.2.2`, a physical device needs your PC's LAN IP, and the PC firewall must allow the port |
| "Invalid or expired token" | The stored JWT expired — log out (or clear app data) and log in again |
| AI buttons return a service-unavailable message | `GROQ_API_KEY` missing on the backend — everything else still works |
| Charts look empty | Create some tasks/sessions first; progress derives from your data |
