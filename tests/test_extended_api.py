from __future__ import annotations

from datetime import timedelta
from uuid import uuid4

from oracle_app.time_utils import now_jst


def _admin_token(client) -> str:
    response = client.post(
        "/admin/login",
        json={"email": "admin@example.com", "password": "ChangeMe123!"},
    )
    assert response.status_code == 200
    return response.json()["token"]


def test_provider_login_and_catalog_endpoints(client):
    apple_provider_id = f"apple_{uuid4().hex}"

    first_login = client.post(
        "/auth/apple",
        json={"provider_user_id": apple_provider_id, "email": "apple_user@example.com"},
    )
    assert first_login.status_code == 200
    user_id = first_login.json()["user_id"]

    second_login = client.post(
        "/auth/apple",
        json={"provider_user_id": apple_provider_id, "email": "apple_user@example.com"},
    )
    assert second_login.status_code == 200
    assert second_login.json()["user_id"] == user_id
    assert second_login.json()["visit_count"] == 2

    google_login = client.post(
        "/auth/google",
        json={"provider_user_id": f"google_{uuid4().hex}", "email": "google_user@example.com"},
    )
    assert google_login.status_code == 200

    cards = client.get("/cards", params={"deck_id": "japanese_mythology"})
    assert cards.status_code == 200
    assert len(cards.json()) >= 1

    searched_cards = client.get("/cards", params={"q": "内省"})
    assert searched_cards.status_code == 200
    assert len(searched_cards.json()) >= 1

    products = client.get("/products")
    assert products.status_code == 200
    assert any(product["product_code"] == "ticket_20" for product in products.json())

    # 2026-09-10 承認: ショップは実URL3件。鑑定・ロンの部屋は公開先が未定のため0件
    # （空でも各画面は「現在表示できるリンクはありません」を出す）。
    shop_links = client.get("/links/shop")
    assert shop_links.status_code == 200
    assert [link["url"] for link in shop_links.json()] == [
        "https://senju888.stores.jp/",
        "https://www.instagram.com/hime_hukuoka/",
        "https://www.threads.com/@hime_hukuoka"
        "?xmt=AQG0Cjz-GijT44I0smyGQAxR-42dmSXK1CQ-TPNh4XmeXLU",
    ]
    assert not any("example.com" in link["url"] for link in shop_links.json())

    consultation_links = client.get("/links/consultation")
    assert consultation_links.status_code == 200
    assert consultation_links.json() == []

    live_links = client.get("/links/live")
    assert live_links.status_code == 200
    assert live_links.json() == []

    live_events = client.get("/links/live-events")
    assert live_events.status_code == 200
    assert len(live_events.json()) >= 1


def test_purchase_restore_and_analytics_event(client):
    user_id = f"restore_{uuid4().hex}"

    restore = client.post(
        "/purchase/restore",
        json={
            "user_id": user_id,
            "product_code": "ticket_20",
            "restore_receipt_id": f"rr_{uuid4().hex}",
        },
    )
    assert restore.status_code == 200
    assert restore.json()["tickets"] == 20
    assert "復元" in restore.json()["message"]

    event = client.post(
        "/analytics/events",
        json={
            "event_name": "announcement_opened",
            "user_id": user_id,
            "properties": {"announcement_id": "ann_001"},
        },
    )
    assert event.status_code == 200

    token = _admin_token(client)
    kpi = client.get("/admin/analytics/kpi", headers={"X-Admin-Token": token})
    assert kpi.status_code == 200
    values = kpi.json()["values"]
    assert values["announcement_opened"] >= 1
    assert values["ticket_purchased"] >= 1


