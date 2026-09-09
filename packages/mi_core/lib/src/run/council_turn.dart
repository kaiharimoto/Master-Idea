import 'package:meta/meta.dart';

import '../council/roles.dart';

/// One request to the model, addressed from one seat.
@immutable
class CouncilTurn {
  const CouncilTurn({
    required this.agent,
    required this.purpose,
    required this.prompt,
    required this.conversation,
  });

  final AgentInstance agent;

  /// `propose`, `challenge`, `rate`, `dissent`, `map`, `integrate`, `pitch`.
  final String purpose;

  final String prompt;

  /// Which conversation this turn belongs to.
  ///
  /// Seats do not share one chat. An assessor whose conversation carried the
  /// prospector's case for a direction is rating the advocacy, which is the
  /// independent-rating invariant broken by transport rather than by code —
  /// so every rating turn opens in a conversation of its own.
  final String conversation;
}

/// What came back.
@immutable
class CouncilReply {
  const CouncilReply({
    required this.text,
    this.tokensIn = 0,
    this.tokensOut = 0,
  });

  final String text;
  final int tokensIn;
  final int tokensOut;
}

/// Raised when the provider stops the council rather than the council
/// stopping itself.
///
/// Carried as an exception rather than an empty reply because the two must
/// never be confused: an empty reply is a round returning nothing, which is
/// evidence of dryness, and a rate limit is the opposite of evidence.
class CouncilPaused implements Exception {
  CouncilPaused(this.kind, this.detail, this.until);

  /// `rate` or `session`.
  final String kind;
  final String detail;
  final DateTime until;

  @override
  String toString() => 'CouncilPaused($kind, until $until): $detail';
}

/// How the run reaches a model. One method, so a scripted double and the real
/// CLI are interchangeable and every test that exercises the run exercises the
/// same code the real transport does.
abstract interface class CouncilTransport {
  Future<CouncilReply> ask(CouncilTurn turn);
}

/// A block the council wrote, read back as fields.
///
/// The wire format is **line-oriented, never JSON**, for the same reason
/// Master Prompt keeps its heartbeat line-oriented: these blocks are written
/// mid-run by a model that may be cut off at any character, and a truncated
/// JSON object loses the whole block where a truncated line grammar loses one
/// field. A round that returns nine good directions and one half-written one
/// should keep the nine.
@immutable
class CouncilBlock {
  const CouncilBlock(this.kind, this.fields);

  final String kind;
  final Map<String, String> fields;

  String get(String key, {String fallback = ''}) => fields[key] ?? fallback;

  bool has(String key) => (fields[key] ?? '').trim().isNotEmpty;

  /// Fields that may legitimately repeat, such as an integration's several
  /// `reinforces` lines, are kept newline-joined by the parser.
  List<String> all(String key) => has(key)
      ? get(key).split('\n').where((String s) => s.trim().isNotEmpty).toList()
      : const <String>[];
}

/// What one reply added up to, including what could not be read.
@immutable
class ParsedReply {
  const ParsedReply({
    required this.blocks,
    required this.unread,
    required this.raw,
  });

  final List<CouncilBlock> blocks;

  /// Lines inside a block that the parser could not use. Kept rather than
  /// dropped: a misread that disappears silently is indistinguishable from a
  /// council that had nothing to say.
  final List<String> unread;

  /// The reply exactly as it arrived. A reply is never discarded, whatever the
  /// parse found, so a session can always be audited against what was said.
  final String raw;

  List<CouncilBlock> of(String kind) =>
      blocks.where((CouncilBlock b) => b.kind == kind).toList();

  bool get foundNothing => blocks.isEmpty;
}

