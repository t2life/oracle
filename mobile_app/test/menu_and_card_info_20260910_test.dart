import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oracle_mobile_app/core/models/domain_models.dart';
import 'package:oracle_mobile_app/core/network/api_client.dart';
import 'package:oracle_mobile_app/core/offline/offline_backend.dart';
import 'package:oracle_mobile_app/core/state/app_state.dart';
import 'package:oracle_mobile_app/core/state/app_state_scope.dart';
import 'package:oracle_mobile_app/features/my_page/presentation/my_page_screen.dart';
import 'package:oracle_mobile_app/features/shell/presentation/main_shell.dart';
import 'package:oracle_mobile_app/features/shared/plan_l10n.dart';
import 'package:oracle_mobile_app/l10n/app_localizations.dart';

/// 2026-09-10 のご指摘①③④⑤⑥に対する回帰テスト。
void main() {
  OracleAppState buildState() => OracleAppState(
        remoteClient: ApiClient(baseUrl: 'http://127.0.0.1:8000'),
        offlineBackend: OfflineBackend(),
      );

  Widget wrap(Widget child, OracleAppState state) {
    return OracleAppStateScope(
      state: state,
      child: MaterialApp(
        locale: const Locale('ja'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(endDrawer: const SecondaryMenuDrawer(), body: child),
      ),
    );
  }

  group('①③ カード情報（ルビ・属性・エレメント）', () {
    ResultCardModel card() => ResultCardModel.fromJson(const {
          'card_id': 'japanese_mythology_card_001',
          'card_name': '天之御中主神',
          'keywords': ['中心'],
          'position_index': 1,
          'position_name': '過去',
          'position_meaning': 'これまでの流れ',
          'reading': 'アメノミナカヌシ',
          'attribute': '別天神/創造神',
          'element': 'エーテル',
        });

    test('神名の後ろにルビを括弧で付ける', () {
      expect(card().nameWithReading, '天之御中主神（アメノミナカヌシ）');
    });

    test('ルビが無いカードは神名だけ（DB非搭載デッキ）', () {
      final plain = ResultCardModel.fromJson(const {
        'card_id': 'tarot_card_001',
        'card_name': 'タロット 1',
        'keywords': <String>[],
        'position_index': 1,
        'position_name': '',
        'position_meaning': '',
      });
      expect(plain.nameWithReading, 'タロット 1');
      expect(plain.attribute, isEmpty);
      expect(plain.element, isEmpty);
    });

    test('属性とエレメントを保持する', () {
      expect(card().attribute, '別天神/創造神');
      expect(card().element, 'エーテル');
    });

    test('結果は代表カードのルビ・属性・エレメントを引ける', () {
      final result = ReadingResultModel.fromJson(const {
        'session_id': 's1',
        'user_id': 'u1',
        'theme_id': 'work',
        'deck_id': 'japanese_mythology',
        'card_id': 'japanese_mythology_card_001',
        'card_name': '天之御中主神',
        'keywords': ['中心'],
        'interpretation_text': '本文',
        'caution_text': null,
        'created_at': '2026-09-10T00:00:00+09:00',
        'copied': false,
        'cards': [
          {
            'card_id': 'japanese_mythology_card_001',
            'card_name': '天之御中主神',
            'keywords': ['中心'],
            'position_index': 1,
            'position_name': '',
            'position_meaning': '',
            'reading': 'アメノミナカヌシ',
            'attribute': '別天神/創造神',
            'element': 'エーテル',
          },
        ],
      });
      expect(result.cardNameWithReadingFor('ja'), '天之御中主神（アメノミナカヌシ）');
      // 読み仮名は日本語話者向けのため、他言語ではルビを付けない
      expect(result.cardNameWithReadingFor('en'), '天之御中主神');
      expect(result.primaryAttribute, '別天神/創造神');
      expect(result.primaryElement, 'エーテル');
    });
  });

  group('④ プラン購入画面', () {
    test('全機能解放の判定は月額有料プランと管理者だけ', () {
      expect(planUnlocksAllFeatures('subscription'), isTrue);
      expect(planUnlocksAllFeatures('admin'), isTrue);
      // チケットは「回数の購入」であって機能解放ではない＝買えるままにする
      expect(planUnlocksAllFeatures('ticket'), isFalse);
      expect(planUnlocksAllFeatures('free'), isFalse);
      expect(planUnlocksAllFeatures('guest'), isFalse);
    });
  });

  group('⑤ マイページ', () {
    testWidgets('プラン購入画面への導線を出さず、アプリ本体の導線を出す', (tester) async {
      final state = buildState();
      addTearDown(state.dispose);

      await tester.pumpWidget(wrap(const MyPageTab(), state));
      await tester.pump();

      expect(find.text('プラン購入画面へ'), findsNothing);
      expect(find.text('アプリを評価'), findsOneWidget);
      expect(find.text('アプリを共有'), findsOneWidget);
      expect(find.text('機種引継ぎコード'), findsOneWidget);
      expect(find.text('App2Craftのアプリ'), findsOneWidget);
      expect(find.text('規約・情報'), findsOneWidget);
    });
  });

  group('⑥ ≡メニュー', () {
    testWidgets('プラン購入とアプリ名の行を出さず、アプリ本体の導線を出す', (tester) async {
      final state = buildState();
      addTearDown(state.dispose);

      await tester.pumpWidget(wrap(const SizedBox.shrink(), state));
      await tester.pump();
      final scaffold = tester.firstState<ScaffoldState>(find.byType(Scaffold));
      scaffold.openEndDrawer();
      await tester.pumpAndSettle();

      expect(find.text('プラン購入'), findsNothing);
      expect(find.text('日本神話オラクルロンカード'), findsNothing);
      expect(find.text('アプリを評価'), findsOneWidget);
      expect(find.text('アプリを共有'), findsOneWidget);
      expect(find.text('App2Craftのアプリ'), findsOneWidget);
      // 既存の導線は残っている
      expect(find.text('お問い合わせ'), findsOneWidget);
    });
  });
}
