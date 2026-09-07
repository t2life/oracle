# API仕様書（バックエンド全エンドポイント）

## 1. 文書情報

| 項目 | 内容 |
|---|---|
| 文書名 | API仕様書 |
| 版数 | Ver.1.1（2026-08-31 機能ギャップ回答反映ラウンドで更新） |
| 作成日 | 2026-07-02 |
| 対象ファイル | `src/oracle_app/api.py`（`create_app()`） |
| ベースURL（開発） | `http://127.0.0.1:8000` |
| フォーマット | 全リクエスト/レスポンスJSON。Pydanticモデルは`extra="forbid"`（未知フィールド拒否） |
| エラー形式 | `ValueError`→400、`PermissionError`→403、その他→500（`{"detail": "内部エラーが発生しました。"}`） |

## 2. ヘルスチェック

| メソッド | パス | 認証 | 説明 |
|---|---|---|---|
| GET | `/health` | 不要 | 単純な生存確認。`MessageResponse{message}` |
| GET | `/health/ready` | 不要 | 詳細ヘルス。`HealthReadyResponse{overall_status, checked_at, components}`。`components`はpostgres/redisそれぞれ`ok`/`degraded`/`skipped` |

## 3. 認証

| メソッド | パス | リクエスト | レスポンス |
|---|---|---|---|
| POST | `/auth/login` | `AuthLoginRequest{user_id}` | `UserResponse{user_id, plan, tickets, visit_count, subscription_expires_at?}` |
| POST | `/auth/apple` | `AuthProviderRequest{provider_user_id, email?}` | `UserResponse` |
| POST | `/auth/google` | `AuthProviderRequest{provider_user_id, email?}` | `UserResponse` |
| POST | `/auth/logout` | `AuthLogoutRequest{user_id}` | `MessageResponse` |

`/auth/login`は`app_open`分析イベントと`auth.login`監査ログを記録。`/auth/apple`・`/auth/google`はそれぞれ`auth.login.apple`/`auth.login.google`監査ログを記録し、`provider_user_id`をキーに既存アカウントを検索、無ければ新規作成する。

補足（2026-08-31更新）:

- `subscription_expires_at`はJSTのISO8601。サブスク未加入・期限切れ後は`null`。
- 認証3エンドポイントは応答前にサブスク期限を都度評価し、期限切れなら`plan`を`free`へ降格してから返す（`BillingService.refresh_subscription_status`経由。期限切れ特権残留の防止）。
- `provider_user_id`の定義: Appleは Sign in with Apple のIDトークン`sub`（ユーザー識別子）、Googleは Google Sign-In のIDトークン`sub`を渡す。最大256文字。
- レスポンスへのフィールド追加は後方互換だが、**フィールド削除は破壊的変更**（モバイルは明示キー参照）。削除時はモバイル改修と同時リリースが必要。

## 4. コンテンツ（マスタ参照）

| メソッド | パス | クエリ | レスポンス |
|---|---|---|---|
| GET | `/themes` | なし | `list[ThemeResponse{theme_id, name_ja}]`（`is_visible=true`のみ） |

`/themes`はプロダクトオーナー確定の6軸を表示順で返す（2026-08-31承認）:
`subconscious`（潜在意識）→`higher_self`（ハイヤーセルフ）→`love`（恋愛）→`money`（金運）→`work`（仕事）→`health`（健康）。
企画書時代の旧5テーマ（relationships/soul/awakening/karma/past_life）は履歴参照整合のため
`is_visible=false`で温存され、`/reading/start`では400で拒否される。

| メソッド | パス | クエリ | レスポンス |
|---|---|---|---|
| GET | `/decks` | なし | `list[DeckResponse{deck_id, name_ja, sort_order}]`（`is_published=true`のみ） |
| GET | `/cards` | `deck_id?`, `q?` | `list[CardResponse{card_id, deck_id, name_ja, keywords}]`。`q`はカード名・キーワードの部分一致検索 |
| GET | `/products` | なし | `list[ProductResponse{product_code, title, plan_type, price_jpy, ticket_amount, is_subscription}]` |
| GET | `/announcements` | なし | `list[AnnouncementResponse{announcement_id, title, body, category, start_at, end_at, is_important, link_url}]`（公開期間内のもの） |

