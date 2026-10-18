import 'package:flutter/material.dart';

/// Bealib 设计令牌。
///
/// 视觉基线：`design/ui-reference.jpg`（浅灰底、白色大圆角卡片、胶囊徽标、
/// 悬浮胶囊导航）。配色与排版数值全部集中在此，供双端共用一套 token
/// （AGENTS.md「跨端一致性」要求）。
abstract final class BealibTokens {
  // ---- 品牌 ----
  static const Color seed = Color(0xFFD9738B);

  // ---- 亮色 ----
  static const Color lightScaffold = Color(0xFFF3F4F6);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceContainer = Color(0xFFF1F2F5);
  static const Color lightSurfaceContainerHigh = Color(0xFFEBEDF0);
  static const Color lightOnSurface = Color(0xFF17181B);
  static const Color lightOnSurfaceVariant = Color(0xFF6B7280);
  static const Color lightOutline = Color(0xFFD3D7DE);
  static const Color lightOutlineVariant = Color(0xFFE5E8ED);

  // ---- 暗色 ----
  static const Color darkScaffold = Color(0xFF101114);
  static const Color darkSurface = Color(0xFF1A1B1E);
  static const Color darkSurfaceContainer = Color(0xFF23252A);
  static const Color darkSurfaceContainerHigh = Color(0xFF2A2D33);
  static const Color darkOnSurface = Color(0xFFF2F3F5);
  static const Color darkOnSurfaceVariant = Color(0xFFA6ACB8);
  static const Color darkOutline = Color(0xFF3A3E46);
  static const Color darkOutlineVariant = Color(0xFF2E323A);

  // ---- 尺寸（dp） ----
  static const double pagePadding = 20;
  static const double cardRadius = 20;
  static const double coverRadius = 14;
  static const double inputRadius = 16;
  static const double navBarHeight = 64;
  static const double navBarBottomInset = 14;
  static const double gridGap = 12;
  static const double minTouchTarget = 48; // Material 3 R6.5

  // ---- 动效 ----
  static const Duration motionFast = Duration(milliseconds: 180);
  static const Duration motionMedium = Duration(milliseconds: 260);

  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  /// 页面背景的柔和环境渐变（对应参考图的模糊壁纸感）。
  static BoxDecoration ambientBackground(Brightness brightness) {
    if (brightness == Brightness.dark) {
      return const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF17181C), Color(0xFF101114), Color(0xFF151317)],
        ),
      );
    }
    return const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFDF1F4), Color(0xFFF2F4F8), Color(0xFFF6F7F9)],
      ),
    );
  }
}

