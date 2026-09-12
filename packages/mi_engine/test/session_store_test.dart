import 'dart:convert';
import 'dart:io';

import 'package:mi_core/mi_core.dart';
import 'package:mi_engine/mi_engine.dart';
import 'package:test/test.dart';

import 'support/fixtures.dart';

/// A council that answers everything from a script, so the store is tested
/// against a session that actually ran rather than one assembled by hand.
class OneRoundCouncil implements CouncilTransport {
  int _n = 0;

  @override
  Future<CouncilReply> ask(CouncilTurn turn) async {
    switch (turn.purpose) {
      case 'propose':
        if (turn.agent.round > 1) return const CouncilReply(text: 'mi-none');
        _n++;
        return CouncilReply(
          text:
              'mi-direction\n'
              'cluster=What the thing is for\n'
              'ambition=ambitious\n'
              'title=Direction number $_n\n'
              'statement=Something specific and unlike the others, number $_n, '
              'about how the work reaches whoever it is for.\n'
              'mechanism=Built by writing $_n distinct parts and joining them '
              'only at the end.\n'
              'trace-answer=${_answerFor(turn.prompt, _n)}\n'
              'quote=the phrase this answers\n'
              'end',
          tokensIn: 100,
          tokensOut: 40,
        );
      case 'rate':
        final List<String> rungs = _rungs(turn.prompt);
        return CouncilReply(
          text:
              'mi-rating\nverdict=${rungs.last}\n'
              'because=Judged on what was written.\nend',
        );
      case 'challenge':
        return const CouncilReply(
          text:
              'mi-challenge\nattack=It needs an audience first.\n'
              'fatal=no\nend',
        );
      case 'map':
        return const CouncilReply(
          text:
              'mi-territory\nid=t-left\nname=Ground left\n'
              'description=Not entered.\nstatus=dropped\n'
              'reason=The client put it out of bounds.\nend',
        );
      default:
        return const CouncilReply(text: 'mi-none');
    }
  }

  static String _answerFor(String prompt, int n) {
    final List<String> ids = <String>[
      for (final RegExpMatch m in RegExp(
        r'^\[([a-z-]+)\]',
        multiLine: true,
      ).allMatches(prompt))
        m.group(1)!,
    ];
    return ids.isEmpty ? 'raw-idea' : ids[n % ids.length];
  }

  static List<String> _rungs(String prompt) {
    final List<String> lines = prompt.split('\n');
    final int i = lines.indexWhere(
      (String l) => l.trim() == 'ANSWER WITH EXACTLY ONE OF',
    );
    return lines[i + 1].split(',').map((String s) => s.trim()).toList();
  }
}

