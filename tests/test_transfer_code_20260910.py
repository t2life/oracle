"""機種変更の引継ぎコード（2026-09-10 追加）。

守りたいこと:
  - コードは使い捨て（2回目は通らない）
  - 発行し直すと前のコードは無効になる（紛失時に締め直せる）
  - 区切り・小文字で入力しても通る（手入力を前提とした正規化）
  - 引き継いだ端末では発行元アカウントのプラン・チケットを引き継ぐ
"""

from __future__ import annotations

from uuid import uuid4


def _issue(client, user_id: str):
    response = client.post("/account/transfer-code", json={"user_id": user_id})
    assert response.status_code == 200, response.text
    return response.json()


def test_transfer_code_moves_the_account(client):
    source = f"src_{uuid4().hex}"
    # 引き継ぎ元にチケットを積んでおく
    assert (
        client.post(
            "/purchase/verify",
            json={
                "user_id": source,
                "product_code": "ticket_20",
                "receipt_id": f"r_{uuid4().hex}",
            },
        ).status_code
        == 200
    )

    issued = _issue(client, source)
    assert len(issued["code"]) == 12
    assert issued["formatted_code"].count("-") == 2
    # 見間違えやすい文字を使わない
    assert not set(issued["code"]) & set("01OIL")

    redeemed = client.post(
        "/account/transfer-code/redeem", json={"code": issued["code"]}
    )
    assert redeemed.status_code == 200
    body = redeemed.json()
    assert body["user_id"] == source
    assert body["tickets"] == 20


def test_transfer_code_is_single_use(client):
    user_id = f"src_{uuid4().hex}"
    issued = _issue(client, user_id)

    assert (
        client.post(
            "/account/transfer-code/redeem", json={"code": issued["code"]}
        ).status_code
        == 200
    )
    second = client.post(
        "/account/transfer-code/redeem", json={"code": issued["code"]}
    )
    assert second.status_code == 400


def test_reissue_invalidates_the_previous_code(client):
    user_id = f"src_{uuid4().hex}"
    first = _issue(client, user_id)
    second = _issue(client, user_id)
    assert first["code"] != second["code"]

    stale = client.post(
        "/account/transfer-code/redeem", json={"code": first["code"]}
    )
    assert stale.status_code == 400
    assert (
        client.post(
            "/account/transfer-code/redeem", json={"code": second["code"]}
        ).status_code
        == 200
    )


def test_input_is_normalized(client):
    user_id = f"src_{uuid4().hex}"
    issued = _issue(client, user_id)

    typed = f"  {issued['formatted_code'].lower()}  "
    response = client.post("/account/transfer-code/redeem", json={"code": typed})
    assert response.status_code == 200
    assert response.json()["user_id"] == user_id


def test_unknown_code_is_rejected(client):
    response = client.post(
        "/account/transfer-code/redeem", json={"code": "ZZZZ-ZZZZ-ZZZZ"}
    )
    assert response.status_code == 400