/// 构建 Bealib 主题。
///
/// - 排版：Inter（400/500/600/700），字号遵循 Material 3 角色
///   （正文 ≥12sp，见 M3 R4.2）。
/// - 圆角/间距：以 [BealibTokens] 为准。
/// - 动态色：由调用方传入 `colorScheme` 时启用（M3 R1.1/R1.11）。
ThemeData buildBealibTheme({
  required Brightness brightness,
  ColorScheme? colorScheme,
  Color? seedColor,
  String? fontFamily,
}) {
  final bool isDark = brightness == Brightness.dark;
  final ColorScheme scheme = (colorScheme ??
          ColorScheme.fromSeed(
            seedColor: seedColor ?? BealibTokens.seed,
            brightness: brightness,
          ))
      .copyWith(
        surface: isDark ? BealibTokens.darkSurface : BealibTokens.lightSurface,
        surfaceContainerLowest:
            isDark ? BealibTokens.darkScaffold : BealibTokens.lightSurface,
        surfaceContainerLow:
            isDark ? BealibTokens.darkSurface : BealibTokens.lightSurfaceContainer,
        surfaceContainer: isDark
            ? BealibTokens.darkSurfaceContainer
            : BealibTokens.lightSurfaceContainer,
        surfaceContainerHigh: isDark
            ? BealibTokens.darkSurfaceContainerHigh
            : BealibTokens.lightSurfaceContainerHigh,
        surfaceContainerHighest: isDark
            ? BealibTokens.darkSurfaceContainerHigh
            : BealibTokens.lightSurfaceContainerHigh,
        onSurface:
            isDark ? BealibTokens.darkOnSurface : BealibTokens.lightOnSurface,
        onSurfaceVariant: isDark
            ? BealibTokens.darkOnSurfaceVariant
            : BealibTokens.lightOnSurfaceVariant,
        outline: isDark ? BealibTokens.darkOutline : BealibTokens.lightOutline,
        outlineVariant: isDark
            ? BealibTokens.darkOutlineVariant
            : BealibTokens.lightOutlineVariant,
      );

  final ThemeData base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    fontFamily: fontFamily ?? 'Inter',
    scaffoldBackgroundColor:
        isDark ? BealibTokens.darkScaffold : BealibTokens.lightScaffold,
  );

  // 用 copyWith 保留 ThemeData(fontFamily) 注入的字体族，只覆盖字号/字重。
  final TextTheme text = base.textTheme.copyWith(
    displayLarge: base.textTheme.displayLarge?.copyWith(
      fontSize: 34,
      fontWeight: FontWeight.w700,
      height: 1.14,
      letterSpacing: -0.6,
    ),
    displayMedium: base.textTheme.displayMedium?.copyWith(
      fontSize: 30,
      fontWeight: FontWeight.w700,
      height: 1.16,
      letterSpacing: -0.4,
    ),
    headlineLarge: base.textTheme.headlineLarge?.copyWith(
      fontSize: 26,
      fontWeight: FontWeight.w700,
      height: 1.2,
    ),
    headlineMedium: base.textTheme.headlineMedium?.copyWith(
      fontSize: 22,
      fontWeight: FontWeight.w700,
      height: 1.24,
    ),
    headlineSmall: base.textTheme.headlineSmall?.copyWith(
      fontSize: 20,
      fontWeight: FontWeight.w600,
      height: 1.26,
    ),
    titleLarge: base.textTheme.titleLarge?.copyWith(
      fontSize: 19,
      fontWeight: FontWeight.w600,
      height: 1.3,
    ),
    titleMedium: base.textTheme.titleMedium?.copyWith(
      fontSize: 16.5,
      fontWeight: FontWeight.w600,
      height: 1.34,
    ),
    titleSmall: base.textTheme.titleSmall?.copyWith(
      fontSize: 14.5,
      fontWeight: FontWeight.w600,
      height: 1.34,
    ),
    bodyLarge: base.textTheme.bodyLarge?.copyWith(fontSize: 16, height: 1.45),
    bodyMedium:
        base.textTheme.bodyMedium?.copyWith(fontSize: 14.5, height: 1.45),
    bodySmall: base.textTheme.bodySmall?.copyWith(fontSize: 13, height: 1.4),
    labelLarge: base.textTheme.labelLarge?.copyWith(
      fontSize: 15,
      fontWeight: FontWeight.w600,
      height: 1.3,
    ),
    labelMedium: base.textTheme.labelMedium?.copyWith(
      fontSize: 13,
      fontWeight: FontWeight.w500,
      height: 1.24,
    ),
    labelSmall: base.textTheme.labelSmall?.copyWith(
      fontSize: 12,
      fontWeight: FontWeight.w500,
      height: 1.2,
    ),
  );

  return base.copyWith(
    textTheme: text,
    primaryTextTheme: text,
    canvasColor:
        isDark ? BealibTokens.darkScaffold : BealibTokens.lightScaffold,
    splashColor: scheme.primary.withValues(alpha: 0.06),
    highlightColor: Colors.transparent,
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: text.titleLarge?.copyWith(color: scheme.onSurface),
    ),
    cardTheme: CardThemeData(
      color: scheme.surface,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.black.withValues(alpha: 0.04),
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(BealibTokens.cardRadius),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    dividerTheme: DividerThemeData(
      color: scheme.outlineVariant,
      thickness: 1,
      space: 1,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surface,
      hintStyle: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(BealibTokens.inputRadius),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(BealibTokens.inputRadius),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(BealibTokens.inputRadius),
        borderSide: BorderSide(color: scheme.primary, width: 1.5),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(BealibTokens.minTouchTarget, 48),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: text.labelLarge,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(48, BealibTokens.minTouchTarget),
        textStyle: text.labelLarge,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(BealibTokens.minTouchTarget, 48),
        side: BorderSide(color: scheme.outlineVariant),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: text.labelLarge,
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor:
          isDark ? BealibTokens.darkSurfaceContainerHigh : const Color(0xFF23252A),
      contentTextStyle: text.bodyMedium?.copyWith(color: Colors.white),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: scheme.surfaceContainer,
      side: BorderSide.none,
      labelStyle: text.labelMedium,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      indicatorColor: scheme.secondaryContainer,
      labelTextStyle: WidgetStatePropertyAll(
        text.labelMedium?.copyWith(color: scheme.onSurface),
      ),
    ),
  );
}

ThemeData oledDarkTheme(ThemeData defaultDarkTheme) {
  return defaultDarkTheme.copyWith(
    scaffoldBackgroundColor: Colors.black,
    canvasColor: Colors.black,
    colorScheme: defaultDarkTheme.colorScheme.copyWith(
      onPrimary: Colors.black,
      onSecondary: Colors.black,
      surface: Colors.black,
      onSurface: Colors.white,
    ),
  );
}
