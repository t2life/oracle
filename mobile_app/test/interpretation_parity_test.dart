import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:oracle_mobile_app/core/interpretation/interpretation_composer.dart';

/// サーバー（Python）とオフライン（Dart）の託宣文が**完全一致**することを検証する。
///
/// 期待値 `interpretation_parity_expected.json` は
/// `src/oracle_app/services/interpretation_engine.py` の出力をそのまま保存したもの。
/// 片方だけ直すと同じ引きで文章が変わってしまうため、
/// 合成ロジックを変更したら必ず期待値を作り直して両実装を揃える。
void main() {
  late InterpretationComposer composer;
  late Map<String, dynamic> cases;

  setUpAll(() {
    final content = json.decode(
      File('assets/interpretation_content.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    composer = InterpretationComposer.forContent(content);
    cases = json.decode(
      File('test/interpretation_parity_expected.json').readAsStringSync(),
    ) as Map<String, dynamic>;
  });

  test('同梱の解釈素材がサーバーと同じ構成である', () {
    final content = json.decode(
      File('assets/interpretation_content.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    expect((content['cards'] as List).length, 44);
    expect((content['spreads'] as List).length, 5);
    expect((content['connectors'] as List).length, 10);
    expect((content['positions'] as Map).containsKey('three'), isTrue);
  });

  test('サーバーとオフラインの託宣文が一致する', () {
    expect(cases, isNotEmpty);
    cases.forEach((name, raw) {
      final entry = raw as Map<String, dynamic>;
      final input = entry['input'] as Map<String, dynamic>;
      final actual = composer.composeReading(
        cardIds: (input['card_ids'] as List<dynamic>).cast<String>(),
        themeId: input['theme_id'] as String,
        // 日替わり選択の条件は期待値と同じものを fixture から受け取る
        // （片方に直書きするとハッシュがずれて偽の不一致になる）。
        dateKey: input['date_key'] as String,
        sessionId: input['session_id'] as String,
        fallbackText: '（素材が見つかりませんでした）',
        spreadId: input['spread_id'] as String,
        questionText: input['question_text'] as String?,
      );
      expect(actual, entry['expected'] as String, reason: '不一致: $name');
    });
  });

  test('素材が無いカードはfallbackを返す（fail-soft）', () {
    final actual = composer.composeReading(
      cardIds: const ['unknown_card_001'],
      themeId: 'love',
      dateKey: '2026-09-10',
      sessionId: 'ses_parity',
      fallbackText: 'fallback',
    );
    expect(actual, 'fallback');
  });
}
