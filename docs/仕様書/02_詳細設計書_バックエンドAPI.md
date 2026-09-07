# 詳細設計書 バックエンドAPI（src/oracle_app）

## 1. 文書情報

| 項目 | 内容 |
|---|---|
| 文書名 | 詳細設計書 バックエンドAPI |
| 版数 | Ver.1.0 |
| 作成日 | 2026-07-02 |
| 対象 | `src/oracle_app/` 配下の全モジュール |
| 実行基盤 | Python 3.11 / FastAPI 0.2.0（アプリタイトル "Oracle Reading App API"） |

## 2. レイヤー構成と責務

```text
api.py           … HTTPエンドポイント。入力検証（Pydantic）→サービス呼び出し→レスポンス整形のみ
services/*.py    … 業務ロジック（占い・課金・認証・通知・分析・管理・問合せ・外部導線・コンテンツ）
orchestrator.py  … DIコンテナ（ServiceContainer）の組立。永続化バックエンド選定もここで行う
store.py         … InMemoryStore（既定の全ドメインデータ保持）
persistence/*.py … HybridStore／PostgresPersistence／RedisCache（永続化拡張）
models.py        … ドメインdataclass（DBスキーマとAPIの中間表現）
schemas.py       … Pydantic リクエスト/レスポンスDTO（`ConfigDict(extra="forbid")`で未知フィールド拒否）
config.py        … AppConfig（環境変数駆動の設定。ハードコード排除の単一基点）
time_utils.py    … JST（Asia/Tokyo）時刻の一元管理
logging_utils.py … 日本語ログの共通設定
```

責務の流れは常に `api.py → services/*.py → store.py（またはHybridStore経由でpersistence/*.py）` の一方向で、API層が直接`store`やDBへアクセスすることはない。

## 3. 設定（config.py: AppConfig）

| フィールド | 既定値 | 説明 |
|---|---|---|
| `runtime_mode` | `local`（env `ORACLE_RUNTIME_MODE`） | `local`/`staging`/`production`。後２者はInMemory禁止・自動フォールバック禁止 |
| `free_daily_draw_limit` | `1` | 無料ユーザーの1日あたり最大セッション数 |
| `default_theme_ids` | 9件（恋愛/仕事/お金/健康/人間関係/魂/覚醒/カルマ/前世） | `ThemeService`初期シード |
| `default_deck_ids` | 3件（`japanese_mythology`/`ryujin`/`blythe`） | デッキ初期シード |
| `card_counts_by_deck` | 日本神話64・龍神32・ブライス32 | デッキ別カード枚数（マスタ管理、固定値ハードコードなし） |
| `shuffle`（ShuffleRules） | `idle_seconds_min=1.0`/`idle_seconds_max=2.0`/`min_swipe_distance=120.0` | シャッフル終了判定の閾値 |
| `history`（HistoryRules） | `free_visible_limit=3` | 無料ユーザーの履歴表示上限 |
| `pricing`（PricingCatalog） | チケット4種＋サブスク月額500円商品・トライアル7日 | 商品カタログ |
| `links`（ExternalLinkCatalog） | ショップ3件・鑑定2件・ライブ2件（現状ダミーURL） | 外部導線カタログ |
| `notifications`（NotificationRules） | カテゴリ10種 | 通知カテゴリ（詳細仕様書12章と一致） |
| `analytics`（AnalyticsRules） | 必須イベント16種 | KPI集計対象イベント名一覧 |
| `admin`（AdminBootstrapConfig） | 既定管理者 `admin@example.com` / role `super_admin` | 初回起動時のブートストラップ管理者 |
| `persistence_backend` | `inmemory`（env `ORACLE_PERSISTENCE_BACKEND`） | `inmemory`/`postgres`/`redis`/`hybrid` |
| `postgres`（PostgresConfig） | `enabled=False`、DSN既定`postgresql+psycopg://oracle:oracle@localhost:5432/oracle_app` | env: `ORACLE_POSTGRES_ENABLED`/`ORACLE_POSTGRES_DSN`/`ORACLE_POSTGRES_ECHO` |
| `redis`（RedisConfig） | `enabled=False`、URL既定`redis://localhost:6379/0`、prefix`oracle:`、TTL 600秒 | env: `ORACLE_REDIS_ENABLED`/`ORACLE_REDIS_URL`/`ORACLE_REDIS_PREFIX`/`ORACLE_REDIS_TTL_SECONDS` |

## 4. ドメインモデル（models.py）

### 4.1 Enum

