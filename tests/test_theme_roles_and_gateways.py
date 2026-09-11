from __future__ import annotations

from datetime import timedelta
from uuid import uuid4

import pytest

from oracle_app.config import AppConfig
from oracle_app.models import AdminUser
from oracle_app.orchestrator import _build_receipt_verifier
from oracle_app.time_utils import now_jst


def _admin_token(client, email: str = "admin@example.com", password: str = "ChangeMe123!") -> str:
    login = client.post("/admin/login", json={"email": email, "password": password})
    assert login.status_code == 200
    return login.json()["token"]


def _run_flow_to_result(client, user_id: str) -> dict:
    start = client.post(
        "/reading/start",
        json={
            "user_id": user_id,
            "theme_id": "love",
            "deck_id": "japanese_mythology",
            "draw_count": 1,
        },
    )
    assert start.status_code == 200
    session_id = start.json()["session_id"]

    shuffle = client.post(
        "/reading/complete-shuffle",
        json={
            "session_id": session_id,
            "idle_seconds": 1.5,
            "finger_released": True,
            "swipe_distance": 180.0,
        },
    )
    assert shuffle.status_code == 200

    pile = client.post(
        "/reading/select-pile",
        json={"session_id": session_id, "pile_index": 1},
    )
    assert pile.status_code == 200

    card = client.post(
        "/reading/select-card",
        json={"session_id": session_id, "card_index": 1},
    )
    assert card.status_code == 200
    return card.json()


def test_themes_return_six_axes_in_approved_order(client):
    response = client.get("/themes")
    assert response.status_code == 200
    themes = response.json()

    assert [theme["theme_id"] for theme in themes] == [
        "subconscious",
        "higher_self",
        "love",
        "money",
        "work",
        "health",
    ]
    assert [theme["name_ja"] for theme in themes] == [
        "潜在意識",
        "ハイヤーセルフ",
        "恋愛",
        "金運",
        "仕事",
        "健康",
    ]
    assert [theme["name_en"] for theme in themes] == [
        "Subconscious",
        "Higher Self",
        "Love",
        "Wealth",
        "Work",
        "Health",
    ]
    assert [theme["name_zh"] for theme in themes] == [
        "潜意识",
        "高我",
        "爱情",
        "财运",
        "事业",
        "健康",
    ]


def test_legacy_theme_rejected_for_new_reading(client):
    start = client.post(
        "/reading/start",
        json={
            "user_id": f"legacy_{uuid4().hex}",
            "theme_id": "karma",
            "deck_id": "japanese_mythology",
            "draw_count": 1,
        },
    )
    assert start.status_code == 400


def test_admin_themes_include_hidden_legacy(client):
    token = _admin_token(client)
    response = client.get("/admin/themes", headers={"X-Admin-Token": token})
    assert response.status_code == 200
    themes = {theme["theme_id"]: theme for theme in response.json()}

    assert len(themes) == 11
    for visible_id in ["subconscious", "higher_self", "love", "money", "work", "health"]:
        assert themes[visible_id]["is_visible"] is True
    for hidden_id in ["relationships", "soul", "awakening", "karma", "past_life"]:
        assert themes[hidden_id]["is_visible"] is False


def test_reading_result_response_key_set_fixed(client):
    result = _run_flow_to_result(client, user_id=f"contract_{uuid4().hex}")

    # オラクルカードは正位置のみ。is_reversed等の向きフィールドが
    # 誤って追加された場合にこのテストで検知する（2026-08-31承認）。
    # 多言語フィールド（en/zh）は2026-09-01の多言語化ラウンドで追加された正規キー。
    assert set(result.keys()) == {
        "session_id",
        "user_id",
        "theme_id",
        "deck_id",
        "card_id",
        "card_name",
        "keywords",
        "interpretation_text",
        "caution_text",
        "created_at",
        "copied",
        "card_name_en",
        "keywords_en",
        "interpretation_text_en",
        "caution_text_en",
        "card_name_zh",
        "keywords_zh",
        "interpretation_text_zh",
        "caution_text_zh",
        "combination_text",
        # 2026-09-10 承認のリーディング拡張（スプレッド・相談内容・複数枚）
        "spread_id",
        "question_text",
        "cards",
        # 2026-09-11 深掘りリーディング（託宣を起点にした場合の元セッション）
        "origin_session_id",
    }
    assert result["interpretation_text_en"]
    assert result["interpretation_text_zh"]


