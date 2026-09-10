import 'package:flutter/material.dart';

import 'keyboard.dart';
import 'theme.dart';
import 'tokens.dart';

/// A section header, echoing the typographic voice of the documents this app
/// produces. The number is optional here: Master Prompt's briefs are numbered
/// `00 / RUNTIME`, and a dossier's sections are not.
class MiSectionHeader extends StatelessWidget {
  const MiSectionHeader({
    required this.title,
    this.number,
    this.subtitle,
    this.trailing,
    super.key,
  });

  final String? number;
  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final MiColors c = MiTheme.colorsOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: <Widget>[
            if (number != null) ...<Widget>[
              Text(
                '$number  /',
                style: MiType.eyebrow.copyWith(color: c.inkFaint),
              ),
              const SizedBox(width: MiSpace.sm),
            ],
            Expanded(
              child: Text(
                title.toUpperCase(),
                style: MiType.eyebrow.copyWith(color: c.inkMuted),
              ),
            ),
            ?trailing,
          ],
        ),
        if (subtitle != null) ...<Widget>[
          const SizedBox(height: MiSpace.sm),
          Text(subtitle!, style: MiType.prose.copyWith(color: c.inkMuted)),
        ],
      ],
    );
  }
}

/// A hairline rule. The app's main structural device.
class MiRule extends StatelessWidget {
  const MiRule({this.strong = false, super.key});

  final bool strong;

  @override
  Widget build(BuildContext context) {
    final MiColors c = MiTheme.colorsOf(context);
    return Container(height: 1, color: strong ? c.lineStrong : c.line);
  }
}

/// A bordered panel. No shadow, no fill contrast beyond one step.
class MiPanel extends StatelessWidget {
  const MiPanel({
    required this.child,
    this.padding = const EdgeInsets.all(MiSpace.md),
    this.accent,
    super.key,
  });

  final Widget child;
  final EdgeInsets padding;

  /// When set, a 2px bar down the leading edge. Used to mark state that needs
  /// attention without resorting to a coloured background.
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final MiColors c = MiTheme.colorsOf(context);
    final Widget body = Padding(padding: padding, child: child);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: MiRadius.card,
        border: Border.all(color: c.line),
      ),
      // Without an accent there is no Row at all. A stretch Row would demand a
      // bounded height, which it never has inside a scroll view.
      child: accent == null
          ? body
          : IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Container(
                    width: 2,
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: const BorderRadius.horizontal(
                        left: MiRadius.md,
                      ),
                    ),
                  ),
                  Expanded(child: body),
                ],
              ),
            ),
    );
  }
}

/// The app's button. One shape, three weights of emphasis.
enum MiButtonKind { primary, secondary, quiet }

class MiButton extends StatelessWidget {
  const MiButton({
    required this.label,
    this.onPressed,
    this.kind = MiButtonKind.secondary,
    this.icon,
    this.expand = false,
    this.busy = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final MiButtonKind kind;
  final IconData? icon;
  final bool expand;

  /// Something long is already happening behind this button.
  ///
  /// The one addition to Master Prompt's button, because this half has actions
  /// that take minutes — computing what a selection becomes, pulling fifty
  /// megabytes of build — and a button that stays live during one invites a
  /// second click that starts it again. It disables and says so; no spinner,
  /// because a spinner is a claim about progress nobody can make.
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final MiColors c = MiTheme.colorsOf(context);
    final bool enabled = onPressed != null && !busy;

    final Color fg = switch (kind) {
      MiButtonKind.primary => c.accentInk,
      _ => enabled ? c.ink : c.inkFaint,
    };
    final Color bg = switch (kind) {
      MiButtonKind.primary => enabled ? c.accent : c.lineStrong,
      MiButtonKind.secondary => c.surface,
      MiButtonKind.quiet => Colors.transparent,
    };

    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: Material(
        color: bg,
        borderRadius: MiRadius.card,
        child: InkWell(
          onTap: enabled ? onPressed : null,
          borderRadius: MiRadius.card,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: MiRadius.card,
              border: Border.all(
                color: kind == MiButtonKind.secondary
                    ? c.lineStrong
                    : Colors.transparent,
              ),
            ),
            constraints: const BoxConstraints(minHeight: MiSpace.tapTarget),
            padding: const EdgeInsets.symmetric(
              horizontal: MiSpace.lg,
              vertical: MiSpace.sm + 4,
            ),
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                if (icon != null) ...<Widget>[
                  Icon(icon, size: 20, color: fg),
                  const SizedBox(width: MiSpace.sm + 2),
                ],
                Flexible(
                  child: Text(
                    busy ? '$label…' : label,
                    style: MiType.heading.copyWith(color: fg),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A small status marker: a phase, a limit type, a parse outcome.
class MiTag extends StatelessWidget {
  const MiTag(this.text, {this.tone, super.key});

  final String text;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final MiColors c = MiTheme.colorsOf(context);
    final Color colour = tone ?? c.inkMuted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: MiSpace.sm, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: MiRadius.chip,
        border: Border.all(color: colour.withValues(alpha: 0.35)),
      ),
      child: Text(
        text.toUpperCase(),
        style: MiType.eyebrow.copyWith(color: colour),
      ),
    );
  }
}

/// A thin progress bar, used for readiness and for rubric score.
class MiMeter extends StatelessWidget {
  const MiMeter({required this.value, this.tone, super.key});

  /// 0..1
  final double value;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final MiColors c = MiTheme.colorsOf(context);
    return ClipRRect(
      borderRadius: const BorderRadius.all(Radius.circular(2)),
      child: SizedBox(
        height: 4,
        child: Stack(
          children: <Widget>[
            Container(color: c.line),
            FractionallySizedBox(
              widthFactor: value.clamp(0, 1),
              child: Container(color: tone ?? c.ink),
            ),
          ],
        ),
      ),
    );
  }
}

/// A labelled row of key and value, used throughout the detail panels.
class MiField extends StatelessWidget {
  const MiField({required this.label, required this.child, super.key});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final MiColors c = MiTheme.colorsOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label.toUpperCase(),
          style: MiType.eyebrow.copyWith(color: c.inkFaint),
        ),
        const SizedBox(height: MiSpace.xs + 2),
        child,
      ],
    );
  }
}

