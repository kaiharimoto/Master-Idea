import 'package:meta/meta.dart';

import '../council/dimensions.dart';
import '../council/roles.dart';
import '../interview/interview_gate.dart';
import '../session/direction.dart';
import '../session/ledger.dart';
import '../session/manifest.dart';
import '../session/rating.dart';
import '../session/round.dart';
import '../session/session.dart';

/// The three properties a session is worthless without.
enum Invariant {
  /// Every direction links to a specific interview answer or a named gap
  /// written in an earlier round. Nothing is unsourced.
  traceability,

  /// No direction is rated by the agent that proposed it, no rater was shown
  /// the proposer's identity or advocacy, and dissent is held rather than
  /// averaged away.
  independentRating,

  /// The run ended only because two consecutive rounds at the same breadth
  /// returned nothing new, and everything dropped was logged with a reason.
  runUntilDry,
}

/// One way a session fails.
@immutable
class InvariantFinding {
  const InvariantFinding(this.invariant, this.detail, {this.subject = ''});

  final Invariant invariant;

  /// What is wrong, specifically enough to find it in the stored files.
  final String detail;

  /// The direction, rating or round it is wrong about.
  final String subject;

  @override
  String toString() => subject.isEmpty
      ? '${invariant.name}: $detail'
      : '${invariant.name} [$subject]: $detail';
}

@immutable
class InvariantReport {
  const InvariantReport(this.sessionId, this.findings);

  final String sessionId;
  final List<InvariantFinding> findings;

  /// Binary on purpose. An invariant that holds most of the time is not an
  /// invariant, so there is no partial credit and no severity ladder here.
  bool get holds => findings.isEmpty;

  bool holdsFor(Invariant i) =>
      findings.every((InvariantFinding f) => f.invariant != i);

  List<InvariantFinding> forInvariant(Invariant i) =>
      findings.where((InvariantFinding f) => f.invariant == i).toList();

  String get summary {
    if (holds) return 'All three invariants hold for $sessionId.';
    final StringBuffer b = StringBuffer('$sessionId FAILS:\n');
    for (final InvariantFinding f in findings) {
      b.writeln('  $f');
    }
    return b.toString();
  }
}

/// The self-test suite.
///
/// Runs against a stored session and nothing else — no council, no network, no
/// build history — because the point of these three properties is that they
/// are checkable next month rather than only on the day the run finished. Every
/// check below is written so that breaking the invariant in a stored file makes
/// it fail; `invariants_test.dart` proves that by breaking each one in turn.
abstract final class InvariantSuite {
  static InvariantReport run(Session s) =>
      InvariantReport(s.id, <InvariantFinding>[
        ..._traceability(s),
        ..._independentRating(s),
        ..._runUntilDry(s),
      ]);

  // ---- Traceability -----------------------------------------------------

