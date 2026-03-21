import 'package:flutter/material.dart';

import 'app_design_theme.dart';

class AppTheme {
  static const Color espresso = Color(0xFF24101A);
  static const Color espressoDeep = Color(0xFF13060D);
  static const Color mocha = Color(0xFF341420);
  static const Color peony = Color(0xFFE05B88);
  static const Color peonySoft = Color(0xFFF7C7D8);
  static const Color roseDust = Color(0xFFB07B90);
  static const Color blush = Color(0xFFFF7A8F);
  static const Color icedMint = Color(0xFF7ACEC3);

  static const Color primary = peony;
  static const Color primaryDark = mocha;
  static const Color primaryLight = peonySoft;
  static const Color secondary = Color(0xFF4A2132);
  static const Color accent = blush;
  static const Color surface = espressoDeep;
  static const Color cardBg = espresso;
  static const Color textPrimary = Color(0xFFF5D5E0);
  static const Color textSecondary = Color(0xFFC79AAD);
  static const Color success = Color(0xFF73D0A2);
  static const Color warning = Color(0xFFF0B36A);
  static const Color error = Color(0xFFFF5E7F);
  static const Color divider = Color(0xFF593041);
  static const LinearGradient berryBackdropGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [espressoDeep, mocha, secondary],
  );

  static const TextStyle headlineLarge = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w800,
    color: textPrimary,
    letterSpacing: -1.2,
    height: 1.02,
  );

  static const TextStyle headlineMedium = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w800,
    color: textPrimary,
    letterSpacing: -0.8,
    height: 1.08,
  );

  static const TextStyle titleLarge = TextStyle(
    fontSize: 19,
    fontWeight: FontWeight.w700,
    color: textPrimary,
    letterSpacing: 0.15,
    height: 1.12,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w500,
    color: textPrimary,
    letterSpacing: 0.18,
    height: 1.6,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 13.5,
    fontWeight: FontWeight.w500,
    color: textSecondary,
    letterSpacing: 0.22,
    height: 1.55,
  );

  static const TextStyle labelLarge = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w800,
    color: textPrimary,
    letterSpacing: 0.9,
    height: 1.0,
  );

  static ThemeData get dark {
    const colorScheme = ColorScheme.dark(
      primary: primary,
      primaryContainer: primaryDark,
      secondary: secondary,
      secondaryContainer: primaryDark,
      tertiary: accent,
      surface: cardBg,
      error: error,
      onPrimary: espressoDeep,
      onPrimaryContainer: textPrimary,
      onSecondary: textPrimary,
      onSecondaryContainer: textPrimary,
      onTertiary: textPrimary,
      onSurface: textPrimary,
      onError: textPrimary,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: surface,
      canvasColor: surface,
      cardColor: cardBg,
      dividerColor: divider,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
        },
      ),
      textTheme: const TextTheme(
        headlineLarge: headlineLarge,
        headlineMedium: headlineMedium,
        titleLarge: titleLarge,
        bodyLarge: bodyLarge,
        bodyMedium: bodyMedium,
        labelLarge: labelLarge,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: true,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          fontSize: 19,
          fontWeight: FontWeight.w800,
          color: textPrimary,
          letterSpacing: 0.35,
        ),
        iconTheme: IconThemeData(color: textPrimary, size: 22),
      ),
      cardTheme: CardThemeData(
        color: cardBg,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: divider.withValues(alpha: 0.72), width: 1),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 6),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: AppDesignTheme.elevatedButtonStyle(
          fillColor: primary,
          foregroundColor: espressoDeep,
          shadowColor: primary,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: AppDesignTheme.filledButtonStyle(
          fillColor: accent,
          foregroundColor: espressoDeep,
          shadowColor: accent,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: AppDesignTheme.outlinedButtonStyle(
          fillColor: primaryDark,
          foregroundColor: primaryLight,
          borderColor: primary.withValues(alpha: 0.38),
          shadowColor: primary,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: AppDesignTheme.textButtonStyle(
          fillColor: primaryDark,
          foregroundColor: primaryLight,
          shadowColor: primary,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: AppDesignTheme.iconButtonStyle(
          fillColor: primaryDark,
          foregroundColor: textPrimary,
          borderColor: primary.withValues(alpha: 0.18),
          shadowColor: primary,
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: accent,
        foregroundColor: espressoDeep,
        shape: StadiumBorder(),
        elevation: 14,
        highlightElevation: 18,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cardBg,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: divider.withValues(alpha: 0.8)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: divider.withValues(alpha: 0.8)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: primary, width: 1.5),
        ),
        labelStyle: const TextStyle(
          color: textSecondary,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
        hintStyle: const TextStyle(
          color: textSecondary,
          fontSize: 13,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.25,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: cardBg,
        disabledColor: divider,
        selectedColor: primary.withValues(alpha: 0.14),
        secondarySelectedColor: secondary.withValues(alpha: 0.16),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        labelStyle: bodyMedium.copyWith(
          color: textPrimary,
          fontWeight: FontWeight.w700,
        ),
        secondaryLabelStyle: bodyMedium.copyWith(
          color: textPrimary,
          fontWeight: FontWeight.w700,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: divider),
        ),
        side: const BorderSide(color: divider),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: cardBg,
        contentTextStyle: bodyLarge,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: cardBg,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      dividerTheme: const DividerThemeData(color: divider, thickness: 1),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: cardBg,
        indicatorColor: primary.withValues(alpha: 0.16),
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          return labelLarge.copyWith(
            color: states.contains(WidgetState.selected)
                ? primaryLight
                : textSecondary,
            fontSize: 11,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          return IconThemeData(
            color: states.contains(WidgetState.selected)
                ? primaryLight
                : textSecondary,
            size: 22,
          );
        }),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: cardBg,
        selectedItemColor: primaryLight,
        unselectedItemColor: textSecondary,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
        unselectedLabelStyle: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.35,
        ),
      ),
    );
  }
}
