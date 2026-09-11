"""リーディング拡張のためのマスタDB整備（2026-09-10 承認方針 D1〜D8）。

やること（すべて冪等。何度実行しても同じ状態になる）:
  1. 実行前に `DB/backup/` へ日付き複製を保存する。
  2. 新シートを追加または更新する。
     - `スプレッド定義`      : 種別・枚数・必要チケット・対象プラン（D1）
     - `ポジション定義`      : 各スプレッドの位置と文中での役割（D2）
     - `接続表現マスタ`      : トーン別の導入句・接続句・締め句（D6）
     - `テーマジャンル対応`  : theme_id ↔ ジャンル（D8。従来はコードにハードコード）
     - `禁止表現マスタ`      : 生成文に現れてはならない表現（2026-09-11）
     - `位置別語り口マスタ`  : 位置ごとの文末・語り口（2026-09-11）
     - `番号解釈マスタ`      : エレメント→時間の単位、番号→数量（2026-09-11）
     - `番号解釈キーワード`  : 期日・数量を問う語（これが無ければ数字を語らない）
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

# --- 禁止表現マスタ（2026-09-11）---------------------------------------------
# 出所: 先行アプリ（吉凶羅針盤）の `Constants.FORTUNE_FORBIDDEN_ASSERTIONS`。
# あちらは docs/150 §4.8 で「生成AIによる文章生成」を意図的に見送り、代わりに
# **人のレビューに頼らず機械で守る**禁止語を置いて全生成文へ当てている。
# 本アプリも 2026-09-11 に同じ判断（外部AIを使わない）をしたため、同じ規律を採る。
# 内蔵エンジンが組み立てる託宣文へ当て、健康の治癒・金銭の増減・恐怖訴求・
# 保証と読める語が出ないことをテストで固定する。
# ★コードに直書きしない。語を足す・外すのはこのシートで行う。
# --- 番号解釈（2026-09-11 承認）----------------------------------------------
# オラクルデッキに標準の数秘体系は無く、意味づけは制作者が決めてよい（WEB調査）。
# 一方タロットの「期日の読み」は定型があり、**スートが時間の単位・数字が数量**を担う。
# 本デッキはスートに相当するものを既に持っている＝**エレメント**。
# ∴ 体系を発明せず、確立した対応をそのまま移す。
#   火=日／風=週／水=月／地=年／エーテル=期日を定めない（大アルカナと同じ扱い）
# 上限を超える数は年数などが非現実的になるため、幅のある言い方へ切り替える。
NUMBER_HEADER = [
    "エレメント", "単位", "上限", "定型文", "超過時の定型文", "数量の定型文",
]
NUMBER_ROWS = [
    ["火", "日", 30,
     "時期でいえば、およそ{n}{unit}のうちに動きが出てきます。",
     "時期でいえば、少し先になりますが、確かに巡ってきます。",
     "数にすれば{n}ほどが目安です。"],
    ["風", "週", 12,
     "時期でいえば、およそ{n}{unit}のうちに風向きが変わります。",
     "時期でいえば、しばらく間がありますが、便りは届きます。",
     "数にすれば{n}ほどが目安です。"],
    ["水", "月", 18,
     "時期でいえば、およそ{n}{unit}のうちに形になっていきます。",
     "時期でいえば、ゆっくりと、しかし確かに満ちていきます。",
     "数にすれば{n}ほどが目安です。"],
    ["地", "年", 10,
     "時期でいえば、およそ{n}{unit}をかけて根づいていきます。",
     "時期でいえば、長い目で見る流れです。急がずに進めてください。",
     "数にすれば{n}ほどが目安です。"],
    ["エーテル", "", 0,
     "時期は定まっていません。時が満ちたときに、自ずと動きます。",
     "時期は定まっていません。時が満ちたときに、自ずと動きます。",
     "数では測れない巡り合わせです。"],
]

# 期日・数量を問われたときだけ数字を語る（常時は語らない＝オラクルの作法）。
# 判定はこの語の部分一致。足す・外すはこのシートで行う。
NUMBER_KEYWORD_HEADER = ["区分", "キーワード"]
NUMBER_KEYWORD_ROWS = [
    ["時期", "いつ"], ["時期", "時期"], ["時期", "いつごろ"], ["時期", "いつ頃"],
    ["時期", "どのくらいで"], ["時期", "どれくらいで"], ["時期", "期限"],
    ["時期", "締め切り"], ["時期", "間に合"], ["時期", "タイミング"],
    ["数量", "何人"], ["数量", "何回"], ["数量", "何件"], ["数量", "何個"],
    ["数量", "いくつ"], ["数量", "どれだけ"], ["数量", "何日"], ["数量", "何度"],
]

# --- 位置別の語り口（2026-09-11）-------------------------------------------
# 従来は全ポジション共通で「〜という意味合いが示されています」と締めていた。
# どの位置でも同じ文末になるため、**一覧を読み上げただけ**の印象を与えていた。
# 占いの実務では、文末は位置（時制）で変わる（WEB調査）:
#   過去 … 「〜てきました」「〜かもしれません」（振り返り・断定しない）
#   現在 … 「〜ています」「〜と言えますね」（今を言い切る）
#   未来 … 「〜でしょう」「可能性が高いです」（可能性として述べる）
# ∴ 位置名ごとに語り口を持ち、カードごとに決定的に選び分ける。
# 差し込み: {name}=神名／{phrase}=意味の句／{meaning}=位置の意味
# ★「必ず」「絶対」等は禁止表現マスタが機械で弾く。断定しない言い回しにすること。
VOICE_HEADER = ["位置名", "語り口1", "語り口2", "語り口3"]
VOICE_ROWS = [
    ["本日の一枚",
     "今日のあなたへ、{name}が{phrase}という便りを届けています。",
     "{name}が示すのは、{phrase}——そんな一日です。",
     "今日は{name}とともに、{phrase}を心に置いて過ごしてみてください。"],
    ["過去",
     "【過去】{name}。ここまでのあなたは、{phrase}という流れの中にいました。",
     "【過去】{name}。{meaning}には、{phrase}が横たわっていたようです。",
     "【過去】{name}。{phrase}が、いまへ続く土台をつくってきました。"],
    ["現在",
     "【現在】{name}。いまは{phrase}が前に出てきています。",
     "【現在】{name}。{meaning}は、{phrase}という局面にあると言えますね。",
     "【現在】{name}。あなたのまわりで、{phrase}が動き始めています。"],
    ["現状",
     "【現状】{name}。いま置かれているのは、{phrase}という状況です。",
     "【現状】{name}。{meaning}には、{phrase}が色濃く出ています。",
     "【現状】{name}。{phrase}——それが、いまのあなたの立ち位置です。"],
    ["未来",
     "【未来】{name}。このまま進めば、{phrase}へ向かう可能性が高いでしょう。",
     "【未来】{name}。やがて{phrase}が、あなたのもとへ巡ってきそうです。",
     "【未来】{name}。この先には、{phrase}が待っているでしょう。"],
    ["近い未来",
     "【近い未来】{name}。ほどなく、{phrase}が形になってきそうです。",
     "【近い未来】{name}。まもなく{phrase}の気配が濃くなるでしょう。",
     "【近い未来】{name}。次に訪れるのは、{phrase}という場面です。"],
    ["原因",
     "【原因】{name}。ここに至った背景には、{phrase}がありました。",
     "【原因】{name}。{meaning}をたどると、{phrase}に行き着きます。",
     "【原因】{name}。{phrase}が、いまの流れを生んでいるようです。"],
    ["課題",
     "【課題】{name}。越えていきたいのは、{phrase}という一点です。",
     "【課題】{name}。{meaning}として、{phrase}が問われています。",
     "【課題】{name}。{phrase}と向き合うことが、次への鍵になりそうです。"],
    ["助言",
     "【助言】{name}。{phrase}に意識を向けてみてください。",
     "【助言】{name}。{phrase}——そこに、進むための手がかりがあります。",
     "【助言】{name}。いまは{phrase}を選ぶことが、あなたを助けてくれるでしょう。"],
    ["結果",
     "【結果】{name}。行き着く先には、{phrase}が見えています。",
     "【結果】{name}。{meaning}として示されたのは、{phrase}です。",
     "【結果】{name}。最後には、{phrase}という形に落ち着いていくでしょう。"],
    ["結末",
     "【結末】{name}。この流れの果てには、{phrase}が待っているでしょう。",
     "【結末】{name}。{meaning}は、{phrase}という姿をしています。",
     "【結末】{name}。たどり着くのは、{phrase}という場所です。"],
    ["本心",
     "【本心】{name}。心の奥では、{phrase}を求めているのかもしれません。",
     "【本心】{name}。{meaning}に触れると、{phrase}が見えてきます。",
     "【本心】{name}。口には出さずとも、{phrase}があなたの本当の願いのようです。"],
    ["周囲",
     "【周囲】{name}。まわりの人たちは、{phrase}という目であなたを見ています。",
     "【周囲】{name}。{meaning}には、{phrase}が漂っています。",
     "【周囲】{name}。あなたを取り巻く空気は、{phrase}に傾いているようです。"],
    ["障害",
     "【障害】{name}。歩みを鈍らせているのは、{phrase}のようです。",
     "【障害】{name}。{meaning}として、{phrase}が立ちはだかっています。",
     "【障害】{name}。{phrase}——ここが、いま引っかかっている点です。"],
]
# フリーリーディング（一枚目〜七枚目）は位置に時制の意味が無いため共通の語り口。
for _index, _label in enumerate(
    ["一枚目", "二枚目", "三枚目", "四枚目", "五枚目", "六枚目", "七枚目"], start=1
):
    VOICE_ROWS.append([
        _label,
        f"【{_label}】{{name}}。ここでは、{{phrase}}が語りかけています。",
        f"【{_label}】{{name}}。{{phrase}}——そんな響きが届いています。",
        f"【{_label}】{{name}}。{{phrase}}を、この流れの中に受け取ってください。",
    ])

FORBIDDEN_HEADER = ["表現", "区分", "理由"]
FORBIDDEN_ROWS = [
    ["治りま", "健康", "治癒の断定は医療表現にあたる"],
    ["治る", "健康", "治癒の断定は医療表現にあたる"],
    ["完治", "健康", "治癒の断定は医療表現にあたる"],
    ["病気が", "健康", "症状・病名への言及は避ける"],
    ["健康になり", "健康", "効果の断定は医療表現にあたる"],
    ["儲か", "金銭", "収益の断定は投資助言にあたる"],
    ["損をし", "金銭", "損失の断定は投資助言にあたる"],
    ["収入が増え", "金銭", "収益の断定は投資助言にあたる"],
    ["金運が上がり", "金銭", "収益の断定は投資助言にあたる"],
    ["必ず得", "金銭", "利得の保証と読める"],
    ["不幸", "恐怖訴求", "不安を煽る表現"],
    ["災い", "恐怖訴求", "不安を煽る表現"],
    ["祟", "恐怖訴求", "不安を煽る表現"],
    ["呪", "恐怖訴求", "不安を煽る表現"],
    ["必ず", "断定", "結果の保証と読める"],
    ["絶対", "断定", "結果の保証と読める"],
    ["危険です", "断定", "警告として読まれる"],
    ["警告", "断定", "警告として読まれる"],
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
        f"禁止表現マスタ: "
        f"{_write_sheet(wb, '禁止表現マスタ', FORBIDDEN_HEADER, FORBIDDEN_ROWS)}"
        f"（{len(FORBIDDEN_ROWS)}件）",
        f"位置別語り口マスタ: "
        f"{_write_sheet(wb, '位置別語り口マスタ', VOICE_HEADER, VOICE_ROWS)}"
        f"（{len(VOICE_ROWS)}件）",
        f"番号解釈マスタ: "
        f"{_write_sheet(wb, '番号解釈マスタ', NUMBER_HEADER, NUMBER_ROWS)}"
        f"（{len(NUMBER_ROWS)}件）",
        f"番号解釈キーワード: "
        f"{_write_sheet(wb, '番号解釈キーワード', NUMBER_KEYWORD_HEADER, NUMBER_KEYWORD_ROWS)}"
        f"（{len(NUMBER_KEYWORD_ROWS)}件）",
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
