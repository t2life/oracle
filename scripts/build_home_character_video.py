"""ホーム画面のキャラ動画（背景合成済み）と背景ポスターを生成する。

用途:
    原素材（市松模様で透過が焼き込まれたキャラ動画）から市松を抜き、
    ホーム背景画像へ合成して `assets/home/character_home.mp4` を作る。
    同じ背景を同じ寸法で `assets/home/bg_temple.png`（動画初期化前のポスター
    ＝ホーム画面の背景素材）として書き出せる。

主なオプション:
    --start / --end   原素材から使う区間（秒）。例: 4.0〜6.0秒だけ使う。
    --dy              キャラを下へずらす量（シーン空間px）。
    --boomerang       順再生＋逆再生でループの継ぎ目を消す（既定・無効化は --no-boomerang）。
    --poster-out      背景をシーン寸法で書き出す先（ポスター兼ホーム背景）。

実行例（2026-09-09 の素材更新）::

    python scripts/build_home_character_video.py \
        --src "C:/Users/81907/Downloads/ロンさん浮遊6.mp4" \
        --bg "G:/マイドライブ/ロンさんカード/ホーム画面8.png" \
        --start 4.0 --end 6.0 \
        --poster-out mobile_app/assets/home/bg_temple.png

注意:
    - ffmpeg は imageio_ffmpeg 同梱版を既定で使う（PATHへの導入は不要）。
    - 原素材は Google ドライブ／Downloads 上にあるため、他PCで実行する場合は
      `--src` / `--bg` を指定する。
    - 出力は常に無音。原素材に音声があっても取り込まない。
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

# --- 既定のシーン寸法（2026-09-09 素材更新で 3:4 から 9:16 相当へ変更）---------
SCENE_W = 768
SCENE_H = 1376  # ホーム画面8.png（1536x2752）の1/2＝背景と完全一致

# 市松（明るい低彩度）の判定と、アンプリマルチプライに用いる市松の代表輝度。
KEY_LUM_HI = 225.0  # これ以上の明度は背景側
KEY_LUM_SOFT = 30.0  # 明度方向のソフトネス
KEY_SAT_LO = 8.0  # これ以下の彩度は背景側
KEY_SAT_SOFT = 12.0  # 彩度方向のソフトネス
CHECKER_LUM = 240.0  # 市松2色（約229/251）の代表値
MATTE_SHRINK = 0.10  # 縁の明るいフリンジを削るためのマット収縮量

REPO_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_SRC = Path.home() / "Downloads" / "ロンさん浮遊6.mp4"
DEFAULT_BG = Path(r"G:\マイドライブ\ロンさんカード\ホーム画面8.png")
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


def probe_fps(ffmpeg: str, src: Path) -> float:
    """原素材のフレームレートを取得する（ffprobe非依存）。"""
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
        for token in line.split(","):
            token = token.strip()
            if token.endswith("fps"):
                return float(token[:-3].strip())
    raise RuntimeError(f"原素材のフレームレートを取得できません: {src}")


def cover(image: Image.Image, width: int, height: int) -> Image.Image:
    """アスペクトを保ったまま指定寸法を覆うように拡縮し、中央で切り出す。"""
    scale = max(width / image.width, height / image.height)
    resized = image.resize(
        (round(image.width * scale), round(image.height * scale)), Image.LANCZOS
    )
    left = (resized.width - width) // 2
    top = (resized.height - height) // 2
    return resized.crop((left, top, left + width, top + height))


def build_alpha(rgb: np.ndarray) -> np.ndarray:
    """市松（明るい低彩度）を背景とみなすソフトマットを作る。"""
    mx = rgb.max(axis=2)
    sat = mx - rgb.min(axis=2)
    by_lum = np.clip((KEY_LUM_HI - mx) / KEY_LUM_SOFT, 0.0, 1.0)
    by_sat = np.clip((sat - KEY_SAT_LO) / KEY_SAT_SOFT, 0.0, 1.0)
    alpha = np.clip(np.maximum(by_lum, by_sat), 0.0, 1.0)
    return np.clip((alpha - MATTE_SHRINK) / (1.0 - MATTE_SHRINK), 0.0, 1.0)


def composite(
    frame: np.ndarray, background: np.ndarray, dy: int, scene_h: int
) -> np.ndarray:
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
    if dy >= scene_h:
        return out
    src_slice = slice(0, scene_h - dy) if dy > 0 else slice(-dy, scene_h)
    dst_slice = slice(dy, scene_h) if dy > 0 else slice(0, scene_h + dy)
    a = alpha[src_slice][..., None]
    out[dst_slice] = fore[src_slice] * a + out[dst_slice] * (1.0 - a)
    return out


def render_forward(
    ffmpeg: str,
    src: Path,
    background: np.ndarray,
    args: argparse.Namespace,
    fps: float,
    dest: Path,
) -> int:
    """指定区間を合成しながらエンコードする（フレームは逐次処理＝低メモリ）。"""
    w, h = args.scene_width, args.scene_height
    trim: list[str] = []
    if args.start is not None:
        trim += ["-ss", str(args.start)]
    if args.end is not None:
        trim += ["-to", str(args.end)]
    reader = subprocess.Popen(
        [ffmpeg, "-hide_banner", "-loglevel", "error", *trim, "-i", str(src),
         # シーン寸法へ cover 相当（拡大して中央切り出し）で合わせる
         "-vf", f"scale={w}:{h}:force_original_aspect_ratio=increase,crop={w}:{h}",
         "-an", "-f", "rawvideo", "-pix_fmt", "rgb24", "-"],
        stdout=subprocess.PIPE,
    )
    writer = subprocess.Popen(
        [ffmpeg, "-hide_banner", "-loglevel", "error", "-y",
         "-f", "rawvideo", "-pix_fmt", "rgb24",
         "-s", f"{w}x{h}", "-r", str(fps), "-i", "-",
         "-an", "-c:v", "libx264", "-crf", "16", "-pix_fmt", "yuv420p",
         str(dest)],
        stdin=subprocess.PIPE,
    )
    frame_bytes = w * h * 3
    count = 0
    try:
        while True:
            raw = reader.stdout.read(frame_bytes)
            if len(raw) < frame_bytes:
                break
            frame = np.frombuffer(raw, dtype=np.uint8).reshape(h, w, 3).astype(
                np.float32
            )
            merged = composite(frame, background, args.dy, h)
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
        raise RuntimeError("原素材から指定区間のフレームを読み出せませんでした")
    return count


def encode_final(
    ffmpeg: str, forward: Path, frames: int, args: argparse.Namespace, dest: Path
) -> None:
    """最終エンコード。既定は順再生＋逆再生（両端の重複を除く）で継ぎ目を消す。

    逆再生ぶんは**別ファイルに書き出してから concat デマルチプレクサで連結**する。
    1本のフィルタグラフ（split＋reverse＋concat）は、reverseが全フレームを抱える間に
    concatが先頭を要求するため**先頭へ灰色フレームが混入する**ことを実測で確認したため
    （2026-09-09。無音のまま数十フレームが単色になり、画面が一瞬灰色になる）。

    ビットレート指定は既存アセットと同等のAPKサイズを保つため。
    """
    common = ["-an", "-c:v", "libx264", "-b:v", args.bitrate,
              "-pix_fmt", "yuv420p", "-movflags", "+faststart", str(dest)]
    if not args.boomerang:
        subprocess.run(
            [ffmpeg, "-hide_banner", "-loglevel", "error", "-y", "-i", str(forward),
             *common],
            check=True,
        )
        return
    reversed_clip = forward.with_name("reversed.mp4")
    trim = f"trim=start_frame=1:end_frame={max(frames - 1, 2)},setpts=PTS-STARTPTS"
    subprocess.run(
        [ffmpeg, "-hide_banner", "-loglevel", "error", "-y", "-i", str(forward),
         "-vf", f"reverse,{trim}", "-an", "-c:v", "libx264", "-crf", "16",
         "-pix_fmt", "yuv420p", str(reversed_clip)],
        check=True,
    )
    listing = forward.with_name("concat.txt")
    listing.write_text(
        f"file '{forward.name}'\nfile '{reversed_clip.name}'\n", encoding="utf-8"
    )
    subprocess.run(
        [ffmpeg, "-hide_banner", "-loglevel", "error", "-y",
         "-f", "concat", "-safe", "0", "-i", listing.name, *common],
        check=True,
        cwd=str(forward.parent),
    )


def verify_output(ffmpeg: str, dest: Path) -> None:
    """出力の先頭が単色（＝合成やフィルタの破綻）でないことを確かめる。

    フィルタグラフの不具合は無言で単色フレームを生むため、目視前に機械検査する。
    """
    proc = subprocess.run(
        [ffmpeg, "-hide_banner", "-loglevel", "error", "-i", str(dest),
         "-frames:v", "1", "-f", "rawvideo", "-pix_fmt", "rgb24", "-"],
        capture_output=True,
    )
    if not proc.stdout:
        raise RuntimeError(f"出力から先頭フレームを取得できません: {dest}")
    frame = np.frombuffer(proc.stdout, dtype=np.uint8).astype(np.float32)
    if frame.std() < 3.0:
        raise RuntimeError(
            f"出力の先頭フレームがほぼ単色です（標準偏差{frame.std():.2f}）: {dest}"
        )


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--src", type=Path, default=DEFAULT_SRC, help="原素材の動画")
    parser.add_argument("--bg", type=Path, default=DEFAULT_BG, help="背景画像")
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT, help="出力先")
    parser.add_argument(
        "--poster-out",
        type=Path,
        default=None,
        help="背景をシーン寸法で書き出す先（ホーム背景＝動画のポスター）",
    )
    parser.add_argument("--start", type=float, default=None, help="使用開始秒")
    parser.add_argument("--end", type=float, default=None, help="使用終了秒")
    parser.add_argument("--scene-width", type=int, default=SCENE_W, help="シーン幅px")
    parser.add_argument("--scene-height", type=int, default=SCENE_H, help="シーン高px")
    parser.add_argument(
        "--dy", type=int, default=0, help="キャラを下へずらす量（シーン空間px）"
    )
    parser.add_argument(
        "--boomerang",
        action=argparse.BooleanOptionalAction,
        default=True,
        help="順再生＋逆再生でループの継ぎ目を消す（既定: 有効）",
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
    if not args.bg.exists():
        print(f"背景画像が見つかりません: {args.bg}", file=sys.stderr)
        return 1

    scene = cover(
        Image.open(args.bg).convert("RGB"), args.scene_width, args.scene_height
    )
    if args.poster_out is not None:
        args.poster_out.parent.mkdir(parents=True, exist_ok=True)
        scene.save(args.poster_out)
    background = np.asarray(scene, dtype=np.float32)
    fps = probe_fps(ffmpeg, args.src)

    with tempfile.TemporaryDirectory() as tmp:
        forward = Path(tmp) / "forward.mp4"
        frames = render_forward(ffmpeg, args.src, background, args, fps, forward)
        encode_final(ffmpeg, forward, frames, args, args.out)
    verify_output(ffmpeg, args.out)

    print(
        json.dumps(
            {
                "出力": str(args.out),
                "ポスター": str(args.poster_out) if args.poster_out else None,
                "シーン": f"{args.scene_width}x{args.scene_height}",
                "使用区間秒": [args.start, args.end],
                "オフセットpx": args.dy,
                "順再生フレーム数": frames,
                "ブーメラン": args.boomerang,
                "fps": fps,
                "サイズbyte": args.out.stat().st_size,
            },
            ensure_ascii=False,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
