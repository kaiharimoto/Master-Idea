import 'dart:io';

/// Identifies exactly which build is running.
///
/// Without this, every report starts with working out which build you are on,
/// and there is no way to tell from inside the app. CI injects the values with
/// `--dart-define`; a local build falls back to something obviously local
/// rather than pretending to be a real one.
abstract final class BuildInfo {
  /// Marketing version.
  ///
  /// Stamped by CI from `pubspec.yaml`, which is the one place it is written.
  /// It was a hand-maintained copy of a number that also appears in four
  /// workflow lines: bumping to 0.2.0 meant five edits, and forgetting any one
  /// of them produced a build that told the client it was something else.
  static const String version = String.fromEnvironment(
    'MI_VERSION',
    defaultValue: '0.1.0',
  );

  /// Where builds come from. Named once so the update feed, the release page
  /// and the diagnostics link cannot drift apart.
  static const String repo = 'kaiharimoto/Master-Idea';

  /// The CI run number. `local` when built on a developer machine.
  static const String build = String.fromEnvironment(
    'MI_BUILD',
    defaultValue: 'local',
  );

  /// The full commit SHA CI built from. Empty for a local build.
  static const String sha = String.fromEnvironment('MI_SHA');

  static bool get isCiBuild => build != 'local';

  static String get shortSha =>
      sha.isEmpty ? 'dev' : sha.substring(0, sha.length < 7 ? sha.length : 7);

  /// What the user sees and quotes back: `0.1.0+42 · a1b2c3d`.
  static String get label => '$version+$build · $shortSha';

  static String get platform {
    if (Platform.isAndroid) return 'Android';
    if (Platform.isWindows) return 'Windows';
    if (Platform.isLinux) return 'Linux';
    if (Platform.isMacOS) return 'macOS';
    if (Platform.isIOS) return 'iOS';
    return 'unknown';
  }

  static String get osVersion => Platform.operatingSystemVersion;

  static String get commitUrl =>
      sha.isEmpty ? '' : 'https://github.com/$repo/commit/$sha';

  /// The rolling prerelease everyone installs from. A fixed tag, so a build
  /// from a year ago still knows where to look.
  static const String releasePage = 'https://github.com/$repo/releases/tag/dev';
}
