# PopTest

A Flutter flashcard app with a **pop-study** (Anki-like) spaced-repetition system, built with a feature-first architecture.

## Stack

| Layer | Package |
|---|---|
| State management | [flutter_riverpod](https://pub.dev/packages/flutter_riverpod) |
| Navigation | [go_router](https://pub.dev/packages/go_router) |
| Local persistence | [Drift](https://drift.simonbinder.eu/) *(planned – issue #2)* |

## Navigation

The app uses **go_router** with a `StatefulShellRoute` to implement a persistent `BottomNavigationBar` across five top-level sections:

| Tab | Path | Description |
|---|---|---|
| ホーム | `/` | Dashboard – ポップ統計、サービス/URL対象、学習中ステータス |
| デッキ | `/decks` | Deck list; `/decks/:deckId` opens a deck; `/decks/:deckId/pop` starts a study session |
| レビュー | `/review` | Manual / interrupt study (stub) |
| 設定 | `/settings` | 保存ボタンで確定する設定画面 |
| 統計 | `/stats` | Stats overview (stub) |

URL updates on every navigation. The system back button works correctly within each branch. Each branch preserves its own navigation stack thanks to `StatefulShellRoute.indexedStack`.

## Pop Study concept

**Pop Study** is the core study mode. Cards are shown one at a time; you reveal the back face and choose:

- **Again** – you didn't remember; the card returns to *Learning* state and is re-queued at the end of the session.
- **Good** – you remembered; the card advances to *Review* state with a next due date of `now + 1 day`.

State transitions: `newCard → review` or `learning → review` on *Good*; any state → `learning` (re-queued) on *Again*.

A session contains:
1. All *Learning* cards (highest priority).
2. All *Review* cards (due today — `dueAt` filter will be added when Drift lands).
3. Up to `newLimit` new cards (configurable in Settings, default 20).

The screen shows both **session-remaining** and **deck-total** breakdowns by state, with the current card's state category underlined and highlighted.

**Solve-to-dismiss**: leaving the Pop Study screen while cards remain triggers a confirmation dialog.

### Pop monitoring behavior

- Homeで「ポップ学習を開始」をONにすると、アプリ内のユーザー操作（タップ）を監視します。
- 対象SNSまたは対象URLが1つ以上設定され、現在URLが一致している状態で、設定した間隔が経過したタイミング（初回は開始時刻+間隔）にポップ出題ダイアログを表示します。
- 学習中に間隔を変更した場合も、前回学習からの経過時間は維持され、次回判定から新しい間隔を適用します。
- ダイアログの「開始」で `/decks/:deckId/pop` の学習セッションを開きます。

## Data model (in-memory)

```dart
enum CardState { newCard, learning, review }

class CardModel { id, front, back, state, dueAt }
```

All data lives in-memory (`DeckRepository`). Drift persistence is tracked in **issue #2**.

## Feature-first layout

```
lib/
├── main.dart                    # entry point – ProviderScope
├── app.dart                     # PopTestApp (ConsumerWidget, MaterialApp.router)
├── routing/
│   ├── router.dart              # GoRouter + AppRoutes constants + StatefulShellRoute
│   └── shell_scaffold.dart      # BottomNavigationBar shell wrapper
├── features/
│   ├── home/
│   │   └── home_screen.dart     # Dashboard – stat placeholders
│   ├── deck/
│   │   ├── decks_screen.dart    # Deck list (/decks)
│   │   └── deck_screen.dart     # Individual deck (/decks/:deckId)
│   ├── pop_study/
│   │   ├── pop_models.dart      # CardState enum + CardModel
│   │   ├── pop_repository.dart  # In-memory DeckRepository + Riverpod provider
│   │   ├── pop_counts.dart      # Count helpers + session queue builder
│   │   ├── pop_study_controller.dart  # Session state notifier (Again/Good)
│   │   ├── pop_study_screen.dart      # Pop Study UI
│   │   └── pop_monitoring_provider.dart # User activity monitoring + popup trigger
│   ├── review/
│   │   └── review_screen.dart   # Manual review (stub)
│   ├── settings/
│   │   ├── settings_providers.dart    # newLimitProvider (StateProvider<int>)
│   │   └── settings_screen.dart       # Settings UI (+/- for newLimit)
│   └── stats/
│       └── stats_screen.dart    # Stats overview (stub)
├── core/
│   ├── scheduler/               # Spaced-repetition logic (TODO – issue #2)
│   └── monitoring/              # Analytics / crash reporting (TODO)
└── data/
    └── local/                   # Drift local DB (TODO – issue #2)
```

## Getting started

```bash
flutter pub get
flutter run
```
