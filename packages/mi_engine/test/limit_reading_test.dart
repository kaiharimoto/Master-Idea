import 'package:mi_engine/mi_engine.dart';
import 'package:test/test.dart';

/// What a failed turn was, and when to come back.
///
/// Every rung of this ladder is acted on for hours by a run with nobody
/// watching, so each is tested against the wording it exists for rather than
/// against a paraphrase of it.
void main() {
  final DateTime now = DateTime.utc(2026, 3, 1, 9);

  LimitReading read(String text, {DateTime? blockStartedAt}) =>
      LimitReader.read(text, now: now, blockStartedAt: blockStartedAt);

  group('what does not lift by waiting', () {
    test('an expired login is never a limit, whatever words it arrives in', () {
      final LimitReading r = read(
        'Claude usage limit: invalid API key · Please run /login',
      );
      expect(
        r.kind,
        FailureKind.auth,
        reason:
            'Auth is read before anything else because it often arrives '
            'wearing the word "limit", and a run that waits five hours for a '
            'password to fix itself is the worst failure this program has.',
      );
      expect(r.kind.liftsByWaiting, isFalse);
    });

    test('an empty balance is not a limit either', () {
      expect(read('Your credit balance is too low').kind, FailureKind.overage);
    });

    test('an unknown flag is fatal, not a pause', () {
      expect(read("error: unknown option '--effort'").kind, FailureKind.fatal);
    });

    test('silence says nothing happened', () {
      expect(read('').kind, FailureKind.none);
    });
  });

  group('when to come back', () {
    test('an epoch the provider stated is taken as given', () {
      final int at =
          DateTime.utc(2026, 3, 1, 14).millisecondsSinceEpoch ~/ 1000;
      final LimitReading r = read('usage limit reached; resets $at');
      expect(r.source, ResetSource.explicit);
      expect(r.until, DateTime.utc(2026, 3, 1, 14));
    });

    test('a delay it stated in words is honoured', () {
      final LimitReading r = read('rate limit; retry after 90 seconds');
      expect(r.source, ResetSource.stated);
      expect(r.until, now.add(const Duration(seconds: 90)));
    });

    test('hours and minutes together', () {
      final LimitReading r = read('usage limit reached; resets in 2h 15m');
      expect(r.until, now.add(const Duration(hours: 2, minutes: 15)));
    });

    test('a clock time is read as the next such time', () {
      final DateTime local = now.toLocal();
      final LimitReading r = read('Your limit resets at 3pm');
      expect(r.source, ResetSource.stated);
      expect(r.until!.isAfter(now), isTrue);
      expect(
        r.until!.toLocal().hour,
        15,
        reason: 'Read in the clock the provider printed and the client reads.',
      );
      expect(
        r.until!.difference(local.toUtc()).inHours,
        lessThan(24),
        reason: 'The next three o\'clock, not some later one.',
      );
    });

    test('with nothing stated, the five-hour block is inferred', () {
      final LimitReading r = read(
        'Claude usage limit reached.',
        blockStartedAt: DateTime.utc(2026, 3, 1, 7),
      );
      expect(r.source, ResetSource.inferred);
      expect(r.until, DateTime.utc(2026, 3, 1, 12, 5));
    });

    test('with nothing at all, the guess is labelled as one', () {
      final LimitReading r = read('Claude usage limit reached.');
      expect(
        r.source,
        ResetSource.guessed,
        reason:
            'A guess that reads like a fact is how an unattended run is '
            'trusted about something nobody ever knew.',
      );
      expect(r.until, now.add(LimitReader.fiveHourWindow));
    });

    test('a weekly limit is not treated as a five-hour one', () {
      final LimitReading r = read('You have hit your weekly limit for Opus.');
      expect(r.kind, FailureKind.weekly);
      expect(r.until!.difference(now).inHours, greaterThan(5));
    });
  });
}
