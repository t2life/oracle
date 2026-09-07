from __future__ import annotations

from typing import Protocol

from ..logging_utils import get_logger


class ReceiptVerificationError(Exception):
    """レシート検証に失敗したことを表す例外。"""


class ReceiptVerifier(Protocol):
    def verify(self, user_id: str, product_code: str, receipt_id: str) -> None:
        """検証に失敗した場合は ReceiptVerificationError を送出する。"""


class LocalFormalVerifier:
    """現行互換の形式チェックのみを行う検証器（既定モード local）。

    ストア公式APIとの照合は行わないため、staging では警告、
    production では起動拒否の対象となる（orchestrator._build_receipt_verifier）。
    """

    def __init__(self) -> None:
        self._logger = get_logger(self.__class__.__name__)

    def verify(self, user_id: str, product_code: str, receipt_id: str) -> None:
        if not receipt_id.strip():
            raise ReceiptVerificationError("レシートIDが空です。")
        self._logger.debug(
            "形式チェックのみでレシートを受理: user_id=%s product=%s",
            user_id,
            product_code,
        )


class AppleStoreKitVerifier:
    """App Store Server API 検証器の骨格。

    認証情報が未設定の場合は起動時に明示エラーとする（fail-fast）。
    実HTTP接続はストア認証情報の投入後に実装する。実装完了までは
    fail-closed（検証失敗扱い）とし、未検証レシートを通さない。
    """

    def __init__(self, issuer_id: str, key_id: str, private_key: str) -> None:
        if not issuer_id or not key_id or not private_key:
            raise ValueError(
                "Apple検証の認証情報（ORACLE_APPLE_ISSUER_ID / ORACLE_APPLE_KEY_ID / "
                "ORACLE_APPLE_PRIVATE_KEY）が未設定です。"
            )
        self._issuer_id = issuer_id
        self._key_id = key_id
        self._private_key = private_key
        self._logger = get_logger(self.__class__.__name__)

    def verify(self, user_id: str, product_code: str, receipt_id: str) -> None:
        self._logger.warning(
            "Apple App Store Server APIとの実接続は未実装のため検証を拒否: user_id=%s product=%s",
            user_id,
            product_code,
        )
        raise ReceiptVerificationError(
            "Apple App Store Server APIとの実接続は未実装です。ロードマップB-1の実装完了後に利用できます。"
        )


class GooglePlayVerifier:
    """Google Play Developer API 検証器の骨格。

    認証情報が未設定の場合は起動時に明示エラーとする（fail-fast）。
    実HTTP接続はサービスアカウント投入後に実装する。実装完了までは
    fail-closed（検証失敗扱い）とし、未検証レシートを通さない。
    """

    def __init__(self, package_name: str, service_account_json: str) -> None:
        if not package_name or not service_account_json:
            raise ValueError(
                "Google検証の認証情報（ORACLE_GOOGLE_PACKAGE_NAME / "
                "ORACLE_GOOGLE_SERVICE_ACCOUNT_JSON）が未設定です。"
            )
        self._package_name = package_name
        self._service_account_json = service_account_json
        self._logger = get_logger(self.__class__.__name__)

    def verify(self, user_id: str, product_code: str, receipt_id: str) -> None:
        self._logger.warning(
            "Google Play Developer APIとの実接続は未実装のため検証を拒否: user_id=%s product=%s",
            user_id,
            product_code,
        )
        raise ReceiptVerificationError(
            "Google Play Developer APIとの実接続は未実装です。ロードマップB-2の実装完了後に利用できます。"
        )


class StoreApiReceiptVerifier:
    """store_api モードの入口。Apple/Google両検証器を保持する。

    プラットフォーム判別（レシートがどちらのストア由来か）は、実接続実装時に
    リクエストへ platform 情報を追加して行う。判別実装までは fail-closed。
    """

    def __init__(self, apple: AppleStoreKitVerifier, google: GooglePlayVerifier) -> None:
        self._apple = apple
        self._google = google
        self._logger = get_logger(self.__class__.__name__)

    def verify(self, user_id: str, product_code: str, receipt_id: str) -> None:
        self._logger.warning(
            "store_apiモードのプラットフォーム判別は未実装のため検証を拒否: user_id=%s product=%s",
            user_id,
            product_code,
        )
        raise ReceiptVerificationError(
            "ストア公式APIによるレシート検証は準備中です（プラットフォーム判別が未実装）。"
        )
