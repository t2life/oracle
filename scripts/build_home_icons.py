"""ホーム画面右上のアイコン3種（≡ / LANG / スピーカー）を同一寸法へ揃える。

背景:
    提供素材は ≡=152x150 / LANG=153x196 / スピーカー=152x152 と縦横比がばらばらで、
    高さを揃えて並べると**横幅が不揃い**になっていた（LANGだけ約34px＝他は約44px）。

方針:
    1. 各素材から「バッジ（銀色の円／地球儀）」の直径を実測する。
    2. **バッジ直径を揃えて**、共通の正方形キャンバスへ中央配置する。
       ＝ 表示時に横幅・高さ・円の大きさがすべて一致する。
    3. 余白は素材自身の地色（濃紺）で埋める＝見た目の継ぎ目を作らない。

実行例::

    python scripts/build_home_icons.py

出力は `mobile_app/assets/home/` の各PNGを上書きする（元素材は Google ドライブ側に残る）。
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path

import numpy as np
from PIL import Image

REPO_ROOT = Path(__file__).resolve().parents[1]
ASSET_DIR = REPO_ROOT / "mobile_app" / "assets" / "home"

# 共通の正方形キャンバスとバッジ直径（LANGは文字が入るぶん縦に余裕が要る）。
CANVAS = 184
BADGE = 132

# バッジ（銀色）とみなす明るさ。
BRIGHT = 110

# 各素材の「バッジ高さ」の測り方。LANGは下部の"LANG"文字を除くため上側だけを見る。
SOURCES: dict[str, dict[str, object]] = {
    "icon_menu.png": {"badge_rows": None},
    "icon_lang.png": {"badge_rows": (0, 140)},
    "icon_speaker.png": {"badge_rows": None},
}


def badge_diameter(rgb: np.ndarray, rows: tuple[int, int] | None) -> float:
    """バッジ（銀色の円）の直径を、明るい画素の縦方向の広がりから測る。"""
    lum = rgb.mean(axis=2)
    region = lum if rows is None else lum[rows[0] : rows[1]]
    bright = region > BRIGHT
    ys = np.nonzero(bright.sum(axis=1) > 0)[0]
    if ys.size == 0:
        raise RuntimeError("バッジを検出できません")
    return float(ys.max() - ys.min() + 1)


def base_color(rgb: np.ndarray) -> tuple[int, int, int]:
    """地色（濃紺）。四隅の中央値を採る。"""
    h, w, _ = rgb.shape
    corners = np.concatenate(
        [
            rgb[0:8, 0:8].reshape(-1, 3),
            rgb[0:8, w - 8 : w].reshape(-1, 3),
            rgb[h - 8 : h, 0:8].reshape(-1, 3),
            rgb[h - 8 : h, w - 8 : w].reshape(-1, 3),
        ]
    )
    median = np.median(corners, axis=0).round().astype(int)
    return int(median[0]), int(median[1]), int(median[2])


def build(name: str, rows: tuple[int, int] | None, asset_dir: Path) -> dict[str, object]:
    path = asset_dir / name
    source = Image.open(path).convert("RGB")
    rgb = np.asarray(source, dtype=np.float32)
    diameter = badge_diameter(rgb, rows)
    scale = BADGE / diameter
    resized = source.resize(
        (max(1, round(source.width * scale)), max(1, round(source.height * scale))),
        Image.LANCZOS,
    )
    canvas = Image.new("RGB", (CANVAS, CANVAS), base_color(rgb))
    # 中央配置。はみ出す場合は中央基準で切り取る（例: スピーカーの音波）。
    left = (CANVAS - resized.width) // 2
    top = (CANVAS - resized.height) // 2
    canvas.paste(resized, (left, top))
    canvas.save(path)
    return {
        "素材": name,
        "元寸法": f"{source.width}x{source.height}",
        "バッジ直径": round(diameter, 1),
        "倍率": round(scale, 3),
        "出力": f"{CANVAS}x{CANVAS}",
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--asset-dir", type=Path, default=ASSET_DIR, help="アイコンの配置先"
    )
    args = parser.parse_args(argv)

    results = [
        build(name, spec["badge_rows"], args.asset_dir)  # type: ignore[arg-type]
        for name, spec in SOURCES.items()
    ]
    print(json.dumps(results, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