  static List<InvariantFinding> _traceability(Session s) {
    final List<InvariantFinding> out = <InvariantFinding>[];
    final Map<String, List<Direction>> byAnswer = <String, List<Direction>>{};

    for (final Direction d in s.directions) {
      final TraceLink t = d.trace;
      if (!t.isSourced) {
        out.add(
          InvariantFinding(
            Invariant.traceability,
            'Traced to neither an interview answer nor a ledger gap.',
            subject: d.id,
          ),
        );
        continue;
      }
      if (t.quote.trim().isEmpty) {
        out.add(
          InvariantFinding(
            Invariant.traceability,
            'Cites a source with no quoted phrase, so the link cannot be '
            'checked against what was actually said.',
            subject: d.id,
          ),
        );
      }
      final String? answerId = t.answerModuleId;
      if (answerId != null) {
        if (s.interview.answerFor(answerId) == null) {
          out.add(
            InvariantFinding(
              Invariant.traceability,
              'Cites interview answer "$answerId", which is not in the '
              'frozen interview record.',
              subject: d.id,
            ),
          );
        } else {
          byAnswer.putIfAbsent(answerId, () => <Direction>[]).add(d);
        }
      }
      final String? gapId = t.gapId;
      if (gapId != null) {
        final Territory? territory = s.ledger.byId(gapId);
        if (territory == null) {
          out.add(
            InvariantFinding(
              Invariant.traceability,
              'Cites ledger territory "$gapId", which is not on the map.',
              subject: d.id,
            ),
          );
        } else if (territory.firstWrittenInRound >= d.round) {
          out.add(
            InvariantFinding(
              Invariant.traceability,
              'Cites gap "$gapId" first written in round '
              '${territory.firstWrittenInRound}, which is not earlier than '
              'the direction\'s own round ${d.round}. A gap written to '
              'justify a direction is not a source.',
              subject: d.id,
            ),
          );
        }
      }
    }

    // Several directions hanging off one answer is how a single sentence from
    // the client gets used to source a whole afternoon of output. Sharing an
    // answer is legitimate only when each direction also names its own gap —
    // a different question about the same material — and the gaps must differ
    // from each other, or the second citation is decoration.
    byAnswer.forEach((String answerId, List<Direction> ds) {
      if (ds.length < 2) return;
      final Map<String, int> gapUse = <String, int>{};
      for (final Direction d in ds) {
        final String? gap = d.trace.gapId;
        if (gap != null) gapUse[gap] = (gapUse[gap] ?? 0) + 1;
      }
      for (final Direction d in ds) {
        final String? gap = d.trace.gapId;
        if (gap == null) {
          out.add(
            InvariantFinding(
              Invariant.traceability,
              'Shares interview answer "$answerId" with '
              '${ds.length - 1} other direction(s) and names no ledger gap of '
              'its own.',
              subject: d.id,
            ),
          );
        } else if ((gapUse[gap] ?? 0) > 1) {
          out.add(
            InvariantFinding(
              Invariant.traceability,
              'Shares both interview answer "$answerId" and ledger gap '
              '"$gap" with another direction, so nothing distinguishes what '
              'the two were generated to answer.',
              subject: d.id,
            ),
          );
        }
      }
    });

    for (final Assumption a in s.assumptions) {
      final String? unknownId = a.answersUnknownId;
      if (unknownId != null &&
          !s.interview.unknowns.any((DeclaredUnknown u) => u.id == unknownId)) {
        out.add(
          InvariantFinding(
            Invariant.traceability,
            'Cites declared unknown "$unknownId", which the client never '
            'declared.',
            subject: a.id,
          ),
        );
      }
      for (final String id in a.affects) {
        if (s.directionById(id) == null) {
          out.add(
            InvariantFinding(
              Invariant.traceability,
              'Marked as load-bearing for direction "$id", which is not in '
              'this session.',
              subject: a.id,
            ),
          );
        }
      }
    }

    return out;
  }

  // ---- Independent rating ------------------------------------------------

