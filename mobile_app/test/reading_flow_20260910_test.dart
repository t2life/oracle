import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oracle_mobile_app/core/models/domain_models.dart';
import 'package:oracle_mobile_app/core/network/api_client.dart';
import 'package:oracle_mobile_app/core/offline/offline_backend.dart';
import 'package:oracle_mobile_app/core/state/app_state.dart';
import 'package:oracle_mobile_app/core/state/app_state_scope.dart';
import 'package:oracle_mobile_app/features/deck_selection/presentation/deck_selection_screen.dart';
import 'package:oracle_mobile_app/features/theme_selection/presentation/theme_selection_screen.dart';
import 'package:oracle_mobile_app/l10n/app_localizations.dart';

/// 2026-09-10 承認のリーディング体験（①種別分岐・②テーマ＋相談内容）の回帰テスト。
///
/// 守りたいこと:
///   ① 導線（託宣／リーディング）でテーマ選択画面の形が変わること
///   ② リーディングは相談内容が空のうちは先へ進めないこと
///   ③ 枚数・課金条件はスプレッド定義（マスタ）が決めること＝画面が独自に持たない
///   ④ 複数枚の結果がポジション付きで解釈できること
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
        home: child,
      ),
    );
  }

  group('スプレッド定義（マスタ）', () {
    test('本日の託宣は1枚・無料枠、リーディングは5チケット', () {
      final daily = SpreadModel.fromJson(const {
        'spread_id': 'daily',
        'name_ja': '本日の託宣',
        'kind': 'oracle',
        'card_count': 1,
        'min_cards': 1,
        'max_cards': 1,
        'required_tickets': 0,
        'allowed_plans': ['free', 'ticket', 'subscription'],
        'sort_order': 1,
      });
      expect(daily.isOracle, isTrue);
      expect(daily.isVariable, isFalse);
      expect(daily.drawCountFor(5), 1, reason: '固定枚数は要求値を無視する');

      final three = SpreadModel.fromJson(const {
        'spread_id': 'three',
        'kind': 'reading',
        'card_count': 3,
        'min_cards': 3,
        'max_cards': 3,
        'required_tickets': 5,
        'allowed_plans': ['ticket', 'subscription'],
        'sort_order': 2,
      });
      expect(three.isOracle, isFalse);
      expect(three.requiredTickets, 5);
    });

    test('フリーは最小〜最大に丸める', () {
      final free = SpreadModel.fromJson(const {
        'spread_id': 'free',
        'kind': 'reading',
        'card_count': 0,
        'min_cards': 1,
        'max_cards': 7,
        'required_tickets': 5,
        'allowed_plans': ['ticket', 'subscription'],
        'sort_order': 5,
      });
      expect(free.isVariable, isTrue);
      expect(free.drawCountFor(0), 1);
      expect(free.drawCountFor(4), 4);
      expect(free.drawCountFor(99), 7);
    });

    test('実行可否はサーバー（またはオフラインエンジン）の判定をそのまま持つ', () {
      final locked = SpreadModel.fromJson(const {
        'spread_id': 'three',
        'kind': 'reading',
        'card_count': 3,
        'required_tickets': 5,
        'allowed_plans': ['ticket'],
        'available': false,
        'unavailable_reason': 'msg_paid_only_draw',
      });
      expect(locked.available, isFalse);
      expect(locked.unavailableReason, 'msg_paid_only_draw');
    });
  });

  group('結果（複数枚）', () {
    test('ポジション付きのカードと相談内容を解釈する', () {
      final result = ReadingResultModel.fromJson(const {
        'session_id': 's1',
        'user_id': 'u1',
        'theme_id': 'work',
        'deck_id': 'japanese_mythology',
        'card_id': 'c1',
        'card_name': '天照大神',
        'keywords': ['光'],
        'interpretation_text': '本文',
        'caution_text': null,
        'created_at': '2026-09-10T00:00:00+09:00',
        'copied': false,
        'spread_id': 'three',
        'question_text': '転職すべきか迷っています。',
        'cards': [
          {
            'card_id': 'c1',
            'card_name': '天照大神',
            'keywords': ['光'],
            'position_index': 1,
            'position_name': '過去',
            'position_meaning': 'これまでの流れ',
          },
          {
            'card_id': 'c2',
            'card_name': '月読命',
            'keywords': ['静けさ'],
            'position_index': 2,
            'position_name': '現在',
            'position_meaning': 'いまの状況',
          },
        ],
      });

      expect(result.spreadId, 'three');
      expect(result.questionText, '転職すべきか迷っています。');
      expect(result.cards.length, 2);
      expect(result.cards[1].positionName, '現在');
      expect(result.cards[1].cardName, '月読命');
    });

    test('cards を持たない旧形式でも壊れない（履歴の互換）', () {
      final result = ReadingResultModel.fromJson(const {
        'session_id': 's1',
        'user_id': 'u1',
        'theme_id': 'work',
        'deck_id': 'japanese_mythology',
        'card_id': 'c1',
        'card_name': '天照大神',
        'keywords': ['光'],
        'interpretation_text': '本文',
        'caution_text': null,
        'created_at': '2026-09-10T00:00:00+09:00',
        'copied': false,
      });
      expect(result.cards, isEmpty);
      expect(result.spreadId, 'daily');
      expect(result.questionText, isEmpty);
    });
  });

  group('テーマ選択の分岐', () {
    testWidgets('本日の託宣では相談内容を出さない（現状維持）', (tester) async {
      final state = buildState();
      addTearDown(state.dispose);
      state.selectSpread('daily');

      await tester.pumpWidget(wrap(const ThemeSelectionScreen(), state));
      await tester.pump();

      expect(state.isOracleFlow, isTrue);
      expect(find.text('相談内容'), findsNothing);
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('リーディングではテーマのプルダウンと相談内容を同じ画面に出す', (tester) async {
      final state = buildState();
      addTearDown(state.dispose);
      state.selectSpread('three');

      await tester.pumpWidget(wrap(const ThemeSelectionScreen(), state));
      await tester.pump();

      expect(state.isOracleFlow, isFalse);
      expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('相談内容は3000文字を超えて入力できない', (tester) async {
      final state = buildState();
      addTearDown(state.dispose);
      state.selectSpread('three');

      await tester.pumpWidget(wrap(const ThemeSelectionScreen(), state));
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'あ' * 3200);
      await tester.pump();

      expect(state.questionText.length, ThemeSelectionScreen.questionMaxLength);
    });

    testWidgets('託宣へ切り替えると相談内容は捨てられる', (tester) async {
      final state = buildState();
      addTearDown(state.dispose);
      state.selectSpread('three');
      state.setQuestionText('転職すべきか迷っています。');

      state.selectSpread('daily');
      expect(state.questionText, isEmpty);
    });
  });

  group('デッキ選択の次の行き先', () {
    testWidgets('リーディングは枚数（種別）選択へ、託宣はテーマ選択へ', (tester) async {
      final state = buildState();
      addTearDown(state.dispose);

      state.selectSpread('daily');
      await tester.pumpWidget(wrap(const DeckSelectionScreen(), state));
      await tester.pump();
      expect(find.text('テーマ選択へ進む'), findsOneWidget);

      state.selectSpread('three');
      await tester.pump();
      expect(find.text('リーディングの種別へ進む'), findsOneWidget);
    });
  });
}
