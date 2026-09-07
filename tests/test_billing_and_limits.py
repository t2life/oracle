from __future__ import annotations

from datetime import timedelta
from uuid import uuid4

from oracle_app.time_utils import now_jst


def _run_paid_flow(client, user_id: str, draw_count: int = 3) -> str:
    start = client.post(
        "/reading/start",
        json={
            "user_id": user_id,
            "theme_id": "subconscious",
            "deck_id": "japanese_mythology",
            "draw_count": draw_count,
        },
    )
    assert start.status_code == 200
    session_id = start.json()["session_id"]

    assert (
        client.post(
            "/reading/complete-shuffle",
            json={
                "session_id": session_id,
                "idle_seconds": 1.6,
                "finger_released": True,
                "swipe_distance": 200.0,
            },
        ).status_code
        == 200
    )
    assert (
        client.post(
            "/reading/select-pile",
            json={"session_id": session_id, "pile_index": 2},
        ).status_code
        == 200
    )
    assert (
        client.post(
            "/reading/select-card",
            json={"session_id": session_id, "card_index": 1},
        ).status_code
        == 200
    )
    assert (
        client.post(
            f"/reading/{session_id}/save-history",
            json={"user_id": user_id},
        ).status_code
        == 200
    )
    return session_id


def test_subscription_unlocks_three_card_draw(client):
    user_id = f"sub_{uuid4().hex}"

    verify = client.post(
        "/purchase/verify",
        json={
            "user_id": user_id,
            "product_code": "subscription_monthly_500",
            "receipt_id": f"r_{uuid4().hex}",
        },
    )
    assert verify.status_code == 200
    assert verify.json()["plan"] == "subscription"

    start = client.post(
        "/reading/start",
        json={
            "user_id": user_id,
            "theme_id": "higher_self",
            "deck_id": "japanese_mythology",
            "draw_count": 3,
        },
    )
    assert start.status_code == 200


def test_ticket_plan_consumes_tickets(app, client):
    user_id = f"ticket_{uuid4().hex}"

    verify = client.post(
        "/purchase/verify",
        json={
            "user_id": user_id,
            "product_code": "ticket_20",
            "receipt_id": f"r_{uuid4().hex}",
        },
    )
    assert verify.status_code == 200
    assert verify.json()["tickets"] == 20

    start = client.post(
        "/reading/start",
        json={
            "user_id": user_id,
            "theme_id": "money",
            "deck_id": "japanese_mythology",
            "draw_count": 3,
        },
    )
    assert start.status_code == 200

    user = app.state.container.store.get_or_create_user(user_id)
    assert user.tickets == 17


def test_free_history_keeps_latest_three(app, client):
    user_id = f"history_{uuid4().hex}"
    store = app.state.container.store

    for i in range(4):
        session_id = _run_paid_flow(client=client, user_id=user_id, draw_count=1)

        session = store.get_session(session_id)
        assert session is not None
        session.started_at = now_jst() - timedelta(days=i + 1)

        history_items = store.list_history(user_id)
        history_items[0].created_at = now_jst() - timedelta(days=i + 1)

    history = client.get("/history", params={"user_id": user_id})
    assert history.status_code == 200
    assert len(history.json()) == 3
