# PopTest

スマホをだらだら見てるときに単語帳形式の問題を出すアプリ。

---

## ディレクトリ構成（feature-first）

```
lib/
├── main.dart           # エントリポイント
├── app.dart            # MaterialApp.router + ProviderScope
├── routing/
│   └── router.dart     # go_router 設定
├── features/
│   ├── home/           # ホーム画面
│   ├── settings/       # 設定画面
│   ├── deck/           # デッキ管理画面
│   └── review/         # レビュー（問題）画面
├── core/
│   ├── scheduler/      # 間隔反復スケジューラ（SM-2 等）
│   └── monitoring/     # クラッシュレポート・アナリティクス
└── data/
    └── local/          # Drift ローカル DB
```

---

## 依存関係ポリシー

| カテゴリ       | パッケージ                | 用途                              |
|--------------|--------------------------|-----------------------------------|
| 状態管理       | `flutter_riverpod`       | グローバル・ローカル状態管理         |
| ナビゲーション  | `go_router`              | 宣言的ルーティング                  |
| ローカルDB     | `drift` + `sqlite3_flutter_libs` | 構造化データの永続化       |

> **方針**: 新しいパッケージを追加する前に Issue でレビューを行う。  
> サードパーティへの依存は上記 3 本柱を基本とし、極力増やさない。

---

## セットアップ

```bash
flutter pub get
flutter run
```

---

## 関連 Issue

- [#5 Flutterプロジェクト初期構成（feature-first）を作成](https://github.com/HASEEEEEEEEEEEEE/PopTest/issues/5)
