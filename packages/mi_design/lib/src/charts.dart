/// Small charts, in the same ink as everything else.
///
/// **Nothing here carries meaning in colour.** The palette is near-monochrome
/// by design, so identity is carried by position and by a written label on
/// every mark — which is also what makes these readable under any colour
/// vision and in a forced-colours mode. A chart that needed a legend to be
/// understood would be the wrong chart for this program.
///
/// **`MiColors.verdict` appears nowhere below.** A council's judgements are
/// the one thing set in that ink, and a bar is not a judgement.
///
/// The one ramp used, in [MiSplitBar], is `ink` → `inkMuted` → `inkFaint`,
/// which was measured rather than chosen: three steps clear the contrast floor
/// against both surfaces, and the fourth neutral in this system is a border
/// token at 1.54:1 — a segment nobody could see.
library;

import 'package:flutter/widgets.dart';

import 'theme.dart';
import 'tokens.dart';

/// One column: what it is, and how much of it there was.
@immutable
class MiColumn {
  const MiColumn(this.label, this.value);
  final String label;
  final int value;
}

/// Magnitude across an ordered sequence — rounds, in practice.
///
/// A column of zero draws as a stub rather than as nothing, because "this
/// round kept nothing" is the single most consequential thing the sequence can
/// say and an absent mark reads as missing data.
class MiColumns extends StatelessWidget {
  const MiColumns({
    required this.data,
    this.height = 88,
    this.semanticLabel = '',
    super.key,
  });

  final List<MiColumn> data;
  final double height;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final MiColors c = MiTheme.colorsOf(context);
    if (data.isEmpty) return const SizedBox.shrink();

    final int top = data.fold(
      0,
      (int a, MiColumn d) => d.value > a ? d.value : a,
    );
    final int peak = data.lastIndexWhere((MiColumn d) => d.value == top);
    final int last = data.length - 1;

