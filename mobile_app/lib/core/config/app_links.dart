/// アプリ本体に関する外部URL（ストア・提供元・規約）の単一の置き場。
///
/// ショップ／鑑定／ロンの部屋の導線は運用で差し替えるためサーバーのマスタが持つが、
/// ここに置くのは「ストアの掲載ページ」「提供元の他アプリ」「規約」といった
/// **アプリの出自に紐づく固定リンク**で、配信ストア側で決まる値のためクライアント常数とする。
///
/// 変更するときはこのファイルだけを直す（画面に直書きしない）。
class AppLinks {
  const AppLinks._();

  /// Google Play のアプリケーションID（`android/app/build.gradle` の applicationId と一致）。
  static const String androidPackageName = 'com.apps2craft.oracle_mobile_app';

  /// 提供元の表示名。
  static const String developerName = 'App2Craft';

  /// ストアの掲載ページ（「アプリを評価」で開く）。
  static const String storeListingUrl =
      'https://play.google.com/store/apps/details?id=$androidPackageName';

  /// 提供元の他アプリ一覧（「App2Craftのアプリ」で開く）。
  /// Play の `pub:` 検索は開発者名で引けるため、デベロッパーIDが未確定でも成立する。
  static const String developerAppsUrl =
      'https://play.google.com/store/search?q=pub%3A$developerName&c=apps';

  /// 「アプリを共有」で送る本文。
  static const String shareSubject = '日本神話オラクルロンカード';
  static const String shareBody =
      '日本神話オラクルロンカード\n$storeListingUrl';

  /// 利用規約・プライバシーポリシー・特定商取引法に基づく表記。
  /// **公開先が未定のため空**。空のあいだ「規約・情報」画面は各項目を
  /// 「準備中」として押せない状態で並べる（開けないリンクを出さない）。
  static const String termsUrl = '';
  static const String privacyUrl = '';
  static const String commercialTransactionsUrl = '';
}
