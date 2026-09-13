/// アプリ本体に関する外部URL（ストア・提供元・規約）の単一の置き場。
///
/// ショップ／鑑定／ロンの部屋の導線は運用で差し替えるためサーバーのマスタが持つが、
/// ここに置くのは「ストアの掲載ページ」「提供元の他アプリ」「規約」といった
/// **アプリの出自に紐づく固定リンク**で、配信ストア側で決まる値のためクライアント常数とする。
///
/// 公開サイト `apps2craft.com` は提供元の共通置き場で、先行アプリ（吉凶羅針盤）と
/// 同じ場所を使う。アプリごとにディレクトリを分ける方式である
/// （例: `/geokarmacompass/privacy.html`）。生成元は先行アプリ側の
/// `scripts/build_site.py`（`jyuuni-tensui-chireki`）。
///
/// 変更するときはこのファイルだけを直す（画面に直書きしない）。
class AppLinks {
  const AppLinks._();

  /// Google Play のアプリケーションID（`android/app/build.gradle` の applicationId と一致）。
  static const String androidPackageName = 'com.apps2craft.oracle_mobile_app';

  /// 提供元の表示名。ドメイン `apps2craft.com`・窓口 `support@apps2craft.com`・
  /// 先行アプリの定数（`AppInfoConfig.SUPPORT_ORGANIZATION`）と同じ綴りに揃える。
  static const String developerName = 'Apps2Craft';

  /// 提供元の公開サイト（提供元共通のトップ）。
  static const String siteUrl = 'https://apps2craft.com/';

  /// ストアの掲載ページ（「アプリを評価」で開く）。
  ///
  /// **未公開のあいだは空**にしておく。掲載前のURLを開くとストアが
  /// 「見つかりません」を出すため、空＝「準備中」として押せない状態にする
  /// （先行アプリの `AppInfoConfig.APP_STORE_URL = ""` と同じ扱い）。
  /// 公開したら次の値を入れる:
  ///   https://play.google.com/store/apps/details?id=com.apps2craft.oracle_mobile_app
  static const String storeListingUrl = '';

  /// 提供元の他アプリ（「Apps2Craftのアプリ」で開く）。
  ///
  /// Play の開発者ページはストアに公開済みのアプリしか載らないため、
  /// 提供元が自分で管理できる公開サイトのトップを出す。
  /// 先行アプリと**同じ場所**を見ることになる。
  static const String developerAppsUrl = siteUrl;

  /// 「アプリを共有」で送る本文。ストア未公開のあいだはURLを付けない。
  static const String shareSubject = '日本神話オラクルロンカード';
  static String get shareBody => storeListingUrl.isEmpty
      ? shareSubject
      : '$shareSubject\n$storeListingUrl';

  /// 利用規約・プライバシーポリシー・特定商取引法に基づく表記。
  ///
  /// 掲載先は決定済みで、先行アプリと同じ形（アプリごとのディレクトリ）:
  ///   利用規約     https://apps2craft.com/oracle/terms.html
  ///   プライバシー https://apps2craft.com/oracle/privacy.html
  ///   特定商取引法 https://apps2craft.com/oracle/tokushoho.html
  /// ページは `scripts/build_legal_site.py` が `docs/仕様書/` の本文から生成する。
  ///
  /// 3件とも本文は確定済み（2026-09-11）。**サーバーへのアップロードが済むまでは
  /// 404になる**ため、掲載を確認してから配布用ビルドを作ること。
  /// 空にすると「規約・情報」画面は各項目を「準備中」として押せない状態で並べる。
  static const String termsUrl = 'https://apps2craft.com/oracle/terms.html';
  static const String privacyUrl = 'https://apps2craft.com/oracle/privacy.html';
  static const String commercialTransactionsUrl =
      'https://apps2craft.com/oracle/tokushoho.html';

  /// 問い合わせ窓口（先行アプリと共通）。
  /// お問い合わせは**利用者のメールアプリ**からここへ送られる（2026-09-13）。
  static const String supportEmail = 'support@apps2craft.com';

  /// アプリの版数。お問い合わせの本文へ自動で付記し、不具合の切り分けに使う。
  ///
  /// ★`pubspec.yaml` の `version:` と**必ず一致させる**。
  /// 依存を増やさずに版数を知るための写しであり、ずれると問い合わせの
  /// 版数が嘘になる。`test/inquiry_mail_20260913_test.dart` が機械的に照合する。
  static const String appVersion = '0.1.0+1';
}
