import 'package:flutter/material.dart';

/// Paleta do Promold, extraída do tema do sistema web (src/index.css).
///
/// Mantém a identidade visual: azul industrial como cor primária, âmbar como
/// acento e cinza-ardósia para superfícies secundárias. Os valores são `const`
/// (hex equivalente aos tokens HSL do webapp).
class AppColors {
  AppColors._();

  // Base
  static const Color background = Color(0xFFF6F7F9); // 220 20% 97%
  static const Color foreground = Color(0xFF1B2232); // 220 30% 15%
  static const Color card = Color(0xFFFFFFFF); // 0 0% 100%
  static const Color border = Color(0xFFDCDFE5); // 220 15% 88%

  // Marca
  static const Color primary = Color(0xFF2258C3); // 220 70% 45%
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color accent = Color(0xFFF9A006); // 38 95% 50%
  static const Color onAccent = Color(0xFFFFFFFF);

  // Superfícies
  static const Color secondary = Color(0xFFE8EAEE); // 220 15% 92%
  static const Color onSecondary = Color(0xFF2D3953); // 220 30% 25%
  static const Color muted = Color(0xFFEDEFF2); // 220 15% 94%
  static const Color mutedForeground = Color(0xFF626D84); // 220 15% 45%

  // Semânticas
  static const Color success = Color(0xFF1FAD6B); // 152 70% 40%
  static const Color warning = Color(0xFFF97415); // 25 95% 53%
  static const Color info = Color(0xFF13A4EC); // 200 85% 50%
  static const Color destructive = Color(0xFFDC2828); // 0 72% 51%

  // Sidebar / navegação
  static const Color sidebar = Color(0xFF171C26); // 220 25% 12%
  static const Color sidebarForeground = Color(0xFFD5D7DD); // 220 10% 85%
  static const Color sidebarAccent = Color(0xFF29303D); // 220 20% 20%
}
