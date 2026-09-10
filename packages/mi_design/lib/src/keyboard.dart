import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Sends on Ctrl+Enter, leaving Enter to insert a newline.
///
/// Every writing field in this app is somewhere you answer a question in a
/// paragraph and then send it. Enter cannot be the send key: `maxLines != 1`
/// makes Flutter route Enter to a newline and never call `onSubmitted`, which
/// is how a submit handler stays dead code for months without anyone noticing.
///
/// Cmd+Enter too, for a Mac, and the numpad's Enter, which is a different key
/// code and is the one on the right-hand side of most keyboards.
class MiSubmit extends StatelessWidget {
  const MiSubmit({required this.child, required this.onSubmit, super.key});

  final Widget child;

  /// Null disables the shortcut, so a busy screen cannot be double-sent from
  /// the keyboard while its button is correctly disabled.
  final VoidCallback? onSubmit;

  /// What to tell the user, once, near the field.
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

/// Escape backs out of a pushed screen, the way it does everywhere else on a
/// desktop. Flutter gives routes no Escape handling of their own.
///
/// It takes focus so that keys reach it before anything has been clicked, so
/// do not wrap a screen whose own field is autofocused — the two would fight
/// over which one the caret lands in.
class MiEscape extends StatelessWidget {
  const MiEscape({required this.child, this.onEscape, super.key});

  final Widget child;

  /// Defaults to popping the enclosing route.
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
