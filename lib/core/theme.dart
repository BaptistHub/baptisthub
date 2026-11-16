import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// Design tokens for the whole app. Dark, warm, gold-accented.
class AppColors {
  static const bg = Color(0xFF09090B);
  static const surface = Color(0xFF131317);
  static const surfaceHigh = Color(0xFF1C1C22);
  static const stroke = Color(0xFF27272F);
  static const text = Color(0xFFF4F4F5);
  static const muted = Color(0xFFA1A1AA);
  static const faint = Color(0xFF71717A);
  static const gold = Color(0xFFE8B04A);
  static const goldDeep = Color(0xFFB7832B);
  static const crimson = Color(0xFFE50914);
}

/// Single entry point for the app's typefaces (bundled in assets/fonts/).
/// Tests turn [useGoogleFonts] off and register the same font files under
/// plain family names, so layout tests use real font metrics.
class AppFonts {
  static bool useGoogleFonts = true;

  static TextStyle inter([TextStyle style = const TextStyle()]) =>
      useGoogleFonts ? GoogleFonts.inter(textStyle: style) : style.copyWith(fontFamily: 'Inter');

  static TextStyle bebas([TextStyle style = const TextStyle()]) =>
      useGoogleFonts ? GoogleFonts.bebasNeue(textStyle: style) : style.copyWith(fontFamily: 'BebasNeue');

  static TextTheme interTheme(TextTheme base) =>
      useGoogleFonts ? GoogleFonts.interTextTheme(base) : base.apply(fontFamily: 'Inter');
}

class AppText {
  /// Condensed cinematic display face used for documentary titles.
  static TextStyle display(double size, {Color color = AppColors.text}) =>
      AppFonts.bebas(TextStyle(
        fontSize: size,
        color: color,
        letterSpacing: 1.1,
        height: 0.95,
      ));

  static TextStyle eyebrow({Color color = AppColors.gold}) => AppFonts.inter(TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.6,
        color: color,
      ));
}

ThemeData buildTheme() {
  final base = ThemeData(
    brightness: Brightness.dark,
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.gold,
      brightness: Brightness.dark,
      surface: AppColors.bg,
      primary: AppColors.gold,
      onPrimary: Colors.black,
    ),
  );
  final textTheme = AppFonts.interTheme(base.textTheme).apply(
    bodyColor: AppColors.text,
    displayColor: AppColors.text,
  );
  return base.copyWith(
    scaffoldBackgroundColor: AppColors.bg,
    textTheme: textTheme.copyWith(
      headlineMedium: textTheme.headlineMedium
          ?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.6),
      headlineSmall: textTheme.headlineSmall
          ?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.4),
      titleLarge: textTheme.titleLarge
          ?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.3),
      titleMedium:
          textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.bg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      titleTextStyle: AppFonts.inter(const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: AppColors.text,
        letterSpacing: -0.3,
      )),
    ),
    splashFactory: InkSparkle.splashFactory,
    dividerColor: AppColors.stroke,
    iconTheme: const IconThemeData(color: AppColors.text),
    sliderTheme: const SliderThemeData(
      activeTrackColor: AppColors.gold,
      inactiveTrackColor: Color(0x33FFFFFF),
      thumbColor: AppColors.gold,
      overlayColor: Color(0x22E8B04A),
      trackHeight: 3,
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: AppColors.text,
      unselectedLabelColor: AppColors.faint,
      indicatorColor: AppColors.gold,
      dividerColor: Colors.transparent,
      labelStyle: AppFonts.inter(const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
      unselectedLabelStyle:
          AppFonts.inter(const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
    ),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.surfaceHigh,
      contentTextStyle: TextStyle(color: AppColors.text),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.android: CupertinoPageTransitionsBuilder(),
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
    }),
  );
}
