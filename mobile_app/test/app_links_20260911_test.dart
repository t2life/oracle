import 'package:flutter_test/flutter_test.dart';

import 'package:oracle_mobile_app/core/config/app_links.dart';

/// 2026-09-11 提供元リンクの回帰テスト。
///
/// 守りたいこと:
///   ① 提供元の綴りがドメイン・窓口メールと一致すること（Apps2Craft）
///   ② 開けないリンクを出さないこと（未公開・未掲載は空文字＝画面が「準備中」を出す）
void main() {
  test('提供元の綴りはドメインと窓口メールに一致する', () {
    expect(AppLinks.developerName, 'Apps2Craft');
    expect(AppLinks.siteUrl, contains('apps2craft.com'));
    expect(AppLinks.supportEmail, endsWith('@apps2craft.com'));
  });

  test('他アプリの導線は提供元の共通サイトを見る（先行アプリと同じ場所）', () {
    expect(AppLinks.developerAppsUrl, AppLinks.siteUrl);
  });

  test('ストア未公開のあいだ掲載URLは空＝共有本文にURLを付けない', () {
    // 公開したら storeListingUrl を埋める。その時この2つは自動で連動する。
    if (AppLinks.storeListingUrl.isEmpty) {
      expect(AppLinks.shareBody, AppLinks.shareSubject);
    } else {
      expect(AppLinks.shareBody, contains(AppLinks.storeListingUrl));
    }
  });

  test('規約類のURLは空か、提供元サイトのオラクル用ディレクトリを指す', () {
    for (final url in [
      AppLinks.termsUrl,
      AppLinks.privacyUrl,
      AppLinks.commercialTransactionsUrl,
    ]) {
      if (url.isNotEmpty) {
        expect(url, startsWith('https://apps2craft.com/oracle/'));
      }
    }
  });
}
