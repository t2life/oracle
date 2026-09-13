import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oracle_mobile_app/core/network/api_client.dart';
import 'package:oracle_mobile_app/core/offline/offline_backend.dart';
import 'package:oracle_mobile_app/core/state/app_state.dart';
import 'package:oracle_mobile_app/core/state/app_state_scope.dart';
import 'package:oracle_mobile_app/features/reading_result/presentation/reading_result_screen.dart';
import 'package:oracle_mobile_app/features/shared/oracle_card_visuals.dart';
import 'package:oracle_mobile_app/l10n/app_localizations.dart';

/// 2026-09-12 iOS実機のご指摘② 結果画面（U-09）上部の札が上下で見切れる。
///
/// 守りたいこと:
///   複数枚の結果で、上部の横スライドに並ぶ札が**画面幅に関係なく**
///   札本来の縦横比（kOracleCardAspect＝120/70）で描かれること。
///   PageView は各ページに「表示幅×0.66 × 高さ」を強制するため、
///   以前は幅390で縦横比が 1.53 に崩れ、図柄の上下が切れていた。

/// 結果を返すだけの接続先（通信しない）。
class _ResultOnlyClient extends ApiClient {
  _ResultOnlyClient() : super(baseUrl: 'http://127.0.0.1:8000');

  @override
  Future<Map<String, dynamic>> startReading({
    required String userId,
    required String themeId,
    required String deckId,
    int drawCount = 1,
    String spreadId = 'daily',
    String questionText = '',
    String? originSessionId,
  }) async =>
      {'session_id': 'ses_top_cards'};

  @override
  Future<Map<String, dynamic>?> selectCard({
    required String sessionId,
    required int cardIndex,
  }) async =>
      _threeCardResult;
}

Map<String, dynamic> _card(int index) => {
      'card_id': 'japanese_mythology_card_00$index',
      'card_name': '札$index',
      'keywords': ['言葉$index'],
      'position_index': index,
      'position_name': '位置$index',
      'position_meaning': '意味$index',
    };

final Map<String, dynamic> _threeCardResult = {
  'session_id': 'ses_top_cards',
  'user_id': 'mobile_demo_user',
  'theme_id': 'money',
  'deck_id': 'japanese_mythology',
  'card_id': 'japanese_mythology_card_001',
  'card_name': '札1',
  'keywords': ['言葉1'],
  'interpretation_text': '本文',
  'caution_text': null,
  'created_at': '2026-09-12T00:00:00+09:00',
  'copied': false,
  'spread_id': 'three',
  'cards': [_card(1), _card(2), _card(3)],
};

void main() {
  Future<void> pumpResult(WidgetTester tester, double width) async {
    tester.view.devicePixelRatio = 3.0;
    tester.view.physicalSize = Size(width * 3, 844 * 3);
    addTearDown(tester.view.reset);

    final state = OracleAppState(
      remoteClient: _ResultOnlyClient(),
      offlineBackend: OfflineBackend(),
    );
    addTearDown(state.dispose);
    state
      ..selectDeck('japanese_mythology')
      ..selectTheme('money')
      ..selectSpread('three');
    await state.startReadingFlow();
    await state.revealCard();
    expect(state.latestResult?.cards.length, 3, reason: '複数枚の結果が作れていない');

    await tester.pumpWidget(
      OracleAppStateScope(
        state: state,
        child: const MaterialApp(
          locale: Locale('ja'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: ReadingResultScreen(),
        ),
      ),
    );
    // 札が浮かび上がる演出（1.8秒）を終わらせる。星の瞬きは繰り返しのため settle しない。
    await tester.pump(const Duration(seconds: 2));
    // 効果音（audioplayers）はテスト環境にプラグインが無く例外を出すため取り除く。
    // 本テストの対象（札の縦横比）とは無関係。
    while (tester.takeException() != null) {}
  }

  for (final width in <double>[320, 360, 390, 411]) {
    testWidgets('幅$width: 上部の札が本来の縦横比で描かれる（上下が切れない）', (tester) async {
      await pumpResult(tester, width);

      final topCards = find.descendant(
        of: find.byType(PageView),
        matching: find.byType(OracleCardFace),
      );
      expect(topCards, findsWidgets, reason: '上部の横スライドに札が無い');

      final count = topCards.evaluate().length;
      for (var i = 0; i < count; i++) {
        final rect = tester.getRect(topCards.at(i));
        expect(
          rect.height / rect.width,
          closeTo(kOracleCardAspect, 0.01),
          reason: '幅$width で札の縦横比が崩れている（${rect.size}）',
        );
      }
    });
  }
}
