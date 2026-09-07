/// 状態層（app_state / offline_backend）がUIへ渡すメッセージコード。
///
/// 状態層はBuildContextへ依存できないため、利用者向け文言はここで定義した
/// コード文字列として保持し、画面側で `resolveStateMessage`（
/// features/shared/state_message_l10n.dart）により現在の言語へ解決する。
/// コードに該当しない文字列（サーバー返却の文言等）はそのまま表示される。
class StateMessages {
  static const String sessionStarted = 'msg_session_started';
  static const String shuffleCompleted = 'msg_shuffle_completed';
  static const String pileSelected = 'msg_pile_selected';
  static const String cardRevealed = 'msg_card_revealed';
  static const String historySaved = 'msg_history_saved';
  static const String premiumUnlocked = 'msg_premium_unlocked';
  static const String offlineMode = 'msg_offline_mode';
  static const String selectDeckTheme = 'msg_select_deck_theme';
  static const String sessionNotStarted = 'msg_session_not_started';
  static const String offlineFeatureUnavailable = 'msg_offline_feature_unavailable';
  static const String freeDailyLimit = 'msg_free_daily_limit';
  static const String paidOnlyDraw = 'msg_paid_only_draw';
  static const String ticketShortage = 'msg_ticket_shortage';
  static const String purchaseRestored = 'msg_purchase_restored';
  static const String historyDeleted = 'msg_history_deleted';
  static const String nicknameSaved = 'msg_nickname_saved';

  static const String commErrorPrefix = 'msg_comm_error:';

  static String commError(int statusCode) => '$commErrorPrefix$statusCode';
}
