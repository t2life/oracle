import 'package:flutter_test/flutter_test.dart';

import 'package:oracle_mobile_app/core/network/api_client.dart';
import 'package:oracle_mobile_app/core/offline/offline_backend.dart';
import 'package:oracle_mobile_app/core/state/app_state.dart';

void main() {
  test('OracleAppStateの初期状態は無料プランかつ未初期化である', () {
    final state = OracleAppState(
      remoteClient: ApiClient(baseUrl: 'http://127.0.0.1:8000'),
      offlineBackend: OfflineBackend(),
    );

    expect(state.initialized, isFalse);
    expect(state.offlineMode, isFalse);
    expect(state.plan, 'free');
    expect(state.tickets, 0);
    expect(state.userId, 'mobile_demo_user');
    expect(state.languagePreference, 'system');
    expect(state.appLocale, isNull);
  });
}
