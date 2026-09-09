import 'package:flutter/material.dart';

const Color _gold = Color(0xFFD9AC57);
const Color _goldBright = Color(0xFFEFCF8B);
const Color _surfaceDark = Color(0xFF1E1834);
const Color _surfaceDarkHigh = Color(0xFF272044);
const Color _inkOnDark = Color(0xFFF1EAD9);
const Color _teal = Color(0xFF3B8C7F);

TextTheme _buildTextTheme(TextTheme base, Color ink) {
  // 見出し系は明朝（serif）で「神託の重み」を演出、本文は可読性優先のサンセリフ。
  TextStyle serif(TextStyle? style, double size, FontWeight weight) {
    return (style ?? const TextStyle()).copyWith(
      fontFamily: 'serif',
      fontSize: size,
      fontWeight: weight,
      color: ink,
      height: 1.4,
    );
  }

  return base.copyWith(
    displaySmall: serif(base.displaySmall, 34, FontWeight.w600),
    headlineMedium: serif(base.headlineMedium, 26, FontWeight.w600),
    headlineSmall: serif(base.headlineSmall, 22, FontWeight.w600),
    titleLarge: serif(base.titleLarge, 20, FontWeight.w700),
    titleMedium: base.titleMedium?.copyWith(fontWeight: FontWeight.w600),
    bodyLarge: base.bodyLarge?.copyWith(height: 1.65),
    bodyMedium: base.bodyMedium?.copyWith(height: 1.55),
  );
}

/// 既定テーマ: ダーク神秘基調（深紺×金の発光アクセント）。
ThemeData buildDarkAppTheme() {
  const scheme = ColorScheme(
    brightness: Brightness.dark,
    primary: _gold,
    onPrimary: Color(0xFF241A05),
    primaryContainer: Color(0xFF4A3A14),
    onPrimaryContainer: _goldBright,
    secondary: _teal,
    onSecondary: Color(0xFFE9F5F1),
    secondaryContainer: Color(0xFF1F4A42),
    onSecondaryContainer: Color(0xFFCBEAE1),
    tertiary: Color(0xFF9B8CC9),
    onTertiary: Color(0xFF221C3A),
    tertiaryContainer: Color(0xFF3A2F63),
    onTertiaryContainer: Color(0xFFE2D9F7),
    error: Color(0xFFF2B0A6),
    onError: Color(0xFF411410),
    errorContainer: Color(0xFF6B2A22),
    onErrorContainer: Color(0xFFFFDAD3),
    surface: _surfaceDark,
    onSurface: _inkOnDark,
    surfaceContainerHighest: _surfaceDarkHigh,
    onSurfaceVariant: Color(0xFFC9C0B0),
    outline: Color(0xFF6E6580),
    outlineVariant: Color(0xFF3B3355),
    shadow: Colors.black,
    scrim: Colors.black,
    inverseSurface: Color(0xFFEFEAE0),
    onInverseSurface: Color(0xFF221E33),
    inversePrimary: Color(0xFF6E5518),
  );

  final base = ThemeData(useMaterial3: true, colorScheme: scheme);
  return base.copyWith(
    // 全画面共通の背景画像（app.dartの_AppBackground）を透かすため地色は透明。
    scaffoldBackgroundColor: Colors.transparent,
    textTheme: _buildTextTheme(base.textTheme, _inkOnDark),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: _inkOnDark,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: _buildTextTheme(base.textTheme, _inkOnDark).titleLarge,
    ),
    cardTheme: base.cardTheme.copyWith(
      color: _surfaceDark,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: _gold.withValues(alpha: 0.22)),
      ),
      margin: const EdgeInsets.symmetric(vertical: 6),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: const Color(0xFF191430),
      indicatorColor: _gold.withValues(alpha: 0.22),
      height: 68,
      labelTextStyle: WidgetStatePropertyAll(
        base.textTheme.labelSmall?.copyWith(color: _inkOnDark, fontSize: 11),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? _goldBright
              : const Color(0xFF9A92A8),
        ),
      ),
    ),
    drawerTheme: const DrawerThemeData(backgroundColor: _surfaceDark),
    dividerTheme: DividerThemeData(color: _gold.withValues(alpha: 0.18)),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: _gold,
        foregroundColor: const Color(0xFF241A05),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: _goldBright,
        side: BorderSide(color: _gold.withValues(alpha: 0.6)),
        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: _surfaceDarkHigh,
      side: BorderSide(color: _gold.withValues(alpha: 0.35)),
      labelStyle: const TextStyle(color: _inkOnDark),
    ),
    listTileTheme: const ListTileThemeData(iconColor: _goldBright),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: _surfaceDarkHigh,
      contentTextStyle: TextStyle(color: _inkOnDark),
    ),
  );
}

