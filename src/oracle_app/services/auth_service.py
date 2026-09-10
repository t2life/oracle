from __future__ import annotations

import secrets
from datetime import timedelta
from uuid import uuid4

from ..config import AppConfig
from ..logging_utils import get_logger
from ..models import AuthProvider, Profile, TransferCode, User
from ..store import InMemoryStore
from ..time_utils import now_jst


class AuthService:
    def __init__(self, store: InMemoryStore, config: AppConfig) -> None:
        self._store = store
        self._config = config
        self._logger = get_logger(self.__class__.__name__)

    def login_by_user_id(self, user_id: str) -> User:
        user = self._store.get_or_create_user(user_id)
        user.visit_count += 1
        user.updated_at = now_jst()
        self._store.update_user(user)
        return user

    def logout_by_user_id(self, user_id: str) -> None:
        _ = self._store.get_or_create_user(user_id)
        self._logger.info("認証ログアウト: user_id=%s", user_id)

    def get_profile(self, user_id: str) -> Profile:
        return self._store.get_or_create_profile(user_id)

    def update_profile(self, user_id: str, display_name: str) -> Profile:
        rules = self._config.profiles
        name = display_name.strip()
        if (
            len(name) < rules.display_name_min
            or len(name) > rules.display_name_max
        ):
            raise ValueError(
                f"ニックネームは{rules.display_name_min}〜"
                f"{rules.display_name_max}文字で入力してください。"
            )
        # NGワード検証（将来のSNS共有・コミュニティ機能向けプレースホルダ。
        # 既定のforbidden_wordsは空＝素通し。config側へ語を追加すると発効する）
        lowered = name.lower()
        for word in rules.forbidden_words:
            if word and word.lower() in lowered:
                raise ValueError("ニックネームに使用できない語が含まれています。")

        profile = self._store.update_profile_display_name(user_id, name)
        self._logger.info("プロフィール更新: user_id=%s", user_id)
        return profile

    def login_with_provider(
        self,
        provider: AuthProvider,
        provider_user_id: str,
        email: str | None,
    ) -> User:
        account = self._store.get_auth_account(provider=provider, provider_user_id=provider_user_id)
        if account is not None:
            user = self._store.get_or_create_user(account.user_id)
            user.visit_count += 1
            user.updated_at = now_jst()
            self._store.update_user(user)
            self._logger.info("認証ログイン: provider=%s user_id=%s", provider.value, user.user_id)
            return user

        user_id = f"{provider.value}_{uuid4().hex[:12]}"
        user = self._store.get_or_create_user(user_id)
        user.visit_count += 1
        user.updated_at = now_jst()
        self._store.update_user(user)

        profile = self._store.get_or_create_profile(user_id)
        if email:
            display_name = email.split("@")[0]
            profile.display_name = display_name
            profile.updated_at = now_jst()

        self._store.add_auth_account(
            user_id=user.user_id,
            provider=provider,
            provider_user_id=provider_user_id,
            email=email,
        )
        self._logger.info("認証新規作成: provider=%s user_id=%s", provider.value, user.user_id)
        return user

    # ---- 機種変更の引継ぎ ----
    def issue_transfer_code(self, user_id: str) -> TransferCode:
        """引継ぎコードを発行する。

        いま使っているアカウント（user_id）を新しい端末へ引き渡すための
        使い捨ての鍵。発行し直すと前のコードは無効になる（紛失時の締め直し）。
        """
        rules = self._config.transfer_codes
        user = self._store.get_or_create_user(user_id)
        code = "".join(
            secrets.choice(rules.alphabet) for _ in range(rules.length)
        )
        issued_at = now_jst()
        transfer_code = TransferCode(
            code=code,
            user_id=user.user_id,
            issued_at=issued_at,
            expires_at=issued_at + timedelta(hours=rules.valid_hours),
        )
        self._store.save_transfer_code(transfer_code)
        self._logger.info(
            "引継ぎコード発行: user_id=%s 期限=%s", user.user_id, transfer_code.expires_at
        )
        return transfer_code

    def redeem_transfer_code(self, code: str) -> User:
        """引継ぎコードを使って、発行元のアカウントへ切り替える。

        使い捨て＝一度使ったコードは二度と通らない。
        期限切れ・未知のコードは同じ文言で断る（存在するコードかどうかを
        入力側に教えない＝総当たりの手がかりを与えない）。
        """
        normalized = self.normalize_transfer_code(code)
        entry = self._store.get_transfer_code(normalized)
        now = now_jst()
        if entry is None or entry.used_at is not None or entry.expires_at < now:
            raise ValueError("引継ぎコードが正しくないか、有効期限が切れています。")

        self._store.mark_transfer_code_used(normalized, now)
        user = self._store.get_or_create_user(entry.user_id)
        user.visit_count += 1
        user.updated_at = now
        self._store.update_user(user)
        self._logger.info("引継ぎ完了: user_id=%s", user.user_id)
        return user

    @staticmethod
    def normalize_transfer_code(code: str) -> str:
        """入力されたコードを照合用の形へ揃える（区切りと空白を落として大文字化）。"""
        return "".join(
            char for char in (code or "").upper() if char.isalnum()
        )

    def format_transfer_code(self, code: str) -> str:
        """表示用に4文字ごとへ区切る（手入力の取り違えを減らす）。"""
        size = self._config.transfer_codes.group_size
        return "-".join(code[i : i + size] for i in range(0, len(code), size))