/// Shown when a list is empty, instead of blank space.
class MiEmpty extends StatelessWidget {
  const MiEmpty({required this.title, this.detail, this.action, super.key});

  final String title;
  final String? detail;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final MiColors c = MiTheme.colorsOf(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              title,
              style: MiType.heading.copyWith(color: c.ink),
              textAlign: TextAlign.center,
            ),
            if (detail != null) ...<Widget>[
              const SizedBox(height: MiSpace.sm),
              Text(
                detail!,
                style: MiType.prose.copyWith(color: c.inkMuted),
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...<Widget>[
              const SizedBox(height: MiSpace.lg),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// A collapsed row that opens in place.
///
/// The device by which this app keeps its promise that nothing is removed, only
/// deferred. Everything the first build printed on screen is still here — it
/// waits behind one of these until asked for.
class MiDisclosure extends StatefulWidget {
  const MiDisclosure({
    required this.label,
    required this.child,
    this.initiallyOpen = false,
    this.trailingNote,
    super.key,
  });

  final String label;
  final Widget child;
  final bool initiallyOpen;

  /// A count or hint shown on the closed row, so the user can judge whether it
  /// is worth opening without opening it.
  final String? trailingNote;

  @override
  State<MiDisclosure> createState() => _MiDisclosureState();
}

class _MiDisclosureState extends State<MiDisclosure>
    with SingleTickerProviderStateMixin {
  late bool _open = widget.initiallyOpen;

  @override
  Widget build(BuildContext context) {
    final MiColors c = MiTheme.colorsOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Semantics(
          button: true,
          expanded: _open,
          label: widget.label,
          child: InkWell(
            onTap: () => setState(() => _open = !_open),
            borderRadius: MiRadius.card,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: MiSpace.sm + 4),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      widget.label,
                      style: MiType.label.copyWith(color: c.inkMuted),
                    ),
                  ),
                  if (widget.trailingNote != null) ...<Widget>[
                    Text(
                      widget.trailingNote!,
                      style: MiType.caption.copyWith(color: c.inkFaint),
                    ),
                    const SizedBox(width: MiSpace.sm),
                  ],
                  AnimatedRotation(
                    turns: _open ? 0.5 : 0,
                    duration: const Duration(milliseconds: 160),
                    child: Icon(
                      Icons.keyboard_arrow_down,
                      size: 20,
                      color: c.inkFaint,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        // Built only when open. A cross-fade keeps both subtrees alive, which
        // means a closed disclosure still lays out its contents and still
        // announces them to a screen reader — so "hidden" would only be true
        // visually, which is not what was promised.
        AnimatedSize(
          alignment: Alignment.topCenter,
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          child: _open
              ? Padding(
                  padding: const EdgeInsets.only(bottom: MiSpace.sm),
                  child: widget.child,
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}

/// A small mark that explains a term without spending a line on it.
///
/// A long-press tooltip would be undiscoverable on a phone, so this is a
/// visible, tappable target that opens a sheet on touch and shows a plain
/// tooltip where there is a pointer.
class MiInfo extends StatelessWidget {
  const MiInfo({required this.title, required this.body, super.key});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final MiColors c = MiTheme.colorsOf(context);
    final bool pointer = MediaQuery.sizeOf(context).width >= MiSpace.wideGate;

    final Widget mark = Icon(Icons.info_outline, size: 18, color: c.inkFaint);

    if (pointer) {
      return Tooltip(
        message: body,
        textStyle: MiType.caption.copyWith(color: c.canvas),
        padding: const EdgeInsets.all(MiSpace.sm + 2),
        margin: const EdgeInsets.all(MiSpace.md),
        child: mark,
      );
    }

    return Semantics(
      button: true,
      label: 'About $title',
      child: InkResponse(
        radius: 22,
        onTap: () => showModalBottomSheet<void>(
          context: context,
          backgroundColor: c.surfaceRaised,
          showDragHandle: true,
          builder: (BuildContext context) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                MiSpace.lg,
                0,
                MiSpace.lg,
                MiSpace.xl,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(title, style: MiType.title.copyWith(color: c.ink)),
                  const SizedBox(height: MiSpace.sm + 4),
                  Text(body, style: MiType.prose.copyWith(color: c.inkMuted)),
                ],
              ),
            ),
          ),
        ),
        child: Padding(padding: const EdgeInsets.all(MiSpace.xs), child: mark),
      ),
    );
  }
}

/// The container a flow screen is built from: one subject, one action.
///
/// Deliberately rigid about structure. The first build let any screen grow
/// another panel, and eight of them ended up stacked on a phone; this type has
/// room for exactly one question, one supporting line, one primary action, and
/// whatever is folded away beneath.
class MiFocal extends StatelessWidget {
  const MiFocal({
    required this.question,
    this.eyebrow,
    this.supporting,
    this.info,
    this.body,
    this.primary,
    this.secondary,
    this.disclosures = const <Widget>[],
    this.maxWidth = MiSpace.readingWidth,
    super.key,
  });

  /// The one line the screen is about.
  final String question;

  /// Where the user is, set small and quiet above the question.
  final String? eyebrow;

  /// A single line of orientation. Never a paragraph.
  final String? supporting;

  /// An optional explanation of a term used in the question.
  final MiInfo? info;

  /// The screen's working area, if it has one — a field, a summary, a preview.
  final Widget? body;

  final Widget? primary;
  final Widget? secondary;

  /// Everything deferred, folded away at the bottom.
  final List<Widget> disclosures;

  /// The measure. One question wants a reading column; a conversation with a
  /// composer under it wants a little more.
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final MiColors c = MiTheme.colorsOf(context);

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            MiSpace.lg,
            MiSpace.lg,
            MiSpace.lg,
            MiSpace.xl,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight - 72),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    if (eyebrow != null) ...<Widget>[
                      Text(
                        eyebrow!.toUpperCase(),
                        style: MiType.eyebrow.copyWith(color: c.inkFaint),
                      ),
                      const SizedBox(height: MiSpace.md),
                    ],
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            question,
                            style: MiType.question.copyWith(color: c.ink),
                          ),
                        ),
                        if (info != null) ...<Widget>[
                          const SizedBox(width: MiSpace.sm),
                          Padding(
                            padding: const EdgeInsets.only(top: MiSpace.xs),
                            child: info,
                          ),
                        ],
                      ],
                    ),
                    if (supporting != null) ...<Widget>[
                      const SizedBox(height: MiSpace.md),
                      Text(
                        supporting!,
                        style: MiType.prose.copyWith(color: c.inkMuted),
                      ),
                    ],
                    if (body != null) ...<Widget>[
                      const SizedBox(height: MiSpace.xl),
                      body!,
                    ],
                    const SizedBox(height: MiSpace.xl),
                    ?primary,
                    if (secondary != null) ...<Widget>[
                      const SizedBox(height: MiSpace.sm),
                      secondary!,
                    ],
                    if (disclosures.isNotEmpty) ...<Widget>[
                      const SizedBox(height: MiSpace.lg),
                      const MiRule(),
                      ...disclosures,
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// A quiet progress mark: how far through the stages, without listing them.
class MiSteps extends StatelessWidget {
  const MiSteps({required this.step, required this.total, super.key});

  final int step;
  final int total;

  @override
  Widget build(BuildContext context) {
    final MiColors c = MiTheme.colorsOf(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (int i = 1; i <= total; i++)
          Container(
            width: i == step ? 16 : 5,
            height: 5,
            margin: const EdgeInsets.only(right: 4),
            decoration: BoxDecoration(
              color: i <= step ? c.ink : c.line,
              borderRadius: const BorderRadius.all(Radius.circular(3)),
            ),
          ),
      ],
    );
  }
}

