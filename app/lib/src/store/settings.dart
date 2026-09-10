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
    this.concurrentTurns = 4,
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

  /// How many turns the council may have in the air at once.
  ///
  /// A round at the largest tier fans out twelve angles and pipelines every
  /// direction through challenge and rating: some fifty `claude` processes
  /// together on a laptop, which is itself the commonest way to provoke the
  /// limits a run then has to wait out. **Not a stop condition** — it decides
  /// how many turns are travelling, never how wide the council searches, and
  /// nothing here can end a round or a run.
  final int concurrentTurns;

  Settings copyWith({
    ThemeMode? themeMode,
    String? claudePath,
    String? model,
    int? concurrentTurns,
  }) => Settings(
    themeMode: themeMode ?? this.themeMode,
    claudePath: claudePath ?? this.claudePath,
    model: model ?? this.model,
    concurrentTurns: concurrentTurns ?? this.concurrentTurns,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'themeMode': themeMode.name,
    'claudePath': claudePath,
    'model': model,
    'concurrentTurns': concurrentTurns,
  };

  static Settings fromJson(Map<String, Object?> j) => Settings(
    themeMode: ThemeMode.values.firstWhere(
      (ThemeMode m) => m.name == j['themeMode'],
      orElse: () => ThemeMode.system,
    ),
    claudePath: '${j['claudePath'] ?? ''}',
    model: '${j['model'] ?? ''}',
    concurrentTurns: (j['concurrentTurns'] as num?)?.toInt() ?? 4,
  );
}
