"""リーディング拡張のためのマスタDB整備（2026-09-10 承認方針 D1〜D8）。

やること（すべて冪等。何度実行しても同じ状態になる）:
  1. 実行前に `DB/backup/` へ日付き複製を保存する。
  2. 新シートを追加または更新する。
     - `スプレッド定義`      : 種別・枚数・必要チケット・対象プラン（D1）
     - `ポジション定義`      : 各スプレッドの位置と文中での役割（D2）
     - `接続表現マスタ`      : トーン別の導入句・接続句・締め句（D6）
     - `テーマジャンル対応`  : theme_id ↔ ジャンル（D8。従来はコードにハードコード）
  3. `文脈パターンDB` のプレースホルダ誤字 `{基本的意意味}` を修正する（D4）。
  4. `質問タイプ分類` に判定用の列を追加する（D3）。
     既存の「キーワード例」は読点区切りでそのまま判定に使えるため複製せず、
     機械判定に足りない **優先度** と、「または」で2値が同居している **状況判定** の
     分解列（状況判定1／状況判定2）だけを補う。

やらないこと:
  - 既存シート・既存列の削除や並べ替え（非破壊）。
  - 44柱のテーマ別解釈の6分割（D5）＝文章の執筆が必要なためオーナー作業。

実行::

    .venv\\Scripts\\python.exe scripts/extend_reading_db.py
"""

from __future__ import annotations

import argparse
import shutil
from datetime import datetime
from pathlib import Path

from openpyxl import load_workbook
from openpyxl.styles import Font
from openpyxl.worksheet.worksheet import Worksheet

DB_PATH = Path(r"C:\Users\81907\Desktop\オラクルカード\DB\日本神話オラクルカード DB.xlsx")

# --- D1: スプレッド定義 -------------------------------------------------------
# 必要チケットは 2026-09-10 承認: リーディングは一律5枚／本日の託宣は無料。
# 対象プランは billing の PlanType（free / ticket / subscription）に対応する。
SPREADS_HEADER = [
    "spread_id", "名称", "種別", "枚数", "最小枚数", "最大枚数",
    "用途", "必要チケット", "対象プラン", "表示順",
]
SPREADS_ROWS = [
    ["daily", "本日の託宣", "oracle", 1, 1, 1,
     "今日一日の指針を一枚に問う", 0, "free,ticket,subscription", 1],
    ["three", "3枚リーディング", "reading", 3, 3, 3,
     "過去・現在・未来の流れを読む", 5, "ticket,subscription", 2],
    ["five", "5枚リーディング", "reading", 5, 5, 5,
     "状況の全体像と取るべき道を読む", 5, "ticket,subscription", 3],
    ["seven", "7枚リーディング", "reading", 7, 7, 7,
     "事情を深く掘り下げて読む", 5, "ticket,subscription", 4],
    ["free", "フリーリーディング", "reading", 0, 1, 7,
     "枚数を自分で決めて読む", 5, "ticket,subscription", 5],
]

