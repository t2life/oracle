"""履歴の種別（2026-09-12 承認オ）。

ご指摘: 履歴は結果内容を即表示せず、「託宣／リーディング」と占い日時の
1行にして、タップで詳細を出す方式にしたい（件数が増えると読めなくなる）。

一覧に種別を出すには履歴が種別を持っていなければならないが、
`HistoryItem` は持っていなかった。**新しい概念を作らず**、
引いた形（`spread_id`）をそのまま持たせる（daily＝託宣／それ以外＝リーディング）。
"""

from __future__ import annotations

from uuid import uuid4

from tests.test_deep_dive_reading_20260911 import (  # 既存の手順を再利用する
    _advance,
    _daily,
    _grant_tickets,
)


def _save(client, user_id: str, session_id: str) -> None:
    saved = client.post(
        f"/reading/{session_id}/save-history", json={"user_id": user_id}
    )
    assert saved.status_code == 200, saved.text


def _history(client, user_id: str) -> list[dict]:
    response = client.get("/history", params={"user_id": user_id})
    assert response.status_code == 200, response.text
    return response.json()


def _reading_three(client, user_id: str) -> dict:
    started = client.post(
        "/reading/start",
        json={
            "user_id": user_id,
            "theme_id": "work",
            "deck_id": "japanese_mythology",
            "spread_id": "three",
            "question_text": "転職すべきか迷っています。",
        },
    )
    assert started.status_code == 200, started.text
    session_id = started.json()["session_id"]
    _advance(client, session_id)
    result = None
    for index in range(1, 4):
        response = client.post(
            "/reading/select-card",
            json={"session_id": session_id, "card_index": index},
        )
        assert response.status_code == 200, response.text
        result = response.json()
    assert result is not None
    return result


def test_本日の託宣の履歴は種別がdaily(app, client):
    user_id = f"hist_{uuid4().hex}"
    _grant_tickets(client, user_id)
    daily = _daily(client, user_id)
    _save(client, user_id, daily["session_id"])

    items = _history(client, user_id)
    assert len(items) == 1
    assert items[0]["spread_id"] == "daily"


def test_リーディングの履歴は種別がスプレッドID(app, client):
    user_id = f"hist_{uuid4().hex}"
    _grant_tickets(client, user_id)
    reading = _reading_three(client, user_id)
    _save(client, user_id, reading["session_id"])

    items = _history(client, user_id)
    assert len(items) == 1
    assert items[0]["spread_id"] == "three"


def test_種別で託宣とリーディングを区別できる(app, client):
    """一覧の1行はこの値だけで「託宣／リーディング」を出す。"""
    user_id = f"hist_{uuid4().hex}"
    _grant_tickets(client, user_id)
    _save(client, user_id, _daily(client, user_id)["session_id"])
    _save(client, user_id, _reading_three(client, user_id)["session_id"])

    kinds = {item["spread_id"] for item in _history(client, user_id)}
    assert kinds == {"daily", "three"}


def test_全文は履歴に残る(app, client):
    """一覧から全文を外しても、詳細で出せるよう保存はされている。"""
    user_id = f"hist_{uuid4().hex}"
    _grant_tickets(client, user_id)
    daily = _daily(client, user_id)
    _save(client, user_id, daily["session_id"])

    item = _history(client, user_id)[0]
    assert item["full_text"] == daily["interpretation_text"]
    assert len(item["full_text"]) > len(item["summary"])
