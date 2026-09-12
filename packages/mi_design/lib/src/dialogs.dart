import 'package:flutter/material.dart';

import 'theme.dart';
import 'tokens.dart';
import 'widgets.dart';

/// Ask before something that cannot be taken back.
///
/// One of these rather than a hand-rolled dialog per screen, because the two
/// that existed disagreed about everything: which button was on which side,
/// whether the destructive one was marked, and whether the body said what
/// would actually be lost. A confirmation that varies is a confirmation people
/// learn to dismiss.
///
/// The body says what happens, not whether the client is sure. "Are you sure?"
/// asks for a feeling; "this removes the files, and nothing else has a copy"
/// tells them the one thing they need to decide with.
Future<bool> showMiConfirm(
  BuildContext context, {
  required String title,
  required String body,
  required String action,
  String cancel = 'Leave it',
}) async {
  final MiColors c = MiTheme.colorsOf(context);
  final bool? said = await showDialog<bool>(
    context: context,
    builder: (BuildContext context) => AlertDialog(
      backgroundColor: c.surfaceRaised,
      title: Text(title, style: MiType.title.copyWith(color: c.ink)),
      content: Text(body, style: MiType.prose.copyWith(color: c.inkMuted)),
      actions: <Widget>[
        MiButton(
          label: cancel,
          kind: MiButtonKind.quiet,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        MiButton(
          label: action,
          kind: MiButtonKind.primary,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    ),
  );
  return said ?? false;
}

/// Say that something just happened.
///
/// Every copy button in this application was silent: the text reached the
/// clipboard and the screen did not change, which on the hand-carry screen is
/// the difference between "I have the turn" and "did that work?". The theme
/// has styled a snack bar since the first build and nothing ever showed one.
void miNotice(BuildContext context, String message) {
  final MiColors c = MiTheme.colorsOf(context);
  ScaffoldMessenger.maybeOf(context)
    ?..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message, style: MiType.body.copyWith(color: c.canvas)),
        duration: const Duration(seconds: 2),
      ),
    );
}