## 5. 占いフロー

| メソッド | パス | リクエスト | レスポンス | 備考 |
|---|---|---|---|---|
| POST | `/reading/start` | `StartReadingRequest{user_id, theme_id, deck_id, draw_count=1(1-3)}` | `StartReadingResponse{session_id, status, started_at, draw_count}` | 無料枠・課金枚数チェック。`theme_selected`・`shuffle_started`イベント記録 |
| POST | `/reading/complete-shuffle` | `CompleteShuffleRequest{session_id, idle_seconds(>=0), finger_released, swipe_distance(>=0)}` | `PileStatusResponse{session_id, status, pile_sizes}` | シャッフル終了判定→3山分割 |
| POST | `/reading/select-pile` | `SelectPileRequest{session_id, pile_index(1-3)}` | `PileStatusResponse` | `pile_selected`イベント記録 |
| POST | `/reading/select-card` | `SelectCardRequest{session_id, card_index(>=1)}` | `ReadingResultResponse{session_id, user_id, theme_id, deck_id, card_id, card_name, keywords, interpretation_text, caution_text, created_at, copied}` | `card_selected`・`reading_completed`イベント記録 |
| GET | `/reading/{session_id}` | パス変数`session_id` | `ReadingResultResponse` | 結果取得 |
| POST | `/reading/{session_id}/copy` | パス変数`session_id` | `ReadingResultResponse`（`copied=true`） | `result_copied`イベント記録 |
| POST | `/reading/{session_id}/save-history` | `SaveHistoryRequest{user_id}` | `MessageResponse` | 履歴保存（無料は直近3件のみ保持） |

占いフローの確定仕様（2026-08-31更新・曖昧項目の精緻化）:

- **正位置のみ原則**: オラクルカードに逆位置は存在せず、全カードは正位置として解釈する
  （プロダクトオーナー確定事項）。`ReadingResultResponse`に`is_reversed`等の向きフィールドは
  仕様として存在しない。レスポンスのキー集合は
  `tests/test_theme_roles_and_gateways.py::test_reading_result_response_key_set_fixed`で固定検証される。
- **無料プランの「1日1回」の定義**: JST（Asia/Tokyo）の暦日単位。`time_utils.date_key_jst`が
  基準で、JST 00:00にリセットされる（ローリング24時間ではない）。
- **シャッフル終了判定（公開仕様）**: 次の3条件のANDで成立する。いずれか欠けると400。
  `idle_seconds`が1.0〜2.0秒（`ShuffleRules.idle_seconds_min/max`）、かつ
  `finger_released=true`、かつ`swipe_distance>=120.0`（`ShuffleRules.min_swipe_distance`）。
  抽選はセッション開始時に確定済みで、シャッフル演出は抽選結果に影響しない。

## 6. 履歴

| メソッド | パス | クエリ | レスポンス |
|---|---|---|---|
| GET | `/history` | `user_id`（必須） | `list[HistoryItemResponse{history_id, session_id, created_at, theme_id, deck_id, card_id, summary, full_text, plan_at_creation}]`。`history_viewed`イベント記録 |

## 7. 課金

| メソッド | パス | リクエスト | レスポンス |
|---|---|---|---|
| POST | `/purchase/verify` | `PurchaseVerifyRequest{user_id, product_code, receipt_id}` | `PurchaseVerifyResponse{accepted, user_id, plan, tickets, message}` |
| POST | `/purchase/restore` | `PurchaseRestoreRequest{user_id, product_code, restore_receipt_id}` | `PurchaseVerifyResponse` |

いずれも`billing.purchase_verify`/`billing.purchase_restore`監査ログを記録し、商品コードがサブスク商品なら`subscription_started`、それ以外は`ticket_purchased`イベントを記録する。`receipt_id`は`_used_receipts`で二重処理を防止（冪等性担保）。

レシート検証モード（2026-08-31追加・`ORACLE_RECEIPT_VERIFICATION_MODE`）:

