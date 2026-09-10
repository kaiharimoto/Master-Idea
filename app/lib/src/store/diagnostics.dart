import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';

import 'build_info.dart';

/// A ring of recent events, and a place for a crash to land.
///
/// A run is unattended for hours, so the interesting failures happen with
/// nobody watching. This is what makes them reportable afterwards: a bounded
/// log the user can copy, and an error handler installed before anything else
/// runs so a failure during startup is still captured.
class Diagnostics {
  Diagnostics._();

  static final Diagnostics instance = Diagnostics._();

  static const int _limit = 400;
  final Queue<String> _lines = Queue<String>();

  List<String> get lines => List<String>.unmodifiable(_lines);

  Future<void> install() async {
    FlutterError.onError = (FlutterErrorDetails details) {
      log('Flutter error: ${details.exceptionAsString()}');
      FlutterError.presentError(details);
    };
    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      log('Uncaught: $error');
      return true;
    };
  }

  void log(String message) {
    final String stamped =
        '${DateTime.now().toUtc().toIso8601String().substring(11, 19)}  $message';
    _lines.addLast(stamped);
    while (_lines.length > _limit) {
      _lines.removeFirst();
    }
    if (kDebugMode) debugPrint(stamped);
  }

  /// Everything a report needs, in the order someone reading it wants it.
  String report() => <String>[
    'Master Idea ${BuildInfo.label}',
    '${BuildInfo.platform} · ${BuildInfo.osVersion}',
    if (BuildInfo.commitUrl.isNotEmpty) BuildInfo.commitUrl,
    '',
    ..._lines,
  ].join('\n');
}