/// Reads the council's line grammar.
///
/// A block opens with its kind on a line of its own and closes with `end`:
///
/// ```
/// mi-direction
/// cluster=What the thing is for
/// ambition=reckless
/// title=Sell the archive, keep the index
/// statement=...
/// mechanism=...
/// trace-answer=ceiling
/// quote=...
/// end
/// ```
///
/// Tolerant on the way in, because a real reply arrives wrapped in prose,
/// sometimes fenced, sometimes bulleted, and refusing it costs a model call
/// that has already been paid for. Strict about what it will claim to have
/// read: an unknown line inside a block goes to [ParsedReply.unread] rather
/// than being guessed at.
abstract final class CouncilReplyParser {
  static const List<String> knownKinds = <String>[
    'mi-direction',
    'mi-rating',
    'mi-dissent',
    'mi-challenge',
    'mi-territory',
    'mi-integration',
    'mi-assumption',
    'mi-none',
  ];

  static ParsedReply parse(String reply) {
    final List<CouncilBlock> blocks = <CouncilBlock>[];
    final List<String> unread = <String>[];

    String? kind;
    Map<String, String>? fields;
    String? lastKey;

    for (String line in reply.split('\n')) {
      line = line.trimRight();
      final String bare = _strip(line);

      // A standalone marker, not a block with fields. Read as its own answer
      // because 'my angle is exhausted' is the single most consequential thing
      // a seat can say — it is what takes a run to dryness.
      if (bare == 'mi-none') {
        if (kind != null) {
          blocks.add(CouncilBlock(kind, fields!));
          kind = null;
          fields = null;
          lastKey = null;
        }
        blocks.add(const CouncilBlock('mi-none', <String, String>{}));
        continue;
      }

      if (kind == null) {
        if (knownKinds.contains(bare)) {
          kind = bare;
          fields = <String, String>{};
          lastKey = null;
        }
        continue;
      }

      if (bare == 'end') {
        blocks.add(CouncilBlock(kind, fields!));
        kind = null;
        fields = null;
        lastKey = null;
        continue;
      }

      // A new block opening without its predecessor closing. Keep what was
      // gathered: a missing `end` is the commonest way a reply is truncated,
      // and throwing the block away turns one lost line into a lost direction.
      if (knownKinds.contains(bare)) {
        blocks.add(CouncilBlock(kind, fields!));
        kind = bare;
        fields = <String, String>{};
        lastKey = null;
        continue;
      }

      if (bare.trim().isEmpty) continue;

      final int eq = bare.indexOf('=');
      if (eq > 0) {
        final String key = bare.substring(0, eq).trim().toLowerCase();
        final String value = bare.substring(eq + 1).trim();
        if (key.contains(' ')) {
          // Prose containing an equals sign, not a field.
          if (lastKey != null) {
            fields![lastKey] = '${fields[lastKey]}\n$bare'.trim();
          } else {
            unread.add(line);
          }
          continue;
        }
        fields![key] = fields.containsKey(key) && _repeatable.contains(key)
            ? '${fields[key]}\n$value'
            : value;
        lastKey = key;
        continue;
      }

      // A continuation line of the field above — a mechanism that ran to two
      // paragraphs, which is the good case rather than the broken one.
      if (lastKey != null) {
        fields![lastKey] = '${fields[lastKey]}\n$bare'.trim();
      } else {
        unread.add(line);
      }
    }

    if (kind != null && fields != null && fields.isNotEmpty) {
      blocks.add(CouncilBlock(kind, fields));
    }

    return ParsedReply(blocks: blocks, unread: unread, raw: reply);
  }

  static const Set<String> _repeatable = <String>{'reinforces', 'conflicts'};

  /// Remove the decoration a real reply arrives wearing: fences, bullets,
  /// numbering, and the bold markers a model reaches for when it is being
  /// helpful.
  static String _strip(String line) {
    String s = line.trim();
    if (s.startsWith('```')) s = s.substring(3).trim();
    s = s.replaceFirst(RegExp(r'^[-*]\s+'), '');
    s = s.replaceFirst(RegExp(r'^\d+[.)]\s+'), '');
    s = s.replaceAll('**', '');
    return s;
  }
}
