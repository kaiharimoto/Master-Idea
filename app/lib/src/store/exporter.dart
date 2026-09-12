import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// What became of a document the client asked to keep.
enum ExportKind {
  /// Written where this platform keeps downloads.
  saved,

  /// The client chose where it went.
  chosen,

  /// They changed their mind.
  cancelled,

  /// Nothing was written, and the reason is with it.
  failed,
}

/// Where a document went, and what to tell the client about it.
class ExportResult {
  const ExportResult(this.kind, this.detail);

  final ExportKind kind;

  /// A path on a desktop, a short phrase on a phone, or the reason it failed.
  final String detail;

  String get message => switch (kind) {
    ExportKind.saved => 'Saved to $detail',
    ExportKind.chosen => 'Saved',
    ExportKind.cancelled => 'Not saved',
    ExportKind.failed => 'It could not be saved. $detail',
  };
}

/// Getting a document out of the app.
///
/// The dossier, the ledger and the pitch are the entire output of a sitting,
/// and until now the only way any of them left was the clipboard — the pitch
/// alone, on one button. A council's case file is a document people forward,
/// print and keep beside the work; a program that can only hand it over as a
/// paste is one whose output does not survive contact with the rest of the
/// client's life.
///
/// The Android side of this has existed since the first build: `MainActivity`
/// implements `save` and `share`, `file_paths.xml` reserves a `handover`
/// directory for exactly this, and the decision log records the contract. It
/// was never called from Dart.
abstract final class Exporter {
  static const MethodChannel _channel = MethodChannel('masteridea/platform');

  static bool get canShare => Platform.isAndroid;

  /// Write [contents] out under [name] for the client to keep.
  static Future<ExportResult> save({
    required String name,
    required String contents,
  }) async {
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        final File staged = await _stage(name, contents);
        final String? outcome = await _channel.invokeMethod<String>(
          'save',
          <String, Object?>{'path': staged.path, 'name': name},
        );
        // The words are the Kotlin side's, and are matched rather than
        // guessed at: a switch that silently falls through to "failed" would
        // report every successful save as a failure the first time the
        // native side gained an outcome.
        return switch (outcome) {
          'downloads' => const ExportResult(ExportKind.saved, 'Downloads'),
          'chosen' => const ExportResult(ExportKind.chosen, ''),
          'cancelled' => const ExportResult(ExportKind.cancelled, ''),
          _ => const ExportResult(
            ExportKind.failed,
            'The system would not take the file.',
          ),
        };
      }

      // A desktop keeps files where the client can find them. Downloads is
      // not guaranteed to exist on Linux, so the app's own directory is the
      // fallback rather than a failure.
      Directory? target;
      try {
        target = await getDownloadsDirectory();
      } on Object {
        target = null;
      }
      target ??= await getApplicationSupportDirectory();
      final File out = File('${target.path}${Platform.pathSeparator}$name');
      out.writeAsStringSync(contents, flush: true);
      return ExportResult(ExportKind.saved, out.path);
    } on Object catch (e) {
      return ExportResult(ExportKind.failed, '$e');
    }
  }

  /// Hand [contents] to another app, where the platform has such a thing.
  ///
  /// Saving is the default and this is the second offer, because a share
  /// always opens a *new* conversation — the receiving app decides that — and
  /// a pitch usually belongs in one that already exists.
  static Future<bool> share({
    required String name,
    required String contents,
  }) async {
    if (!canShare) return false;
    try {
      final File staged = await _stage(name, contents);
      return await _channel.invokeMethod<bool>('share', <String, Object?>{
            'path': staged.path,
            'text': '',
          }) ??
          false;
    } on Object {
      return false;
    }
  }

  /// Written into the one directory this app shares outward, and nowhere else:
  /// a provider over the whole of internal storage would hand every stored
  /// session — every interview answer the client gave — to any app holding
  /// the URI.
  static Future<File> _stage(String name, String contents) async {
    final Directory tmp = await getTemporaryDirectory();
    final Directory dir = Directory(
      '${tmp.path}${Platform.pathSeparator}handover',
    );
    if (!dir.existsSync()) dir.createSync(recursive: true);
    final File f = File('${dir.path}${Platform.pathSeparator}$name');
    f.writeAsStringSync(contents, flush: true);
    return f;
  }
}
