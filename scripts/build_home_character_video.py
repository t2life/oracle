"""ホーム画面のキャラ動画（背景合成済み）を再生成する。

用途:
    原素材（市松模様で透過が焼き込まれたキャラ動画）から市松を抜き、
    寺院背景（bg_temple.png）へ合成して `assets/home/character_home.mp4` を作る。
    キャラの縦位置は ``--dy``（背景に対する下方向オフセット・シーン空間px）で指定する。

背景は全面に敷いたままキャラだけを動かすため、上端の空白も継ぎ目もズームも発生しない。

実行例（既定値のまま再生成する場合）::

    python scripts/build_home_character_video.py --dy 121

注意:
    - ffmpeg は imageio_ffmpeg 同梱版を既定で使う（PATHへの導入は不要）。
    - 原素材は Google ドライブ上にあるため、他PCで実行する場合は ``--src`` を指定する。
    - 出力は無音・ループ用のブーメラン（順再生＋逆再生）で、始点と終点が滑らかに繋がる。
"""

from __future__ import annotations

import argparse
import json
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

import numpy as np
from PIL import Image

# --- 既定値（2026-09-08 の初版合成と同一の座標系） ---------------------------
SCENE_W = 768
SCENE_H = 1024

# 市松（明るい低彩度）の判定と、アンプリマルチプライに用いる市松の代表輝度。
KEY_LUM_HI = 225.0  # これ以上の明度は背景側
KEY_LUM_SOFT = 30.0  # 明度方向のソフトネス
KEY_SAT_LO = 8.0  # これ以下の彩度は背景側
KEY_SAT_SOFT = 12.0  # 彩度方向のソフトネス
CHECKER_LUM = 240.0  # 市松2色（約229/251）の代表値
MATTE_SHRINK = 0.10  # 縁の明るいフリンジを削るためのマット収縮量

REPO_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_SRC = Path(r"G:\マイドライブ\ロンさんカード\ロンさん浮遊.mp4")
DEFAULT_BG = REPO_ROOT / "mobile_app" / "assets" / "home" / "bg_temple.png"
DEFAULT_OUT = REPO_ROOT / "mobile_app" / "assets" / "home" / "character_home.mp4"


def resolve_ffmpeg(explicit: str | None) -> str:
    """ffmpeg の実行パスを解決する（明示指定 → PATH → imageio_ffmpeg 同梱版）。"""
    if explicit:
        return explicit
    found = shutil.which("ffmpeg")
    if found:
        return found
    import imageio_ffmpeg  # 遅延import（未使用環境での不要な依存を避ける）

    return imageio_ffmpeg.get_ffmpeg_exe()


def probe_stream(ffmpeg: str, src: Path) -> tuple[int, int, float]:
    """原素材の幅・高さ・フレームレートを取得する（ffprobe非依存）。"""
    proc = subprocess.run(
        [ffmpeg, "-hide_banner", "-i", str(src)],
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
    )
    for line in proc.stderr.splitlines():
        if "Video:" not in line:
            continue
        size = fps = None
        for token in line.split(","):
            token = token.strip()
            if token.endswith("fps"):
                fps = float(token[:-3].strip())
            parts = token.split(" ")[0]
            if "x" in parts:
                w, _, h = parts.partition("x")
                if w.isdigit() and h.isdigit():
                    size = (int(w), int(h))
        if size and fps:
            return size[0], size[1], fps
    raise RuntimeError(f"原素材の解像度・フレームレートを取得できません: {src}")


def build_alpha(rgb: np.ndarray) -> np.ndarray:
    """市松（明るい低彩度）を背景とみなすソフトマットを作る。"""
    mx = rgb.max(axis=2)
    sat = mx - rgb.min(axis=2)
    by_lum = np.clip((KEY_LUM_HI - mx) / KEY_LUM_SOFT, 0.0, 1.0)
    by_sat = np.clip((sat - KEY_SAT_LO) / KEY_SAT_SOFT, 0.0, 1.0)
    alpha = np.clip(np.maximum(by_lum, by_sat), 0.0, 1.0)
    return np.clip((alpha - MATTE_SHRINK) / (1.0 - MATTE_SHRINK), 0.0, 1.0)


def composite(frame: np.ndarray, background: np.ndarray, dy: int) -> np.ndarray:
    """1フレームを合成する。キャラのみ ``dy`` px 下へずらし、背景は全面のまま。"""
    alpha = build_alpha(frame)
    # 市松との合成を解いてキャラ本来の色へ戻す（縁の明るい滲みを除去）。
    fore = np.clip(
        (frame - (1.0 - alpha)[..., None] * CHECKER_LUM)
        / np.maximum(alpha, 1e-3)[..., None],
        0.0,
        255.0,
    )
    out = background.copy()
    if dy >= SCENE_H:
        return out
    src_slice = slice(0, SCENE_H - dy) if dy > 0 else slice(-dy, SCENE_H)
    dst_slice = slice(dy, SCENE_H) if dy > 0 else slice(0, SCENE_H + dy)
    a = alpha[src_slice][..., None]
    out[dst_slice] = fore[src_slice] * a + out[dst_slice] * (1.0 - a)
    return out


