from __future__ import annotations

"""効果音アセット生成スクリプト。

正式な効果音素材が未提供のため、標準ライブラリのみで神秘系の
プレースホルダ効果音（WAV）を合成し `mobile_app/assets/sounds/` へ出力する。
実素材が用意されたら同名ファイルを差し替えるだけでアプリ側は無変更で済む。
"""

import math
import random
import struct
import wave
from pathlib import Path

ROOT_DIR = Path(__file__).resolve().parents[1]
OUT_DIR = ROOT_DIR / "mobile_app" / "assets" / "sounds"
RATE = 22050


def _write(name: str, samples: list[float]) -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    path = OUT_DIR / name
    frames = b"".join(
        struct.pack("<h", max(-32767, min(32767, int(sample * 32767))))
        for sample in samples
    )
    with wave.open(str(path), "wb") as writer:
        writer.setnchannels(1)
        writer.setsampwidth(2)
        writer.setframerate(RATE)
        writer.writeframes(frames)
    print(f"生成: {path.name} ({len(samples) / RATE:.2f}s)")


def _bell(freq: float, duration: float, volume: float = 0.5) -> list[float]:
    """減衰する鐘系トーン（基音＋非整数倍音）。"""
    n = int(RATE * duration)
    out = []
    for i in range(n):
        t = i / RATE
        decay = math.exp(-3.2 * t / duration)
        value = (
            math.sin(2 * math.pi * freq * t)
            + 0.45 * math.sin(2 * math.pi * freq * 2.76 * t)
            + 0.2 * math.sin(2 * math.pi * freq * 5.4 * t)
        )
        attack = min(1.0, i / (RATE * 0.005))
        out.append(volume * decay * attack * value / 1.65)
    return out


def _mix(base: list[float], overlay: list[float], offset_sec: float) -> None:
    start = int(RATE * offset_sec)
    for i, sample in enumerate(overlay):
        idx = start + i
        if idx >= len(base):
            break
        base[idx] += sample


def _noise_swish(duration: float, volume: float, descending: bool = False) -> list[float]:
    """帯域ノイズのスウィッシュ（カード摩擦音の代用）。"""
    n = int(RATE * duration)
    out = []
    prev = 0.0
    rng = random.Random(7)
    for i in range(n):
        t = i / n
        raw = rng.uniform(-1, 1)
        # 簡易ローパス（前回値との補間）で「シュッ」という柔らかい質感にする
        alpha = 0.18 if not descending else max(0.04, 0.25 * (1 - t))
        prev = prev + alpha * (raw - prev)
        envelope = math.sin(math.pi * t) ** 1.5
        out.append(volume * envelope * prev * 2.2)
    return out


def gen_tap() -> None:
    """ボタンタップ音（短いポロン）。"""
    _write("tap.wav", _bell(880.0, 0.10, volume=0.32))


def gen_flip() -> None:
    """カードめくり音（パチッ＋余韻）。"""
    samples = _noise_swish(0.06, 0.5)
    _mix(samples, _bell(1318.5, 0.18, volume=0.22), 0.02)
    # 長さを確保
    samples += [0.0] * int(RATE * 0.08)
    _write("flip.wav", samples)


def gen_shuffle() -> None:
    """シャッフル摩擦音（スワイプ毎に再生）。"""
    _write("shuffle.wav", _noise_swish(0.28, 0.42))


def gen_whoosh() -> None:
    """山分け・山選択の移動音。"""
    _write("whoosh.wav", _noise_swish(0.4, 0.5, descending=True))


def gen_chime() -> None:
    """結果表示のチャイム（ペンタトニック上行）。"""
    total = [0.0] * int(RATE * 1.6)
    for idx, freq in enumerate([523.25, 659.25, 783.99, 1046.5]):
        _mix(total, _bell(freq, 1.0, volume=0.30), idx * 0.16)
    _write("chime.wav", total)


def gen_opening() -> None:
    """オープニング環境音（約9秒・琴風ペンタトニック＋低音パッド）。"""
    duration = 9.0
    total = [0.0] * int(RATE * duration)
    # 低音パッド（A2）
    for i in range(len(total)):
        t = i / RATE
        fade = min(1.0, t / 1.5) * min(1.0, (duration - t) / 2.0)
        total[i] += 0.08 * fade * (
            math.sin(2 * math.pi * 110.0 * t) + 0.5 * math.sin(2 * math.pi * 164.8 * t)
        )
    # 琴風アルペジオ（Aマイナーペンタトニック）
    notes = [220.0, 261.63, 293.66, 329.63, 392.0, 440.0, 523.25, 440.0, 392.0, 329.63]
    for idx, freq in enumerate(notes):
        _mix(total, _bell(freq, 2.2, volume=0.22), 0.5 + idx * 0.8)
    _write("opening.wav", total)


def main() -> None:
    gen_tap()
    gen_flip()
    gen_shuffle()
    gen_whoosh()
    gen_chime()
    gen_opening()
    print("完了: 全効果音アセットを生成しました。")


if __name__ == "__main__":
    main()
