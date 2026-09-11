# オラクルリーディングアプリ システム実装

このワークスペースは、仕様書に基づく以下3層のシステムファイルを含みます。

- バックエンドAPI: Python + FastAPI
- モバイルアプリ層: Flutter構成（`mobile_app`）
- 管理画面層: Next.js構成（`admin_app`）

## 前提

- OS: Windows
- Python仮想環境: `.venv`
- 推奨起動ファイル: `オラクルアプリ.code-workspace`

## ディレクトリ

- `src/oracle_app`: バックエンド本体（config/models/store/services/api）
- `tests`: バックエンドテスト
- `scripts`: 開発補助スクリプト
- `mobile_app`: Flutterモバイル層（U-01〜U-19対応骨格）
- `admin_app`: Next.js管理画面層（A-01〜A-08対応骨格）
- `docs`: 仕様書と作業ドキュメント

## バックエンドセットアップ

1. 仮想環境を有効化
2. 依存関係をインストール（`requirements.txt`）
3. APIを起動

主な実行コマンド（**仮想環境を有効化した状態**で実行する。
Windows は `.venv\Scripts\Activate.ps1`、macOS は `source .venv/bin/activate`）:

- 開発サーバー: `python scripts/run_dev_server.py`
- スモークテスト: `python scripts/smoke_test.py`
- テスト実行: `python -m pytest -q`

### PostgreSQL / Redis 段階導入

既定はInMemory実装ですが、以下の環境変数で段階的に永続化を有効化できます。

- `ORACLE_PERSISTENCE_BACKEND` (`inmemory` / `postgres` / `redis` / `hybrid`)
- `ORACLE_RUNTIME_MODE` (`local` / `staging` / `production`)
- `ORACLE_POSTGRES_ENABLED` (`true`/`false`)
- `ORACLE_POSTGRES_DSN` (例: `postgresql+psycopg://oracle:oracle@localhost:5432/oracle_app`)
- `ORACLE_REDIS_ENABLED` (`true`/`false`)
- `ORACLE_REDIS_URL` (例: `redis://localhost:6379/0`)
- `ORACLE_REDIS_PREFIX` (既定: `oracle:`)
- `ORACLE_REDIS_TTL_SECONDS` (既定: `600`)

初期接続・スキーマ作成確認:

- `python scripts/init_persistence.py`
- `python scripts/run_migration.py up`
- ロールバック: `python scripts/run_migration.py down`

接続失敗時は自動的にInMemoryへフォールバックします。
ただし `ORACLE_RUNTIME_MODE=staging|production` の場合はフォールバックせず起動失敗とします。

監視向けエンドポイント:

- `GET /health`（簡易ヘルス）
- `GET /health/ready`（PostgreSQL/Redis依存状態を含む詳細ヘルス）

## モバイルアプリ（Flutter）

- ディレクトリ: `mobile_app`
- 主要ファイル: `lib/core/routing/app_router.dart`, `lib/core/network/api_client.dart`, `lib/core/state/app_state.dart`
- 画面ID対応: READMEにU-01〜U-19の対応表を記載

実行例:

- `flutter pub get`
- `flutter run`

## 管理画面（Next.js）

- ディレクトリ: `admin_app`
- 主要ファイル: `lib/api.ts`, `components/nav-shell.tsx`, `app/*`
- 画面ID対応: READMEにA-01〜A-08の対応表を記載

実行例:

- `npm install`
- `npm run dev`

環境変数（任意）:

- `NEXT_PUBLIC_API_BASE_URL`（既定: `http://127.0.0.1:8000`）

## 実装方針

- 仕様書準拠の責務分離（設定、ストア、サービス、API）
- 既存占いフロー互換を維持しつつAPIを拡張
- 認証、課金復元、管理、通知運用、分析、外部導線を追加
- JST時刻処理を統一（Windows tzdata不足時はフォールバック）
