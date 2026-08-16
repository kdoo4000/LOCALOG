import 'package:flutter/material.dart';

abstract final class AppColors {
  static const primaryBlue = Color(0xFF2457F5);
  static const primaryBlueDark = Color(0xFF173BB7);
  static const primaryBlueSoft = Color(0xFFDCE5FF);
  static const accentLime = Color(0xFFC8FF3D);
  static const sky = primaryBlueSoft;
  static const mint = Color(0xFFE9F5EF);
  static const yellow = Color(0xFFF7F0D7);
  static const secondaryLavender = sky;
  static const accentYellow = accentLime;
  static const ink = Color(0xFF101828);
  static const warmBackground = Color(0xFFF7F6F2);
  static const gray50 = warmBackground;
  static const gray100 = Color(0xFFF3F4F6);
  static const gray200 = Color(0xFFE5E7EB);
  static const gray400 = Color(0xFF9CA3AF);
  static const gray500 = Color(0xFF6B7280);
  static const white = Color(0xFFFFFFFF);

  // Semantic aliases. Screens should prefer these over raw palette names.
  static const surface = white;
  static const surfaceElevated = Color(0xFFFFFEFB);
  static const surfaceMuted = Color(0xFFF0EFEA);
  static const textPrimary = ink;
  static const textSecondary = gray500;
  static const borderSubtle = Color(0xFFE6E5E0);
  static const borderStrong = Color(0xFFD4D2CA);
  static const interactivePrimary = primaryBlue;
  static const disabledSurface = Color(0xFFEDECE7);
  static const disabledContent = Color(0xFF858B96);
  static const success = Color(0xFF14804A);
  static const warning = Color(0xFFB65D12);
  static const error = Color(0xFFBA1A1A);
}