def render_forward(
    ffmpeg: str, src: Path, background: np.ndarray, dy: int, fps: float, dest: Path
) -> int:
    """順再生ぶんを合成しながらエンコードする（フレームは逐次処理＝低メモリ）。"""
    src_w, src_h, _ = probe_stream(ffmpeg, src)
    reader = subprocess.Popen(
        [ffmpeg, "-hide_banner", "-loglevel", "error", "-i", str(src),
         "-f", "rawvideo", "-pix_fmt", "rgb24", "-"],
        stdout=subprocess.PIPE,
    )
    writer = subprocess.Popen(
        [ffmpeg, "-hide_banner", "-loglevel", "error", "-y",
         "-f", "rawvideo", "-pix_fmt", "rgb24",
         "-s", f"{SCENE_W}x{SCENE_H}", "-r", str(fps), "-i", "-",
         "-an", "-c:v", "libx264", "-crf", "16", "-pix_fmt", "yuv420p",
         str(dest)],
        stdin=subprocess.PIPE,
    )
    frame_bytes = src_w * src_h * 3
    count = 0
    try:
        while True:
            raw = reader.stdout.read(frame_bytes)
            if len(raw) < frame_bytes:
                break
            image = Image.frombytes("RGB", (src_w, src_h), raw)
            if (src_w, src_h) != (SCENE_W, SCENE_H):
                image = image.resize((SCENE_W, SCENE_H), Image.LANCZOS)
            merged = composite(np.asarray(image, dtype=np.float32), background, dy)
            writer.stdin.write(merged.round().astype(np.uint8).tobytes())
            count += 1
    finally:
        if reader.stdout:
            reader.stdout.close()
        reader.wait()
        if writer.stdin:
            writer.stdin.close()
        writer.wait()
    if count == 0:
        raise RuntimeError("原素材からフレームを読み出せませんでした")
    return count


def make_boomerang(
    ffmpeg: str, forward: Path, frames: int, bitrate: str, dest: Path
) -> None:
    """順再生＋逆再生（両端の重複を除く）で、継ぎ目のないループ動画にする。

    ビットレート指定は既存アセット（約1,062kbps）と同等のAPKサイズを保つため。
    """
    trim = f"trim=start_frame=1:end_frame={max(frames - 1, 2)},setpts=PTS-STARTPTS"
    subprocess.run(
        [ffmpeg, "-hide_banner", "-loglevel", "error", "-y", "-i", str(forward),
         "-filter_complex",
         f"[0:v]split=2[a][b];[b]reverse,{trim}[r];[a][r]concat=n=2:v=1[o]",
         "-map", "[o]", "-an", "-c:v", "libx264", "-b:v", bitrate,
         "-pix_fmt", "yuv420p", "-movflags", "+faststart", str(dest)],
        check=True,
    )


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--src", type=Path, default=DEFAULT_SRC, help="原素材の動画")
    parser.add_argument("--bg", type=Path, default=DEFAULT_BG, help="背景画像")
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT, help="出力先")
    parser.add_argument(
        "--dy",
        type=int,
        default=121,
        help="キャラを下へずらす量（768x1024シーン空間px・宝石1個の90%%＝121）",
    )
    parser.add_argument(
        "--bitrate",
        default="1050k",
        help="最終エンコードの映像ビットレート（既存アセットと同等の約1,050kbps）",
    )
    parser.add_argument("--ffmpeg", default=None, help="ffmpegの実行パス")
    args = parser.parse_args(argv)

    ffmpeg = resolve_ffmpeg(args.ffmpeg)
    if not args.src.exists():
        print(f"原素材が見つかりません: {args.src}", file=sys.stderr)
        return 1

    background = np.asarray(
        Image.open(args.bg).convert("RGB").resize((SCENE_W, SCENE_H), Image.LANCZOS),
        dtype=np.float32,
    )
    _, _, fps = probe_stream(ffmpeg, args.src)

    with tempfile.TemporaryDirectory() as tmp:
        forward = Path(tmp) / "forward.mp4"
        frames = render_forward(ffmpeg, args.src, background, args.dy, fps, forward)
        make_boomerang(ffmpeg, forward, frames, args.bitrate, args.out)

    print(
        json.dumps(
            {
                "出力": str(args.out),
                "オフセットpx": args.dy,
                "順再生フレーム数": frames,
                "fps": fps,
                "サイズbyte": args.out.stat().st_size,
            },
            ensure_ascii=False,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
