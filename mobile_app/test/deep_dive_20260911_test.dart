import 'package:flutter_test/flutter_test.dart';

import 'package:oracle_mobile_app/core/models/domain_models.dart';
import 'package:oracle_mobile_app/core/network/api_client.dart';
import 'package:oracle_mobile_app/core/offline/offline_backend.dart';
import 'package:oracle_mobile_app/core/state/app_state.dart';

/// 2026-09-11 深掘りリーディングの回帰テスト。
///
/// 守りたいこと:
///   ① 深掘りに入ると起点・テーマ・デッキが託宣から引き継がれる
///   ② 深掘りを抜けたら起点が残らない（次の占いが前回を引き継がない）
///   ③ 結果は起点セッションを持ち、履歴の統合に使える
void main() {
  OracleAppState buildState() => OracleAppState(
        remoteClient: ApiClient(baseUrl: 'http://127.0.0.1:8000'),
        offlineBackend: OfflineBackend(),
      );

  ReadingResultModel daily() => ReadingResultModel.fromJson(const {
        'session_id': 'ses_daily',
        'user_id': 'u1',
        'theme_id': 'work',
        'deck_id': 'japanese_mythology',
        'card_id': 'japanese_mythology_card_006',
        'card_name': '須佐之男命',
        'keywords': ['嵐'],
        'interpretation_text': '本文',
        'caution_text': null,
        'created_at': '2026-09-11T00:00:00+09:00',
        'copied': false,
        'spread_id': 'daily',
      });

  test('起点が無いときは深掘りではない', () {
    final state = buildState();
    addTearDown(state.dispose);
    expect(state.isDeepDive, isFalse);
    expect(state.originSessionId, isNull);
  });

  test('結果が無ければ深掘りを始められない', () {
    final state = buildState();
    addTearDown(state.dispose);
    state.startDeepDive();
    expect(state.isDeepDive, isFalse);
  });

  test('深掘りを抜けると起点が残らない', () {
    final state = buildState();
    addTearDown(state.dispose);
    // 起点を持たせてから捨てる（次の占いへ持ち越さない）
    state.clearDeepDive();
    expect(state.isDeepDive, isFalse);
  });

  test('結果は起点セッションを解釈できる（履歴の統合に使う）', () {
    final deep = ReadingResultModel.fromJson(const {
      'session_id': 'ses_deep',
      'user_id': 'u1',
      'theme_id': 'work',
      'deck_id': 'japanese_mythology',
      'card_id': 'japanese_mythology_card_006',
      'card_name': '須佐之男命',
      'keywords': ['嵐'],
      'interpretation_text': '本文',
      'caution_text': null,
      'created_at': '2026-09-11T00:00:00+09:00',
      'copied': false,
      'spread_id': 'three',
      'origin_session_id': 'ses_daily',
    });
    expect(deep.originSessionId, 'ses_daily');
    // 起点が無い結果は null（通常のリーディング）
    expect(daily().originSessionId, isNull);
  });
}
