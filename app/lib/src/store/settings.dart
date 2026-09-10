import 'package:flutter/material.dart';

/// The few things the client chooses.
///
/// Deliberately short. Every setting is a decision the app could not make for
/// itself, and a setting that exists because a decision was avoided is a
/// question asked of everyone forever.
@immutable
class Settings {
  const Settings({
    this.themeMode = ThemeMode.system,
    this.claudePath = '',
    this.model = '',
    this.pasteLimit = 12000,
  });

  final ThemeMode themeMode;

  /// An explicit path to the Claude CLI.
  ///
  /// **A directive, not a hint.** When set it is used alone, so a wrong path is
  /// reported as wrong rather than silently bypassed by a working install
  /// elsewhere — otherwise this field appears to do nothing.
  final String claudePath;

  /// Empty means send no `--model` at all, leaving the CLI on whatever the
  /// client chose with `/model`. The flag enumerates no choices in `--help`,
  /// so a bad value cannot be caught before it fails a turn.
  final String model;

  /// How much text the receiving chat app will accept in one paste.
  ///
  /// A setting because nothing can probe the real ceiling, and only the person
  /// holding the phone can find it.
  final int pasteLimit;

  Settings copyWith({
    ThemeMode? themeMode,
    String? claudePath,
    String? model,
    int? pasteLimit,
  }) => Settings(
    themeMode: themeMode ?? this.themeMode,
    claudePath: claudePath ?? this.claudePath,
    model: model ?? this.model,
    pasteLimit: pasteLimit ?? this.pasteLimit,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'themeMode': themeMode.name,
    'claudePath': claudePath,
    'model': model,
    'pasteLimit': pasteLimit,
  };

  static Settings fromJson(Map<String, Object?> j) => Settings(
    themeMode: ThemeMode.values.firstWhere(
      (ThemeMode m) => m.name == j['themeMode'],
      orElse: () => ThemeMode.system,
    ),
    claudePath: '${j['claudePath'] ?? ''}',
    model: '${j['model'] ?? ''}',
    pasteLimit: (j['pasteLimit'] as num?)?.toInt() ?? 12000,
  );
}
