from __future__ import annotations

from ..config import AppConfig
from ..logging_utils import get_logger
from ..models import Inquiry
from ..store import InMemoryStore


class InquiryService:
    def __init__(self, store: InMemoryStore, config: AppConfig) -> None:
        self._store = store
        self._config = config
        self._logger = get_logger(self.__class__.__name__)

    def submit(self, user_id: str, category: str, body: str, email: str | None) -> Inquiry:
        allowed = self._config.inquiries.categories
        if category not in allowed:
            raise ValueError(
                f"問い合わせカテゴリが不正です。許可値: {', '.join(allowed)}"
            )
        inquiry = self._store.add_inquiry(
            user_id=user_id,
            category=category,
            body=body,
            email=email,
        )
        self._logger.info("問い合わせ受付: inquiry_id=%s user_id=%s", inquiry.inquiry_id, user_id)
        return inquiry