- `local`（既定）: 形式チェックのみ（現行互換）。**productionでは起動拒否**、stagingでは警告ログ。
- `store_api`: Apple App Store Server API / Google Play Developer API との照合モード。
  認証情報（`ORACLE_APPLE_ISSUER_ID`/`ORACLE_APPLE_KEY_ID`/`ORACLE_APPLE_PRIVATE_KEY`/
  `ORACLE_GOOGLE_PACKAGE_NAME`/`ORACLE_GOOGLE_SERVICE_ACCOUNT_JSON`）未設定時は起動時エラー。
  実HTTP接続はロードマップB-1/B-2の実装完了までfail-closed（検証失敗=400）で、未検証レシートを通さない。
- 検証は冪等チェックの**前段**で行われ、検証失敗時は400
  （`{"detail": "レシート検証に失敗しました: ..."}`）。

## 8. 通知・問合せ

| メソッド | パス | リクエスト | レスポンス |
|---|---|---|---|
| POST | `/notifications/token` | `NotificationTokenRequest{user_id, token(16-512文字)}` | `MessageResponse` |
| POST | `/inquiries` | `InquiryRequest{user_id, category, body, email?}` | `MessageResponse` |

`/inquiries`の`category`は次の列挙値のみ受理する（2026-08-31追加・`InquiryRules.categories`）:
`general`（一般）/`billing`（課金）/`bug`（不具合）/`request`（機能要望）/`other`（その他）。
非該当は400（`{"detail": "問い合わせカテゴリが不正です。許可値: ..."}`）。
日本語表示名はUI層（U-19ドロップダウン）の責務であり、APIは英字コードのみを扱う。

## 9. 外部導線

| メソッド | パス | レスポンス |
|---|---|---|
| GET | `/links/shop` | `list[ExternalLinkResponse{link_id, category, title, url}]` |
| GET | `/links/consultation` | `list[ExternalLinkResponse]` |
| GET | `/links/live` | `list[ExternalLinkResponse]` |
| GET | `/links/live-events` | `list[LiveEventResponse{live_event_id, title, start_at, archive_url}]` |

## 10. 分析

| メソッド | パス | リクエスト/クエリ | レスポンス |
|---|---|---|---|
| POST | `/analytics/events` | `AnalyticsEventRequest{event_name, user_id?, properties?}` | `AnalyticsEventResponse{event_id, event_name, user_id, occurred_at, properties}` |

## 11. 管理API（すべて`X-Admin-Token`ヘッダー必須。無い場合401、権限不足・不正トークンは403）

2026-08-31更新: ロール別アクセス制御を実装済み。トークン検証後、エンドポイントごとの必要権限を
`AdminRole.permissions`と照合し、不足時は403（`{"detail": "この操作を行う権限がありません。"}`）。

| メソッド | パス | 必要権限 | リクエスト | レスポンス |
|---|---|---|---|---|
| POST | `/admin/login` | 不要 | `AdminLoginRequest{email, password}` | `AdminLoginResponse{token, admin_user_id, role_id}` |
| GET | `/admin/dashboard` | `dashboard:view` | — | `AdminDashboardResponse{users_total, inquiries_total, announcements_total, campaigns_total, reading_completed, ticket_purchased, subscription_started, updated_at}` |
| GET | `/admin/users` | `users:view` | — | `list[UserSummaryResponse{user_id, plan, tickets, created_at}]` |
| GET | `/admin/inquiries` | `inquiries:view` | — | `list[InquiryResponse{inquiry_id, user_id, category, body, email, created_at}]` |
| GET | `/admin/announcements` | `announcements:manage` | — | `list[AnnouncementResponse]`（全件、公開期間外も含む） |
| POST | `/admin/announcements` | `announcements:manage` | `AnnouncementCreateRequest{title, body, category, start_at, end_at, is_important=false, link_url?}` | `AnnouncementResponse` |
| GET | `/admin/themes` | `themes:manage` | — | `list[ThemeAdminResponse{theme_id, name_ja, is_visible}]` |
| GET | `/admin/decks` | `decks:manage` | — | `list[DeckAdminResponse{deck_id, name_ja, sort_order, is_published}]` |
| GET | `/admin/admin-users` | `audit:view` | — | `list[AdminUserResponse{admin_user_id, email, role_id, is_active}]` |
| POST | `/admin/campaigns` | `notifications:manage` | `PushCampaignCreateRequest{title, body, category, target_segment="all", scheduled_at, is_ab_test=false}` | `PushCampaignResponse{campaign_id, title, body, category, target_segment, scheduled_at, created_at, status, is_ab_test, dispatch_result?}` |
| GET | `/admin/campaigns` | `notifications:manage` | — | `list[PushCampaignResponse]` |
| POST | `/admin/campaigns/{campaign_id}/dispatch` | `notifications:manage` | パス変数 | `PushCampaignResponse`（`status=dispatched`、`dispatch_result`に実配信結果） |
| GET | `/admin/audit-logs` | `audit:view` | `limit`（既定200, 1-1000） | `list[AuditLogResponse{audit_id, actor_type, actor_id, action, resource_type, resource_id, detail, occurred_at}]` |
| GET | `/admin/analytics/kpi` | `dashboard:view` | — | `KpiSnapshotResponse{values: dict[str,int]}` |