/// A judgement.
///
/// **The only widget in this application that paints with [MiColors.verdict].**
/// The palette's single reservation — oxblood for verdicts and ratings, and
/// nothing else — is a rule about colour that can only be kept by being a rule
/// about code, because a second place reaching for it makes the first one mean
/// nothing. `treatment_test.dart` reads the source and asserts that nothing
/// else does.
///
/// The verdict is an ordinal word and never a numeral. That is enforced
/// upstream in the rating vocabularies, and it is why this is set at reading
/// size: a number invites averaging, and averaging is how dissent disappears.
class MiVerdict extends StatelessWidget {
  const MiVerdict({
    required this.dimension,
    required this.verdict,
    this.because = '',
    this.by = '',
    this.dissenting = false,
    super.key,
  });

  final String dimension;
  final String verdict;
  final String because;

  /// The seat that gave it. A verdict nobody is named for is not attributable,
  /// and attribution is the standard this whole tool holds itself to.
  final String by;

  /// A minority verdict, set as one: indented under the record it dissents
  /// from, in the same colour, because dissent is a judgement too.
  final bool dissenting;

  @override
  Widget build(BuildContext context) {
    final MiColors c = MiTheme.colorsOf(context);
    return Padding(
      padding: EdgeInsets.only(
        left: dissenting ? MiSpace.lg : 0,
        top: MiSpace.xs,
        bottom: MiSpace.xs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: <Widget>[
              Text(
                dissenting
                    ? 'DISSENT · ${dimension.toUpperCase()}'
                    : dimension.toUpperCase(),
                style: MiType.eyebrow.copyWith(color: c.inkFaint),
              ),
              const SizedBox(width: MiSpace.sm),
              Flexible(
                child: Text(
                  verdict,
                  style: MiType.verdict.copyWith(color: c.verdict),
                ),
              ),
            ],
          ),
          if (because.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                because,
                style: MiType.caption.copyWith(color: c.inkMuted),
              ),
            ),
          if (by.isNotEmpty)
            Text(by, style: MiType.mono.copyWith(color: c.inkFaint)),
        ],
      ),
    );
  }
}