  static List<InvariantFinding> _independentRating(Session s) {
    final List<InvariantFinding> out = <InvariantFinding>[];

    for (final Direction d in s.directions) {
      if (s.ratingsFor(d.id).isEmpty) {
        out.add(
          InvariantFinding(
            Invariant.independentRating,
            'Entered the dossier with no rating from anyone.',
            subject: d.id,
          ),
        );
      }
    }

    for (final Rating r in s.ratings) {
      final Direction? d = s.directionById(r.directionId);
      final String subject = '${r.directionId}/${r.dimensionId}';
      if (d == null) {
        out.add(
          InvariantFinding(
            Invariant.independentRating,
            'Rates a direction that is not in this session.',
            subject: subject,
          ),
        );
        continue;
      }

      if (r.ratedBy == d.proposedBy) {
        out.add(
          InvariantFinding(
            Invariant.independentRating,
            'Rated by ${r.ratedBy}, which is the agent instance that '
            'proposed it.',
            subject: subject,
          ),
        );
      }

      // Guarded rather than trusted. This suite's job is to catch a session
      // that has been tampered with or written by something else, and a check
      // that throws on the malformed input it exists to detect reports
      // nothing at all — it crashes the tool instead of failing the session.
      final CouncilRole? raterRole = _roleOf(r.ratedBy);
      if (raterRole == null) {
        out.add(
          InvariantFinding(
            Invariant.independentRating,
            'Rated by "${r.ratedBy}", which does not name a seat this council '
            'could have seated.',
            subject: subject,
          ),
        );
      } else if (raterRole.can(CouncilLicence.propose)) {
        out.add(
          InvariantFinding(
            Invariant.independentRating,
            'Rated by ${r.ratedBy}, a seat licensed to propose. A seat that '
            'can advocate may not judge.',
            subject: subject,
          ),
        );
      }

      if (r.context.carriedProposerIdentity || r.context.carriedAdvocacy) {
        out.add(
          InvariantFinding(
            Invariant.independentRating,
            'The rater was given the proposer\'s identity or their case for '
            'the direction.',
            subject: subject,
          ),
        );
      }
      if (r.context.shownText.contains(d.proposedBy)) {
        out.add(
          InvariantFinding(
            Invariant.independentRating,
            'The context the rater was shown names the proposer '
            '(${d.proposedBy}).',
            subject: subject,
          ),
        );
      }

      final RatingDimension? dim = _dimensionOrNull(r.dimensionId);
      if (dim == null) {
        out.add(
          InvariantFinding(
            Invariant.independentRating,
            'Rated on dimension "${r.dimensionId}", which is not in the '
            'catalog.',
            subject: subject,
          ),
        );
        continue;
      }
      if (dim.vocabulary.id != r.vocabularyId) {
        out.add(
          InvariantFinding(
            Invariant.independentRating,
            'Names vocabulary "${r.vocabularyId}" where dimension '
            '"${dim.id}" draws from "${dim.vocabulary.id}".',
            subject: subject,
          ),
        );
      }
      if (!dim.vocabulary.contains(r.verdict)) {
        out.add(
          InvariantFinding(
            Invariant.independentRating,
            'Verdict "${r.verdict}" is not a rung of '
            '${dim.vocabulary.id}.',
            subject: subject,
          ),
        );
      }
      if (RegExp(r'[0-9]').hasMatch(r.verdict)) {
        out.add(
          InvariantFinding(
            Invariant.independentRating,
            'Verdict "${r.verdict}" contains a numeral. Ratings are ordinal '
            'words, so that they cannot be averaged.',
            subject: subject,
          ),
        );
      }

      for (final Dissent dis in r.dissents) {
        if (dis.by == r.ratedBy) {
          out.add(
            InvariantFinding(
              Invariant.independentRating,
              'Dissent recorded against a verdict by the same seat that gave '
              'it, which is a revision rather than a dissent.',
              subject: subject,
            ),
          );
        }
        if (dis.by == d.proposedBy) {
          out.add(
            InvariantFinding(
              Invariant.independentRating,
              'Dissent held by the direction\'s own proposer.',
              subject: subject,
            ),
          );
        }
        if (!dim.vocabulary.contains(dis.verdict)) {
          out.add(
            InvariantFinding(
              Invariant.independentRating,
              'Dissenting verdict "${dis.verdict}" is not a rung of '
              '${dim.vocabulary.id}.',
              subject: subject,
            ),
          );
        }
        if (dis.verdict == r.verdict) {
          out.add(
            InvariantFinding(
              Invariant.independentRating,
              'Dissent records the same verdict it dissents from, which is '
              'dissent manufactured to look rigorous.',
              subject: subject,
            ),
          );
        }
        if (dis.because.trim().isEmpty) {
          out.add(
            InvariantFinding(
              Invariant.independentRating,
              'Dissent recorded with no reason, so nothing was actually held.',
              subject: subject,
            ),
          );
        }
      }
    }

    return out;
  }

  static RatingDimension? _dimensionOrNull(String id) {
    for (final RatingDimension d in ratingDimensions) {
      if (d.id == id) return d;
    }
    return null;
  }

  // ---- Run until dry -----------------------------------------------------

