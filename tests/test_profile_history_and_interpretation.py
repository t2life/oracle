from __future__ import annotations

from uuid import uuid4

from oracle_app.content_loader import load_card_content
from oracle_app.services.interpretation_engine import InterpretationEngine


def _login(client, user_id: str) -> dict:
    response = client.post("/auth/login", json={"user_id": user_id})
    assert response.status_code == 200
    return response.json()


def _run_flow_and_save_history(client, user_id: str) -> str:
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
    assert client.post(
        "/reading/complete-shuffle",
        json={
            "session_id": session_id,
            "idle_seconds": 1.5,
            "finger_released": True,
            "swipe_distance": 200.0,
        },
    ).status_code == 200
    assert client.post(
        "/reading/select-pile",
        json={"session_id": session_id, "pile_index": 1},
    ).status_code == 200
    assert client.post(
        "/reading/select-card",
        json={"session_id": session_id, "card_index": 1},
    ).status_code == 200
    assert client.post(
        f"/reading/{session_id}/save-history",
        json={"user_id": user_id},
    ).status_code == 200

    history = client.get("/history", params={"user_id": user_id})
    assert history.status_code == 200
    items = history.json()
    assert len(items) >= 1
    return items[0]["history_id"]


def test_profile_update_and_login_display_name(client):
    user_id = f"prof_{uuid4().hex}"
    _login(client, user_id)

    updated = client.put(
        "/profile",
        json={"user_id": user_id, "display_name": "  ロン子  "},
    )
    assert updated.status_code == 200
    assert updated.json()["display_name"] == "ロン子"

    fetched = client.get("/profile", params={"user_id": user_id})
    assert fetched.status_code == 200
    assert fetched.json()["display_name"] == "ロン子"

    login = _login(client, user_id)
    assert login["display_name"] == "ロン子"


def test_profile_update_rejects_out_of_range(client):
    user_id = f"prof_{uuid4().hex}"
    _login(client, user_id)

    too_long = client.put(
        "/profile",
        json={"user_id": user_id, "display_name": "あ" * 21},
    )
    assert too_long.status_code == 400

    blank = client.put(
        "/profile",
        json={"user_id": user_id, "display_name": "   "},
    )
    assert blank.status_code == 400


def test_history_delete_own_and_forbidden(client):
    owner = f"own_{uuid4().hex}"
    other = f"oth_{uuid4().hex}"
    _login(client, owner)
    _login(client, other)
    history_id = _run_flow_and_save_history(client, owner)

    forbidden = client.delete(
        f"/history/{history_id}", params={"user_id": other}
    )
    assert forbidden.status_code == 403

    deleted = client.delete(
        f"/history/{history_id}", params={"user_id": owner}
    )
    assert deleted.status_code == 200

    not_found = client.delete(
        f"/history/{history_id}", params={"user_id": owner}
    )
    assert not_found.status_code == 404

    listing = client.get("/history", params={"user_id": owner})
    assert all(item["history_id"] != history_id for item in listing.json())


def test_japanese_deck_seeded_from_card_db(client):
    cards = client.get("/cards", params={"deck_id": "japanese_mythology"})
    assert cards.status_code == 200
    body = cards.json()
    assert len(body) == 44
    names = [card["name_ja"] for card in body]
    assert "天照大御神" in names
    assert body[0]["card_id"] == "japanese_mythology_card_001"
    # 機械生成の連番名（「日本神話デッキ 1」）が残っていないこと
    assert all("デッキ " not in name for name in names)


def test_interpretation_engine_compose_deterministic():
    engine = InterpretationEngine(load_card_content())
    text_1 = engine.compose_ja(
        card_id="japanese_mythology_card_001",
        theme_id="love",
        date_key="2026-09-06",
        session_id="ses_test",
        fallback_text="fallback",
    )
    text_2 = engine.compose_ja(
        card_id="japanese_mythology_card_001",
        theme_id="love",
        date_key="2026-09-06",
        session_id="ses_test",
        fallback_text="fallback",
    )
    assert text_1 == text_2
    assert "{" not in text_1 and "}" not in text_1
    assert "天之御中主神" in text_1 or len(text_1) > 40
    # 2026-09-10 の文体層導入で見出しは「行動提案」→「アドバイス」へ変更
    assert "アドバイス" in text_1

    unknown = engine.compose_ja(
        card_id="ryujin_card_001",
        theme_id="love",
        date_key="2026-09-06",
        session_id="ses_test",
        fallback_text="fallback",
    )
    assert unknown == "fallback"


def test_interpretation_engine_combination_latent():
    engine = InterpretationEngine(load_card_content())
    content = load_card_content()
    fire_cards = [
        card["card_id"] for card in content["cards"] if card["element"] == "火"
    ]
    assert len(fire_cards) >= 2
    text = engine.compose_combination(fire_cards[0], fire_cards[1])
    assert text is not None
    assert "組み合わせ" in text
