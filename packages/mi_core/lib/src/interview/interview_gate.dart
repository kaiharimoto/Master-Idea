import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:meta/meta.dart';

import '../council/templates.dart';
import 'modules.dart';

/// One answer, stored exactly as the client gave it.
///
/// Verbatim is not a nicety. Every direction in the dossier traces back to one
/// of these, and a paraphrase stored here would make the traceability link
/// point at the tool's own words — which is precisely the failure the link
/// exists to prevent.
@immutable
class InterviewAnswer {
  const InterviewAnswer({
    required this.moduleId,
    required this.question,
    required this.text,
    required this.at,
  });

  /// Answers are one per module, so the module id is the answer id and a
  /// traceability link is readable without a lookup table.
  final String moduleId;

  /// The question exactly as it was put, so an answer read a year later is
  /// still an answer to something.
  final String question;

  final String text;
  final DateTime at;

  Map<String, Object?> toJson() => <String, Object?>{
    'moduleId': moduleId,
    'question': question,
    'text': text,
    'at': at.toIso8601String(),
  };

  static InterviewAnswer fromJson(Map<String, Object?> j) => InterviewAnswer(
    moduleId: '${j['moduleId']}',
    question: '${j['question']}',
    text: '${j['text']}',
    at: DateTime.parse('${j['at']}'),
  );
}

/// Something the client does not know and has licensed the run to settle.
///
/// This is the run's authority to proceed in the client's absence. An
/// assumption made against one of these is legitimate and marked; an
/// assumption made outside them is still marked, but it is a finding rather
/// than a licence being exercised.
@immutable
class DeclaredUnknown {
  const DeclaredUnknown({
    required this.id,
    required this.question,
    required this.licence,
  });

  final String id;

  /// What is not known.
  final String question;

  /// What the run is permitted to do about it — the client's own words where
  /// they gave them.
  final String licence;

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'question': question,
    'licence': licence,
  };

  static DeclaredUnknown fromJson(Map<String, Object?> j) => DeclaredUnknown(
    id: '${j['id']}',
    question: '${j['question']}',
    licence: '${j['licence']}',
  );
}

/// The interview's judgement of how much run the idea warrants.
///
/// Made by the model from the vision, not chosen by the client from a menu:
/// asked directly, everyone picks the longest one, and a six-hour run on a
/// postcard produces a hundred directions about a postcard.
@immutable
class ScaleVerdict {
  const ScaleVerdict({required this.templateId, required this.reasoning});

  final String templateId;

  /// Why this tier and not the one above or below. Written into the dossier,
  /// because a tier the client disagrees with is worth arguing about before
  /// the run rather than after.
  final String reasoning;

  HarnessTemplate get template => templateById(templateId);

  Map<String, Object?> toJson() => <String, Object?>{
    'templateId': templateId,
    'reasoning': reasoning,
  };

  static ScaleVerdict fromJson(Map<String, Object?> j) => ScaleVerdict(
    templateId: '${j['templateId']}',
    reasoning: '${j['reasoning']}',
  );
}

/// The tool's restatement of the idea, approved verbatim by the client.
///
/// Constitution for the run: nothing the council produces may contradict it,
/// and the fidelity dimension exists to catch anything that tries. It is the
/// client's approval that makes it constitutional, so [approvedAt] is not
/// decoration — an unapproved restatement is just the tool talking to itself.
@immutable
class ConfirmedBrief {
  const ConfirmedBrief({required this.restatement, required this.approvedAt});

  final String restatement;
  final DateTime approvedAt;

  /// Stable hash of the approved text. Stored with the session so a later
  /// audit can tell whether the constitution a run was judged against is the
  /// one the client actually signed.
  String get hash =>
      sha256.convert(utf8.encode(restatement)).toString().substring(0, 16);

  Map<String, Object?> toJson() => <String, Object?>{
    'restatement': restatement,
    'approvedAt': approvedAt.toIso8601String(),
    'hash': hash,
  };

  static ConfirmedBrief fromJson(Map<String, Object?> j) => ConfirmedBrief(
    restatement: '${j['restatement']}',
    approvedAt: DateTime.parse('${j['approvedAt']}'),
  );
}

