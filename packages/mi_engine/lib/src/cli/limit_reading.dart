import 'package:meta/meta.dart';

/// What a failed turn actually was.
///
/// The distinction that matters is not how bad the failure looks but whether
/// waiting fixes it. A usage limit lifts on its own and the run should sit
/// through it; a login that expired, an unknown model or an empty balance
/// never lift, and a run that waits them out spends hours in silence, loses
/// every search, and then records itself as having gone dry.
enum FailureKind {
  /// Nothing in the output says the provider stopped us.
  none,

  /// A five-hour session limit.
  session,

  /// A weekly limit.
  weekly,

  /// A per-minute rate limit or a transient overload.
  rate,

  /// Not logged in, or a token that expired.
  auth,

  /// The account is out of credit or past a spend ceiling.
  overage,

  /// Something the provider says is not retryable at all.
  fatal,
}

/// Whether the failure is one that waiting resolves.
extension FailureKindWaiting on FailureKind {
  bool get liftsByWaiting =>
      this == FailureKind.session ||
      this == FailureKind.weekly ||
      this == FailureKind.rate;
}

/// The wordings a limit arrives in.
///
/// Data rather than code because the wording changes between CLI versions and
/// a release should not be needed to follow it. Ordered checks live in
/// [LimitReader]; this only says what to look for.
@immutable
class LimitPatterns {
  const LimitPatterns({
    this.auth = const <String>[
      'invalid api key',
      'authentication_error',
      'authentication failed',
      'not logged in',
      'please run /login',
      'unauthorized',
      'oauth token has expired',
      'no api key',
    ],
    this.overage = const <String>[
      'credit balance',
      'insufficient credit',
      'spend limit',
      'billing',
      'payment required',
    ],
    this.weekly = const <String>[
      'weekly limit',
      '7-day limit',
      'seven-day limit',
      'weekly usage limit',
    ],
    this.session = const <String>[
      'usage limit',
      'limit reached',
      'limit resets',
      'resets at',
      'quota exceeded',
    ],
    this.rate = const <String>[
      'rate limit',
      'rate_limit_error',
      'too many requests',
      '429',
      'overloaded',
      'overloaded_error',
    ],
    this.fatal = const <String>[
      'unknown option',
      'invalid model',
      'model not found',
      'is not a valid model',
      'no such file or directory',
      'permission denied',
    ],
  });

  final List<String> auth;
  final List<String> overage;
  final List<String> weekly;
  final List<String> session;
  final List<String> rate;
  final List<String> fatal;
}

/// How a resume time was arrived at.
///
/// Kept beside the time itself because an unattended run acts on it for hours
/// with nobody watching, and a guess that reads like a fact is how a sitting
/// comes back early, spends a call, and pauses again.
abstract final class ResetSource {
  /// The provider gave a timestamp.
  static const String explicit = 'explicit';

  /// The provider gave a delay or a clock time.
  static const String stated = 'stated';

  /// Worked out from when this sitting's block began.
  static const String inferred = 'inferred';

  /// Nothing to go on.
  static const String guessed = 'guessed';
}

/// What one failed turn's output said.
@immutable
class LimitReading {
  const LimitReading({
    required this.kind,
    required this.detail,
    this.until,
    this.source = ResetSource.guessed,
  });

  final FailureKind kind;

  /// What the provider said, as it said it.
  final String detail;

  /// When to try again. Null when [kind] does not lift by waiting.
  final DateTime? until;

  final String source;
}

/// Reads a failed turn's output.
///
/// Auth is checked before anything else: a login that expired often arrives
/// wearing the word "limit", and a run that waits five hours for a password to
/// fix itself is the worst failure this program can have.
abstract final class LimitReader {
  static const LimitPatterns defaultPatterns = LimitPatterns();

  /// How long a five-hour block lasts, plus a margin so a resume does not land
  /// microseconds early and burn a call.
  static const Duration fiveHourWindow = Duration(hours: 5, minutes: 5);

  static LimitReading read(
    String output, {
    required DateTime now,
    DateTime? blockStartedAt,
    LimitPatterns patterns = defaultPatterns,
  }) {
    final String detail = output.trim();
    final String hay = output.toLowerCase();

    if (patterns.auth.any(hay.contains)) {
      return LimitReading(kind: FailureKind.auth, detail: detail);
    }
    if (patterns.overage.any(hay.contains)) {
      return LimitReading(kind: FailureKind.overage, detail: detail);
    }

    FailureKind kind = FailureKind.none;
    if (patterns.weekly.any(hay.contains)) {
      kind = FailureKind.weekly;
    } else if (patterns.session.any(hay.contains)) {
      kind = FailureKind.session;
    } else if (patterns.rate.any(hay.contains)) {
      kind = FailureKind.rate;
    }

    if (kind == FailureKind.none) {
      return LimitReading(
        kind: patterns.fatal.any(hay.contains)
            ? FailureKind.fatal
            : FailureKind.none,
        detail: detail,
      );
    }

    final _Reset reset = _reset(
      kind: kind,
      hay: hay,
      now: now,
      blockStartedAt: blockStartedAt,
    );
    return LimitReading(
      kind: kind,
      detail: detail,
      until: reset.at,
      source: reset.source,
    );
  }

