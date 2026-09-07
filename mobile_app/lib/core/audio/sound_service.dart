import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 効果音の種類。アセットは `assets/sounds/<name>.wav`。
/// 実素材が用意されたら同名WAVを差し替えるだけでよい
/// （生成元: system/scripts/generate_sound_assets.py）。
enum OracleSound {
  tap('tap.wav'),
  flip('flip.wav'),
  shuffle('shuffle.wav'),
  whoosh('whoosh.wav'),
  chime('chime.wav'),
  opening('opening.wav');

  const OracleSound(this.fileName);

  final String fileName;
}

/// 効果音の再生と、スピーカーアイコンによるON/OFF状態を司る単一サービス。
///
/// - ON/OFFは端末に保存され、全画面のスピーカーアイコンが [enabled] を購読する。
/// - 再生失敗（端末音量0・プラグイン初期化前等）はアプリ動作を阻害しない。
class SoundService {
  SoundService._();

  static final SoundService instance = SoundService._();

  static const String _prefsKey = 'app_sound_enabled';

  final ValueNotifier<bool> enabled = ValueNotifier<bool>(true);

  final AudioPlayer _effectPlayer = AudioPlayer();
  final AudioPlayer _ambiencePlayer = AudioPlayer();
  bool _loaded = false;

  Future<void> ensureLoaded() async {
    if (_loaded) {
      return;
    }
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      enabled.value = prefs.getBool(_prefsKey) ?? true;
    } catch (_) {
      // 設定読込失敗は既定ON
    }
    try {
      await _effectPlayer.setPlayerMode(PlayerMode.lowLatency);
    } catch (_) {
      // モード設定失敗は既定モードで継続
    }
  }

  Future<void> toggle() async {
    enabled.value = !enabled.value;
    if (!enabled.value) {
      await stopAmbience();
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefsKey, enabled.value);
    } catch (_) {
      // 保存失敗時も画面上の状態は反映済み
    }
  }

  /// 短い効果音を再生する（前の効果音は打ち切り＝連打時の重なり防止）。
  Future<void> play(OracleSound sound) async {
    if (!enabled.value) {
      return;
    }
    try {
      await _effectPlayer.stop();
      await _effectPlayer.play(AssetSource('sounds/${sound.fileName}'));
    } catch (_) {
      // 効果音は非致命
    }
  }

  /// オープニング等の長尺環境音（多重再生しない）。
  Future<void> playAmbience(OracleSound sound) async {
    if (!enabled.value) {
      return;
    }
    try {
      await _ambiencePlayer.stop();
      await _ambiencePlayer.play(AssetSource('sounds/${sound.fileName}'));
    } catch (_) {
      // 非致命
    }
  }

  Future<void> stopAmbience() async {
    try {
      await _ambiencePlayer.stop();
    } catch (_) {
      // 非致命
    }
  }
}
