from __future__ import annotations

"""カードの図柄をアプリ同梱用のアセットへ変換する。

素材（印刷用・1枚12MB前後）をそのまま同梱するとアプリが肥大するため、
表示に必要な寸法まで落として WebP へ変換する。**手作業で変換しない**
（同じ寸法・同じ品質で作り直せることが大事）。

出力: mobile_app/assets/cards/

  back.webp          … 裏面（44枚共通）
  sample_front.webp  … 表面のサンプル。実図柄が無いカードはこれを出す
  {card_id}.webp     … 実図柄（あれば sample より優先。今回は未配置）

寸法は実物のカードに合わせる（縦120mm : 横70mm）。
`CARD_WIDTH` / `CARD_HEIGHT` がその比率で、画面の拡大表示にも耐える大きさにしてある。

使い方::

    .venv\\Scripts\\python.exe scripts/build_card_assets.py
"""

import argparse
from pathlib import Path

from PIL import Image

ROOT_DIR = Path(__file__).resolve().parents[1]
OUTPUT_DIR = ROOT_DIR / "mobile_app" / "assets" / "cards"
ART_DIR = Path(r"C:\Users\81907\Desktop\オラクルカード\カード図柄")
DOWNLOADS = Path(r"C:\Users\81907\Downloads")

# 実物のカードは縦120mm × 横70mm。比率を崩さない。
CARD_WIDTH = 700
CARD_HEIGHT = 1200  # 700 / 1200 = 0.58333… = 70 / 120

# 画質。WebPの80は、この絵柄では目視で劣化が分からず容量が1/100になる。
WEBP_QUALITY = 80


def _content_box(image: Image.Image) -> tuple[int, int, int, int]:
    """カード本体の範囲を返す（白い余白と、絵の外に付いた説明文を除く）。

    素材には「神託の裏面」のようなキャプションが**カードの外**に入っていることがある。
    そのまま縮小すると、アプリの札にキャプションまで写る。
    ∴ 明るい画素だけの行・列を端から落とす。行の**大半**が暗いことを条件にするため、
    細い帯（キャプション）は本体と見なされない。
    """
    grey = image.convert("L")
    width, height = grey.size
    pixels = grey.load()
    step = 4
    # その行・列の何割が暗ければ本体とみなすか
    row_need = (width // step) * 0.5
    col_need = (height // step) * 0.5

    rows = [
        y
        for y in range(height)
        if sum(1 for x in range(0, width, step) if pixels[x, y] < 110) > row_need
    ]
    cols = [
        x
        for x in range(width)
        if sum(1 for y in range(0, height, step) if pixels[x, y] < 110) > col_need
    ]
    if not rows or not cols:
        return (0, 0, width, height)
    return (cols[0], rows[0], cols[-1] + 1, rows[-1] + 1)


def _to_card(
    source: Path, destination: Path, *, label: str, crop: bool = False
) -> None:
    """素材を CARD_WIDTH × CARD_HEIGHT の WebP へ変換する。

    **比率が違う素材は引き延ばす**（切り取らない）。裏面のように
    「横に圧縮して合わせる」という指示があるため、余白を作らず全面を使う。
    どれだけ変形したかは必ず表示する（黙って歪ませない）。

    [crop] は**絵の外にキャプションや白余白がある素材にだけ**指定する。
    表面の図柄は淡い金の枠まで含めて1枚の絵なので、自動検出に任せると
    枠を切り落として比率を壊す（実際に +5.7% 変形させた）。
    """
    if not source.exists():
        raise SystemExit(f"素材が見つかりません: {source}")

    with Image.open(source) as image:
        original = image.size
        box = _content_box(image) if crop else (0, 0, *original)
        cropped = image.crop(box) if box != (0, 0, *original) else image
        before = cropped.size
        before_ratio = before[0] / before[1]
        target_ratio = CARD_WIDTH / CARD_HEIGHT
        resized = cropped.convert("RGB").resize(
            (CARD_WIDTH, CARD_HEIGHT), Image.LANCZOS
        )
        destination.parent.mkdir(parents=True, exist_ok=True)
        resized.save(destination, "WEBP", quality=WEBP_QUALITY, method=6)

    stretch = (target_ratio / before_ratio - 1) * 100
    size_kb = destination.stat().st_size / 1024
    note = "比率そのまま" if abs(stretch) < 0.5 else f"横へ {stretch:+.1f}% 変形"
    crop_note = (
        "" if before == original else f"／余白を除去 {original[0]}x{original[1]}→"
    )
    print(
        f"  {label}: {crop_note}{before[0]}x{before[1]} → {CARD_WIDTH}x{CARD_HEIGHT}"
        f"（{note}）{size_kb:,.0f} KB"
    )


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--back",
        type=Path,
        default=DOWNLOADS / "カード裏面.png",
        help="裏面の素材",
    )
    parser.add_argument(
        "--sample",
        type=Path,
        default=ART_DIR / "11カード120×70.png",
        help="表面サンプルの素材（実図柄が無いカードに使う）",
    )
    args = parser.parse_args(argv)

    # 裏面の素材は絵の下に「神託の裏面」のキャプションが付いているため切り抜く。
    _to_card(args.back, OUTPUT_DIR / "back.webp", label="裏面", crop=True)
    _to_card(args.sample, OUTPUT_DIR / "sample_front.webp", label="表面サンプル")

    total = sum(path.stat().st_size for path in OUTPUT_DIR.glob("*.webp"))
    print(f"書き出しました: {OUTPUT_DIR}（合計 {total / 1024:,.0f} KB）")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
