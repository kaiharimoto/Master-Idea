import 'package:flutter/material.dart';

import 'tokens.dart';

/// Makes the palette available below it without threading it through every
/// constructor.
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
  /// Falls back to the ambient [Theme] brightness rather than asserting.
  /// Dialogs, sheets and pushed routes build from the [Navigator], which can
  /// sit above wherever [MiTheme] was inserted — an assertion there turns a
  /// layout detail into a crash in the places hardest to reach from a test.
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

/// Builds the Material theme from the tokens, so a stock widget that slips in
/// still arrives in the archive's own voice.
///
/// Three things here are the treatment rather than taste, and undoing any of
/// them undoes it: **no elevation anywhere**, so structure can only come from
/// rules and spacing; **the accent is never handed to Material**, so no stock
/// widget can reach for oxblood on its own and quietly make it mean nothing;
/// and splashes are off, because ink does not ripple.
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
    scaffoldBackgroundColor: c.ground,
    canvasColor: c.ground,
    // The package-qualified name, which is what a font declared by a package
    // is actually registered as. `MiType.family` alone resolves to nothing and
    // silently falls through to the platform serif — the same treatment, set
    // in a different face on each platform, which is the failure this vendored
    // font exists to prevent.
    fontFamily: MiType.themeFamily,
    fontFamilyFallback: const <String>['Georgia', 'Noto Serif', 'serif'],
    textTheme: text,
    colorScheme: ColorScheme(
      brightness: dark ? Brightness.dark : Brightness.light,
      // Ink, not oxblood. A Material widget that reaches for `primary` must
      // not be able to paint a verdict-coloured thing that is not a verdict.
      primary: c.ink,
      onPrimary: c.ground,
      secondary: c.inkMuted,
      onSecondary: c.ground,
      error: c.warning,
      onError: c.ground,
      surface: c.leaf,
      onSurface: c.ink,
    ),
    dividerTheme: DividerThemeData(color: c.rule, thickness: 1, space: 1),
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    cardTheme: CardThemeData(
      elevation: 0,
      color: c.leaf,
      shape: const RoundedRectangleBorder(),
    ),
    dialogTheme: DialogThemeData(
      elevation: 0,
      backgroundColor: c.raised,
      shape: RoundedRectangleBorder(side: BorderSide(color: c.ruleStrong)),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      elevation: 0,
      backgroundColor: c.raised,
      shape: const RoundedRectangleBorder(),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: c.leaf,
      hintStyle: MiType.body.copyWith(color: c.inkFaint),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: MiSpace.md,
        vertical: MiSpace.sm + 4,
      ),
      // A rule under the field, not a box around it. A form of boxes is the
      // fastest way for this to start reading as a web app.
      border: UnderlineInputBorder(borderSide: BorderSide(color: c.rule)),
      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: c.rule)),
      focusedBorder: UnderlineInputBorder(
        borderSide: BorderSide(color: c.ruleStrong, width: 1.5),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: c.ink,
      contentTextStyle: MiType.body.copyWith(color: c.ground),
      behavior: SnackBarBehavior.fixed,
    ),
  );
}
