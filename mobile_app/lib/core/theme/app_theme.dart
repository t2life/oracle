import 'package:flutter/material.dart';

/// テーマ配色のルール（2026-09-09 制定）。
///
/// 1テーマ＝1パレットとし、**背景・アクセント（操作色）・文字**を必ず組で定義する。
/// 個々の画面やウィジェットで色を直接指定せず、必ずこのパレット由来の
/// `ThemeData` を経由させる（色の乱立防止）。
///
/// 共通ルール:
/// - アクセント（ボタン等）の上の文字色は**明度で自動決定**する。
///   濃い色のボタンには白、淡い色のボタンには濃いインクを載せる（[OraclePalette.onAccent]）。
/// - 背景は「面」を1段持つ（[OraclePalette.surface]）。カード・ドロワー・入力はこの面に載せる。
/// - 本文は [OraclePalette.ink]、補助文は [OraclePalette.subInk]。真っ黒・真っ白は使わない。
@immutable
class OraclePalette {
  const OraclePalette({
    required this.background,
    required this.surface,
    required this.accent,
    required this.secondary,
    required this.ink,
    required this.subInk,
    required this.brightness,
  });

  /// 画面の地色。
  final Color background;

  /// カード・ドロワー等の面。背景とわずかに差をつける。
  final Color surface;

  /// 操作（ボタン・選択状態・強調）の色。
  final Color accent;

  /// 補助アクセント（副次ボタン・装飾）。
  final Color secondary;

  /// 本文の文字色。
  final Color ink;

  /// 補助文・キャプションの文字色。
  final Color subInk;

  final Brightness brightness;

  /// アクセント（ボタン）の上の文字色。白と濃いインクのうち**コントラストが高い方**。
  /// 「濃い色のボタンには白」を輝度の固定閾値でなくコントラスト比で担保する
  /// （固定閾値だとゴールド等の中間色で白が選ばれ読めなくなるため）。
  Color get onAccent => _readableOn(accent);

  /// 補助アクセント上の文字色（同じ規則）。
  Color get onSecondary => _readableOn(secondary);
}

/// 淡い面に載せる濃いインク（真っ黒は使わない）。
const Color _kDarkInk = Color(0xFF2B2B2B);

