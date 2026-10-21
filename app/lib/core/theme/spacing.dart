import 'package:flutter/material.dart';

/// Tokens de espaciado, bordes y dimensiones ergonómicas para InkFlow.
/// Optimizados para pantallas táctiles de tablet (10.9" S Pen) y escritorio con mouse.
class InkSpacing {
  InkSpacing._();

  // Espaciados estándar
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 20.0;
  static const double xxl = 24.0;
  static const double xxxl = 32.0;
  static const double jumbo = 48.0;

  // Bordes redondeados
  static const double radiusXs = 4.0;
  static const double radiusSm = 8.0;
  static const double radiusMd = 12.0;
  static const double radiusLg = 16.0;
  static const double radiusXl = 20.0;
  static const double radiusFull = 999.0;

  static final BorderRadius roundedXs = BorderRadius.circular(radiusXs);
  static final BorderRadius roundedSm = BorderRadius.circular(radiusSm);
  static final BorderRadius roundedMd = BorderRadius.circular(radiusMd);
  static final BorderRadius roundedLg = BorderRadius.circular(radiusLg);
  static final BorderRadius roundedXl = BorderRadius.circular(radiusXl);
  static final BorderRadius roundedFull = BorderRadius.circular(radiusFull);

  // Dimensiones ergonómicas para stylus y dedos
  static const double minTouchTarget =
      48.0; // Estándar de accesibilidad Google/Material
  static const double stylusButtonSize =
      44.0; // Tamaño óptimo de selector de pluma
  static const double floatingToolbarHeight = 56.0;
  static const double sidebarExpandedWidth = 280.0;
  static const double sidebarCollapsedWidth = 72.0;

  // Sombras sutiles y elevaciones
  static const List<BoxShadow> elevationSm = [
    BoxShadow(color: Color(0x0A000000), blurRadius: 4, offset: Offset(0, 1)),
    BoxShadow(color: Color(0x0F000000), blurRadius: 6, offset: Offset(0, 2)),
  ];

  static const List<BoxShadow> elevationMd = [
    BoxShadow(color: Color(0x0F000000), blurRadius: 8, offset: Offset(0, 4)),
    BoxShadow(color: Color(0x14000000), blurRadius: 16, offset: Offset(0, 6)),
  ];

  static const List<BoxShadow> elevationFloatingToolbar = [
    BoxShadow(
      color: Color(0x1E000000),
      blurRadius: 18,
      spreadRadius: 2,
      offset: Offset(0, 8),
    ),
  ];
}
