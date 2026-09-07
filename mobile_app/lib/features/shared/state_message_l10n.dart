import 'package:flutter/widgets.dart';

import '../../core/state/state_messages.dart';
import '../../l10n/app_localizations.dart';

/// 状態層が保持するメッセージ（コード or サーバー文言）を表示用文字列へ解決する。
/// [StateMessages] のコードは現在の表示言語へローカライズし、
/// コードに該当しない文字列（サーバー返却の文言等）はそのまま返す。
String resolveStateMessage(BuildContext context, String raw) {
  final l10n = AppLocalizations.of(context)!;

  if (raw.startsWith(StateMessages.commErrorPrefix)) {
    final status = raw.substring(StateMessages.commErrorPrefix.length);
    return l10n.msgCommError(status);
  }

  switch (raw) {
    case StateMessages.sessionStarted:
      return l10n.msgSessionStarted;
    case StateMessages.shuffleCompleted:
      return l10n.msgShuffleCompleted;
    case StateMessages.pileSelected:
      return l10n.msgPileSelected;
    case StateMessages.cardRevealed:
      return l10n.msgCardRevealed;
    case StateMessages.historySaved:
      return l10n.msgHistorySaved;
    case StateMessages.premiumUnlocked:
      return l10n.msgPremiumUnlocked;
    case StateMessages.offlineMode:
      return l10n.msgOfflineMode;
    case StateMessages.selectDeckTheme:
      return l10n.msgSelectDeckTheme;
    case StateMessages.sessionNotStarted:
      return l10n.msgSessionNotStarted;
    case StateMessages.offlineFeatureUnavailable:
      return l10n.msgOfflineFeatureUnavailable;
    case StateMessages.freeDailyLimit:
      return l10n.msgFreeDailyLimit;
    case StateMessages.paidOnlyDraw:
      return l10n.msgPaidOnlyDraw;
    case StateMessages.ticketShortage:
      return l10n.msgTicketShortage;
    case StateMessages.purchaseRestored:
      return l10n.msgPurchaseRestored;
    case StateMessages.historyDeleted:
      return l10n.msgHistoryDeleted;
    case StateMessages.nicknameSaved:
      return l10n.msgNicknameSaved;
    default:
      return raw;
  }
}