/// Where the client writes.
///
/// A field, its hint, and Ctrl+Enter — never Enter, which these fields need for
/// a newline.
class MiWriting extends StatelessWidget {
  const MiWriting({
    required this.controller,
    this.hint = '',
    this.minLines = 3,
    this.maxLines = 12,
    this.autofocus = false,
    this.onSubmit,
    this.onChanged,
    super.key,
  });

  final TextEditingController controller;
  final String hint;
  final int minLines;
  final int maxLines;
  final bool autofocus;
  final VoidCallback? onSubmit;

  /// Every keystroke, for the few fields that answer as they are typed — a
  /// filter over a list, a button that has to enable itself. A screen that
  /// listens to the controller instead has to remember to stop.
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final MiColors c = MiTheme.colorsOf(context);
    return MiSubmit(
      onSubmit: onSubmit,
      child: TextField(
        controller: controller,
        autofocus: autofocus,
        minLines: minLines,
        maxLines: maxLines,
        onChanged: onChanged,
        style: MiType.prose.copyWith(color: c.ink),
        decoration: InputDecoration(hintText: hint),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shorthand over the vocabulary above.
//
// Three things this half writes constantly — a section mark, a labelled line
// of prose, and a page of a measure — which Master Prompt writes out longhand
// because it needs them less often. They render exactly what it renders; they
// are here so a dossier screen reads as a dossier rather than as a wall of
// `Text(x.toUpperCase(), style: …)`.
// ---------------------------------------------------------------------------

/// A section mark: what the thing below it is.
class MiEyebrow extends StatelessWidget {
  const MiEyebrow(this.text, {this.tone, super.key});

  final String text;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final MiColors c = MiTheme.colorsOf(context);
    return Text(
      text.toUpperCase(),
      style: MiType.eyebrow.copyWith(color: tone ?? c.inkFaint),
    );
  }
}

/// A labelled line: what it is, then what it says.
///
/// The label is set in small caps, which is right for `TRACED TO` and wrong for
/// a sentence — a line of prose is a [Text], not a record label.
class MiRecord extends StatelessWidget {
  const MiRecord({
    required this.label,
    required this.value,
    this.tone,
    this.style,
    super.key,
  });

  final String label;
  final String value;
  final Color? tone;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final MiColors c = MiTheme.colorsOf(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: MiSpace.xs),
      child: MiField(
        label: label,
        child: Text(
          value,
          style: (style ?? MiType.body).copyWith(color: tone ?? c.ink),
        ),
      ),
    );
  }
}

/// A page of a measure, centred, with the window growing around it.
///
/// A document at 1600px full-bleed is unreadable, so the page stays a page.
class MiLeaf extends StatelessWidget {
  const MiLeaf({
    required this.child,
    this.width = MiSpace.conversationWidth,
    this.padding = const EdgeInsets.symmetric(
      horizontal: MiSpace.lg,
      vertical: MiSpace.xl,
    ),
    super.key,
  });

  final Widget child;
  final double width;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: width),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}