# --- D2: ポジション定義 -------------------------------------------------------
# 「文中での役割」は文章生成の構成層が段落の順序と接続を決めるために使う。
POSITIONS_HEADER = ["spread_id", "位置No", "位置名", "位置の意味", "文中での役割"]
POSITIONS_ROWS = [
    ["daily", 1, "本日の一枚", "今日一日を貫くテーマ", "導入と結論を兼ねる"],

    ["three", 1, "過去", "ここへ至るまでの流れと背景", "導入として背景を述べる"],
    ["three", 2, "現在", "いまの状況と立ち位置", "核心として現状を述べる"],
    ["three", 3, "未来", "この流れが向かう先", "結びとして見通しを述べる"],

    ["five", 1, "現状", "相談者が置かれている状況", "導入として現状を述べる"],
    ["five", 2, "原因", "状況を作っている背景", "展開として原因を述べる"],
    ["five", 3, "課題", "いま向き合うべきこと", "核心として課題を述べる"],
    ["five", 4, "助言", "取るべき姿勢と行動", "転換として助言を述べる"],
    ["five", 5, "結果", "その先に訪れる状態", "結びとして見通しを述べる"],

    ["seven", 1, "現状", "相談者が置かれている状況", "導入として現状を述べる"],
    ["seven", 2, "過去", "ここへ至るまでの流れ", "展開として背景を述べる"],
    ["seven", 3, "近い未来", "間もなく訪れる変化", "展開として兆しを述べる"],
    ["seven", 4, "本心", "相談者自身の望みと迷い", "核心として内面を述べる"],
    ["seven", 5, "周囲", "相手や環境の状態", "展開として外側を述べる"],
    ["seven", 6, "障害", "越えるべき壁", "核心として課題を述べる"],
    ["seven", 7, "結末", "最終的に落ち着く場所", "結びとして見通しを述べる"],

    ["free", 1, "一枚目", "問いに対する最初の答え", "導入として全体を述べる"],
    ["free", 2, "二枚目", "問いを深める視点", "展開として補足を述べる"],
    ["free", 3, "三枚目", "問いを深める視点", "展開として補足を述べる"],
    ["free", 4, "四枚目", "問いを深める視点", "展開として補足を述べる"],
    ["free", 5, "五枚目", "問いを深める視点", "展開として補足を述べる"],
    ["free", 6, "六枚目", "問いを深める視点", "展開として補足を述べる"],
    ["free", 7, "七枚目", "問いに対する結び", "結びとして見通しを述べる"],
]

# --- D6: 接続表現マスタ -------------------------------------------------------
# 段落を繋ぐ言葉が無いことが「文章が繋がらない」直接の原因（作業1 §2.3）。
# トーン名は既存シート「感情トーン設定」の10種と一致させる。
CONNECTORS_HEADER = ["トーン名", "導入句", "接続句", "締め句"]
CONNECTORS_ROWS = [
    ["励ましトーン", "いま、あなたのもとに届いているのは", "そして", "この流れに身を委ねてみてください。"],
    # 2026-09-10 承認: 導入句を「降りてきた託宣は」へ変更（ご指摘②）。
    ["優しいトーン", "降りてきた託宣は", "また", "どうかご自身をいたわりながら進んでください。"],
    ["明確なトーン", "はっきりと示されているのは", "さらに", "いまが動くべき時です。"],
    ["神秘的トーン", "静かに示されているのは", "そのうえで", "この兆しは、あなたを導いています。"],
    ["実用的トーン", "いま整えるべきなのは", "続いて", "小さな一歩から始めてください。"],
    ["警告トーン", "気に留めておきたいのは", "一方で", "急がず、足元を確かめて進んでください。"],
    ["祝福トーン", "喜びとともに示されているのは", "そして", "この巡り合わせを受け取ってください。"],
    ["中立トーン", "いま示されているのは", "また", "この時期の流れとして受け止めてください。"],
    ["共感トーン", "あなたの心に寄り添うように現れたのは", "そして", "その気持ちは、決して不自然なものではありません。"],
    ["権威的トーン", "神託として告げられているのは", "さらに", "これは定められた流れです。"],
]

# --- D8: テーマ↔ジャンル -----------------------------------------------------
THEME_GENRE_HEADER = ["theme_id", "テーマ名", "ジャンル"]
THEME_GENRE_ROWS = [
    ["love", "恋愛・人間関係", "恋愛"],
    ["work", "仕事・キャリア", "仕事"],
    ["money", "金運・財運", "金運"],
    ["health", "健康・体調", "健康"],
    ["subconscious", "潜在意識", "精神"],
    ["higher_self", "ハイヤーセルフ", "精神"],
]

# --- D3: 質問タイプ分類へ足す列 ----------------------------------------------
QUESTION_EXTRA_COLUMNS = ["状況判定1", "状況判定2", "優先度"]
SITUATION_SEPARATOR = "または"


def _backup(path: Path) -> Path:
    backup_dir = path.parent / "backup"
    backup_dir.mkdir(parents=True, exist_ok=True)
    dest = backup_dir / f"{path.stem}_{datetime.now():%Y%m%d_%H%M%S}前{path.suffix}"
    shutil.copy2(path, dest)
    return dest


