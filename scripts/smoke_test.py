from __future__ import annotations

import json
import sys
from pathlib import Path
from uuid import uuid4

from fastapi.testclient import TestClient

ROOT_DIR = Path(__file__).resolve().parents[1]
SRC_DIR = ROOT_DIR / "src"
if str(SRC_DIR) not in sys.path:
    sys.path.insert(0, str(SRC_DIR))

from oracle_app.api import create_app


def main() -> None:
    app = create_app()
    client = TestClient(app)
    user_id = f"smoke_{uuid4().hex}"

    client.get("/health/ready").raise_for_status()
    client.post("/auth/login", json={"user_id": user_id}).raise_for_status()

    response = client.post(
        "/reading/start",
        json={
            "user_id": user_id,
            "theme_id": "love",
            "deck_id": "japanese_mythology",
            "draw_count": 1,
        },
    )
    response.raise_for_status()
    session_id = response.json()["session_id"]

    client.post(
        "/reading/complete-shuffle",
        json={
            "session_id": session_id,
            "idle_seconds": 1.3,
            "finger_released": True,
            "swipe_distance": 180.0,
        },
    ).raise_for_status()
    client.post(
        "/reading/select-pile",
        json={"session_id": session_id, "pile_index": 1},
    ).raise_for_status()
    client.post(
        "/reading/select-card",
        json={"session_id": session_id, "card_index": 1},
    ).raise_for_status()
    client.post(f"/reading/{session_id}/save-history", json={"user_id": user_id}).raise_for_status()

    result = client.get(f"/reading/{session_id}")
    result.raise_for_status()
    client.post("/auth/logout", json={"user_id": user_id}).raise_for_status()

    admin_login = client.post(
        "/admin/login",
        json={"email": "admin@example.com", "password": "ChangeMe123!"},
    )
    admin_login.raise_for_status()
    admin_token = admin_login.json()["token"]
    client.get(
        "/admin/audit-logs",
        params={"limit": 50},
        headers={"X-Admin-Token": admin_token},
    ).raise_for_status()

    print(json.dumps(result.json(), ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
