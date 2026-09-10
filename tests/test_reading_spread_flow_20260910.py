"""スプレッド／相談内容／複数枚リーディングの検証（2026-09-10 承認方針§4.1〜4.2）。

承認内容:
  - リーディングは一律チケット5枚消費、無料ユーザーは「本日の託宣」のみ
  - 相談内容は任意・3000文字まで
  - 3/5/7枚は必要枚数に達するまでカード選択を繰り返す
"""

from __future__ import annotations

from uuid import uuid4


def _grant_tickets(client, user_id: str) -> None:
    response = client.post(
        "/purchase/verify",
        json={
            "user_id": user_id,
            "product_code": "ticket_20",
            "receipt_id": f"r_{uuid4().hex}",
        },
    )
    assert response.status_code == 200


def _start(client, user_id: str, **overrides) -> tuple[int, dict]:
    payload = {
        "user_id": user_id,
        "theme_id": "work",
        "deck_id": "japanese_mythology",
    }
    payload.update(overrides)
    response = client.post("/reading/start", json=payload)
    return response.status_code, (
        response.json() if response.status_code == 200 else {}
    )


def _advance_to_card_selection(client, session_id: str) -> None:
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


def test_spread_list_reflects_plan(client):
    free_user = f"free_{uuid4().hex}"
    response = client.get("/reading/spreads", params={"user_id": free_user})
    assert response.status_code == 200
    spreads = {item["spread_id"]: item for item in response.json()}

    assert len(spreads) == 5
    assert spreads["daily"]["required_tickets"] == 0
    assert spreads["daily"]["available"] is True
    for spread_id in ("three", "five", "seven", "free"):
        assert spreads[spread_id]["required_tickets"] == 5, spread_id
        assert spreads[spread_id]["available"] is False, spread_id
        assert spreads[spread_id]["unavailable_reason"], spread_id

    # 表示順はマスタの sort_order どおり
    order = [item["spread_id"] for item in response.json()]
    assert order == ["daily", "three", "five", "seven", "free"]


def test_free_user_can_only_use_daily(client):
    user_id = f"free_{uuid4().hex}"
    status, _ = _start(client, user_id, spread_id="three")
    assert status == 403

    status, _ = _start(client, user_id, spread_id="daily")
    assert status == 200


def test_question_text_is_limited(client):
    user_id = f"free_{uuid4().hex}"
    status, _ = _start(
        client, user_id, spread_id="daily", question_text="あ" * 3001
    )
    assert status in (400, 422)


def test_three_card_reading_requires_three_selections(client):
    user_id = f"ticket_{uuid4().hex}"
    _grant_tickets(client, user_id)

    status, body = _start(
        client,
        user_id,
        spread_id="three",
        question_text="転職すべきか迷っています。",
    )
    assert status == 200
    session_id = body["session_id"]
    _advance_to_card_selection(client, session_id)

    first = client.post(
        "/reading/select-card", json={"session_id": session_id, "card_index": 1}
    )
    assert first.status_code == 200
    assert first.json() is None, "1枚目で結果を返してはいけない"

    second = client.post(
        "/reading/select-card", json={"session_id": session_id, "card_index": 2}
    )
    assert second.json() is None

    third = client.post(
        "/reading/select-card", json={"session_id": session_id, "card_index": 3}
    )
    assert third.status_code == 200
    result = third.json()
    assert result is not None

    assert result["spread_id"] == "three"
    assert result["question_text"] == "転職すべきか迷っています。"
    assert len(result["cards"]) == 3
    assert [card["position_name"] for card in result["cards"]] == [
        "過去",
        "現在",
        "未来",
    ]
    # 単数フィールドは1枚目を指し続ける（履歴・管理画面の互換）
    assert result["card_id"] == result["cards"][0]["card_id"]
    # 位置見出しと組み合わせ解釈が本文へ入る
    assert "【過去】" in result["interpretation_text"]
    assert result["combination_text"]


def test_same_card_cannot_be_selected_twice(client):
    user_id = f"ticket_{uuid4().hex}"
    _grant_tickets(client, user_id)
    status, body = _start(client, user_id, spread_id="three")
    assert status == 200
    session_id = body["session_id"]
    _advance_to_card_selection(client, session_id)

    assert (
        client.post(
            "/reading/select-card",
            json={"session_id": session_id, "card_index": 1},
        ).status_code
        == 200
    )
    duplicated = client.post(
        "/reading/select-card", json={"session_id": session_id, "card_index": 1}
    )
    assert duplicated.status_code == 400


def test_daily_reading_completes_with_one_card(client):
    user_id = f"free_{uuid4().hex}"
    status, body = _start(client, user_id, spread_id="daily")
    assert status == 200
    session_id = body["session_id"]
    _advance_to_card_selection(client, session_id)

    response = client.post(
        "/reading/select-card", json={"session_id": session_id, "card_index": 1}
    )
    assert response.status_code == 200
    result = response.json()
    assert result is not None
    assert result["spread_id"] == "daily"
    assert len(result["cards"]) == 1
    assert result["combination_text"] is None


def test_daily_spread_reports_used_free_quota(client):
    """本日の託宣を使い切ったら、種別選択の前に available=False で分かること。

    以前は `available` がプランとチケットしか見ておらず、無料枠を使い切った
    ユーザーは種別→デッキ→テーマまで進んでから 403 で弾かれていた。
    """
    user_id = f"free_{uuid4().hex}"

    before = client.get("/reading/spreads", params={"user_id": user_id}).json()
    assert next(s for s in before if s["spread_id"] == "daily")["available"] is True

    status, _ = _start(client, user_id, spread_id="daily")
    assert status == 200

    after = client.get("/reading/spreads", params={"user_id": user_id}).json()
    daily = next(s for s in after if s["spread_id"] == "daily")
    assert daily["available"] is False
    assert daily["unavailable_reason"] == "本日の無料枠は使い切りました。"


def test_spread_availability_without_user_is_neutral(client):
    """user_id 無し（未ログイン相当）では可否を判定しない＝一覧の取得だけ。"""
    spreads = client.get("/reading/spreads").json()
    assert all(spread["available"] is True for spread in spreads)
    assert all(spread["unavailable_reason"] is None for spread in spreads)