  /// The reset ladder. The first rung that answers wins, and the rung is
  /// recorded so an auditor knows how much the time is worth.
  static _Reset _reset({
    required FailureKind kind,
    required String hay,
    required DateTime now,
    required DateTime? blockStartedAt,
  }) {
    // 1. An epoch the provider stated. Its own bookkeeping stores seconds;
    //    reading them as milliseconds would schedule a resume fifty years out,
    //    so the unit is asserted by range rather than assumed.
    final RegExpMatch? epoch = RegExp(
      r'\b(1[6-9]\d{8}|2[0-9]{9})\b',
    ).firstMatch(hay);
    if (epoch != null) {
      final DateTime at = DateTime.fromMillisecondsSinceEpoch(
        int.parse(epoch.group(1)!) * 1000,
        isUtc: true,
      );
      if (at.isAfter(now) && at.difference(now) < const Duration(days: 30)) {
        return _Reset(at, ResetSource.explicit);
      }
    }

    // 2. A delay it stated in words.
    final Duration? delay = _delayIn(hay);
    if (delay != null) return _Reset(now.add(delay), ResetSource.stated);

    // 3. A clock time it stated. Read in local time, because that is the clock
    //    the provider prints and the client reads.
    final DateTime? clock = _clockTimeIn(hay, now);
    if (clock != null) return _Reset(clock, ResetSource.stated);

    // 4. The block this sitting began in. No text, no locale, no cooperation
    //    from the provider — which makes it the sturdiest rung on the ladder.
    if (kind == FailureKind.session && blockStartedAt != null) {
      final DateTime at = blockStartedAt.toUtc().add(fiveHourWindow);
      if (at.isAfter(now)) return _Reset(at, ResetSource.inferred);
      return _Reset(now.add(const Duration(minutes: 2)), ResetSource.inferred);
    }

    // 5. A guess, recorded as one.
    return _Reset(
      now.add(switch (kind) {
        FailureKind.session => fiveHourWindow,
        FailureKind.weekly => const Duration(hours: 12),
        _ => const Duration(minutes: 2),
      }),
      ResetSource.guessed,
    );
  }

  static Duration? _delayIn(String hay) {
    final RegExpMatch? m = RegExp(
      r'(?:retry after|try again in|resets? in|available again in)\s+'
      r'(?:(\d+)\s*h(?:ours?|rs?)?)?\s*(?:(\d+)\s*m(?:inutes?|ins?)?)?'
      r'\s*(?:(\d+)\s*s(?:econds?|ecs?)?)?',
    ).firstMatch(hay);
    if (m == null) return null;
    final int h = int.tryParse(m.group(1) ?? '') ?? 0;
    final int mi = int.tryParse(m.group(2) ?? '') ?? 0;
    final int sec = int.tryParse(m.group(3) ?? '') ?? 0;
    if (h == 0 && mi == 0 && sec == 0) return null;
    return Duration(hours: h, minutes: mi, seconds: sec);
  }

  static DateTime? _clockTimeIn(String hay, DateTime now) {
    final RegExpMatch? m = RegExp(
      r'resets? at\s+(\d{1,2})(?::(\d{2}))?\s*(am|pm)?',
    ).firstMatch(hay);
    if (m == null) return null;
    int hour = int.parse(m.group(1)!);
    final int minute = int.tryParse(m.group(2) ?? '') ?? 0;
    final String? meridiem = m.group(3);
    if (hour > 23 || minute > 59) return null;
    if (meridiem == 'pm' && hour < 12) hour += 12;
    if (meridiem == 'am' && hour == 12) hour = 0;

    final DateTime local = now.toLocal();
    DateTime at = DateTime(local.year, local.month, local.day, hour, minute);
    // A time already past today is tomorrow's, which is what "resets at 3pm"
    // means when it is four o'clock.
    if (!at.isAfter(local)) at = at.add(const Duration(days: 1));
    return at.toUtc();
  }
}

@immutable
class _Reset {
  const _Reset(this.at, this.source);
  final DateTime at;
  final String source;
}