void main() {
  late Directory tmp;
  late SessionStore store;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('mi-store');
    store = SessionStore(Directory('${tmp.path}/sessions'));
  });

  tearDown(() => tmp.deleteSync(recursive: true));

  Future<Session> ranSession() => CouncilRun(
    transport: OneRoundCouncil(),
    clock: FakeClock(),
  ).deliberate(referenceSession());

  group('a session on disk', () {
    test('is the layout the brief fixes', () async {
      final Session s = await ranSession();
      store.write(s);
      final String dir = '${store.root.path}/${s.id}';
      for (final String path in <String>[
        'session.json',
        'interview/record.json',
        'interview/brief.md',
        'ledger.json',
        'directions.json',
        'assembly.json',
        'run_manifest.json',
      ]) {
        expect(File('$dir/$path').existsSync(), isTrue, reason: path);
      }
      expect(Directory('$dir/rounds').listSync(), isNotEmpty);
      expect(Directory('$dir/ratings').listSync(), isNotEmpty);
    });

    test('reads back as the session that was written', () async {
      final Session s = await ranSession();
      store.write(s);
      final Session back = store.read(s.id);

      expect(back.directions.length, s.directions.length);
      expect(back.ratings.length, s.ratings.length);
      expect(
        back.rounds.map((RoundRecord r) => r.number),
        s.rounds.map((RoundRecord r) => r.number),
      );
      expect(
        back.manifest.dryness!.secondRound,
        s.manifest.dryness!.secondRound,
      );
      expect(back.interview.brief.hash, s.interview.brief.hash);
      expect(back.ratings.first.context.shownText, isNotEmpty);
    });

    test(
      'still passes the invariant suite when read from files alone',
      () async {
        final Session s = await ranSession();
        store.write(s);
        final InvariantReport report = InvariantSuite.run(store.read(s.id));
        expect(report.holds, isTrue, reason: report.summary);
      },
    );

    test('renders without the council existing', () async {
      final Session s = await ranSession();
      store.write(s);
      final Session reopened = store.read(s.id);
      expect(DossierRenderer.render(reopened).toText(), isNotEmpty);
      expect(LedgerRenderer.render(reopened).toText(), contains('Rounds'));
    });

    test('does not rewrite a round that has already closed', () async {
      final Session s = await ranSession();
      store.write(s);
      final File first = Directory(
        '${store.root.path}/${s.id}/rounds',
      ).listSync().whereType<File>().first;
      final DateTime before = first.lastModifiedSync();
      first.writeAsStringSync(
        first.readAsStringSync().replaceFirst('"number"', '"number_touched"'),
      );
      store.write(s);
      expect(
        first.readAsStringSync(),
        contains('number_touched'),
        reason:
            'Rewriting a closed round would make the stored history a '
            'function of when the session was last saved.',
      );
      expect(before, isNotNull);
    });
  });

  group('minting an id', () {
    test('cannot repeat inside one coarse clock tick', () {
      // Windows advances its clock in ticks of a millisecond or more, so two
      // sessions made inside one tick were handed the same id in the other half
      // of this pair — and the second silently overwrote the first. A frozen
      // clock is that platform taken to its limit, and it proves the property
      // on a Linux runner where the real clock would not.
      final DateTime frozen = DateTime.utc(2026, 3, 1, 9);
      final SessionStore s = SessionStore(
        Directory('${tmp.path}/sessions'),
        now: () => frozen,
      );
      final List<String> ids = <String>[for (int i = 0; i < 5; i++) s.mintId()];
      expect(ids.toSet(), hasLength(5));
    });

    test(
      'cannot reissue an id already on disk after a clock moves backwards',
      () async {
        final Session s = await ranSession();
        final SessionStore ahead = SessionStore(
          Directory('${tmp.path}/sessions'),
          now: () => DateTime.utc(2027),
        );
        final String late = ahead.mintId();
        Directory('${tmp.path}/sessions/$late').createSync(recursive: true);
        File('${tmp.path}/sessions/$late/session.json').writeAsStringSync('{}');

        // A different launch, with a clock that has been corrected backwards.
        final SessionStore behind = SessionStore(
          Directory('${tmp.path}/sessions'),
          now: () => DateTime.utc(2026),
        );
        expect(
          behind.mintId(),
          isNot(late),
          reason:
              'The counter alone dies with the process. An id that repeats is '
              'a session overwritten.',
        );
        expect(s.id, isNotEmpty);
      },
    );

    test('lists what is on disk', () async {
      final Session s = await ranSession();
      store.write(s);
      expect(store.listIds(), <String>[s.id]);
      expect(store.exists(s.id), isTrue);
    });
  });

  group('removing a session', () {
    test('takes its files with it and refuses anything else', () {
      final Directory root = Directory.systemTemp.createTempSync('mi-rm');
      addTearDown(() => root.deleteSync(recursive: true));
      final SessionStore store = SessionStore(root);
      final Session s = referenceSession();
      store.write(s);
      expect(store.exists(s.id), isTrue);

      store.delete(s.id);
      expect(store.exists(s.id), isFalse);
      expect(store.listIds(), isEmpty);

      expect(
        () => store.delete('../..'),
        throwsA(isA<ArgumentError>()),
        reason:
            'This deletes recursively, so an id that walked out of the '
            'library would take something else with it.',
      );
    });

    test('refuses a directory that is not a stored session', () {
      final Directory root = Directory.systemTemp.createTempSync('mi-rm2');
      addTearDown(() => root.deleteSync(recursive: true));
      Directory('${root.path}/not-a-session').createSync(recursive: true);
      expect(
        () => SessionStore(root).delete('not-a-session'),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('two writers', () {
    test('the second is told who holds it rather than overwriting', () {
      final Directory root = Directory.systemTemp.createTempSync('mi-lock');
      addTearDown(() => root.deleteSync(recursive: true));
      final SessionStore store = SessionStore(root);
      final Session s = referenceSession();
      store.write(s);

      expect(store.lock(s.id, 'mi run pid 1'), isTrue);
      expect(
        store.lock(s.id, 'the app'),
        isFalse,
        reason:
            'Both writers hold a whole session in memory and write it out '
            'entire, so the second to finish would discard the first\'s '
            'rounds.',
      );
      expect(store.lockedBy(s.id), contains('pid 1'));
      store.unlock(s.id);
      expect(store.lock(s.id, 'the app'), isTrue);
    });
  });

  group('a session from another build', () {
    test('a newer stored shape is refused, not guessed at', () {
      final Directory root = Directory.systemTemp.createTempSync('mi-schema');
      addTearDown(() => root.deleteSync(recursive: true));
      final SessionStore store = SessionStore(root);
      final Session s = referenceSession();
      store.write(s);

      final File index = File('${root.path}/${s.id}/session.json');
      final Map<String, Object?> json =
          jsonDecode(index.readAsStringSync())! as Map<String, Object?>;
      index.writeAsStringSync(
        jsonEncode(<String, Object?>{...json, 'schema': Session.schema + 1}),
      );

      expect(
        () => store.read(s.id),
        throwsA(isA<StateError>()),
        reason:
            'Reading it anyway is guessing at fields whose meaning has '
            'changed under the same names.',
      );
    });

    test('a pitch removed from a session is removed from disk', () {
      final Directory root = Directory.systemTemp.createTempSync('mi-pitch');
      addTearDown(() => root.deleteSync(recursive: true));
      final SessionStore store = SessionStore(root);
      final Session s = referenceSession();
      store.write(s.copyWith(pitch: 'A pitch for a selection.'));
      expect(File('${root.path}/${s.id}/pitch.md').existsSync(), isTrue);

      store.write(s.copyWith(dropPitch: true));
      expect(
        File('${root.path}/${s.id}/pitch.md').existsSync(),
        isFalse,
        reason:
            'A launch document for a selection nobody has any more is worse '
            'than none, because it reads as current.',
      );
    });
  });
}
