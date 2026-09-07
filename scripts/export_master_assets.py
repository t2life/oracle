from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT_DIR = Path(__file__).resolve().parents[1]
SRC_DIR = ROOT_DIR / "src"
if str(SRC_DIR) not in sys.path:
    sys.path.insert(0, str(SRC_DIR))

from oracle_app.config import AppConfig  # noqa: E402
from oracle_app.store import InMemoryStore  # noqa: E402

OUTPUT_PATH = ROOT_DIR / "mobile_app" / "assets" / "master_data.json"


def main() -> None:
    """バックエンドのマスタシードをモバイルのオフライン用資産へ書き出す。

    単一真実源はバックエンド（store._seed_master_data / config.py）。
    このJSONを手動編集してはならない。マスタ変更時は本スクリプトを再実行し、
    モバイルを再ビルドすること。
    """
    config = AppConfig()
    store = InMemoryStore(config)

    visible_theme_ids = list(config.default_theme_ids)

    themes = [
        {
            "theme_id": theme.theme_id,
            "name_ja": theme.name_ja,
            "name_en": theme.name_en,
            "name_zh": theme.name_zh,
        }
        for theme in store.list_themes()
    ]

    decks = [
        {
            "deck_id": deck.deck_id,
            "name_ja": deck.name_ja,
            "name_en": deck.name_en,
            "name_zh": deck.name_zh,
            "sort_order": deck.sort_order,
        }
        for deck in store.list_decks()
    ]

    cards = []
    for deck in store.list_decks():
        for card in store.list_cards_by_deck(deck.deck_id):
            cards.append(
                {
                    "card_id": card.card_id,
                    "deck_id": card.deck_id,
                    "name_ja": card.name_ja,
                    "name_en": card.name_en,
                    "name_zh": card.name_zh,
                    "keywords": card.keywords,
                    "keywords_en": card.keywords_en,
                    "keywords_zh": card.keywords_zh,
                    "default_meaning": card.default_meaning,
                    "default_meaning_en": card.default_meaning_en,
                    "default_meaning_zh": card.default_meaning_zh,
                    # オフラインで選択可能なのは可視テーマのみのため、可視分だけ持つ
                    "meanings_by_theme": {
                        tid: card.meanings_by_theme[tid] for tid in visible_theme_ids
                    },
                    "meanings_by_theme_en": {
                        tid: card.meanings_by_theme_en[tid] for tid in visible_theme_ids
                    },
                    "meanings_by_theme_zh": {
                        tid: card.meanings_by_theme_zh[tid] for tid in visible_theme_ids
                    },
                }
            )

    products = [
        {
            "product_code": product.product_code,
            "title": product.title,
            "plan_type": product.plan_type.value,
            "price_jpy": product.price_jpy,
            "ticket_amount": product.ticket_amount,
            "is_subscription": product.is_subscription,
        }
        for product in store.list_products()
    ]

    links = {
        category: [
            {
                "link_id": link.link_id,
                "category": link.category,
                "title": link.title,
                "url": link.url,
            }
            for link in store.list_external_links(category)
        ]
        for category in ("shop", "consultation", "live")
    }

    announcements = [
        {
            "announcement_id": ann.announcement_id,
            "title": ann.title,
            "body": ann.body,
            "category": ann.category,
            "is_important": ann.is_important,
            "link_url": ann.link_url,
            # 公開期間はオフライン側で「取得時刻±日数」として再構成する
            "start_days_from_now": -1,
            "end_days_from_now": 30,
        }
        for ann in store.list_announcements()
    ]

    live_events = [
        {
            "live_event_id": event.live_event_id,
            "title": event.title,
            "start_days_from_now": 3,
            "archive_url": event.archive_url,
        }
        for event in store.list_live_events()
    ]

    payload = {
        "_generated_by": "scripts/export_master_assets.py",
        "_note": "手動編集禁止。単一真実源はバックエンドのマスタシード。変更時は再エクスポートしてモバイルを再ビルドする。",
        # 注意文言は reading_service.select_card 内の定型文と同一内容を保つこと
        "texts": {
            "caution_ja": "本結果は内省を助けるためのメッセージです。最終判断はご自身で行ってください。",
            "caution_en": (
                "This result is a message to support self-reflection. "
                "Please make the final decision yourself."
            ),
            "caution_zh": "本结果仅为帮助自我反思的讯息，最终决定请由您自己做出。",
        },
        "rules": {
            "free_daily_draw_limit": config.free_daily_draw_limit,
            "free_history_limit": config.history.free_visible_limit,
            "subscription_product_code": config.pricing.subscription_product_code,
            "ticket_products": dict(config.pricing.ticket_products),
            "shuffle": {
                "idle_seconds_min": config.shuffle.idle_seconds_min,
                "idle_seconds_max": config.shuffle.idle_seconds_max,
                "min_swipe_distance": config.shuffle.min_swipe_distance,
            },
        },
        "themes": themes,
        "decks": decks,
        "cards": cards,
        "products": products,
        "links": links,
        "announcements": announcements,
        "live_events": live_events,
    }

    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT_PATH.write_text(
        json.dumps(payload, ensure_ascii=False, indent=1),
        encoding="utf-8",
    )
    size_kb = OUTPUT_PATH.stat().st_size / 1024
    print(f"マスタ資産を書き出しました: {OUTPUT_PATH} ({size_kb:.0f} KB)")
    print(
        f"テーマ{len(themes)}件 / デッキ{len(decks)}件 / カード{len(cards)}件 / "
        f"商品{len(products)}件"
    )


if __name__ == "__main__":
    main()