| Enum | 値 |
|---|---|
| `PlanType` | guest / free / ticket / subscription / admin |
| `SessionStatus` | started / shuffled / pile_selected / card_opened / completed |
| `AuthProvider` | email / apple / google |
| `CampaignStatus` | scheduled / dispatched / canceled |
| `CampaignChannel` | push |

### 4.2 主要dataclass（全て`@dataclass(slots=True)`）

| モデル | 主フィールド |
|---|---|
| `User` | user_id, plan, tickets, subscription_expires_at, created_at, updated_at, visit_count |
| `Profile` | user_id, display_name, locale（既定`ja-JP`）, created_at, updated_at |
| `AuthAccount` | auth_account_id, user_id, provider, provider_user_id, email, created_at |
| `Theme` | theme_id, name_ja, is_visible |
| `Deck` | deck_id, name_ja, is_published, sort_order |
| `Card` | card_id, deck_id, name_ja, keywords, default_meaning, meanings_by_theme |
| `ReadingSession` | session_id, user_id, theme_id, deck_id, draw_count, started_at, status, shuffled_at, chosen_pile, selected_card_id, precomputed_card_ids, piles |
| `ReadingResult` | session_id, user_id, theme_id, deck_id, card_id, card_name, keywords, interpretation_text, caution_text, created_at, copied |
| `HistoryItem` | history_id, user_id, session_id, created_at, theme_id, deck_id, card_id, summary, full_text, plan_at_creation |
| `Announcement` | announcement_id, title, body, category, start_at, end_at, is_important, link_url |
| `PushCampaign` | campaign_id, title, body, category, channel, target_segment, scheduled_at, created_at, status, is_ab_test |
| `NotificationSetting` | user_id, push_enabled, reminder_enabled, campaign_enabled, updated_at |
| `Product` | product_code, title, plan_type, price_jpy, ticket_amount, is_subscription, is_active |
| `ExternalLink` | link_id, category, title, url, is_active |
| `LiveEvent` | live_event_id, title, start_at, archive_url, is_public |
| `AdminRole` | role_id, name, permissions |
| `AdminUser` | admin_user_id, email, password, role_id, is_active, created_at |
| `AdminSession` | token, admin_user_id, issued_at, expires_at |
| `AnalyticsEvent` | event_id, event_name, user_id, occurred_at, properties |
| `Inquiry` | inquiry_id, user_id, category, body, email, created_at |
| `PurchaseResult` | accepted, user_id, plan, tickets, message |
| `AuditLog` | audit_id, actor_type, actor_id, action, resource_type, resource_id, detail, occurred_at |

## 5. サービス層（services/）

| サービス | 責務 | 主要メソッド |
|---|---|---|
| `AuthService` | ログイン/ログアウト/外部認証 | `login_by_user_id`, `logout_by_user_id`, `login_with_provider(provider, provider_user_id, email)` |
| `ContentService` | テーマ・デッキ・カード・お知らせ・商品のマスタ参照 | `list_themes`, `list_decks`, `list_cards(deck_id, query)`, `list_announcements`, `list_products` |
| `BillingService` | 課金判定・消費・検証・復元 | `is_paid_user`, `can_use_draw_count`, `consume_for_session`, `verify_purchase`, `restore_purchase`, `_refresh_subscription_status`（期限切れ時に自動でfreeへ降格） |
| `ReadingService` | 占いセッションの状態遷移全体 | `start_session`, `complete_shuffle`, `select_pile`, `select_card`, `get_result`, `mark_copied`, `save_history`, `list_history` |
| `NotificationService` | 通知トークン登録・許諾誘導判定 | `register_device_token`, `should_prompt_permission` |
| `InquiryService` | 問合せ受付 | `submit(user_id, category, body, email)` |
| `AnalyticsService` | イベント記録・KPI集計 | `track_event`, `get_kpi_snapshot` |
| `LinkService` | 外部導線一覧（ショップ/鑑定/ライブ） | `list_shop_links`, `list_consultation_links`, `list_live_links`, `list_live_events` |
| `AdminService` | 管理者認証・ダッシュボード・お知らせ/キャンペーン管理 | `login`, `require_admin`, `get_dashboard`, `create_announcement`, `create_push_campaign`, `dispatch_push_campaign`, `list_push_campaigns` |

### 5.1 占いフローの状態遷移（ReadingService）

