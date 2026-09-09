import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oracle_mobile_app/core/theme/app_theme.dart';

/// 2026-09-09 制定の配色ルールを機械的に検証する。
/// ルール:
///   ① 全テーマが「背景・アクセント・文字」の組を持ち、ThemeDataへ反映される
///   ② 濃いボタンの上は白文字／淡いボタンの上は濃いインク（明度で自動決定）
///   ③ 背景と本文文字のコントラストが十分（読める）
double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  test('全テーマのパレットが定義され、表示順と一致する', () {
    expect(oracleThemeOrder, isNotEmpty);
    for (final id in oracleThemeOrder) {
      expect(oraclePalettes[id], isNotNull, reason: '$id のパレットが無い');
    }
    expect(oraclePalettes.length, oracleThemeOrder.length);
  });

  test('アクセント上の文字色はコントラストが高い方が選ばれる', () {
    for (final id in oracleThemeOrder) {
      final palette = paletteFor(id);
      const darkInk = Color(0xFF2B2B2B);
      final better = _contrast(palette.accent, Colors.white) >=
              _contrast(palette.accent, darkInk)
          ? Colors.white
          : darkInk;
      expect(
        palette.onAccent,
        better,
        reason: '$id のボタン文字色がルールと異なる',
      );
      expect(
        _contrast(palette.accent, palette.onAccent),
        greaterThan(3.0),
        reason: '$id のボタン文字が読めない',
      );
    }
  });

  test('濃い色のボタンには白文字が載る（共通ルール）', () {
    for (final id in <String>['pink', 'skyblue', 'lime', 'light']) {
      expect(
        paletteFor(id).onAccent,
        Colors.white,
        reason: '$id の濃いボタンに白文字が載っていない',
      );
    }
  });

  test('背景と本文のコントラストが確保されている', () {
    for (final id in oracleThemeOrder) {
      final palette = paletteFor(id);
      expect(
        _contrast(palette.background, palette.ink),
        greaterThan(4.5),
        reason: '$id の本文が背景に対して読みにくい',
      );
      expect(
        _contrast(palette.surface, palette.ink),
        greaterThan(4.5),
        reason: '$id のカード上の本文が読みにくい',
      );
    }
  });

  test('ThemeDataへパレットが反映される（地色・ボタン・文字）', () {
    for (final id in oracleThemeOrder) {
      final palette = paletteFor(id);
      final theme = resolveAppTheme(id);
      expect(theme.scaffoldBackgroundColor, palette.background);
      expect(theme.colorScheme.primary, palette.accent);
      expect(theme.colorScheme.onPrimary, palette.onAccent);
      expect(theme.textTheme.bodyMedium?.color, palette.ink);
    }
  });

  test('画像テーマは地色を透過して背景画像を見せる', () {
    expect(resolveAppTheme('image').scaffoldBackgroundColor, Colors.transparent);
  });
}
