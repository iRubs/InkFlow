import 'package:flutter/material.dart';

import 'colors.dart';
import 'spacing.dart';
import 'typography.dart';

/// Extensión personalizada para temas de InkFlow (soporte de lienzo, papel y herramientas)
class InkCanvasThemeExtension extends ThemeExtension<InkCanvasThemeExtension> {
  final Color paperColor;
  final Color gridColor;
  final Color marginLineColor;
  final Color toolbarBackground;
  final Color activeToolBorder;

  const InkCanvasThemeExtension({
    required this.paperColor,
    required this.gridColor,
    required this.marginLineColor,
    required this.toolbarBackground,
    required this.activeToolBorder,
  });

  @override
  ThemeExtension<InkCanvasThemeExtension> copyWith({
    Color? paperColor,
    Color? gridColor,
    Color? marginLineColor,
    Color? toolbarBackground,
    Color? activeToolBorder,
  }) {
    return InkCanvasThemeExtension(
      paperColor: paperColor ?? this.paperColor,
      gridColor: gridColor ?? this.gridColor,
      marginLineColor: marginLineColor ?? this.marginLineColor,
      toolbarBackground: toolbarBackground ?? this.toolbarBackground,
      activeToolBorder: activeToolBorder ?? this.activeToolBorder,
    );
  }

  @override
  ThemeExtension<InkCanvasThemeExtension> lerp(
    covariant ThemeExtension<InkCanvasThemeExtension>? other,
    double t,
  ) {
    if (other is! InkCanvasThemeExtension) return this;
    return InkCanvasThemeExtension(
      paperColor: Color.lerp(paperColor, other.paperColor, t)!,
      gridColor: Color.lerp(gridColor, other.gridColor, t)!,
      marginLineColor: Color.lerp(marginLineColor, other.marginLineColor, t)!,
      toolbarBackground: Color.lerp(
        toolbarBackground,
        other.toolbarBackground,
        t,
      )!,
      activeToolBorder: Color.lerp(
        activeToolBorder,
        other.activeToolBorder,
        t,
      )!,
    );
  }
}

/// Configurador principal del tema de la aplicación InkFlow.
class InkTheme {
  InkTheme._();

  static ThemeData light() {
    const colorScheme = ColorScheme.light(
      primary: InkColors.primary,
      onPrimary: Colors.white,
      primaryContainer: InkColors.primaryContainerLight,
      onPrimaryContainer: InkColors.primaryDark,
      secondary: InkColors.accentIndigo,
      surface: InkColors.surfaceLight,
      onSurface: InkColors.textPrimaryLight,
      outline: InkColors.borderLight,
      outlineVariant: InkColors.dividerLight,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: InkColors.backgroundLight,
      textTheme: InkTypography.textTheme(false),
      dividerColor: InkColors.dividerLight,
      cardTheme: CardThemeData(
        color: InkColors.cardLight,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: InkSpacing.roundedMd,
          side: const BorderSide(color: InkColors.borderLight),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: InkColors.surfaceLight,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
        titleTextStyle: InkTypography.titleLarge.copyWith(
          color: InkColors.textPrimaryLight,
        ),
        iconTheme: const IconThemeData(color: InkColors.textPrimaryLight),
      ),
      navigationRailTheme: const NavigationRailThemeData(
        backgroundColor: InkColors.surfaceLight,
        selectedIconTheme: IconThemeData(color: InkColors.primary),
        unselectedIconTheme: IconThemeData(color: InkColors.textSecondaryLight),
        indicatorColor: InkColors.primaryContainerLight,
        labelType: NavigationRailLabelType.all,
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(
            InkSpacing.minTouchTarget,
            InkSpacing.minTouchTarget,
          ),
        ),
      ),
      extensions: const [
        InkCanvasThemeExtension(
          paperColor: InkColors.paperWhite,
          gridColor: InkColors.gridLight,
          marginLineColor: InkColors.marginLineRed,
          toolbarBackground: InkColors.surfaceLight,
          activeToolBorder: InkColors.primary,
        ),
      ],
    );
  }

  static ThemeData dark() {
    const colorScheme = ColorScheme.dark(
      primary: InkColors.primaryLight,
      onPrimary: Color(0xFF0F172A),
      primaryContainer: InkColors.primaryContainerDark,
      onPrimaryContainer: InkColors.primaryLight,
      secondary: InkColors.accentIndigo,
      surface: InkColors.surfaceDark,
      onSurface: InkColors.textPrimaryDark,
      outline: InkColors.borderDark,
      outlineVariant: InkColors.dividerDark,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: InkColors.backgroundDark,
      textTheme: InkTypography.textTheme(true),
      dividerColor: InkColors.dividerDark,
      cardTheme: CardThemeData(
        color: InkColors.cardDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: InkSpacing.roundedMd,
          side: const BorderSide(color: InkColors.borderDark),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: InkColors.surfaceDark,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
        titleTextStyle: InkTypography.titleLarge.copyWith(
          color: InkColors.textPrimaryDark,
        ),
        iconTheme: const IconThemeData(color: InkColors.textPrimaryDark),
      ),
      navigationRailTheme: const NavigationRailThemeData(
        backgroundColor: InkColors.surfaceDark,
        selectedIconTheme: IconThemeData(color: InkColors.primaryLight),
        unselectedIconTheme: IconThemeData(color: InkColors.textSecondaryDark),
        indicatorColor: InkColors.primaryContainerDark,
        labelType: NavigationRailLabelType.all,
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(
            InkSpacing.minTouchTarget,
            InkSpacing.minTouchTarget,
          ),
        ),
      ),
      extensions: const [
        InkCanvasThemeExtension(
          paperColor: InkColors.paperDark,
          gridColor: InkColors.gridDark,
          marginLineColor: InkColors.marginLineRed,
          toolbarBackground: InkColors.surfaceDark,
          activeToolBorder: InkColors.primaryLight,
        ),
      ],
    );
  }
}
