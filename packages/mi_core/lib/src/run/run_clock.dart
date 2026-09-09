/// The run's only source of time.
///
/// Injected for the same reason Master Prompt's supervisor takes one: a run
/// that waits out a five-hour usage limit cannot be tested against a real
/// clock, and a limit pause that is never exercised in a test is a limit pause
/// that is broken the first time a provider imposes one. The fake advances
/// instantly and records what it was asked to wait for.
abstract interface class RunClock {
  DateTime now();

  /// Wait until [when]. Returning early is a lie the caller cannot detect, so
  /// implementations must not.
  Future<void> waitUntil(DateTime when);
}

/// The real clock.
class SystemClock implements RunClock {
  const SystemClock();

  @override
  DateTime now() => DateTime.now().toUtc();

  @override
  Future<void> waitUntil(DateTime when) async {
    final Duration d = when.difference(now());
    if (d.isNegative || d == Duration.zero) return;
    await Future<void>.delayed(d);
  }
}
