import 'package:flutter/material.dart';
import 'package:mi_core/mi_core.dart';
import 'package:mi_design/mi_design.dart';

/// Renders a document the core produced.
///
/// **One renderer, both clients.** The dossier, the coverage ledger and the
/// pitch all arrive here as an `MiDocument` — a list of typed blocks read out
/// of the stored session — so neither platform decides for itself what a
/// verdict looks like. Parity is a property of there being one of these rather
/// than a promise anyone has to keep.
///
/// It is also what keeps the accent honest. A verdict block is the only thing
/// that reaches `MiVerdict`, which is the only widget that paints oxblood, so
/// judgement is the loudest thing on the page and nothing else can be.
class DocumentView extends StatelessWidget {
  const DocumentView(this.document, {this.padding, super.key});

  final MiDocument document;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    final MiColors c = MiTheme.colorsOf(context);
    return ListView.builder(
      padding:
          padding ??
          const EdgeInsets.fromLTRB(
            MiSpace.lg,
            MiSpace.lg,
            MiSpace.lg,
            MiSpace.xxxl,
          ),
      itemCount: document.blocks.length,
      itemBuilder: (BuildContext context, int i) =>
          _block(context, c, document.blocks[i]),
    );
  }

  Widget _block(BuildContext context, MiColors c, DocBlock b) {
    switch (b.kind) {
      case BlockKind.title:
        return Padding(
          padding: const EdgeInsets.only(bottom: MiSpace.sm),
          child: Text(b.text, style: MiType.display.copyWith(color: c.ink)),
        );
      case BlockKind.heading:
        return Padding(
          padding: const EdgeInsets.only(top: MiSpace.xl, bottom: MiSpace.sm),
          child: MiEyebrow(b.text),
        );
      case BlockKind.subheading:
        return Padding(
          padding: const EdgeInsets.only(top: MiSpace.lg, bottom: MiSpace.xs),
          child: Text(b.text, style: MiType.title.copyWith(color: c.ink)),
        );
      case BlockKind.rule:
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: MiSpace.lg),
          child: MiRule(strong: true),
        );
      case BlockKind.paragraph:
        return Padding(
          padding: const EdgeInsets.only(bottom: MiSpace.md),
          child: Text(b.text, style: MiType.prose.copyWith(color: c.ink)),
        );
      case BlockKind.field:
        return MiRecord(label: b.label, value: b.text);
      case BlockKind.verdict:
        return _verdict(b, dissenting: false);
      case BlockKind.dissent:
        return _verdict(b, dissenting: true);
      case BlockKind.trace:
        return MiRecord(
          label: b.label.isEmpty ? 'Traced to' : b.label,
          value: b.text,
          tone: c.inkMuted,
          style: MiType.caption,
        );
      case BlockKind.revisit:
        // A marked revisit point: an assumption the run made while nobody was
        // watching. Set apart by a rule down its left edge rather than by a
        // colour, because the only colour here belongs to judgement.
        return Container(
          margin: const EdgeInsets.symmetric(vertical: MiSpace.sm),
          padding: const EdgeInsets.only(left: MiSpace.md),
          decoration: Border(
            left: BorderSide(color: c.lineStrong, width: 2),
          ).toBoxDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              MiEyebrow(b.label.isEmpty ? 'Revisit' : b.label),
              const SizedBox(height: 2),
              Text(b.text, style: MiType.body.copyWith(color: c.ink)),
            ],
          ),
        );
      case BlockKind.item:
        return Padding(
          padding: const EdgeInsets.only(bottom: MiSpace.xs),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('·  ', style: MiType.body.copyWith(color: c.inkFaint)),
              Expanded(
                child: Text(b.text, style: MiType.body.copyWith(color: c.ink)),
              ),
            ],
          ),
        );
    }
  }

  /// A verdict block, split back into its parts.
  ///
  /// The core writes one line — `verdict — reason (seat, vocabulary)` — because
  /// a document has to be readable as text for the evidence set. Here it is
  /// taken apart again so the verdict word can carry the accent on its own.
  Widget _verdict(DocBlock b, {required bool dissenting}) {
    final int dash = b.text.indexOf(' — ');
    final String verdict = dash < 0 ? b.text : b.text.substring(0, dash);
    String rest = dash < 0 ? '' : b.text.substring(dash + 3);
    String by = '';
    final int open = rest.lastIndexOf(' (');
    if (open >= 0 && rest.endsWith(')')) {
      by = rest.substring(open + 2, rest.length - 1);
      rest = rest.substring(0, open);
    }
    return MiVerdict(
      dimension: b.label,
      verdict: verdict.trim(),
      because: rest.trim(),
      by: by.trim(),
      dissenting: dissenting,
    );
  }
}

extension on Border {
  BoxDecoration toBoxDecoration() => BoxDecoration(border: this);
}