```text
start_session（無料枠/課金枚数チェック）
   → status=started, precomputed_card_ids確定（結果は開始時点で内部確定。演出とロジックを分離）
complete_shuffle（idle_seconds/finger_released/swipe_distanceの3条件判定）
   → status=shuffled, 3山へラウンドロビン分割（_split_three_piles）
select_pile（pile_index 1-3）
   → status=pile_selected
select_card（card_index）
   → status=completed, ReadingResult確定（テーマ別解釈=meanings_by_theme優先、無ければdefault_meaning）
```

シャッフル終了判定は詳細仕様書9.6のとおり `idle_seconds`（1.0〜2.0秒範囲内）・`finger_released`・`min_swipe_distance`(120.0)超過の組合せで判定する（`ShuffleRules`で設定化、ハードコードなし）。

### 5.2 課金判定（BillingService）

- 無料ユーザー: `draw_count`は1のみ許可（`can_use_draw_count`）。
- チケットプラン: セッション開始時に`draw_count`分のチケットを消費。
- サブスクプラン: `subscription_expires_at`を毎回`_refresh_subscription_status`で確認し、期限切れなら`PlanType.FREE`へ自動降格。
- `verify_purchase`/`restore_purchase`は`receipt_id`の重複登録を`_used_receipts`セットで防止し、冪等性を担保。

## 6. DI構成（orchestrator.py）

`build_service_container(config)` が `AppConfig` → ストア選定 → 9サービスの生成 → `ServiceContainer` dataclass への集約、の順で実行される。ストア選定ロジック（`_build_store`）:

1. `runtime_mode`が`staging`/`production`かつ`persistence_backend=inmemory`の場合は起動時に`RuntimeError`（ガード）。
2. Postgres/Redisどちらも要求されなければ`InMemoryStore`。
3. いずれか要求される場合、`PostgresPersistence.initialize_schema()`＋`check_connection()`、`RedisCache.check_connection()`を実施し`HybridStore`を返す。
4. 初期化中に例外が発生した場合、`local`モードのみ`InMemoryStore`へフォールバック。`staging`/`production`では再送出（フォールバック禁止）。

## 7. 永続化層（persistence/）

| モジュール | 役割 |
|---|---|
| `postgres.py`（PostgresPersistence） | SQLAlchemy経由でusers/announcements/inquiries/audit_logs/reading_results/reading_historyをupsert/fetch。`initialize_schema()`でテーブル作成、`check_connection()`で疎通確認 |
| `redis_cache.py`（RedisCache） | 結果・履歴・お知らせ・問合せの短期キャッシュ（JSON文字列としてget/set、TTL付き） |
| `hybrid_store.py`（HybridStore） | `InMemoryStore`を継承し、書込はPostgres優先＋Redis無効化、読込はRedis→Postgres→InMemoryの順にフォールバックする多層キャッシュパターン |

HybridStoreの各メソッドは、Postgres/Redis呼び出し失敗時に例外を握りつぶしInMemory側の結果を返す設計（段階導入中の可用性優先方針）。この挙動は`staging`/`production`でも初期化時のガードのみが効き、稼働後の個別呼び出し失敗は握りつぶされる点に留意（詳細は`11_今後の開発ロードマップ.md`の残課題参照）。

## 8. 監査ログ・ヘルスチェック

- `_audit_action()`（api.py内共通関数）が認証・課金・管理操作を`store.add_audit_log()`に記録。記録失敗時はログ警告のみでAPI応答は継続。
- `GET /health`: 単純な生存確認（メッセージのみ）。
- `GET /health/ready`: `postgres`/`redis`の疎通状態を`ok`/`degraded`/`skipped`で返す詳細ヘルス（`_build_health_components`）。監視ツールからの死活監視に使用する想定。

## 9. CI/CD（.github/workflows/backend-ci.yml）

push/PR契機で以下を自動実行:

1. PostgreSQL 16・Redis 7 のサービスコンテナ起動
2. Python 3.11環境構築＋`requirements.txt`インストール
3. `pytest -q`（PYTHONPATH=src）
4. `scripts/smoke_test.py`
5. `ORACLE_PERSISTENCE_BACKEND=hybrid`＋Postgres/Redis有効化での`scripts/init_persistence.py`

## 10. ログ・時刻の統一方針

- `time_utils.now_jst()`: すべての時刻生成はJST（Asia/Tokyo）で統一。Windows環境のtzdata欠如を考慧しフォールバック処理あり。
- `logging_utils.get_logger(name)`: フォーマット統一（`%(asctime)s %(levelname)s [%(name)s] %(message)s`）。ログメッセージは日本語で統一する方針（README.md記載の実装方針）。
