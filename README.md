# PopTest

A Flutter flashcard app built with a **feature-first** architecture.

## Stack

| Layer | Package |
|---|---|
| State management | [flutter_riverpod](https://pub.dev/packages/flutter_riverpod) |
| Navigation | [go_router](https://pub.dev/packages/go_router) |
| Local persistence | [Drift](https://drift.simonbinder.eu/) *(planned – issue #2)* |

## Feature-first layout

```
lib/
├── main.dart              # entry point – ProviderScope
├── app.dart               # PopTestApp (ConsumerWidget, MaterialApp.router)
├── routing/
│   └── router.dart        # GoRouter + AppRoutes constants
├── features/
│   ├── home/
│   │   └── home_screen.dart
│   ├── deck/
│   │   └── deck_screen.dart
│   ├── review/
│   │   └── review_screen.dart
│   └── settings/
│       └── settings_screen.dart
├── core/
│   ├── scheduler/         # spaced-repetition logic (TODO)
│   └── monitoring/        # analytics / crash reporting (TODO)
└── data/
    └── local/             # Drift local DB (TODO – issue #2)
```

## Getting started

```bash
flutter pub get
flutter run
```

