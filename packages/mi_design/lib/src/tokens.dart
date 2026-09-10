import 'package:flutter/widgets.dart';

/// The palette: a court archive.
///
/// Parchment-warm neutrals as the ground, ink black for text, and **a single
/// oxblood accent reserved exclusively for verdicts and ratings**. That
/// reservation is the whole colour system. It means judgement is the loudest
/// thing on any screen without a chart anywhere — and it only holds if nothing
/// else ever reaches for [accent]. `MiVerdict` is the one widget that paints
/// with it, and `theme_test.dart` holds that as a contract.
///
/// No gradients, no neon, no glass, nothing that reads as a contemporary AI
/// product. A dossier is paper.
@immutable
class MiColors {
  const MiColors({
    required this.ground,
    required this.leaf,
    required this.raised,
    required this.rule,
    required this.ruleStrong,
    required this.ink,
    required this.inkMuted,
    required this.inkFaint,
    required this.accent,
    required this.accentInk,
    required this.warning,
  });

  /// The page itself.
  final Color ground;

  /// A leaf of paper laid on the page — very slightly lighter, never a card.
  final Color leaf;

  /// Something genuinely above the page: a menu, a dialog.
  final Color raised;

  /// Hairline rules. **All structure comes from these.** No borders, no boxes,
  /// no shadows, no elevation anywhere in this system.
  final Color rule;
  final Color ruleStrong;

  final Color ink;
  final Color inkMuted;
  final Color inkFaint;

  /// Oxblood. Verdicts and ratings only.
  final Color accent;
  final Color accentInk;

  /// The one other colour, for a thing that is wrong rather than judged — a
  /// run that could not reach the council. Deliberately not oxblood, so a
  /// failure is never mistaken for a verdict.
  final Color warning;

  static const MiColors light = MiColors(
    ground: Color(0xFFF4F1E8),
    leaf: Color(0xFFFAF8F2),
    raised: Color(0xFFFDFCF8),
    rule: Color(0xFFD9D3C3),
    ruleStrong: Color(0xFFB3AB97),
    ink: Color(0xFF14120E),
    inkMuted: Color(0xFF5B564A),
    inkFaint: Color(0xFF8B8474),
    accent: Color(0xFF6E1F1B),
    accentInk: Color(0xFFF4F1E8),
    warning: Color(0xFF6B5410),
  );

  /// Lamplight rather than a screen: the same archive after dark, warm and
  /// low. The accent lifts, because oxblood on near-black is unreadable at the
  /// weight a verdict is set in — it stays the only colour on the page.
  static const MiColors dark = MiColors(
    ground: Color(0xFF14130F),
    leaf: Color(0xFF1B1A15),
    raised: Color(0xFF23211B),
    rule: Color(0xFF34312A),
    ruleStrong: Color(0xFF4E4A40),
    ink: Color(0xFFEDE8DA),
    inkMuted: Color(0xFFA49C89),
    inkFaint: Color(0xFF77705F),
    accent: Color(0xFFC4665C),
    accentInk: Color(0xFF14130F),
    warning: Color(0xFFC9A544),
  );
}

/// An 8-point scale. Every gap in the app is one of these.
abstract final class MiSpace {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
  static const double xxxl = 72;

  /// A measure you can read a case file across without losing the line.
  static const double readingWidth = 660;

  /// The widest a document region is set. A dossier at 1600px full-bleed is
  /// unreadable; the page stays a page and the window grows around it.
  static const double documentWidth = 860;

  /// Minimum height of anything tappable.
  static const double tapTarget = 52;

  /// The width of the rail on a desktop window.
  static const double railWidth = 300;

  /// Below this the app is one column and destinations are pushed routes.
  /// A *layout* gate, never a platform check — those are different questions.
  static const double wideGate = 900;
}

/// Type, in Source Serif 4.
///
/// A serif throughout, including labels and controls. That is the treatment
/// rather than a preference: this app is a proceeding whose output is a
/// document, and a grotesque interface wrapped around a serif document reads
/// as a web app that renders a PDF. The archive sets everything in one voice.
abstract final class MiType {
  static const String family = 'SourceSerif';
  static const String package = 'mi_design';

  /// How the font is registered once Flutter has loaded it from this package.
  /// [ThemeData] takes a family name and no package, so it needs this form.
  static const String themeFamily = 'packages/$package/$family';

  static const TextStyle _base = TextStyle(
    fontFamily: family,
    package: package,
    fontWeight: FontWeight.w400,
    height: 1.45,
    letterSpacing: 0,
  );

  /// The one line a screen is about.
  static TextStyle get question => _base.copyWith(
    fontSize: 28,
    height: 1.2,
    letterSpacing: -0.2,
    fontWeight: FontWeight.w600,
  );

  static TextStyle get display => _base.copyWith(
    fontSize: 24,
    height: 1.22,
    fontWeight: FontWeight.w600,
  );

  static TextStyle get title =>
      _base.copyWith(fontSize: 20, height: 1.28, fontWeight: FontWeight.w600);

  static TextStyle get heading =>
      _base.copyWith(fontSize: 17, height: 1.32, fontWeight: FontWeight.w600);

  static TextStyle get body => _base.copyWith(fontSize: 17, height: 1.45);

  /// Long-form reading — a direction's statement, the brief, the pitch.
  static TextStyle get prose => _base.copyWith(fontSize: 17, height: 1.62);

  static TextStyle get label =>
      _base.copyWith(fontSize: 15, height: 1.35, color: null);

  static TextStyle get caption => _base.copyWith(fontSize: 14, height: 1.4);

  /// Section marks and record labels, set in small tracked caps — the archive's
  /// own hand for saying what a thing is.
  static TextStyle get eyebrow => _base.copyWith(
    fontSize: 12,
    letterSpacing: 1.4,
    height: 1.2,
    fontWeight: FontWeight.w600,
  );

  /// A verdict. Set in the same serif at reading size, never larger — the
  /// colour is what carries it, and a verdict shouted in display type would be
  /// the closest thing this design has to a chart.
  static TextStyle get verdict => _base.copyWith(
    fontSize: 17,
    height: 1.35,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.2,
  );

  /// Ids, hashes and file paths. The one place a monospace appears.
  static const TextStyle mono = TextStyle(
    fontFamily: 'monospace',
    fontSize: 13,
    height: 1.5,
  );
}
