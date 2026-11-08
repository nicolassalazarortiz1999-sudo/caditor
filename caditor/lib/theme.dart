import 'package:flutter/material.dart';

const Color kBg = Color(0xFF0B0B14);
const Color kCard = Color(0xFF161625);
const Color kPurple = Color(0xFF8B5CF6);
const Color kPink = Color(0xFFEC4899);
const Color kMuted = Color(0xFF9CA3AF);

const LinearGradient kBrandGradient = LinearGradient(
  colors: [kPurple, kPink],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

ThemeData buildTheme() {
  final base = ThemeData(
    brightness: Brightness.dark,
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: kPurple,
      brightness: Brightness.dark,
      surface: kBg,
    ),
  );
  return base.copyWith(
    scaffoldBackgroundColor: kBg,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
    ),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: kCard,
    ),
    sliderTheme: base.sliderTheme.copyWith(
      activeTrackColor: kPink,
      thumbColor: kPink,
      inactiveTrackColor: Colors.white12,
    ),
  );
}
