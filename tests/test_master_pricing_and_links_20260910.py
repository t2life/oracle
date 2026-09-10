"""マスタ（金額・外部導線）の回帰テスト（2026-09-10 承認分）。

- チケット金額は税込。画面が「金額（税込）」としか出さないため、
  マスタが税抜のままだと表示そのものが嘘になる。
- ショップ導線は実URL。プレースホルダ（example.com）が残っていると
  ユーザーの手元で開けないリンクが出る。
"""

from oracle_app.config import AppConfig
from oracle_app.store import InMemoryStore


def _store() -> InMemoryStore:
    return InMemoryStore(AppConfig())


def test_ticket_prices_are_tax_included() -> None:
    store = _store()
    prices = {
        product.product_code: product.price_jpy for product in store.list_products()
    }
    assert prices["ticket_trial_30"] == 330
    assert prices["ticket_20"] == 550
    assert prices["ticket_50"] == 1100
    assert prices["ticket_120"] == 2200
    assert prices["subscription_monthly_500"] == 550


def test_shop_links_are_real_urls() -> None:
    store = _store()
    links = store.list_external_links("shop")
    assert [(link.title, link.url) for link in links] == [
        ("公式ショップ", "https://senju888.stores.jp/"),
        ("Instagram", "https://www.instagram.com/hime_hukuoka/"),
        (
            "Threads",
            "https://www.threads.com/@hime_hukuoka"
            "?xmt=AQG0Cjz-GijT44I0smyGQAxR-42dmSXK1CQ-TPNh4XmeXLU",
        ),
    ]


def test_consultation_and_live_links_are_not_placeholders() -> None:
    """公開先が未定の間は0件にする（example.com を出さない）。"""
    store = _store()
    assert store.list_external_links("consultation") == []
    assert store.list_external_links("live") == []
