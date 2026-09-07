/// 表示言語コード（ja/en/zh）に応じてローカライズ済み文字列を選ぶ。
/// en/zh が未提供（空文字）の場合は日本語へフォールバックする。
String pickLocalizedText({
  required String languageCode,
  required String ja,
  String en = '',
  String zh = '',
}) {
  switch (languageCode) {
    case 'en':
      return en.isNotEmpty ? en : ja;
    case 'zh':
      return zh.isNotEmpty ? zh : ja;
    default:
      return ja;
  }
}

List<String> pickLocalizedList({
  required String languageCode,
  required List<String> ja,
  List<String> en = const [],
  List<String> zh = const [],
}) {
  switch (languageCode) {
    case 'en':
      return en.isNotEmpty ? en : ja;
    case 'zh':
      return zh.isNotEmpty ? zh : ja;
    default:
      return ja;
  }
}

List<String> _stringList(dynamic value) {
  if (value is List) {
    return value.map((item) => item.toString()).toList();
  }
  return const [];
}

class ThemeModel {
  const ThemeModel({
    required this.themeId,
    required this.nameJa,
    this.nameEn = '',
    this.nameZh = '',
  });

  factory ThemeModel.fromJson(Map<String, dynamic> json) {
    return ThemeModel(
      themeId: json['theme_id'] as String,
      nameJa: json['name_ja'] as String,
      nameEn: json['name_en'] as String? ?? '',
      nameZh: json['name_zh'] as String? ?? '',
    );
  }

  final String themeId;
  final String nameJa;
  final String nameEn;
  final String nameZh;

  String nameFor(String languageCode) => pickLocalizedText(
        languageCode: languageCode,
        ja: nameJa,
        en: nameEn,
        zh: nameZh,
      );
}

class DeckModel {
  const DeckModel({
    required this.deckId,
    required this.nameJa,
    required this.sortOrder,
    this.nameEn = '',
    this.nameZh = '',
  });

  factory DeckModel.fromJson(Map<String, dynamic> json) {
    return DeckModel(
      deckId: json['deck_id'] as String,
      nameJa: json['name_ja'] as String,
      sortOrder: json['sort_order'] as int,
      nameEn: json['name_en'] as String? ?? '',
      nameZh: json['name_zh'] as String? ?? '',
    );
  }

  final String deckId;
  final String nameJa;
  final int sortOrder;
  final String nameEn;
  final String nameZh;

  String nameFor(String languageCode) => pickLocalizedText(
        languageCode: languageCode,
        ja: nameJa,
        en: nameEn,
        zh: nameZh,
      );
}

class CardModel {
  const CardModel({
    required this.cardId,
    required this.deckId,
    required this.nameJa,
    required this.keywords,
    this.nameEn = '',
    this.nameZh = '',
    this.keywordsEn = const [],
    this.keywordsZh = const [],
  });

  factory CardModel.fromJson(Map<String, dynamic> json) {
    return CardModel(
      cardId: json['card_id'] as String,
      deckId: json['deck_id'] as String,
      nameJa: json['name_ja'] as String,
      keywords: _stringList(json['keywords']),
      nameEn: json['name_en'] as String? ?? '',
      nameZh: json['name_zh'] as String? ?? '',
      keywordsEn: _stringList(json['keywords_en']),
      keywordsZh: _stringList(json['keywords_zh']),
    );
  }

  final String cardId;
  final String deckId;
  final String nameJa;
  final List<String> keywords;
  final String nameEn;
  final String nameZh;
  final List<String> keywordsEn;
  final List<String> keywordsZh;

  String nameFor(String languageCode) => pickLocalizedText(
        languageCode: languageCode,
        ja: nameJa,
        en: nameEn,
        zh: nameZh,
      );

  List<String> keywordsFor(String languageCode) => pickLocalizedList(
        languageCode: languageCode,
        ja: keywords,
        en: keywordsEn,
        zh: keywordsZh,
      );
}

class ReadingResultModel {
  const ReadingResultModel({
    required this.sessionId,
    required this.userId,
    required this.themeId,
    required this.deckId,
    required this.cardId,
    required this.cardName,
    required this.keywords,
    required this.interpretationText,
    required this.cautionText,
    required this.createdAt,
    required this.copied,
    this.cardNameEn = '',
    this.keywordsEn = const [],
    this.interpretationTextEn = '',
    this.cautionTextEn,
    this.cardNameZh = '',
    this.keywordsZh = const [],
    this.interpretationTextZh = '',
    this.cautionTextZh,
    this.combinationText,
  });

  factory ReadingResultModel.fromJson(Map<String, dynamic> json) {
    return ReadingResultModel(
      sessionId: json['session_id'] as String,
      userId: json['user_id'] as String,
      themeId: json['theme_id'] as String,
      deckId: json['deck_id'] as String,
      cardId: json['card_id'] as String,
      cardName: json['card_name'] as String,
      keywords: _stringList(json['keywords']),
      interpretationText: json['interpretation_text'] as String,
      cautionText: json['caution_text'] as String?,
      createdAt: json['created_at'] as String,
      copied: json['copied'] as bool,
      cardNameEn: json['card_name_en'] as String? ?? '',
      keywordsEn: _stringList(json['keywords_en']),
      interpretationTextEn: json['interpretation_text_en'] as String? ?? '',
      cautionTextEn: json['caution_text_en'] as String?,
      cardNameZh: json['card_name_zh'] as String? ?? '',
      keywordsZh: _stringList(json['keywords_zh']),
      interpretationTextZh: json['interpretation_text_zh'] as String? ?? '',
      cautionTextZh: json['caution_text_zh'] as String?,
      combinationText: json['combination_text'] as String?,
    );
  }