  static List<InvariantFinding> _runUntilDry(Session s) {
    final List<InvariantFinding> out = <InvariantFinding>[];
    final DrynessDecision? dry = s.manifest.dryness;

    for (final Territory t in s.ledger.dropped) {
      if (t.reason.trim().isEmpty) {
        out.add(
          InvariantFinding(
            Invariant.runUntilDry,
            'Territory dropped with no reason recorded, which is silent '
            'truncation wearing a label.',
            subject: t.id,
          ),
        );
      }
    }

    if (dry == null) {
      out.add(
        const InvariantFinding(
          Invariant.runUntilDry,
          'The run has no dryness decision, so nothing says why it stopped.',
        ),
      );
      return out;
    }

    if (dry.secondRound != dry.firstRound + 1) {
      out.add(
        InvariantFinding(
          Invariant.runUntilDry,
          'Deciding rounds ${dry.firstRound} and ${dry.secondRound} are not '
          'consecutive.',
        ),
      );
    }

    if (dry.secondAngleSet.length < dry.firstAngleSet.length) {
      out.add(
        InvariantFinding(
          Invariant.runUntilDry,
          'The deciding round searched ${dry.secondAngleSet.length} angles '
          'where the round before it searched ${dry.firstAngleSet.length}. '
          'Dryness found by looking less hard is a timer with better manners.',
        ),
      );
    }

    for (final int number in <int>[dry.firstRound, dry.secondRound]) {
      final RoundRecord? r = _round(s, number);
      if (r == null) {
        out.add(
          InvariantFinding(
            Invariant.runUntilDry,
            'Deciding round $number has no stored record.',
          ),
        );
        continue;
      }
      if (r.returnedSomethingNew) {
        out.add(
          InvariantFinding(
            Invariant.runUntilDry,
            'Round $number is named as deciding but returned '
            '${r.newDirectionIds.length} new direction(s).',
          ),
        );
      }
    }

    final int last = s.rounds.isEmpty ? 0 : s.rounds.last.number;
    if (last > dry.secondRound) {
      out.add(
        InvariantFinding(
          Invariant.runUntilDry,
          'Round $last was run after the run was declared dry at round '
          '${dry.secondRound}. A run continued past dryness to reach a floor '
          'is padding.',
        ),
      );
    }

    // A pause is the provider stopping the council, and a council that was
    // stopped did not fall silent. Any pause overlapping the deciding rounds
    // makes the dryness unsafe.
    for (final int number in <int>[dry.firstRound, dry.secondRound]) {
      final RoundRecord? r = _round(s, number);
      if (r == null) continue;
      for (final LimitPause p in s.manifest.pauses) {
        final bool overlaps =
            p.from.isBefore(r.endedAt) && p.until.isAfter(r.startedAt);
        if (overlaps) {
          out.add(
            InvariantFinding(
              Invariant.runUntilDry,
              'A ${p.kind} limit paused the council during deciding round '
              '$number, so the silence that ended this run was the '
              'provider\'s and not the council\'s.',
            ),
          );
        }
      }
    }

    if (dry.wentDryBelowFloor &&
        s.manifest.templateId == s.interview.verdict.templateId &&
        s.template.tier > 0) {
      out.add(
        InvariantFinding(
          Invariant.runUntilDry,
          'Went dry at ${dry.directionCount} directions against a floor of '
          '${dry.floorAtTier} and was left at tier '
          '"${s.manifest.templateId}". A run that goes dry below its floor is '
          're-tiered downward, never continued to reach the number.',
        ),
      );
    }

    return out;
  }

  /// The role behind a seat id, or null when the id is not one this council
  /// could have issued.
  static CouncilRole? _roleOf(String agentId) {
    try {
      return AgentInstance.parse(agentId).role;
    } on Object {
      return null;
    }
  }

  static RoundRecord? _round(Session s, int number) {
    for (final RoundRecord r in s.rounds) {
      if (r.number == number) return r;
    }
    return null;
  }
}