    return Semantics(
      label: semanticLabel.isEmpty ? null : semanticLabel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SizedBox(
            height: height,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                for (int i = 0; i < data.length; i++)
                  Expanded(
                    child: Padding(
                      // The 2px gap between neighbours is a gap in the
                      // surface, never a drawn border.
                      padding: const EdgeInsets.symmetric(horizontal: 1),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: <Widget>[
                          if (i == peak || i == last)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 2),
                              child: Text(
                                '${data[i].value}',
                                style: MiType.caption.copyWith(color: c.ink),
                                textAlign: TextAlign.center,
                                maxLines: 1,
                              ),
                            ),
                          Container(
                            height: top == 0
                                ? 2
                                : (2 + (height - 26) * data[i].value / top),
                            decoration: BoxDecoration(
                              color: i == last ? c.ink : c.inkMuted,
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(2),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Container(height: 1, color: c.line),
          const SizedBox(height: MiSpace.xs),
          Row(
            children: <Widget>[
              for (final MiColumn d in data)
                Expanded(
                  child: Text(
                    d.label,
                    style: MiType.caption.copyWith(color: c.inkFaint),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One labelled bar.
@immutable
class MiBar {
  const MiBar(this.label, this.value);
  final String label;
  final int value;
}

/// Labelled magnitudes sharing one baseline.
///
/// One ink for every bar: the length already carries the magnitude, and
/// shading each bar by its own size would spend the only free channel this
/// palette has on information the chart is already showing.
class MiBars extends StatelessWidget {
  const MiBars({
    required this.data,
    this.labelWidth = 132,
    this.semanticLabel = '',
    super.key,
  });

  final List<MiBar> data;
  final double labelWidth;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final MiColors c = MiTheme.colorsOf(context);
    if (data.isEmpty) return const SizedBox.shrink();
    final int top = data.fold(0, (int a, MiBar d) => d.value > a ? d.value : a);

    return Semantics(
      label: semanticLabel.isEmpty ? null : semanticLabel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (final MiBar d in data)
            Padding(
              padding: const EdgeInsets.only(bottom: MiSpace.xs),
              child: Row(
                children: <Widget>[
                  SizedBox(
                    width: labelWidth,
                    child: Text(
                      d.label,
                      style: MiType.caption.copyWith(color: c.inkMuted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: MiSpace.sm),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: top == 0
                            ? 0
                            : (d.value / top).clamp(0.0, 1.0),
                        child: Container(
                          height: 7,
                          decoration: BoxDecoration(
                            color: c.ink,
                            borderRadius: const BorderRadius.horizontal(
                              right: Radius.circular(2),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: MiSpace.sm),
                  Text(
                    '${d.value}',
                    style: MiType.caption.copyWith(color: c.ink),
                    maxLines: 1,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// One share of a whole.
@immutable
class MiSplit {
  const MiSplit(this.label, this.value);
  final String label;
  final int value;
}

/// Part to whole, in at most three shares.
///
/// Three because the ramp has three steps that clear the contrast floor, and a
/// fourth would be a segment nobody can see. Every share is written out
/// underneath, so the bar is a picture of something the reader can also read.
class MiSplitBar extends StatelessWidget {
  const MiSplitBar({required this.parts, this.semanticLabel = '', super.key});

  final List<MiSplit> parts;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final MiColors c = MiTheme.colorsOf(context);
    final List<MiSplit> shown = parts.take(3).toList();
    final int total = shown.fold(0, (int a, MiSplit p) => a + p.value);
    final List<Color> ramp = <Color>[c.ink, c.inkMuted, c.inkFaint];

    return Semantics(
      label: semanticLabel.isEmpty ? null : semanticLabel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SizedBox(
            height: 7,
            child: total == 0
                ? Container(
                    decoration: BoxDecoration(
                      color: c.line,
                      borderRadius: MiRadius.chip,
                    ),
                  )
                : Row(
                    children: <Widget>[
                      for (int i = 0; i < shown.length; i++)
                        if (shown[i].value > 0)
                          Expanded(
                            flex: shown[i].value,
                            child: Padding(
                              padding: EdgeInsets.only(
                                right: i == shown.length - 1 ? 0 : 2,
                              ),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: ramp[i],
                                  borderRadius: MiRadius.chip,
                                ),
                              ),
                            ),
                          ),
                    ],
                  ),
          ),
          const SizedBox(height: MiSpace.xs),
          Text(
            total == 0
                ? 'nothing mapped yet'
                : <String>[
                    for (final MiSplit p in shown) '${p.value} ${p.label}',
                  ].join(' · '),
            style: MiType.caption.copyWith(color: c.inkMuted),
          ),
        ],
      ),
    );
  }
}

/// How many of a known number have come back.
///
/// The one place in this program where a denominator is honestly known: the
/// angles seated in a round are decided before it opens. Nothing else here
/// gets a fraction, because nothing else has one.
class MiFanIn extends StatelessWidget {
  const MiFanIn({
    required this.total,
    required this.back,
    this.exhausted = 0,
    this.note = '',
    super.key,
  });

  final int total;

  /// How many have returned, exhausted ones included.
  final int back;

  /// Of those, how many said there was nothing left down their line.
  final int exhausted;

  final String note;

  @override
  Widget build(BuildContext context) {
    final MiColors c = MiTheme.colorsOf(context);
    final int returned = (back - exhausted).clamp(0, total);
    final int spent = exhausted.clamp(0, total - returned);

    return Semantics(
      label:
          '$back of $total angles back'
          '${exhausted == 0 ? '' : ', $exhausted with nothing left'}',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: <Widget>[
              for (int i = 0; i < total; i++)
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    // Returned is solid; an angle with nothing left is a ring,
                    // because 'came back empty' and 'still out' are the two
                    // states a dryness decision turns on and they must never
                    // look alike.
                    color: i < returned
                        ? c.ink
                        : (i < returned + spent
                              ? const Color(0x00000000)
                              : c.line),
                    border: i >= returned && i < returned + spent
                        ? Border.all(color: c.inkMuted, width: 1.5)
                        : null,
                  ),
                ),
            ],
          ),
          if (note.isNotEmpty) ...<Widget>[
            const SizedBox(width: MiSpace.md),
            Flexible(
              child: Text(
                note,
                style: MiType.caption.copyWith(color: c.inkMuted),
                maxLines: 2,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