def test_login_returns_subscription_expires_at(app, client):
    user_id = f"expiry_{uuid4().hex}"
    verify = client.post(
        "/purchase/verify",
        json={
            "user_id": user_id,
            "product_code": "subscription_monthly_500",
            "receipt_id": f"r_{uuid4().hex}",
        },
    )
    assert verify.status_code == 200

    login = client.post("/auth/login", json={"user_id": user_id})
    assert login.status_code == 200
    body = login.json()
    assert body["plan"] == "subscription"
    assert body["subscription_expires_at"] is not None


def test_login_downgrades_expired_subscription(app, client):
    user_id = f"expired_{uuid4().hex}"
    verify = client.post(
        "/purchase/verify",
        json={
            "user_id": user_id,
            "product_code": "subscription_monthly_500",
            "receipt_id": f"r_{uuid4().hex}",
        },
    )
    assert verify.status_code == 200

    store = app.state.container.store
    user = store.get_or_create_user(user_id)
    user.subscription_expires_at = now_jst() - timedelta(days=1)
    store.update_user(user)

    login = client.post("/auth/login", json={"user_id": user_id})
    assert login.status_code == 200
    body = login.json()
    assert body["plan"] == "free"
    assert body["subscription_expires_at"] is None


def test_inquiry_category_validation(client):
    user_id = f"inq_{uuid4().hex}"

    accepted = client.post(
        "/inquiries",
        json={"user_id": user_id, "category": "general", "body": "テスト問い合わせです。"},
    )
    assert accepted.status_code == 200

    rejected = client.post(
        "/inquiries",
        json={"user_id": user_id, "category": "spam", "body": "不正カテゴリです。"},
    )
    assert rejected.status_code == 400
    assert "問い合わせカテゴリが不正です" in rejected.json()["detail"]


def test_admin_role_permission_enforced(app, client):
    store = app.state.container.store
    # 権限制御テスト用に閲覧専用ロールの管理者を直接投入する
    # （管理者アカウント作成APIは未実装のため、テストからストアへ直接登録する）
    store._admin_users["admin_analyst"] = AdminUser(
        admin_user_id="admin_analyst",
        email="analyst@example.com",
        password="AnalystPass123!",
        role_id="analyst",
        is_active=True,
    )

    token = _admin_token(client, email="analyst@example.com", password="AnalystPass123!")
    headers = {"X-Admin-Token": token}

    dashboard = client.get("/admin/dashboard", headers=headers)
    assert dashboard.status_code == 200

    now = now_jst()
    create_announcement = client.post(
        "/admin/announcements",
        headers=headers,
        json={
            "title": "権限外テスト",
            "body": "analystには作成権限がありません。",
            "category": "重要なお知らせ",
            "start_at": now.isoformat(),
            "end_at": (now + timedelta(days=1)).isoformat(),
        },
    )
    assert create_announcement.status_code == 403

    audit_logs = client.get("/admin/audit-logs", headers=headers)
    assert audit_logs.status_code == 403

    super_token = _admin_token(client)
    super_audit = client.get("/admin/audit-logs", headers={"X-Admin-Token": super_token})
    assert super_audit.status_code == 200


def test_receipt_verifier_local_rejected_in_production(monkeypatch):
    monkeypatch.setenv("ORACLE_RUNTIME_MODE", "production")
    monkeypatch.delenv("ORACLE_RECEIPT_VERIFICATION_MODE", raising=False)
    config = AppConfig()

    with pytest.raises(RuntimeError):
        _build_receipt_verifier(config)


def test_receipt_verifier_store_api_requires_credentials(monkeypatch):
    monkeypatch.setenv("ORACLE_RECEIPT_VERIFICATION_MODE", "store_api")
    monkeypatch.delenv("ORACLE_APPLE_ISSUER_ID", raising=False)
    monkeypatch.delenv("ORACLE_APPLE_KEY_ID", raising=False)
    monkeypatch.delenv("ORACLE_APPLE_PRIVATE_KEY", raising=False)
    config = AppConfig()

    with pytest.raises(ValueError):
        _build_receipt_verifier(config)


def test_dispatch_campaign_noop_reports_no_delivery(client):
    token = _admin_token(client)
    headers = {"X-Admin-Token": token}

    created = client.post(
        "/admin/campaigns",
        headers=headers,
        json={
            "title": "noop配信テスト",
            "body": "実配信は行われないことを確認します。",
            "category": "キャンペーン通知",
            "scheduled_at": now_jst().isoformat(),
        },
    )
    assert created.status_code == 200
    campaign_id = created.json()["campaign_id"]

    dispatched = client.post(
        f"/admin/campaigns/{campaign_id}/dispatch",
        headers=headers,
    )
    assert dispatched.status_code == 200
    body = dispatched.json()
    assert body["status"] == "dispatched"
    assert body["dispatch_result"] is not None
    assert "実配信モード未設定" in body["dispatch_result"]
