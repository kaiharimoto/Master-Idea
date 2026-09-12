import 'package:meta/meta.dart';

import '../council/angles.dart';
import '../council/roles.dart';
import '../council/templates.dart';
import '../run/council_run.dart';
import '../session/manifest.dart';
import '../session/round.dart';
import '../session/session.dart';

/// A duration in words.
///
/// Here rather than in one renderer because two readers say how long a round
/// took — the exported ledger and the screen watching it happen — and two
/// spellings of the same forty minutes is the kind of difference nobody can
/// explain afterwards.
String spellDuration(Duration d) {
  if (d.inMinutes < 1) return 'under a minute';
  if (d.inHours < 1) return '${d.inMinutes} minutes';
  final int hours = d.inHours;
  final int minutes = d.inMinutes % 60;
  return minutes == 0
      ? '$hours hour${hours == 1 ? '' : 's'}'
      : '$hours hour${hours == 1 ? '' : 's'} $minutes minutes';
}

/// What one angle did in one round, in words rather than in ids.
@immutable
class AngleAccount {
  const AngleAccount({
    required this.angleId,
    required this.angleName,
    required this.modality,
    required this.by,
    required this.bySeat,
    required this.proposed,
    required this.kept,
    required this.exhausted,
    required this.unread,
  });

  /// Read one stored return.
  ///
  /// Both lookups are the forgiving kind on purpose. A session written by
  /// another build can name an angle this catalog no longer has and a seat
  /// whose id this one cannot parse, and a screen building a list of rounds
  /// must print what it was given rather than take every other session on the
  /// page down with it.
  factory AngleAccount.of(AngleReturn r) {
    final ExplorationAngle? angle = angleByIdOrNull(r.angleId);
    final AgentInstance? seat = AgentInstance.parseOrNull(r.by);
    final CouncilRole? role = seat == null ? null : roleByIdOrNull(seat.roleId);
    return AngleAccount(
      angleId: r.angleId,
      angleName: angle?.name ?? r.angleId,
      modality: angle?.modality ?? '',
      by: r.by,
      bySeat: role == null ? r.by : 'a ${role.name.toLowerCase()}',
      proposed: r.proposedIds.length,
      kept: r.keptIds.length,
      exhausted: r.exhausted,
      unread: r.unread.length,
    );
  }

  final String angleId;

  /// The catalog's name for it, or the raw id when this build has no such
  /// angle.
  final String angleName;

  /// The search this angle performs, in a few words. Empty when unknown.
  final String modality;

  /// The seat id exactly as the record holds it, because that is the record.
  final String by;

  /// The same seat as a person would say it: 'a prospector'.
  final String bySeat;

  final int proposed;
  final int kept;
  final bool exhausted;
  final int unread;

  bool get returnedNothingReadable => !exhausted && proposed == 0 && unread > 0;

  /// One line, for a list.
  String get line {
    if (exhausted) {
      return '$angleName — nothing left down this line.';
    }
    if (returnedNothingReadable) {
      return '$angleName — answered, and none of it could be read.';
    }
    if (proposed == 0) {
      return '$angleName — came back with nothing.';
    }
    return '$angleName — $kept kept of $proposed put forward.';
  }
}

/// One round, accounted for.
///
/// **One computation, two readers.** The coverage ledger and the sitting
/// screen both say what a round did, and two implementations of
/// 'put forward → refused → already held → kept' drift. An exported record and
/// a live screen disagreeing about the same round is worse than either of them
/// being absent.
///
/// Pure over the stored round and the manifest, so it is testable without
/// Flutter, without a process and without a council.
@immutable
class RoundAccount {
  const RoundAccount({
    required this.number,
    required this.angleNames,
    required this.angles,
    required this.breadth,
    required this.anglesReturned,
    required this.anglesExhausted,
    required this.unreadLines,
    required this.proposed,
    required this.refused,
    required this.duplicates,
    required this.kept,
    required this.gapsNamed,
    required this.took,
    required this.calls,
    required this.tokensOut,
    required this.inputAllIn,
  });

  factory RoundAccount.of(RoundRecord r, RunManifest m) {
    final List<AngleAccount> angles = <AngleAccount>[
      for (final AngleReturn a in r.returns) AngleAccount.of(a),
    ];
    final List<ModelCall> calls = m.callsIn(r.startedAt, r.endedAt);
    return RoundAccount(
      number: r.number,
      angleNames: <String>[
        for (final String id in r.angleSet) angleByIdOrNull(id)?.name ?? id,
      ],
      angles: angles,
      breadth: r.breadth,
      anglesReturned: angles.length,
      anglesExhausted: angles.where((AngleAccount a) => a.exhausted).length,
      unreadLines: angles.fold(0, (int n, AngleAccount a) => n + a.unread),
      proposed: angles.fold(0, (int n, AngleAccount a) => n + a.proposed),
      refused: r.refusals.length,
      duplicates: r.rejections.length,
      kept: r.newDirectionIds.length,
      gapsNamed: r.gapsNamed.length,
      took: r.endedAt.difference(r.startedAt),
      calls: calls.length,
      tokensOut: calls.fold(0, (int n, ModelCall c) => n + c.tokensOut),
      inputAllIn: calls.fold(0, (int n, ModelCall c) => n + c.inputAllIn),
    );
  }

