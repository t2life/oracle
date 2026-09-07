# オラクルリーディングアプリ バックエンド

このワークスペースは Python + FastAPI で実装したオラクルリーディングアプリのAPI基盤です。

## 前提

- 仮想環境: .venv
- 推奨起動ファイル: オラクルアプリ.code-workspace

## ディレクトリ

- src/oracle_app: アプリ本体
- tests: テストコード
- scripts: 実行補助スクリプト
- docs: 仕様書と作業ドキュメント

## セットアップ

1. 仮想環境を有効化
2. 依存関係をインストール

インストール済みパッケージ:

- fastapi
- uvicorn
- pytest
- httpx

## 実行

- 開発サーバー: scripts/run_dev_server.py
- スモークテスト: scripts/smoke_test.py
- テスト実行: pytest

## 実装方針

- 仕様書に沿った責務分離（設定、ストア、サービス、API）
- 抽選ロジックと演出判定ロジックの分離
- JST時刻処理の統一
- 日本語ログ出力
