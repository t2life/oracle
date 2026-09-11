import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oracle_mobile_app/core/models/domain_models.dart';
import 'package:oracle_mobile_app/features/history/presentation/history_detail_screen.dart';
import 'package:oracle_mobile_app/features/history/presentation/history_labels.dart';
import 'package:oracle_mobile_app/core/network/api_client.dart';
import 'package:oracle_mobile_app/core/offline/offline_backend.dart';
import 'package:oracle_mobile_app/core/state/app_state.dart';
import 'package:oracle_mobile_app/core/state/app_state_scope.dart';
import 'package:oracle_mobile_app/l10n/app_localizations.dart';

/// 2026-09-12 ご指摘③ 履歴を一覧＋詳細にする。
void main() {
  HistoryItemModel item({
    String spreadId = 'daily',
    String createdAt = '2026-09-12T22:21:03.123456+09:00',
  }) =>
      HistoryItemModel.fromJson({
        'history_id': 'his_1',
        'session_id': 'ses_1',
        'created_at': createdAt,
        'theme_id': 'money',
        'deck_id': 'japanese_mythology',
        'card_id': 'japanese_mythology_card_001',
        'summary': '要約です',
        'full_text': '長い全文です。' * 40,
        'plan_at_creation': 'free',
        'spread_id': spreadId,
      });

  Widget wrap(Widget child) {
    return OracleAppStateScope(
      state: OracleAppState(
        remoteClient: ApiClient(baseUrl: 'http://127.0.0.1:8000'),
        offlineBackend: OfflineBackend(),
      ),
      child: MaterialApp(
        locale: const Locale('ja'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: child,
      ),
    );
  }

  group('日時の整形', () {
    test('ISO文字列を YYYY/M/D HH:MM にする', () {
      // 端末のタイムゾーンで出す。テスト環境がJSTなら 22:21。
      final formatted =
          formatHistoryTimestamp('2026-09-12T22:21:03.123456+09:00');
      expect(formatted, matches(r'^\d{4}/\d{1,2}/\d{1,2} \d{2}:\d{2}$'));
      expect(formatted, startsWith('2026/9/'));
    });

    test('読めない値はそのまま返す（欠損で壊れない）', () {
      expect(formatHistoryTimestamp('---'), '---');
    });
  });

  group('種別', () {
    test('daily は託宣、それ以外はリーディング', () {
      expect(item(spreadId: 'daily').isDaily, isTrue);
      expect(item(spreadId: 'three').isDaily, isFalse);
      expect(item(spreadId: 'seven').isDaily, isFalse);
    });

    test('spread_id が無い古い履歴は託宣として扱う', () {
      final legacy = HistoryItemModel.fromJson({
        'history_id': 'his_old',
        'session_id': 'ses_old',
        'created_at': '2026-09-01T10:00:00+09:00',
        'theme_id': 'love',
        'deck_id': 'japanese_mythology',
        'card_id': 'japanese_mythology_card_002',
        'summary': '要約',
        'full_text': '全文',
        'plan_at_creation': 'free',
      });
      expect(legacy.spreadId, 'daily');
      expect(legacy.isDaily, isTrue);
    });

    testWidgets('札に「託宣」「リーディング」が出る', (tester) async {
      await tester.pumpWidget(
        wrap(Scaffold(body: HistoryKindChip(item: item(spreadId: 'daily')))),
      );
      expect(find.text('託宣'), findsOneWidget);

      await tester.pumpWidget(
        wrap(Scaffold(body: HistoryKindChip(item: item(spreadId: 'three')))),
      );
      expect(find.text('リーディング'), findsOneWidget);
    });
  });

  group('詳細画面', () {
    testWidgets('全文・種別・日時・削除が出る', (tester) async {
      await tester.pumpWidget(wrap(HistoryDetailScreen(item: item())));
      await tester.pump();

      expect(find.text('履歴の詳細'), findsOneWidget);
      expect(find.text('託宣'), findsOneWidget);
      expect(find.textContaining('2026/9/'), findsOneWidget);
      expect(find.textContaining('長い全文です。'), findsOneWidget);
      expect(find.text('削除'), findsOneWidget);
    });

    testWidgets('履歴が渡らなくても落ちない', (tester) async {
      await tester.pumpWidget(wrap(const HistoryDetailScreen()));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });
}