/// ライト系テーマの共通ビルダー（生成り〜淡色地＋アクセント色）。
/// 地色は全画面共通の背景画像を透かすため透明。`scaffold` はAppBar等の
/// 淡色トーンを決める基調色としてのみ用いる。
ThemeData _buildLightVariant({
  required Color seed,
  required Color accent,
  required Color scaffold,
  required Color surface,
}) {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: seed,
      primary: seed,
      secondary: accent,
      surface: surface,
    ),
  );
  const ink = Color(0xFF2A2620);
  return base.copyWith(
    scaffoldBackgroundColor: Colors.transparent,
    textTheme: _buildTextTheme(base.textTheme, ink),
    appBarTheme: AppBarTheme(
      backgroundColor: scaffold.withValues(alpha: 0.86),
      foregroundColor: ink,
      elevation: 0,
      titleTextStyle: _buildTextTheme(base.textTheme, ink).titleLarge,
    ),
    cardTheme: base.cardTheme.copyWith(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: seed.withValues(alpha: 0.20)),
      ),
      margin: const EdgeInsets.symmetric(vertical: 6),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: surface,
      indicatorColor: seed.withValues(alpha: 0.16),
      height: 68,
    ),
  );
}

/// 選択制のライトテーマ（従来の生成り×深緑×金を継承）。
ThemeData buildLightAppTheme() {
  return _buildLightVariant(
    seed: const Color(0xFF23635C),
    accent: const Color(0xFFB8860B),
    scaffold: const Color(0xFFF3EFE4),
    surface: const Color(0xFFF8F5EE),
  );
}

/// ピンク（承認済み追加プリセット）。
ThemeData buildPinkAppTheme() {
  return _buildLightVariant(
    seed: const Color(0xFFC2185B),
    accent: const Color(0xFFEC6BA0),
    scaffold: const Color(0xFFFBEEF3),
    surface: const Color(0xFFFDF5F8),
  );
}

/// スカイブルー（承認済み追加プリセット）。
ThemeData buildSkyBlueAppTheme() {
  return _buildLightVariant(
    seed: const Color(0xFF1E6FA8),
    accent: const Color(0xFF4FB0E0),
    scaffold: const Color(0xFFEDF4FA),
    surface: const Color(0xFFF5FAFD),
  );
}

/// ライムグリーン（承認済み追加プリセット）。
ThemeData buildLimeAppTheme() {
  return _buildLightVariant(
    seed: const Color(0xFF558B2F),
    accent: const Color(0xFF9CCC65),
    scaffold: const Color(0xFFF1F6EA),
    surface: const Color(0xFFF7FBF1),
  );
}

/// テーマ設定コード→ThemeDataの解決。
/// 全テーマともscaffoldは透過で、背景は全画面共通の背景層（app.dartの
/// `_AppBackground`）が担う。'image' はユーザー画像、それ以外はホームと同じ寺院背景。
ThemeData resolveAppTheme(String preference) {
  switch (preference) {
    case 'light':
      return buildLightAppTheme();
    case 'pink':
      return buildPinkAppTheme();
    case 'skyblue':
      return buildSkyBlueAppTheme();
    case 'lime':
      return buildLimeAppTheme();
    case 'image':
      // 背景画像の上に明色文字で載せる（ダーク基調を流用）
      return buildDarkAppTheme();
    case 'dark':
    default:
      return buildDarkAppTheme();
  }
}
