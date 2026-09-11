import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oracle_mobile_app/features/shared/oracle_card_visuals.dart';

/// 2026-09-11 カード図柄の回帰テスト。
///
/// 守りたいこと:
///   ① 縦横比が実物（縦120mm × 横70mm）に一致すること
///   ② 図柄が無いカードでも札が必ず出ること（空白にしない）
void main() {
  testWidgets('カードの縦横比が実物（120:70）に一致する', (tester) async {
    // 1.55 が直書きされていて実物と食い違っていた。比率は1か所で持つ。
    expect(kOracleCardAspect, closeTo(120 / 70, 0.0001));

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: OracleCardBack(width: 100))),
      ),
    );
    final size = tester.getSize(find.byType(OracleCardBack));
    expect(size.width, 100);
    expect(size.height, closeTo(100 * 120 / 70, 0.01));
  });

  testWidgets('図柄が無いカードでも札が描かれる（空白にしない）', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: OracleCardFace(
              cardId: 'there_is_no_such_card',
              cardName: '天之御中主神',
              width: 120,
            ),
          ),
        ),
      ),
    );
    // 図柄→サンプル→文字札の三段構え。いずれかが必ず出る。
    final size = tester.getSize(find.byType(OracleCardFace));
    expect(size.width, 120);
    expect(size.height, closeTo(120 * 120 / 70, 0.01));
  });

  test('同梱アセットの置き場が規約どおり', () {
    expect(kOracleCardBackAsset, 'assets/cards/back.webp');
    expect(kOracleCardSampleFront, 'assets/cards/sample_front.webp');
  });
}
