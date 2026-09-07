from __future__ import annotations

from uuid import uuid4

from ..config import AppConfig
from ..logging_utils import get_logger
from ..models import AuthProvider, Profile, User
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