def _write_sheet(wb, title: str, header: list[str], rows: list[list]) -> str:
    """シートを作成または全面更新する（既存なら中身だけ入れ替える＝冪等）。"""
    created = title not in wb.sheetnames
    if created:
        ws: Worksheet = wb.create_sheet(title)
    else:
        ws = wb[title]
        ws.delete_rows(1, ws.max_row)
    ws.append(header)
    for cell in ws[1]:
        cell.font = Font(bold=True)
    for row in rows:
        ws.append(row)
    return "新規作成" if created else "更新"


def _fix_placeholder_typo(wb) -> int:
    """`{基本的意意味}` → `{基本的意味}`（置換されず生表示される事故を止める）。"""
    fixed = 0
    ws = wb["文脈パターンDB"]
    for row in ws.iter_rows(min_row=2):
        for cell in row:
            if isinstance(cell.value, str) and "{基本的意意味}" in cell.value:
                cell.value = cell.value.replace("{基本的意意味}", "{基本的意味}")
                fixed += 1
    return fixed


def _extend_question_types(wb) -> int:
    """状況判定の「または」を2列へ分解し、優先度（行順）を付与する。"""
    ws = wb["質問タイプ分類"]
    header = [cell.value for cell in ws[1]]
    for name in QUESTION_EXTRA_COLUMNS:
        if name not in header:
            header.append(name)
            ws.cell(row=1, column=len(header), value=name).font = Font(bold=True)
    idx_situation = header.index("状況判定") + 1
    idx_s1 = header.index("状況判定1") + 1
    idx_s2 = header.index("状況判定2") + 1
    idx_priority = header.index("優先度") + 1

    updated = 0
    priority = 0
    for row in range(2, ws.max_row + 1):
        if not ws.cell(row=row, column=1).value:
            continue
        priority += 1
        raw = str(ws.cell(row=row, column=idx_situation).value or "")
        parts = [part.strip() for part in raw.split(SITUATION_SEPARATOR) if part.strip()]
        ws.cell(row=row, column=idx_s1, value=parts[0] if parts else "")
        ws.cell(row=row, column=idx_s2, value=parts[1] if len(parts) > 1 else "")
        ws.cell(row=row, column=idx_priority, value=priority)
        updated += 1
    return updated


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--db", type=Path, default=DB_PATH, help="マスタDBのxlsx")
    parser.add_argument(
        "--no-backup", action="store_true", help="実行前の複製を作らない（非推奨）"
    )
    args = parser.parse_args(argv)

    if not args.db.exists():
        print(f"マスタDBが見つかりません: {args.db}")
        return 1

    if not args.no_backup:
        print(f"複製を作成: {_backup(args.db)}")

    wb = load_workbook(args.db)
    report = [
        f"スプレッド定義: {_write_sheet(wb, 'スプレッド定義', SPREADS_HEADER, SPREADS_ROWS)}"
        f"（{len(SPREADS_ROWS)}件）",
        f"ポジション定義: {_write_sheet(wb, 'ポジション定義', POSITIONS_HEADER, POSITIONS_ROWS)}"
        f"（{len(POSITIONS_ROWS)}件）",
        f"接続表現マスタ: {_write_sheet(wb, '接続表現マスタ', CONNECTORS_HEADER, CONNECTORS_ROWS)}"
        f"（{len(CONNECTORS_ROWS)}件）",
        f"テーマジャンル対応: "
        f"{_write_sheet(wb, 'テーマジャンル対応', THEME_GENRE_HEADER, THEME_GENRE_ROWS)}"
        f"（{len(THEME_GENRE_ROWS)}件）",
        f"文脈パターンDBの誤字修正: {_fix_placeholder_typo(wb)}セル",
        f"質問タイプ分類の判定列: {_extend_question_types(wb)}行",
    ]
    wb.save(args.db)

    for line in report:
        print(f"  - {line}")
    print(f"保存しました: {args.db}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
