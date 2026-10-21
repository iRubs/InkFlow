import 'package:flutter/material.dart';

/// Paleta de colores oficial de InkFlow.
/// Diseñada para legibilidad óptima en tablets (S Pen) y monitores de escritorio.
class InkColors {
  InkColors._();

  // Primarios y de marca
  static const Color primary = Color(0xFF2563EB); // Royal Blue
  static const Color primaryLight = Color(0xFF60A5FA);
  static const Color primaryDark = Color(0xFF1D4ED8);
  static const Color primaryContainerLight = Color(0xFFDBEAFE);
  static const Color primaryContainerDark = Color(0xFF1E3A8A);

  // Acentos
  static const Color accent = Color(0xFF0284C7); // Sky 600
  static const Color accentIndigo = Color(0xFF6366F1);
  static const Color accentTeal = Color(0xFF0D9488);
  static const Color accentAmber = Color(0xFFF59E0B);
  static const Color accentRose = Color(0xFFF43F5E);
  static const Color accentEmerald = Color(0xFF10B981);

  // Fondos y superficies en modo claro
  static const Color backgroundLight = Color(0xFFF8FAFC); // Slate 50
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceVariantLight = Color(0xFFF1F5F9); // Slate 100
  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color borderLight = Color(0xFFE2E8F0); // Slate 200
  static const Color dividerLight = Color(0xFFCBD5E1); // Slate 300

  // Fondos y superficies en modo oscuro
  static const Color backgroundDark = Color(0xFF0F172A); // Slate 900
  static const Color surfaceDark = Color(0xFF1E293B); // Slate 800
  static const Color surfaceVariantDark = Color(0xFF334155); // Slate 700
  static const Color cardDark = Color(0xFF1E293B);
  static const Color borderDark = Color(0xFF334155);
  static const Color dividerDark = Color(0xFF475569);

  // Textos modo claro
  static const Color textPrimaryLight = Color(0xFF0F172A);
  static const Color textSecondaryLight = Color(0xFF475569);
  static const Color textTertiaryLight = Color(0xFF94A3B8);

  // Textos modo oscuro
  static const Color textPrimaryDark = Color(0xFFF8FAFC);
  static const Color textSecondaryDark = Color(0xFFCBD5E1);
  static const Color textTertiaryDark = Color(0xFF64748B);

  // Colores de Lienzo y Papel Físico
  static const Color paperWhite = Color(0xFFFFFFFF);
  static const Color paperCream = Color(0xFFFBF8EE); // Marfil cálido
  static const Color paperYellow = Color(
    0xFFFEF9C3,
  ); // Amarillo suave legal pad
  static const Color paperMint = Color(0xFFF0FDF4); // Menta descansado
  static const Color paperDark = Color(0xFF18181B); // Negro zinc
  static const Color paperSlate = Color(0xFF1E293B); // Pizarra oscuro

  // Colores de Guías de Papel (cuadrículas, renglones, puntos)
  static const Color gridLight = Color(0xFFD6D3D1); // Piedra suave
  static const Color gridDark = Color(0xFF3F3F46); // Zinc suave
  static const Color marginLineRed = Color(0xFFFCA5A5); // Línea de margen roja

  // Colores de Herramientas de Tinta (Stylus Palettes)
  static const List<Color> defaultInkPalette = [
    Color(0xFF000000), // Negro azabache
    Color(0xFF1E3A8A), // Azul marino
    Color(0xFFB91C1C), // Rojo carmesí
    Color(0xFF047857), // Verde bosque
    Color(0xFF6D28D9), // Púrpura real
    Color(0xFFC2410C), // Naranja quemado
    Color(0xFF0284C7), // Azul cielo
    Color(0xFFBE185D), // Magenta
    Color(0xFF4B5563), // Gris plomo
    Color(0xFFEAB308), // Amarillo resaltador
  ];

  static const List<Color> defaultHighlighterPalette = [
    Color(0x66FDE047), // Amarillo traslúcido
    Color(0x6686EFAC), // Verde menta traslúcido
    Color(0x6693C5FD), // Azul cielo traslúcido
    Color(0x66F9A8D4), // Rosa chicle traslúcido
    Color(0x66FDBA74), // Naranja traslúcido
    Color(0x66D8B4FE), // Lavanda traslúcido
  ];
}
