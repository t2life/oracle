/// お問い合わせの中身（2026-09-13 承認）。
///
/// ★**送信は利用者のメールアプリに委ねる**。アプリから直接は送らない。
///
/// これは妥協ではなく、この構成での最良である。
/// - **返信先**: 利用者自身のメールアプリから出るため、**送信元がそのまま返信先**になる。
///   アドレスを入力させる必要も、入力ミスで届かない心配も無い。
/// - **オフラインでも押せる**: 以前はサーバーへ送っていたため、機内モードや
///   サーバー未公開の状態では**ボタンごと無効**だった。メーラーに委ねれば
///   その制約が消える。
///
/// ★件名・本文の組み立ては**画面ではなくここで行う**。
/// 画面ごとに組み立てると、片方だけ「版数の付記」を忘れるといった食い違いが起きる。
///
/// 文言は多言語（ja/en/zh）に従うため、**localized な文字列は引数で受け取る**。
/// ここに日本語を書かない（画面が `AppLocalizations` から渡す）。
class InquiryForm {
  const InquiryForm._();

  /// 本文の上限。長すぎる本文は `mailto:` のURL長でメーラーが開けなくなることがある。
  static const int maxBodyLength = 4000;

  /// 本文と環境情報の区切り。
  static const String _separator = '--------------------';

  /// メールの件名。
  ///
  /// ★アプリ名を前置する。受信箱で他の連絡と混ざらず、種類で仕分けできる。
  static String subject({
    required String appName,
    required String topicLabel,
  }) =>
      '[$appName] $topicLabel';

  /// メールの本文。
  ///
  /// ★**端末とアプリの情報を自動で付記する**。不具合の切り分けには
  /// 「どの版で・どの端末で」が要るが、利用者に毎回書かせるのは酷であり、
  /// 書き忘れれば結局こちらから聞き返すことになる。
  static String body({
    required String input,
    required String environmentNote,
    required String environment,
  }) {
    final buffer = StringBuffer()
      ..write(input.trimRight())
      ..write('\n\n')
      ..write(_separator)
      ..write('\n')
      ..write(environmentNote)
      ..write('\n')
      ..write(environment);
    return buffer.toString();
  }

  /// 送信できるか。空文字と上限超過を弾く。
  static bool canSend(String input) =>
      input.trim().isNotEmpty && input.length <= maxBodyLength;

  /// 残り文字数。**負なら超過**している。
  ///
  /// ★0で頭打ちにしない。あと何文字削ればよいか分からなくなるため。
  static int remaining(String input) => maxBodyLength - input.length;

  /// メーラーを開くための `mailto:` URI。
  ///
  /// ★`Uri(queryParameters: …)` は空白を `+` にするため使わない。
  /// `mailto:` の本文で `+` は空白に戻らず、そのまま文字として届くメーラーがある。
  /// ∴ `Uri.encodeComponent`（空白は `%20`）で自分で組む。
  static Uri mailtoUri({
    required String to,
    required String subject,
    required String body,
  }) {
    final query = 'subject=${Uri.encodeComponent(subject)}'
        '&body=${Uri.encodeComponent(body)}';
    return Uri.parse('mailto:$to?$query');
  }
}
