from __future__ import annotations

"""規約・プライバシーポリシーの公開ページを生成する。

出力: system/site/oracle/{privacy,terms}.html（手動編集禁止）

掲載先は提供元の共通サイト `apps2craft.com` で、アプリごとにディレクトリを分ける
方式に合わせる（先行アプリは `/geokarmacompass/…`・本アプリは `/oracle/…`）。
見た目も先行アプリの `jyuuni-tensui-chireki/scripts/build_site.py` と同じ雛形に揃え、
2つのアプリのページが別物に見えないようにする。

本文の単一真実源は `docs/仕様書/09_プライバシーポリシー.md` と `15_利用規約.md`。
**HTMLを手で直さない**。文面を変えたい時はmdを直して本スクリプトを再実行する。

掲載しない節（内部向け）は [DOCUMENTS] の `skip_sections` で明示する。
文書情報・更新履歴・「今後の対応事項」は社内の管理情報であり、
利用者が読む規約に混ぜない。

使い方:
    python scripts/build_legal_site.py
    → system/site/oracle/ をサーバー（apps2craft.com）の /oracle/ へアップロードする
"""

import html
import json
import re
from dataclasses import dataclass, field
from pathlib import Path

ROOT_DIR = Path(__file__).resolve().parents[1]
DOCS_DIR = ROOT_DIR / "docs" / "仕様書"
OUTPUT_DIR = ROOT_DIR / "site" / "oracle"
# 事業者情報（氏名・住所・電話番号）。本リポジトリは公開のため実値は置かず、
# .gitignore 済みのこのファイルから差し込む。ひな形は business_info.example.json。
BUSINESS_INFO_PATH = Path(__file__).resolve().parent / "business_info.local.json"

APP_NAME = "日本神話オラクルロンカード"
PROVIDER = "Apps2Craft"
SUPPORT_EMAIL = "support@apps2craft.com"


@dataclass(frozen=True)
class Document:
    """1ページぶんの定義。"""

    source: str
    output: str
    title: str
    # 掲載しない見出し（前方一致）。内部向けの節を公開ページへ出さないため。
    skip_sections: tuple[str, ...] = field(default_factory=tuple)


DOCUMENTS: tuple[Document, ...] = (
    Document(
        source="09_プライバシーポリシー.md",
        output="privacy.html",
        title="プライバシーポリシー",
        skip_sections=("1. 文書情報", "13. 実装メモ", "14. 更新履歴"),
    ),
    Document(
        source="15_利用規約.md",
        output="terms.html",
        title="利用規約",
        skip_sections=("1. 文書情報", "更新履歴"),
    ),
    Document(
        source="14_特定商取引法に基づく表記.md",
        output="tokushoho.html",
        title="特定商取引法に基づく表記",
        skip_sections=("1. 文書情報", "3. 確定の経緯", "4. 更新履歴"),
    ),
)

# 確定していない項目を含んだまま公開すると、法定表示として成立しない。
# 生成そのものを止める（警告だけでは見落とすため）。
UNRESOLVED_MARKER = "【要確定】"


def load_business_info() -> dict[str, str]:
    """事業者情報を読む。無ければ生成しない（空欄のまま公開しないため）。"""
    if not BUSINESS_INFO_PATH.exists():
        raise SystemExit(
            f"{BUSINESS_INFO_PATH.name} がありません。"
            f"{BUSINESS_INFO_PATH.with_name('business_info.example.json').name} を"
            "複製して実値を記入してください（このファイルはコミットされません）。"
        )
    data = json.loads(BUSINESS_INFO_PATH.read_text(encoding="utf-8"))
    return {k: str(v) for k, v in data.items() if not k.startswith("_")}


def expand(text: str, business_info: dict[str, str]) -> str:
    """`${項目名}` を事業者情報で置き換える。未知の項目は失敗させる
    （空文字で埋めると、欠けたまま公開ページができてしまう）。"""

    def replace(match: "re.Match[str]") -> str:
        key = match.group(1)
        if key not in business_info:
            raise SystemExit(
                f"事業者情報に '{key}' がありません（{BUSINESS_INFO_PATH.name} を確認）"
            )
        return business_info[key]

    return re.sub(r"\$\{([^}]+)\}", replace, text)


def _inline(text: str) -> str:
    """行内の記法だけを変換する。装飾は足さない。"""
    escaped = html.escape(text)
    escaped = re.sub(r"\*\*(.+?)\*\*", r"<strong>\1</strong>", escaped)
    escaped = re.sub(r"`(.+?)`", r"<code>\1</code>", escaped)
    return escaped


def _is_table_row(line: str) -> bool:
    return line.startswith("|") and line.endswith("|")


def _is_table_divider(line: str) -> bool:
    return _is_table_row(line) and set(line.replace("|", "").strip()) <= set("-: ")


def _cells(line: str) -> list[str]:
    return [cell.strip() for cell in line.strip("|").split("|")]


