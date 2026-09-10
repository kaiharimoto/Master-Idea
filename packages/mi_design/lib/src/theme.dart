import 'package:flutter/material.dart';

import 'tokens.dart';

/// Makes the palette available below it without threading it through every
/// widget constructor.
class MiTheme extends InheritedWidget {
  const MiTheme({
    required this.colors,
    required this.isDark,
    required super.child,
    super.key,
  });

  final MiColors colors;
  final bool isDark;

  static MiTheme? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<MiTheme>();

  /// The palette for this subtree.
  ///
  /// Falls back to deriving from the ambient [Theme] brightness rather than
  /// asserting. Dialogs, bottom sheets and pushed routes are built from the
  /// [Navigator], which can sit above wherever [MiTheme] was inserted — an
  /// assertion there turns a layout detail into a crash in exactly the places
  /// that are hardest to reach in a test.
  static MiColors colorsOf(BuildContext context) {
    final MiTheme? t = maybeOf(context);
    if (t != null) return t.colors;
    return Theme.of(context).brightness == Brightness.dark
        ? MiColors.dark
        : MiColors.light;
  }

  @override
  bool updateShouldNotify(MiTheme oldWidget) =>
      oldWidget.colors != colors || oldWidget.isDark != isDark;
}

/// Builds the Material theme from the tokens, so stock widgets inherit the
/// same typography and palette as the custom ones.
///
/// `verdict` is never handed to Material. A stock widget reaching for
/// `primary` would otherwise be able to paint something verdict-coloured that
/// is not a verdict, which is the reservation broken by accident rather than
/// by intent.
ThemeData buildMiTheme(MiColors c, {required bool dark}) {
  final TextTheme text = TextTheme(
    displaySmall: MiType.display.copyWith(color: c.ink),
    titleLarge: MiType.title.copyWith(color: c.ink),
    titleMedium: MiType.heading.copyWith(color: c.ink),
    bodyMedium: MiType.body.copyWith(color: c.ink),
    bodySmall: MiType.caption.copyWith(color: c.inkMuted),
    labelMedium: MiType.label.copyWith(color: c.inkMuted),
    labelSmall: MiType.eyebrow.copyWith(color: c.inkMuted),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: dark ? Brightness.dark : Brightness.light,
    scaffoldBackgroundColor: c.canvas,
    canvasColor: c.canvas,
    // The package-qualified name, which is what a font declared by a package
    // is actually registered as.
    fontFamily: MiType.themeFamily,
    fontFamilyFallback: const <String>['Roboto', 'Segoe UI', 'sans-serif'],
    textTheme: text,
    colorScheme: ColorScheme(
      brightness: dark ? Brightness.dark : Brightness.light,
      primary: c.accent,
      onPrimary: c.accentInk,
      secondary: c.inkMuted,
      onSecondary: c.canvas,
      error: c.danger,
      onError: c.accentInk,
      surface: c.surface,
      onSurface: c.ink,
    ),
    dividerTheme: DividerThemeData(color: c.line, thickness: 1, space: 1),
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    // Structure comes from hairlines and spacing, never from drop shadows.
    cardTheme: CardThemeData(
      elevation: 0,
      color: c.surface,
      shape: RoundedRectangleBorder(
        borderRadius: MiRadius.card,
        side: BorderSide(color: c.line),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: c.surface,
      hintStyle: MiType.body.copyWith(color: c.inkFaint),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: MiSpace.md,
        vertical: MiSpace.sm + 2,
      ),
      border: OutlineInputBorder(
        borderRadius: MiRadius.card,
        borderSide: BorderSide(color: c.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: MiRadius.card,
        borderSide: BorderSide(color: c.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: MiRadius.card,
        borderSide: BorderSide(color: c.lineStrong, width: 1.5),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: c.ink,
      contentTextStyle: MiType.body.copyWith(color: c.canvas),
      behavior: SnackBarBehavior.floating,
    ),
  );
}
