import 'package:meta/meta.dart';

import 'round.dart';

/// One call to the model, as the machine saw it.
///
/// Written by the run, never by hand. This is the record that separates a real
/// six-hour session from a six-hour wait: a manifest whose calls, wall clock
/// and token totals cannot account for the directions in the dossier is
/// evidence that the dossier came from somewhere else.
@immutable
class ModelCall {
  const ModelCall({
    required this.at,
    required this.purpose,
    required this.by,
    required this.promptChars,
    required this.replyChars,
    this.tokensIn = 0,
    this.tokensOut = 0,
  });

  final DateTime at;

  /// What the call was for — `propose`, `challenge`, `rate`, `map`,
  /// `integrate`. Matches the licence the seat was exercising.
  final String purpose;

  /// The agent instance that made it.
  final String by;

  final int promptChars;
  final int replyChars;

  /// Zero when the transport does not report usage. Recorded as zero rather
  /// than omitted, so 'not reported' and 'nothing spent' stay distinguishable.
  final int tokensIn;
  final int tokensOut;

  Map<String, Object?> toJson() => <String, Object?>{
    'at': at.toIso8601String(),
    'purpose': purpose,
    'by': by,
    'promptChars': promptChars,
    'replyChars': replyChars,
    'tokensIn': tokensIn,
    'tokensOut': tokensOut,
  };

  static ModelCall fromJson(Map<String, Object?> j) => ModelCall(
    at: DateTime.parse('${j['at']}'),
    purpose: '${j['purpose']}',
    by: '${j['by']}',
    promptChars: (j['promptChars']! as num).toInt(),
    replyChars: (j['replyChars']! as num).toInt(),
    tokensIn: (j['tokensIn'] as num?)?.toInt() ?? 0,
    tokensOut: (j['tokensOut'] as num?)?.toInt() ?? 0,
  );
}

/// A wait the provider imposed.
///
/// A rate or session limit is not the council thinking, so it is excluded from
/// council time; and a run paused by a limit has emphatically not gone dry,
/// which is the mistake this record exists to make impossible. The pause is
/// logged with both ends so an auditor can subtract it themselves.
@immutable
class LimitPause {
  const LimitPause({
    required this.from,
    required this.until,
    required this.kind,
    required this.detail,
    this.source = 'guessed',
  });

  final DateTime from;
  final DateTime until;

  /// `session`, `weekly`, `overage`, `rate` or `transient`.
  final String kind;

  /// What the provider said, as it said it.
  final String detail;

  /// How the resume time was arrived at: `explicit`, `stated`, `inferred` or
  /// `guessed`. Recorded because a guess and a timestamp the provider gave are
  /// worth different amounts to whoever reads this afterwards, and a guess
  /// that reads like a fact is how an unattended run is trusted about
  /// something nobody ever knew.
  final String source;

  Duration get length => until.difference(from);

  Map<String, Object?> toJson() => <String, Object?>{
    'from': from.toIso8601String(),
    'until': until.toIso8601String(),
    'kind': kind,
    'detail': detail,
    'source': source,
    'seconds': length.inSeconds,
  };

  static LimitPause fromJson(Map<String, Object?> j) => LimitPause(
    from: DateTime.parse('${j['from']}'),
    until: DateTime.parse('${j['until']}'),
    kind: '${j['kind']}',
    detail: '${j['detail']}',
    source: '${j['source'] ?? 'guessed'}',
  );
}

/// The machine-written account of a run.
@immutable
class RunManifest {
  const RunManifest({
    required this.sessionId,
    required this.templateId,
    required this.tier,
    required this.transport,
    required this.startedAt,
    this.endedAt,
    this.calls = const <ModelCall>[],
    this.pauses = const <LimitPause>[],
    this.dryness,
  });

  final String sessionId;
  final String templateId;
  final int tier;

  /// `cli` on the desktop, `handover` on the phone. Recorded because the
  /// Android client cannot run unattended, and a session claiming six hours of
  /// autonomy on the handover transport is claiming something impossible.
  final String transport;

  final DateTime startedAt;
  final DateTime? endedAt;
  final List<ModelCall> calls;
  final List<LimitPause> pauses;
  final DrynessDecision? dryness;

  Duration get wallClock => (endedAt ?? startedAt).difference(startedAt);

  /// Wall clock less every provider pause. This is what a tier's expectation
  /// is compared against — a run that waited four hours for a limit to lift
  /// did not deliberate for four hours.
  Duration get councilTime {
    Duration paused = Duration.zero;
    for (final LimitPause p in pauses) {
      paused += p.length;
    }
    return wallClock - paused;
  }

  int get tokensIn => calls.fold(0, (int sum, ModelCall c) => sum + c.tokensIn);
  int get tokensOut =>
      calls.fold(0, (int sum, ModelCall c) => sum + c.tokensOut);

  RunManifest record(ModelCall c) => _copy(calls: <ModelCall>[...calls, c]);

  RunManifest paused(LimitPause p) => _copy(pauses: <LimitPause>[...pauses, p]);

  RunManifest closed(DateTime at, DrynessDecision d) =>
      _copy(endedAt: at, dryness: d);

  /// Record which transport actually drove the sitting.
  ///
  /// Written when the sitting opens rather than when the session does, because
  /// the route is a fact about the device the run happened on and the session
  /// may have been opened on the other one. A hand-carried session whose
  /// manifest says `cli` is claiming six hours of autonomy that no phone has.
  RunManifest onTransport(String t) => _copy(transport: t);

  RunManifest _copy({
    List<ModelCall>? calls,
    List<LimitPause>? pauses,
    DateTime? endedAt,
    DrynessDecision? dryness,
    String? transport,
  }) => RunManifest(
    sessionId: sessionId,
    templateId: templateId,
    tier: tier,
    transport: transport ?? this.transport,
    startedAt: startedAt,
    endedAt: endedAt ?? this.endedAt,
    calls: calls ?? this.calls,
    pauses: pauses ?? this.pauses,
    dryness: dryness ?? this.dryness,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'sessionId': sessionId,
    'templateId': templateId,
    'tier': tier,
    'transport': transport,
    'startedAt': startedAt.toIso8601String(),
    if (endedAt != null) 'endedAt': endedAt!.toIso8601String(),
    'wallClockSeconds': wallClock.inSeconds,
    'councilTimeSeconds': councilTime.inSeconds,
    'tokensIn': tokensIn,
    'tokensOut': tokensOut,
    'calls': calls.map((ModelCall c) => c.toJson()).toList(),
    'pauses': pauses.map((LimitPause p) => p.toJson()).toList(),
    if (dryness != null) 'dryness': dryness!.toJson(),
  };

  static RunManifest fromJson(Map<String, Object?> j) => RunManifest(
    sessionId: '${j['sessionId']}',
    templateId: '${j['templateId']}',
    tier: (j['tier']! as num).toInt(),
    transport: '${j['transport']}',
    startedAt: DateTime.parse('${j['startedAt']}'),
    endedAt: j['endedAt'] == null ? null : DateTime.parse('${j['endedAt']}'),
    calls: (j['calls'] as List<Object?>? ?? const <Object?>[])
        .map((Object? e) => ModelCall.fromJson(e! as Map<String, Object?>))
        .toList(),
    pauses: (j['pauses'] as List<Object?>? ?? const <Object?>[])
        .map((Object? e) => LimitPause.fromJson(e! as Map<String, Object?>))
        .toList(),
    dryness: j['dryness'] == null
        ? null
        : DrynessDecision.fromJson(j['dryness']! as Map<String, Object?>),
  );
}