/// Everything the single authorised interview produced, frozen.
///
/// The gate closes once and does not reopen. No answer may be re-elicited
/// afterwards — not because re-asking would be unhelpful, but because the run
/// is unattended by design and a tool that can ask again will, at hour three,
/// to a room with nobody in it.
@immutable
class InterviewRecord {
  const InterviewRecord({
    required this.profileId,
    required this.moduleOrder,
    required this.answers,
    required this.brief,
    required this.unknowns,
    required this.verdict,
    required this.closedAt,
  });

  final String profileId;

  /// The modules used, in the order they were put. Stored so a session can be
  /// audited for whether the interview was composed or improvised.
  final List<String> moduleOrder;

  final List<InterviewAnswer> answers;
  final ConfirmedBrief brief;
  final List<DeclaredUnknown> unknowns;
  final ScaleVerdict verdict;
  final DateTime closedAt;

  InterviewAnswer? answerFor(String moduleId) {
    for (final InterviewAnswer a in answers) {
      if (a.moduleId == moduleId) return a;
    }
    return null;
  }

  /// Whether every module that was put has an answer stored. A module asked
  /// and unanswered is a hole in the constitution that nothing downstream can
  /// fill, so the gate refuses to close over one.
  List<String> get unanswered => <String>[
    for (final String id in moduleOrder)
      if (answerFor(id) == null) id,
  ];

  /// Parts of the brief this interview produced nothing for.
  Set<BriefPart> get unservedParts => InterviewComposer.unservedParts(
    <InterviewModule>[for (final String id in moduleOrder) moduleById(id)],
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'profileId': profileId,
    'moduleOrder': moduleOrder,
    'answers': answers.map((InterviewAnswer a) => a.toJson()).toList(),
    'brief': brief.toJson(),
    'unknowns': unknowns.map((DeclaredUnknown u) => u.toJson()).toList(),
    'verdict': verdict.toJson(),
    'closedAt': closedAt.toIso8601String(),
  };

  static InterviewRecord fromJson(Map<String, Object?> j) => InterviewRecord(
    profileId: '${j['profileId']}',
    moduleOrder: (j['moduleOrder']! as List<Object?>)
        .map((Object? e) => '$e')
        .toList(),
    answers: (j['answers']! as List<Object?>)
        .map(
          (Object? e) => InterviewAnswer.fromJson(e! as Map<String, Object?>),
        )
        .toList(),
    brief: ConfirmedBrief.fromJson(j['brief']! as Map<String, Object?>),
    unknowns: (j['unknowns']! as List<Object?>)
        .map(
          (Object? e) => DeclaredUnknown.fromJson(e! as Map<String, Object?>),
        )
        .toList(),
    verdict: ScaleVerdict.fromJson(j['verdict']! as Map<String, Object?>),
    closedAt: DateTime.parse('${j['closedAt']}'),
  );
}

/// Why an interview may not be closed yet.
@immutable
class GateRefusal {
  const GateRefusal(this.reason);
  final String reason;
  @override
  String toString() => reason;
}

/// The single authorised gate between the client and the run.
abstract final class InterviewGate {
  /// Everything standing between this interview and a run that can proceed
  /// unattended.
  ///
  /// Returns the refusals rather than throwing on the first, because a client
  /// being told one missing thing at a time is a client being interviewed
  /// three more times.
  static List<GateRefusal> refusals(InterviewRecord record) {
    final List<GateRefusal> out = <GateRefusal>[];
    for (final String id in record.unanswered) {
      out.add(GateRefusal('Module "$id" was put and never answered.'));
    }
    for (final BriefPart p in record.unservedParts) {
      out.add(
        GateRefusal(
          'Nothing in this interview produces the brief\'s ${p.name} part.',
        ),
      );
    }
    if (record.brief.restatement.trim().isEmpty) {
      out.add(const GateRefusal('The confirmed brief is empty.'));
    }
    if (record.unknowns.isEmpty) {
      out.add(
        const GateRefusal(
          'No unknowns were declared, so the run has no licence to settle '
          'anything on its own and will stall the first time it needs to.',
        ),
      );
    }
    return out;
  }

  static bool canOpenRun(InterviewRecord record) => refusals(record).isEmpty;
}