def test_admin_operations_endpoints(client):
    token = _admin_token(client)
    headers = {"X-Admin-Token": token}

    user_id = f"admin_flow_{uuid4().hex}"
    assert client.post("/auth/login", json={"user_id": user_id}).status_code == 200

    inquiry = client.post(
        "/inquiries",
        json={
            "user_id": user_id,
            "category": "request",
            "body": "管理画面テスト用の問い合わせです。",
        },
    )
    assert inquiry.status_code == 200

    now = now_jst()
    created_announcement = client.post(
        "/admin/announcements",
        headers=headers,
        json={
            "title": "管理作成テスト",
            "body": "管理画面から作成したお知らせです。",
            "category": "重要なお知らせ",
            "start_at": (now - timedelta(hours=1)).isoformat(),
            "end_at": (now + timedelta(days=2)).isoformat(),
            "is_important": True,
            "link_url": "https://example.com/admin/announcement",
        },
    )
    assert created_announcement.status_code == 200

    announcements = client.get("/admin/announcements", headers=headers)
    assert announcements.status_code == 200
    assert any(item["title"] == "管理作成テスト" for item in announcements.json())

    campaign = client.post(
        "/admin/campaigns",
        headers=headers,
        json={
            "title": "配信テスト",
            "body": "通知配信のテストです。",
            "category": "キャンペーン通知",
            "target_segment": "all",
            "scheduled_at": (now + timedelta(minutes=30)).isoformat(),
            "is_ab_test": False,
        },
    )
    assert campaign.status_code == 200
    campaign_id = campaign.json()["campaign_id"]

    campaign_list = client.get("/admin/campaigns", headers=headers)
    assert campaign_list.status_code == 200
    assert any(item["campaign_id"] == campaign_id for item in campaign_list.json())

    dispatch = client.post(f"/admin/campaigns/{campaign_id}/dispatch", headers=headers)
    assert dispatch.status_code == 200
    assert dispatch.json()["status"] == "dispatched"

    dashboard = client.get("/admin/dashboard", headers=headers)
    assert dashboard.status_code == 200
    dashboard_data = dashboard.json()
    assert dashboard_data["users_total"] >= 1
    assert dashboard_data["inquiries_total"] >= 1
    assert dashboard_data["campaigns_total"] >= 1

    users = client.get("/admin/users", headers=headers)
    assert users.status_code == 200
    assert any(item["user_id"] == user_id for item in users.json())

    inquiries = client.get("/admin/inquiries", headers=headers)
    assert inquiries.status_code == 200
    assert any(item["user_id"] == user_id for item in inquiries.json())

    themes = client.get("/admin/themes", headers=headers)
    assert themes.status_code == 200
    assert len(themes.json()) >= 1

    decks = client.get("/admin/decks", headers=headers)
    assert decks.status_code == 200
    assert len(decks.json()) >= 1

    admin_users = client.get("/admin/admin-users", headers=headers)
    assert admin_users.status_code == 200
    assert any(item["email"] == "admin@example.com" for item in admin_users.json())


def test_admin_endpoint_requires_token(client):
    response = client.get("/admin/dashboard")
    assert response.status_code == 401


def test_health_ready_logout_and_admin_audit_logs(client):
    ready = client.get("/health/ready")
    assert ready.status_code == 200
    ready_payload = ready.json()
    assert ready_payload["overall_status"] in {"ok", "degraded"}
    assert ready_payload["components"]["app"] == "ok"
    assert "postgres" in ready_payload["components"]
    assert "redis" in ready_payload["components"]

    user_id = f"audit_{uuid4().hex}"
    login = client.post("/auth/login", json={"user_id": user_id})
    assert login.status_code == 200

    logout = client.post("/auth/logout", json={"user_id": user_id})
    assert logout.status_code == 200

    restore = client.post(
        "/purchase/restore",
        json={
            "user_id": user_id,
            "product_code": "ticket_20",
            "restore_receipt_id": f"audit_restore_{uuid4().hex}",
        },
    )
    assert restore.status_code == 200

    token = _admin_token(client)
    logs = client.get(
        "/admin/audit-logs",
        headers={"X-Admin-Token": token},
        params={"limit": 500},
    )
    assert logs.status_code == 200

    actions = [item["action"] for item in logs.json()]
    assert "auth.login" in actions
    assert "auth.logout" in actions
    assert "billing.purchase_restore" in actions


def test_admin_audit_logs_requires_token(client):
    response = client.get("/admin/audit-logs")
    assert response.status_code == 401