管理系のPOST操作（`admin.login`/`admin.announcement.create`/`admin.campaign.create`/`admin.campaign.dispatch`）はすべて監査ログに記録される。

### 11.1 ロール定義（詳細仕様書14.2章準拠・`store._seed_master_data`）

| role_id | 名称 | 権限 |
|---|---|---|
| `super_admin` | Super Admin | 全権限（dashboard:view, cards:manage, decks:manage, themes:manage, announcements:manage, notifications:manage, users:view, inquiries:view, audit:view） |
| `content_admin` | Content Admin | dashboard:view, cards:manage, decks:manage, themes:manage, announcements:manage, notifications:manage |
| `cs_support` | CS Support | dashboard:view, users:view, inquiries:view |
| `analyst` | Analyst | dashboard:view |

権限語彙の設計判断: KPI閲覧は既存`dashboard:view`を流用、通知キャンペーンは既存
`notifications:manage`を流用（新語彙の乱立防止）。監査ログと管理者一覧は機微情報のため
新設の`audit:view`（super_adminのみ）で括る。

### 11.2 通知配信仕様の補足

- `target_segment`は現行`all`のみサポート（セグメント別配信は将来拡張項目）。
- 実配信モード（`ORACLE_PUSH_DELIVERY_MODE`）: `noop`（既定）は実送信を行わず、
  `dispatch_result`とWARNINGログで「実配信モード未設定」を明示する（送ったつもり事故の防止）。
  `fcm`はFCM HTTP v1接続モードで、認証情報（`ORACLE_FCM_PROJECT_ID`/
  `ORACLE_FCM_SERVICE_ACCOUNT_JSON`）未設定時は起動時エラー。実HTTP接続は
  ロードマップB-3の実装完了までfail-closed（配信失敗=400・ステータスは`dispatched`へ遷移しない）。

## 12. エンドポイント総数

全32エンドポイント（ヘルス2・認証4・コンテンツ5・占い7・履歴1・課金2・通知/問合せ2・外部導線4・分析1・管理14の内訳をベースに、後方互換のため重複計上なく列挙。上記合計は11節分類上32件）。

## 13. 詳細仕様書18章との対応差分

| 詳細仕様書記載API | 現状 |
|---|---|
| POST /auth/login | 準拠（当初"簡易"実装との指摘は"user_id"のみの意図的な簡略設計。是正なし） |
| POST /auth/apple, /auth/google | 実装済み（是正済み。当初は未実装） |
| GET /themes, /decks | 準拠 |
| POST /reading/start〜GET /reading/{id} | 準拠 |
| GET /history | 準拠 |
| POST /purchase/verify | 準拠（サーバー内ロジックのみ。ストア公式レシート検証APIとの連携は未接続） |
| POST /notifications/token | 準拠（登録のみ。配信本体はAdmin側キャンペーンAPI） |
| GET /announcements | 準拠 |
| POST /inquiries | 準拠 |
| （仕様外の追加） | `/reading/complete-shuffle`, `/reading/{id}/copy`, `/reading/{id}/save-history`, `/health/ready`, `/auth/logout`, `/cards`, `/products`, `/purchase/restore`, `/links/*`, `/analytics/events`, `/admin/*` 全14種, `/admin/audit-logs` |
