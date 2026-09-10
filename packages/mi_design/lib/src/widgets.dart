import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'theme.dart';
import 'tokens.dart';

/// A hairline. The only structural device in this system.
///
/// There are no cards, no boxes and no shadows anywhere in this app, so a rule
/// is how one thing is separated from another. It is a widget rather than a
/// `Divider` so that its inset can be part of the vocabulary: a rule that runs
/// the full measure separates sections, and an indented one separates entries
/// inside a section.
class MiRule extends StatelessWidget {
  const MiRule({this.strong = false, this.indent = 0, super.key});

  final bool strong;
  final double indent;

  @override
  Widget build(BuildContext context) {
    final MiColors c = MiTheme.colorsOf(context);
    return Padding(
      padding: EdgeInsets.only(left: indent),
      child: Container(height: 1, color: strong ? c.ruleStrong : c.rule),
    );
  }
}

/// A section mark, in small tracked caps: what the thing below it is.
class MiEyebrow extends StatelessWidget {
  const MiEyebrow(this.text, {this.tone, super.key});

  final String text;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final MiColors c = MiTheme.colorsOf(context);
    return Text(
      text.toUpperCase(),
      style: MiType.eyebrow.copyWith(color: tone ?? c.inkMuted),
    );
  }
}

/// A labelled record line: what it is, then what it says.
///
/// The label is set in small caps, which is right for `TRACED TO` and wrong
/// for a sentence — Master Prompt learned that the hard way with a field whose
/// label was a line of prose. A line of prose is a [Text], not a record label.
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          MiEyebrow(label),
          const SizedBox(height: 2),
          Text(
            value,
            style: (style ?? MiType.body).copyWith(color: tone ?? c.ink),
          ),
        ],
      ),
    );
  }
}

