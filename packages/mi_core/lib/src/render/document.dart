import 'package:meta/meta.dart';

/// What kind of thing a line in a rendered document is.
///
/// The kinds exist so that presentation cannot invent emphasis. Oxblood is
/// reserved for judgement, and the only way a client renders something in
/// oxblood is if it arrives as [BlockKind.verdict] or [BlockKind.dissent] —
/// so 'the accent is used only for verdicts' is a property of the document
/// model rather than a rule two platforms have to remember separately.
enum BlockKind {
  title,
  heading,
  subheading,

  /// A horizontal rule. Hierarchy comes from type, spacing and rules, never
  /// from cards, borders or shadows.
  rule,

  paragraph,

  /// A labelled line: the label is set small and quiet, the value is the text.
  field,

  /// A judgement. Rendered in the accent, in both clients, and nowhere else.
  verdict,

  /// A minority verdict, held rather than averaged.
  dissent,

  /// Where a direction came from.
  trace,

  /// An assumption the run made, marked so the client can cheaply overturn it.
  revisit,

  item,
}

@immutable
class DocBlock {
  const DocBlock(this.kind, this.text, {this.label = ''});

  final BlockKind kind;
  final String text;

  /// Shown before [text] for [BlockKind.field], [BlockKind.verdict] and
  /// [BlockKind.dissent] — the dimension being judged, or the name of the
  /// thing on the line.
  final String label;

  Map<String, Object?> toJson() => <String, Object?>{
    'kind': kind.name,
    if (label.isNotEmpty) 'label': label,
    'text': text,
  };
}

/// A rendered document: the dossier, the ledger, or the pitch as presented.
///
/// Pure over the stored session, which is what lets a completed session be
/// reopened with no API key, no network and no council — and what stops a
/// renderer that reaches back into the model from quietly becoming a second
/// implementation of the session, free to disagree with the files on disk.
@immutable
class MiDocument {
  const MiDocument(this.blocks);

  final List<DocBlock> blocks;

  List<DocBlock> ofKind(BlockKind k) =>
      blocks.where((DocBlock b) => b.kind == k).toList();

  /// Plain text, for headless inspection and for the evidence set.
  String toText() {
    final StringBuffer b = StringBuffer();
    for (final DocBlock block in blocks) {
      switch (block.kind) {
        case BlockKind.title:
          b
            ..writeln(block.text.toUpperCase())
            ..writeln('=' * block.text.length);
        case BlockKind.heading:
          b
            ..writeln()
            ..writeln(block.text.toUpperCase());
        case BlockKind.subheading:
          b
            ..writeln()
            ..writeln(block.text);
        case BlockKind.rule:
          b.writeln('-' * 72);
        case BlockKind.paragraph:
          b
            ..writeln(block.text)
            ..writeln();
        case BlockKind.field:
        case BlockKind.verdict:
        case BlockKind.dissent:
        case BlockKind.trace:
        case BlockKind.revisit:
          b.writeln(
            block.label.isEmpty
                ? block.text
                : '${block.label.padRight(16)}${block.text}',
          );
        case BlockKind.item:
          b.writeln('  ${block.text}');
      }
    }
    return b.toString();
  }
}
