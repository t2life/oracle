from __future__ import annotations

from uuid import uuid4


def _run_basic_flow(client, user_id: str, draw_count: int = 1) -> str:
    start = client.post(
        "/reading/start",
        json={
            "user_id": user_id,
            "theme_id": "love",
            "deck_id": "japanese_mythology",
            "draw_count": draw_count,
        },
    )
    assert start.status_code == 200
    session_id = start.json()["session_id"]

    complete = client.post(
        "/reading/complete-shuffle",
        json={
            "session_id": session_id,
            "idle_seconds": 1.2,
            "finger_released": True,
            "swipe_distance": 220.0,
        },
    )
    assert complete.status_code == 200

    choose_pile = client.post(
        "/reading/select-pile",
        json={"session_id": session_id, "pile_index": 1},
    )
    assert choose_pile.status_code == 200

    choose_card = client.post(
        "/reading/select-card",
        json={"session_id": session_id, "card_index": 1},
    )
    assert choose_card.status_code == 200
    return session_id


def test_full_reading_flow_and_history_save(client):
    user_id = f"user_{uuid4().hex}"
    session_id = _run_basic_flow(client=client, user_id=user_id)

    save = client.post(f"/reading/{session_id}/save-history", json={"user_id": user_id})
    assert save.status_code == 200

    result = client.get(f"/reading/{session_id}")
    assert result.status_code == 200
    assert result.json()["session_id"] == session_id

    history = client.get("/history", params={"user_id": user_id})
    assert history.status_code == 200
    assert len(history.json()) == 1


def test_free_plan_daily_limit(client):
    user_id = f"free_{uuid4().hex}"
    first = client.post(
        "/reading/start",
        json={
            "user_id": user_id,
            "theme_id": "work",
            "deck_id": "japanese_mythology",
            "draw_count": 1,
        },
    )
    assert first.status_code == 200

    second = client.post(
        "/reading/start",
        json={
            "user_id": user_id,
            "theme_id": "money",
            "deck_id": "japanese_mythology",
            "draw_count": 1,
        },
    )
    assert second.status_code == 403
    assert "1日1回" in second.json()["detail"]


def test_shuffle_rule_validation(client):
    user_id = f"shuffle_{uuid4().hex}"
    start = client.post(
        "/reading/start",
        json={
            "user_id": user_id,
            "theme_id": "health",
            "deck_id": "japanese_mythology",
            "draw_count": 1,
        },
    )
    assert start.status_code == 200
    session_id = start.json()["session_id"]

    invalid = client.post(
        "/reading/complete-shuffle",
        json={
            "session_id": session_id,
            "idle_seconds": 0.5,
            "finger_released": True,
            "swipe_distance": 300.0,
        },
    )
    assert invalid.status_code == 400
