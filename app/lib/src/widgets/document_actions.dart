import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mi_core/mi_core.dart';
import 'package:mi_design/mi_design.dart';

import '../store/exporter.dart';

/// Copy, save and share, over any document the core rendered.
///
/// One row rather than three implementations, because the dossier, the ledger
/// and the pitch are the same kind of thing to a client — the output — and
/// they were three different offers: the pitch could be copied, and the other
/// two could not leave the application at all.
class DocumentActions extends StatelessWidget {
  const DocumentActions({
    required this.filename,
    required this.text,
    this.trailing,
    super.key,
  });

  /// What the file is called when it lands somewhere.
  final String filename;

  /// The document as text, which is what the renderers already produce for the
  /// evidence set and for the command line.
  final String text;

  final Widget? trailing;

  Future<void> _save(BuildContext context) async {
    final ExportResult result = await Exporter.save(
      name: filename,
      contents: text,
    );
    if (context.mounted) miNotice(context, result.message);
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: MiSpace.sm),
    child: Wrap(
      spacing: MiSpace.sm,
      runSpacing: MiSpace.xs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        MiButton(
          label: 'Copy',
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: text));
            if (context.mounted) miNotice(context, 'Copied');
          },
        ),
        MiButton(label: 'Save', onPressed: () => _save(context)),
        if (Exporter.canShare)
          MiButton(
            label: 'Share',
            onPressed: () async {
              final bool went = await Exporter.share(
                name: filename,
                contents: text,
              );
              if (context.mounted && !went) {
                miNotice(context, 'Nothing here would take it.');
              }
            },
          ),
        ?trailing,
      ],
    ),
  );

  /// The plain-text form of a rendered document.
  static String textOf(MiDocument document) => document.toText();
}