/// A judgement.
///
/// **The only widget in this application that paints with the accent.** The
/// palette's single reservation — oxblood for verdicts and ratings, nothing
/// else — is a rule about colour that can only be kept by being a rule about
/// code, because a second place that reaches for it makes the first one mean
/// nothing. `theme_test.dart` asserts that nothing else does.
///
/// The verdict is an ordinal word and never a numeral. That is enforced
/// upstream, in the rating vocabularies, but it is also why this is set at
/// reading size: the colour carries the weight, and a verdict in display type
/// would be the closest thing this design has to a chart.
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
  /// and attribution is the whole standard this tool holds itself to.
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
              MiEyebrow(dissenting ? 'Dissent · $dimension' : dimension),
              const SizedBox(width: MiSpace.sm),
              Flexible(
                child: Text(
                  verdict,
                  style: MiType.verdict.copyWith(color: c.accent),
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

/// The primary action on a screen.
///
/// Flat and matte: ink fill, no radius worth noticing, no shadow. A secondary
/// action is the same shape drawn in a rule instead of a fill, so the two read
/// as the same object at two weights rather than as two different controls.
class MiAction extends StatelessWidget {
  const MiAction({
    required this.label,
    required this.onPressed,
    this.secondary = false,
    this.busy = false,
    super.key,
  });

  final String label;

  /// Null disables it. A disabled action stays in place rather than
  /// disappearing, so a screen does not reflow as it becomes usable.
  final VoidCallback? onPressed;

  final bool secondary;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final MiColors c = MiTheme.colorsOf(context);
    final bool enabled = onPressed != null && !busy;
    final Color fill = secondary ? Colors.transparent : c.ink;
    final Color ink = secondary ? c.ink : c.ground;

    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: InkWell(
        onTap: enabled ? onPressed : null,
        child: Container(
          constraints: const BoxConstraints(minHeight: MiSpace.tapTarget),
          padding: const EdgeInsets.symmetric(horizontal: MiSpace.lg),
          decoration: BoxDecoration(
            color: enabled ? fill : (secondary ? null : c.inkFaint),
            border: Border.all(color: enabled ? c.ink : c.inkFaint),
          ),
          alignment: Alignment.center,
          child: Text(
            busy ? '$label…' : label,
            style: MiType.body.copyWith(
              color: enabled ? ink : (secondary ? c.inkFaint : c.ground),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

/// A quiet action: a word with a rule under it.
class MiQuietAction extends StatelessWidget {
  const MiQuietAction({
    required this.label,
    required this.onPressed,
    this.tone,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final MiColors c = MiTheme.colorsOf(context);
    final Color ink = onPressed == null ? c.inkFaint : (tone ?? c.ink);
    return Semantics(
      button: true,
      enabled: onPressed != null,
      child: InkWell(
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: MiSpace.sm,
            horizontal: MiSpace.xs,
          ),
          child: Text(
            label,
            style: MiType.body.copyWith(
              color: ink,
              decoration: TextDecoration.underline,
              decorationColor: c.rule,
            ),
          ),
        ),
      ),
    );
  }
}

/// Something folded away until it is wanted.
///
/// Built with [AnimatedSize] and a **conditional child**, never
/// `AnimatedCrossFade`: that builds both branches, so a collapsed disclosure
/// still lays out its contents and still announces them to a screen reader.
/// "Hidden" would be true only visually.
class MiDisclosure extends StatefulWidget {
  const MiDisclosure({
    required this.summary,
    required this.child,
    this.initiallyOpen = false,
    super.key,
  });

  final String summary;
  final Widget child;
  final bool initiallyOpen;

  @override
  State<MiDisclosure> createState() => _MiDisclosureState();
}

class _MiDisclosureState extends State<MiDisclosure> {
  late bool _open = widget.initiallyOpen;

  @override
  Widget build(BuildContext context) {
    final MiColors c = MiTheme.colorsOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        InkWell(
          onTap: () => setState(() => _open = !_open),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: MiSpace.sm),
            child: Row(
              children: <Widget>[
                Expanded(child: MiEyebrow(widget.summary)),
                Text(
                  _open ? '−' : '+',
                  style: MiType.body.copyWith(color: c.inkMuted),
                ),
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 140),
          alignment: Alignment.topCenter,
          child: _open
              ? Padding(
                  padding: const EdgeInsets.only(bottom: MiSpace.md),
                  child: widget.child,
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}

/// The page a region is set on: a measure of paper, centred, with the window
/// growing around it rather than the text stretching to fill it.
class MiLeaf extends StatelessWidget {
  const MiLeaf({
    required this.child,
    this.width = MiSpace.documentWidth,
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

/// Sends on Ctrl+Enter, leaving Enter to insert a newline.
///
/// Every writing field here is multi-line, and with `maxLines` above one
/// Flutter routes Enter to a newline and never calls `onSubmitted` — which is
/// how a submit handler stays dead code for months without anyone noticing.
class MiSubmit extends StatelessWidget {
  const MiSubmit({required this.child, required this.onSubmit, super.key});

  final Widget child;

  /// Null disables the shortcut, so a busy screen cannot be double-sent from
  /// the keyboard while its button is correctly disabled.
  final VoidCallback? onSubmit;

  static String hintFor(BuildContext context) =>
      Theme.of(context).platform == TargetPlatform.macOS ? '⌘↵' : 'Ctrl+Enter';

  @override
  Widget build(BuildContext context) {
    final VoidCallback? send = onSubmit;
    if (send == null) return child;
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.enter, control: true): send,
        const SingleActivator(LogicalKeyboardKey.enter, meta: true): send,
        const SingleActivator(LogicalKeyboardKey.numpadEnter, control: true):
            send,
        const SingleActivator(LogicalKeyboardKey.numpadEnter, meta: true): send,
      },
      child: child,
    );
  }
}

/// Escape backs out of a pushed screen, as it does everywhere else on a
/// desktop. Flutter gives routes no Escape handling of their own.
///
/// It takes focus so keys reach it before anything is clicked, so do not wrap
/// a screen whose own field is autofocused — the two fight over the caret.
class MiEscape extends StatelessWidget {
  const MiEscape({required this.child, this.onEscape, super.key});

  final Widget child;
  final VoidCallback? onEscape;

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.escape):
            onEscape ?? () => Navigator.of(context).maybePop(),
      },
      child: Focus(autofocus: true, child: child),
    );
  }
}

/// Where the client writes.
class MiWriting extends StatelessWidget {
  const MiWriting({
    required this.controller,
    this.hint = '',
    this.minLines = 3,
    this.maxLines = 12,
    this.autofocus = false,
    this.onSubmit,
    super.key,
  });

  final TextEditingController controller;
  final String hint;
  final int minLines;
  final int maxLines;
  final bool autofocus;
  final VoidCallback? onSubmit;

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
        style: MiType.prose.copyWith(color: c.ink),
        decoration: InputDecoration(hintText: hint),
      ),
    );
  }
}