  static List<RoundAccount> forSession(Session s) => <RoundAccount>[
    for (final RoundRecord r in s.rounds) RoundAccount.of(r, s.manifest),
  ];

  final int number;

  /// The angles seated, in seating order, named rather than identified.
  final List<String> angleNames;

  final List<AngleAccount> angles;
  final int breadth;
  final int anglesReturned;
  final int anglesExhausted;
  final int unreadLines;
  final int proposed;
  final int refused;
  final int duplicates;
  final int kept;
  final int gapsNamed;
  final Duration took;
  final int calls;
  final int tokensOut;
  final int inputAllIn;

  /// The only definition of 'new' this system has, restated for a reader.
  bool get returnedSomethingNew => kept > 0;

  /// Whether the cartographer sat at the end of this round.
  bool get drewTheMap => gapsNamed > 0;

  /// '48 put forward · 3 refused · 22 already held · 23 kept'
  String get funnel =>
      '$proposed put forward · $refused refused · $duplicates already held · '
      '$kept kept';

  /// 'eleven of twelve came back, one with nothing left'
  String get attendance {
    final String back = '$anglesReturned of $breadth came back';
    if (anglesExhausted == 0) return back;
    return '$back, $anglesExhausted with nothing left';
  }

  String get tookInWords => spellDuration(took);

  /// The whole round in one line, for a collapsed row or a log.
  String get line =>
      'Round $number: $breadth angles, $funnel'
      '${drewTheMap ? ', $gapsNamed gaps named' : ''}'
      '${unreadLines == 0 ? '' : ', $unreadLines lines unreadable'}'
      '${calls == 0 ? '' : ', $calls model calls'}.';
}

/// Two honest things to say about work not yet done.
///
/// **Both are floors, and there is deliberately no ceiling anywhere near
/// them.** Nothing here may say when a run ends, how far through it is, or
/// what fraction of anything is complete — decision 0003, restated at the one
/// place in this program where breaking it was tempting. A run ends when two
/// consecutive rounds keep nothing new, which is unknowable in advance, so the
/// only truthful statements are *the map is next drawn at round N* and *this
/// cannot end before round M*. Both of them say there is more work, never
/// less.
///
/// Read by the client's screen and by nothing inside [CouncilRun]. That must
/// stay true: an arithmetic the loop can see is an arithmetic the loop can be
/// made to obey, and then 'ran until the number' would be recorded as 'ran
/// dry'.
@immutable
class LowerBounds {
  const LowerBounds({
    required this.roundsClosed,
    required this.quietRoundsSoFar,
    required this.nextMapAtRound,
    required this.noEarlierThanRound,
    required this.mapFirstDrawnAtRound,
  });

  factory LowerBounds.forSession(Session s) {
    final HarnessTemplate t = s.template;
    final int closed = s.rounds.length;

    int quiet = 0;
    for (final RoundRecord r in s.rounds.reversed) {
      if (r.returnedSomethingNew) break;
      quiet++;
    }

    int next = closed + 1;
    while (!CouncilRun.mapsAfterRound(next, t)) {
      next++;
    }

    int? firstMap;
    for (final RoundRecord r in s.rounds) {
      if (r.gapsNamed.isNotEmpty) {
        firstMap = r.number;
        break;
      }
    }

    return LowerBounds(
      roundsClosed: closed,
      quietRoundsSoFar: quiet,
      nextMapAtRound: next,
      // Two quiet rounds end it, so what remains is two less the quiet ones
      // already on the record, and never less than the next round.
      noEarlierThanRound: closed + (quiet >= 2 ? 1 : 2 - quiet),
      mapFirstDrawnAtRound: firstMap,
    );
  }

  final int roundsClosed;

  /// How many of the stored rounds, at the end, kept nothing new.
  final int quietRoundsSoFar;

  final int nextMapAtRound;

  /// The earliest round at which the dryness rule could be satisfied.
  final int noEarlierThanRound;

  /// The round this session's map was first drawn in, or null when it never
  /// was. An older session ran its first rounds without one and should say so
  /// rather than look like a fresh one that had a map all along.
  final int? mapFirstDrawnAtRound;

  /// What the map is for, said once, where the number appears.
  String get mapSentence =>
      'The cartographer writes down what ground the council has entered, what '
      'it has deliberately left, and what nobody has reached yet. A direction '
      'can point at one of those gaps instead of at something you said in the '
      'interview.';

  /// The rule that ends a sitting, stated as the floor it implies.
  String get endSentence {
    if (roundsClosed == 0) {
      return 'A sitting ends when two rounds in a row keep nothing new, so it '
          'always runs at least two rounds past its last find. Nothing here '
          'knows when that will be.';
    }
    if (quietRoundsSoFar == 0) {
      return 'Round $roundsClosed kept something, so two more rounds have to '
          'keep nothing before this can end. That is a floor on the work left, '
          'not an estimate of when it finishes.';
    }
    if (quietRoundsSoFar == 1) {
      return 'Round $roundsClosed kept nothing. One more round like it ends '
          'the sitting; anything it keeps starts the count again.';
    }
    return 'Two rounds in a row kept nothing, which is what ends a sitting.';
  }
}