def to_html(markdown: str, skip_sections: tuple[str, ...]) -> str:
    """見出し・段落・箇条書き・表・引用だけを扱う小さな変換器。

    掲載しない節に入ったら、次の見出しまで読み飛ばす。
    """
    out: list[str] = []
    bullets: list[str] = []
    table: list[list[str]] = []
    skipping = False

    def flush_bullets() -> None:
        if bullets:
            out.append("<ul>" + "".join(f"<li>{b}</li>" for b in bullets) + "</ul>")
            bullets.clear()

    def flush_table() -> None:
        if not table:
            return
        header, *rows = table
        head = "".join(f"<th>{cell}</th>" for cell in header)
        body = "".join(
            "<tr>" + "".join(f"<td>{cell}</td>" for cell in row) + "</tr>"
            for row in rows
        )
        out.append(f"<table><thead><tr>{head}</tr></thead><tbody>{body}</tbody></table>")
        table.clear()

    def flush_all() -> None:
        flush_bullets()
        flush_table()

    for raw in markdown.splitlines():
        line = raw.rstrip()
        stripped = line.strip()

        if stripped.startswith("#"):
            flush_all()
            heading = stripped.lstrip("#").strip()
            skipping = any(heading.startswith(skip) for skip in skip_sections)
            if skipping or stripped.startswith("# "):
                # H1 はページ見出しとして別に描くため本文には出さない。
                continue
            # 章番号は社内文書の通し番号。公開ページでは落とす
            # （掲載しない節を抜くと番号が飛び、読み手に意味が無いため）。
            heading = re.sub(r"^\d+\.\s*", "", heading)
            out.append(f"<h2>{_inline(heading)}</h2>")
            continue

        if skipping:
            continue

        if not stripped or stripped == "---":
            flush_all()
            continue

        if _is_table_divider(stripped):
            continue
        if _is_table_row(stripped):
            flush_bullets()
            table.append([_inline(cell) for cell in _cells(stripped)])
            continue
        flush_table()

        if stripped.startswith(("- ", "* ")):
            bullets.append(_inline(stripped[2:]))
            continue
        numbered = re.match(r"^\d+\.\s+(.*)$", stripped)
        if numbered:
            bullets.append(_inline(numbered.group(1)))
            continue
        flush_bullets()

        if stripped.startswith(">"):
            out.append(f"<blockquote><p>{_inline(stripped.lstrip('>').strip())}</p></blockquote>")
            continue

        out.append(f"<p>{_inline(stripped)}</p>")

    flush_all()
    return "\n".join(out)


def page(title: str, body: str, updated: str) -> str:
    """先行アプリ（apps2craft.com）のページと同じ雛形。表だけ追加している。"""
    return f"""<!doctype html>
<html lang="ja">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{html.escape(title)} — {html.escape(APP_NAME)}</title>
<style>
  :root {{ color-scheme: light dark; }}
  body {{ margin:0 auto; padding:24px 16px 64px; max-width:760px;
         font-family:system-ui,-apple-system,"Hiragino Sans","Noto Sans JP",sans-serif;
         line-height:1.9; }}
  h1 {{ font-size:1.5rem; margin:0 0 4px; }}
  h2 {{ font-size:1.05rem; margin:2em 0 .4em; padding-left:.5em;
        border-left:4px solid #7986CB; }}
  p, li {{ margin:.5em 0; }}
  ul {{ padding-left:1.2em; }}
  table {{ border-collapse:collapse; width:100%; margin:1em 0; font-size:.92rem;
          display:block; overflow-x:auto; }}
  th, td {{ border:1px solid rgba(128,128,128,.4); padding:.4em .6em; text-align:left;
           vertical-align:top; }}
  blockquote {{ margin:1em 0; padding:.2em 1em; border-left:4px solid rgba(128,128,128,.4);
               opacity:.9; }}
  code {{ font-size:.9em; }}
  .meta {{ opacity:.7; font-size:.85rem; margin-bottom:2em; }}
  a {{ color:#3f51b5; }}
  footer {{ margin-top:3em; padding-top:1em; border-top:1px solid rgba(128,128,128,.3);
            font-size:.85rem; opacity:.8; }}
</style>
</head>
<body>
<h1>{html.escape(title)}</h1>
<p class="meta">{html.escape(APP_NAME)}／最終更新 {html.escape(updated)}</p>
{body}
<footer>
<p>提供: {html.escape(PROVIDER)}／お問い合わせ:
<a href="mailto:{html.escape(SUPPORT_EMAIL)}">{html.escape(SUPPORT_EMAIL)}</a></p>
</footer>
</body>
</html>
"""


def _updated_date(markdown: str) -> str:
    """文書情報の「作成日」を最終更新として使う（無ければ空欄にしない＝失敗させる）。"""
    match = re.search(r"\|\s*作成日\s*\|\s*([0-9]{4}-[0-9]{2}-[0-9]{2})\s*\|", markdown)
    if match is None:
        raise SystemExit("作成日が読み取れません（文書情報の表を確認してください）")
    return match.group(1)


def main() -> int:
    business_info = load_business_info()
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    for document in DOCUMENTS:
        source = DOCS_DIR / document.source
        if not source.exists():
            raise SystemExit(f"本文が見つかりません: {source}")
        markdown = expand(source.read_text(encoding="utf-8"), business_info)
        body = to_html(markdown, document.skip_sections)

        if UNRESOLVED_MARKER in body:
            raise SystemExit(
                f"{document.source} に {UNRESOLVED_MARKER} が残っています。"
                "確定してから公開ページを作ってください。"
            )

        destination = OUTPUT_DIR / document.output
        destination.write_text(
            page(document.title, body, _updated_date(markdown)), encoding="utf-8"
        )
        print(f"  {document.output}: {destination.stat().st_size:,} bytes")

    print(f"書き出しました: {OUTPUT_DIR}")
    print("apps2craft.com の /oracle/ へアップロードしてください。")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