  final String sessionId;
  final String userId;
  final String themeId;
  final String deckId;
  final String cardId;
  final String cardName;
  final List<String> keywords;
  final String interpretationText;
  final String? cautionText;
  final String createdAt;
  final bool copied;
  final String cardNameEn;
  final List<String> keywordsEn;
  final String interpretationTextEn;
  final String? cautionTextEn;
  final String cardNameZh;
  final List<String> keywordsZh;
  final String interpretationTextZh;
  final String? cautionTextZh;

  /// 組み合わせ解釈（日本語のみ提供・ja以外の表示言語では描画しない）
  final String? combinationText;

  String cardNameFor(String languageCode) => pickLocalizedText(
        languageCode: languageCode,
        ja: cardName,
        en: cardNameEn,
        zh: cardNameZh,
      );

  List<String> keywordsFor(String languageCode) => pickLocalizedList(
        languageCode: languageCode,
        ja: keywords,
        en: keywordsEn,
        zh: keywordsZh,
      );

  String interpretationFor(String languageCode) => pickLocalizedText(
        languageCode: languageCode,
        ja: interpretationText,
        en: interpretationTextEn,
        zh: interpretationTextZh,
      );

  String? cautionFor(String languageCode) {
    final resolved = pickLocalizedText(
      languageCode: languageCode,
      ja: cautionText ?? '',
      en: cautionTextEn ?? '',
      zh: cautionTextZh ?? '',
    );
    return resolved.isEmpty ? null : resolved;
  }
}

class ProductModel {
  const ProductModel({
    required this.productCode,
    required this.title,
    required this.planType,
    required this.priceJpy,
    required this.ticketAmount,
    required this.isSubscription,
  });

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    return ProductModel(
      productCode: json['product_code'] as String,
      title: json['title'] as String,
      planType: json['plan_type'] as String,
      priceJpy: json['price_jpy'] as int,
      ticketAmount: json['ticket_amount'] as int,
      isSubscription: json['is_subscription'] as bool,
    );
  }

  final String productCode;
  final String title;
  final String planType;
  final int priceJpy;
  final int ticketAmount;
  final bool isSubscription;
}

class AnnouncementModel {
  const AnnouncementModel({
    required this.announcementId,
    required this.title,
    required this.body,
    required this.category,
    required this.startAt,
    required this.endAt,
    required this.isImportant,
    required this.linkUrl,
  });

  factory AnnouncementModel.fromJson(Map<String, dynamic> json) {
    return AnnouncementModel(
      announcementId: json['announcement_id'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      category: json['category'] as String,
      startAt: json['start_at'] as String,
      endAt: json['end_at'] as String,
      isImportant: json['is_important'] as bool,
      linkUrl: json['link_url'] as String?,
    );
  }

  final String announcementId;
  final String title;
  final String body;
  final String category;
  final String startAt;
  final String endAt;
  final bool isImportant;
  final String? linkUrl;
}

class HistoryItemModel {
  const HistoryItemModel({
    required this.historyId,
    required this.sessionId,
    required this.createdAt,
    required this.themeId,
    required this.deckId,
    required this.cardId,
    required this.summary,
    required this.fullText,
    required this.planAtCreation,
  });

  factory HistoryItemModel.fromJson(Map<String, dynamic> json) {
    return HistoryItemModel(
      historyId: json['history_id'] as String,
      sessionId: json['session_id'] as String,
      createdAt: json['created_at'] as String,
      themeId: json['theme_id'] as String,
      deckId: json['deck_id'] as String,
      cardId: json['card_id'] as String,
      summary: json['summary'] as String,
      fullText: json['full_text'] as String,
      planAtCreation: json['plan_at_creation'] as String,
    );
  }

  final String historyId;
  final String sessionId;
  final String createdAt;
  final String themeId;
  final String deckId;
  final String cardId;
  final String summary;
  final String fullText;
  final String planAtCreation;
}

class UserProfileModel {
  const UserProfileModel({
    required this.userId,
    required this.plan,
    required this.tickets,
    required this.visitCount,
    this.displayName = '',
  });

  factory UserProfileModel.fromJson(Map<String, dynamic> json) {
    return UserProfileModel(
      userId: json['user_id'] as String,
      plan: json['plan'] as String,
      tickets: json['tickets'] as int,
      visitCount: json['visit_count'] as int,
      displayName: json['display_name'] as String? ?? '',
    );
  }

  final String userId;
  final String plan;
  final int tickets;
  final int visitCount;
  final String displayName;
}

class ExternalLinkModel {
  const ExternalLinkModel({
    required this.linkId,
    required this.category,
    required this.title,
    required this.url,
  });

  factory ExternalLinkModel.fromJson(Map<String, dynamic> json) {
    return ExternalLinkModel(
      linkId: json['link_id'] as String,
      category: json['category'] as String,
      title: json['title'] as String,
      url: json['url'] as String,
    );
  }

  final String linkId;
  final String category;
  final String title;
  final String url;
}

class LiveEventModel {
  const LiveEventModel({
    required this.liveEventId,
    required this.title,
    required this.startAt,
    required this.archiveUrl,
  });

  factory LiveEventModel.fromJson(Map<String, dynamic> json) {
    return LiveEventModel(
      liveEventId: json['live_event_id'] as String,
      title: json['title'] as String,
      startAt: json['start_at'] as String,
      archiveUrl: json['archive_url'] as String?,
    );
  }

  final String liveEventId;
  final String title;
  final String startAt;
  final String? archiveUrl;
}
