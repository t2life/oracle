"""深掘りリーディング（2026-09-11 承認）。

承認内容:
  1. 枚数は選ばせる（3／5／7）
  2. 一律チケット5枚
  3. 月額プランは無制限
  4. 託宣と深掘りは履歴1件にまとめる

設計の要（占いの作法）:
  同じ問いを引き直すのは読みが成立しない。∴ **託宣で出たカードを1枚目として
  引き継ぎ**、残りだけを引く。これは「引き直し」ではなく「展開」である。
"""

from __future__ import annotations

from uuid import uuid4

import pytest


def _grant_tickets(client, user_id: str) -> None:
    assert (
        client.post(
            "/purchase/verify",
            json={
                "user_id": user_id,
                "product_code": "ticket_20",
                "receipt_id": f"r_{uuid4().hex}",
            },
        ).status_code
        == 200
    )


def _tickets(client, user_id: str) -> int:
    return client.post("/auth/login", json={"user_id": user_id}).json()["tickets"]


def _advance(client, session_id: str) -> None:
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
            json={"session_id": session_id, "pile_index": 1},
        ).status_code
        == 200
    )


def _daily(client, user_id: str) -> dict:
    started = client.post(
        "/reading/start",
        json={
            "user_id": user_id,
            "theme_id": "work",
            "deck_id": "japanese_mythology",
            "spread_id": "daily",
        },
    )
    assert started.status_code == 200, started.text
    session_id = started.json()["session_id"]
    _advance(client, session_id)
    result = client.post(
        "/reading/select-card", json={"session_id": session_id, "card_index": 1}
    )
    assert result.status_code == 200
    return result.json()


def _deep_start(client, user_id: str, origin: str, spread_id: str = "three"):
    return client.post(
        "/reading/start",
        json={
            "user_id": user_id,
            "theme_id": "work",
            "deck_id": "japanese_mythology",
            "spread_id": spread_id,
            "question_text": "この先どう動くべきでしょうか。",
            "origin_session_id": origin,
        },
    )


def test_origin_card_is_carried_and_not_redrawn(app, client):
    """託宣のカードが1枚目として引き継がれ、残りだけを引く。"""
    user_id = f"deep_{uuid4().hex}"
    _grant_tickets(client, user_id)
    daily = _daily(client, user_id)

    started = _deep_start(client, user_id, daily["session_id"])
    assert started.status_code == 200, started.text
    session_id = started.json()["session_id"]
    _advance(client, session_id)

    # 3枚のうち1枚は引き継ぎ済み＝**あと2枚**で結果が出る
    first = client.post(
        "/reading/select-card", json={"session_id": session_id, "card_index": 1}
    )
    assert first.json() is None, "1枚目の選択で結果が出てはいけない"
    second = client.post(
        "/reading/select-card", json={"session_id": session_id, "card_index": 2}
    )
    result = second.json()
    assert result is not None, "引き継ぎ1枚＋2枚で結果が出るはず"

    assert len(result["cards"]) == 3
    # 引き継いだカードが先頭に来ている（引き直しではなく展開）
    assert result["cards"][0]["card_id"] == daily["card_id"]
    assert result["origin_session_id"] == daily["session_id"]


def test_ticket_plan_pays_five_once(app, client):
    """承認②: 一律5枚。深掘りの開始で1度だけ引かれる。"""
    user_id = f"deep_{uuid4().hex}"
    _grant_tickets(client, user_id)
    daily = _daily(client, user_id)
    before = _tickets(client, user_id)

    assert _deep_start(client, user_id, daily["session_id"]).status_code == 200
    assert _tickets(client, user_id) == before - 5


def test_subscription_is_unlimited(app, client):
    """承認③: 月額は無制限＝チケットを消費しない。"""
    user_id = f"sub_{uuid4().hex}"
    assert (
        client.post(
            "/purchase/verify",
            json={
                "user_id": user_id,
                "product_code": "subscription_monthly_500",
                "receipt_id": f"r_{uuid4().hex}",
            },
        ).status_code
        == 200
    )
    daily = _daily(client, user_id)
    before = _tickets(client, user_id)

    for _ in range(3):
        assert _deep_start(client, user_id, daily["session_id"]).status_code == 200
    assert _tickets(client, user_id) == before


def test_free_plan_cannot_deep_dive(app, client):
    """無料プランは深掘りできない（リーディング本体と同じ規則）。"""
    user_id = f"free_{uuid4().hex}"
    daily = _daily(client, user_id)
    assert _deep_start(client, user_id, daily["session_id"]).status_code == 403


@pytest.mark.parametrize("spread_id, total", [("three", 3), ("five", 5), ("seven", 7)])
def test_all_three_sizes_are_selectable(app, client, spread_id: str, total: int):
    """承認①: 3／5／7 を選ばせる。いずれも引き継ぎ1枚＋残りで成立する。"""
    user_id = f"deep_{uuid4().hex}"
    _grant_tickets(client, user_id)
    daily = _daily(client, user_id)

    started = _deep_start(client, user_id, daily["session_id"], spread_id)
    assert started.status_code == 200
    session_id = started.json()["session_id"]
    _advance(client, session_id)

    result = None
    for index in range(1, total):  # 残り total-1 枚
        result = client.post(
            "/reading/select-card",
            json={"session_id": session_id, "card_index": index},
        ).json()
    assert result is not None
    assert len(result["cards"]) == total
    assert result["cards"][0]["card_id"] == daily["card_id"]


def test_history_is_merged_into_one(app, client):
    """承認④: 託宣を保存済みでも、深掘り後の履歴は1件になる。"""
    user_id = f"deep_{uuid4().hex}"
    _grant_tickets(client, user_id)
    daily = _daily(client, user_id)

    # 先に託宣を履歴へ保存しておく
    assert (
        client.post(
            f"/reading/{daily['session_id']}/save-history", json={"user_id": user_id}
        ).status_code
        == 200
    )
    assert len(client.get("/history", params={"user_id": user_id}).json()) == 1

    started = _deep_start(client, user_id, daily["session_id"])
    session_id = started.json()["session_id"]
    _advance(client, session_id)
    for index in (1, 2):
        client.post(
            "/reading/select-card",
            json={"session_id": session_id, "card_index": index},
        )
    assert (
        client.post(
            f"/reading/{session_id}/save-history", json={"user_id": user_id}
        ).status_code
        == 200
    )

    history = client.get("/history", params={"user_id": user_id}).json()
    assert len(history) == 1, "託宣と深掘りで2件に増えてはいけない"
    assert history[0]["session_id"] == session_id


def test_cannot_deep_dive_someone_elses_result(app, client):
    user_id = f"deep_{uuid4().hex}"
    _grant_tickets(client, user_id)
    daily = _daily(client, user_id)

    intruder = f"deep_{uuid4().hex}"
    _grant_tickets(client, intruder)
    assert _deep_start(client, intruder, daily["session_id"]).status_code in (400, 403)


def test_unknown_origin_is_rejected(app, client):
    user_id = f"deep_{uuid4().hex}"
    _grant_tickets(client, user_id)
    before = _tickets(client, user_id)

    assert _deep_start(client, user_id, "ses_nope").status_code == 400
    assert _tickets(client, user_id) == before, "失敗したのに消費してはいけない"