/// 2色のコントラスト比（WCAG）。
double contrastRatio(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

/// 指定色の上に載せて読める文字色（白 or 濃いインク）を返す。
Color _readableOn(Color background) =>
    contrastRatio(background, Colors.white) >=
            contrastRatio(background, _kDarkInk)
        ? Colors.white
        : _kDarkInk;

/// 紺（ネイビー）系＝既定。ダークモード風で高級感。文字は白〜薄いグレー。
const OraclePalette _navy = OraclePalette(
  background: Color(0xFF0B192C),
  surface: Color(0xFF14263F),
  accent: Color(0xFFD4AF37), // ゴールド
  secondary: Color(0xFF00D2FF), // 明るい水色
  ink: Color(0xFFFFFFFF),
  subInk: Color(0xFFE0E0E0),
  brightness: Brightness.dark,
);

/// 白（ホワイト）系。真っ白は目が疲れるため乳白色。文字は濃いグレー。
const OraclePalette _white = OraclePalette(
  background: Color(0xFFF9F9F9),
  surface: Color(0xFFF5F5F0),
  accent: Color(0xFF2B2B2B), // くすみ黒
  secondary: Color(0xFF8E8D8A), // グレージュ
  ink: Color(0xFF333333),
  subInk: Color(0xFF6B6B68),
  brightness: Brightness.light,
);

/// ピンク系。背景はペールピンク、ボタンはローズピンク、文字は濃いグレー。
const OraclePalette _pink = OraclePalette(
  background: Color(0xFFFFD1DC),
  surface: Color(0xFFFFF0F4),
  accent: Color(0xFFE0115F), // ローズピンク
  secondary: Color(0xFFEC6BA0),
  ink: Color(0xFF333333),
  subInk: Color(0xFF6B4A55),
  brightness: Brightness.light,
);

/// 青（ブルー）系。清潔感と信頼感。薄い青地に濃い青文字。
const OraclePalette _blue = OraclePalette(
  background: Color(0xFFE3F2FD),
  surface: Color(0xFFF4F9FE),
  accent: Color(0xFF0D47A1), // ロイヤルブルー
  secondary: Color(0xFF4FB0E0),
  ink: Color(0xFF0A2540),
  subInk: Color(0xFF44607A),
  brightness: Brightness.light,
);

/// 緑（グリーン）系。目に優しいナチュラル。ミント地にフォレストグリーン。
const OraclePalette _green = OraclePalette(
  background: Color(0xFFE8F5E9),
  surface: Color(0xFFF3FAF4),
  accent: Color(0xFF2E7D32), // フォレストグリーン
  secondary: Color(0xFFD0E1D4), // セージグリーン
  ink: Color(0xFF1B5E20),
  subInk: Color(0xFF4B6B4E),
  brightness: Brightness.light,
);

/// テーマ設定コード → パレット。設定値（SharedPreferences）は従来のコードを維持する。
const Map<String, OraclePalette> oraclePalettes = <String, OraclePalette>{
  'dark': _navy,
  'light': _white,
  'pink': _pink,
  'skyblue': _blue,
  'lime': _green,
};

/// マイページのスウォッチ等で使う表示順（テーマ選択UIと配色の単一真実源）。
const List<String> oracleThemeOrder = <String>[
  'dark',
  'light',
  'pink',
  'skyblue',
  'lime',
];

/// 未知のコードは既定（紺）へ寄せる。
OraclePalette paletteFor(String preference) =>
    oraclePalettes[preference] ?? _navy;

TextTheme _buildTextTheme(TextTheme base, OraclePalette palette) {
  // 見出し系は明朝（serif）で「神託の重み」を演出、本文は可読性優先のサンセリフ。
  TextStyle serif(TextStyle? style, double size, FontWeight weight) {
    return (style ?? const TextStyle()).copyWith(
      fontFamily: 'serif',
      fontSize: size,
      fontWeight: weight,
      color: palette.ink,
      height: 1.4,
    );
  }

  return base.copyWith(
    displaySmall: serif(base.displaySmall, 34, FontWeight.w600),
    headlineMedium: serif(base.headlineMedium, 26, FontWeight.w600),
    headlineSmall: serif(base.headlineSmall, 22, FontWeight.w600),
    titleLarge: serif(base.titleLarge, 20, FontWeight.w700),
    titleMedium: base.titleMedium?.copyWith(
      fontWeight: FontWeight.w600,
      color: palette.ink,
    ),
    titleSmall: base.titleSmall?.copyWith(color: palette.ink),
    bodyLarge: base.bodyLarge?.copyWith(height: 1.65, color: palette.ink),
    bodyMedium: base.bodyMedium?.copyWith(height: 1.55, color: palette.ink),
    bodySmall: base.bodySmall?.copyWith(color: palette.subInk),
    labelLarge: base.labelLarge?.copyWith(color: palette.ink),
    labelMedium: base.labelMedium?.copyWith(color: palette.subInk),
    labelSmall: base.labelSmall?.copyWith(color: palette.subInk),
  );
}

/// パレットから配色ルールどおりの [ThemeData] を組み立てる（全テーマ共通の唯一の入口）。
ThemeData buildAppTheme(OraclePalette palette) {
  final isDark = palette.brightness == Brightness.dark;
  final scheme = ColorScheme(
    brightness: palette.brightness,
    primary: palette.accent,
    onPrimary: palette.onAccent,
    primaryContainer: Color.alphaBlend(
      palette.accent.withValues(alpha: isDark ? 0.28 : 0.16),
      palette.surface,
    ),
    onPrimaryContainer: palette.ink,
    secondary: palette.secondary,
    onSecondary: palette.onSecondary,
    secondaryContainer: Color.alphaBlend(
      palette.secondary.withValues(alpha: isDark ? 0.28 : 0.20),
      palette.surface,
    ),
    onSecondaryContainer: palette.ink,
    tertiary: palette.secondary,
    onTertiary: palette.onSecondary,
    tertiaryContainer: Color.alphaBlend(
      palette.secondary.withValues(alpha: 0.14),
      palette.surface,
    ),
    onTertiaryContainer: palette.ink,
    error: isDark ? const Color(0xFFF2B0A6) : const Color(0xFFB3261E),
    onError: isDark ? const Color(0xFF411410) : Colors.white,
    errorContainer: isDark ? const Color(0xFF6B2A22) : const Color(0xFFF9DEDC),
    onErrorContainer: isDark ? const Color(0xFFFFDAD3) : const Color(0xFF410E0B),
    surface: palette.surface,
    onSurface: palette.ink,
    surfaceContainerHighest: Color.alphaBlend(
      palette.ink.withValues(alpha: 0.06),
      palette.surface,
    ),
    onSurfaceVariant: palette.subInk,
    outline: palette.subInk,
    outlineVariant: palette.subInk.withValues(alpha: 0.4),
    shadow: Colors.black,
    scrim: Colors.black,
    inverseSurface: palette.ink,
    onInverseSurface: palette.background,
    inversePrimary: palette.secondary,
  );

  final base = ThemeData(useMaterial3: true, colorScheme: scheme);
  final text = _buildTextTheme(base.textTheme, palette);
  return base.copyWith(
    scaffoldBackgroundColor: palette.background,
    textTheme: text,
    appBarTheme: AppBarTheme(
      backgroundColor: palette.background,
      foregroundColor: palette.ink,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: text.titleLarge,
    ),
    cardTheme: base.cardTheme.copyWith(
      color: palette.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: palette.accent.withValues(alpha: 0.22)),
      ),
      margin: const EdgeInsets.symmetric(vertical: 6),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: palette.surface,
      indicatorColor: palette.accent.withValues(alpha: 0.22),
      height: 68,
      labelTextStyle: WidgetStatePropertyAll(
        text.labelSmall?.copyWith(color: palette.ink, fontSize: 11),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? palette.accent
              : palette.subInk,
        ),
      ),
    ),
    drawerTheme: DrawerThemeData(backgroundColor: palette.surface),
    dividerTheme: DividerThemeData(
      color: palette.accent.withValues(alpha: 0.18),
    ),
    // 濃いボタンには白文字（共通ルール）。onAccentがそれを保証する。
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: palette.accent,
        foregroundColor: palette.onAccent,
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: palette.accent,
        foregroundColor: palette.onAccent,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: palette.accent),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: palette.accent,
        side: BorderSide(color: palette.accent.withValues(alpha: 0.6)),
        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: palette.surface,
      side: BorderSide(color: palette.accent.withValues(alpha: 0.35)),
      labelStyle: TextStyle(color: palette.ink),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: palette.accent,
      textColor: palette.ink,
    ),
    iconTheme: IconThemeData(color: palette.ink),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: palette.accent),
    sliderTheme: base.sliderTheme.copyWith(
      activeTrackColor: palette.accent,
      thumbColor: palette.accent,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: palette.surface,
      contentTextStyle: TextStyle(color: palette.ink),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: palette.surface,
      labelStyle: TextStyle(color: palette.subInk),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: palette.accent.withValues(alpha: 0.35)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: palette.accent.withValues(alpha: 0.35)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: palette.accent, width: 2),
      ),
    ),
  );
}

/// テーマ設定コード→ThemeDataの解決。
/// 'image'（ユーザー画像テーマ）は紺基調＋透過scaffoldで背景画像を透かす。
ThemeData resolveAppTheme(String preference) {
  if (preference == 'image') {
    // 背景画像の上に明色文字で載せる（scaffoldは透過し画像を見せる）
    return buildAppTheme(_navy).copyWith(
      scaffoldBackgroundColor: Colors.transparent,
    );
  }
  return buildAppTheme(paletteFor(preference));
}
