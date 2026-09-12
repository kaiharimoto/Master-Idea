import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mi_core/mi_core.dart';
import 'package:mi_design/mi_design.dart';

import '../transport/handover_council.dart';

/// One turn, on its way out by hand and back again.
///
/// The phone's whole council is this panel, used once per turn for as long as
/// the sitting lasts — and used again in Assembly, because the integrator is a
/// turn like any other and a client who cannot reach it has a session that
/// ends at the dossier.
///
/// **A reply is read before it is accepted.** What comes back from a chat app
/// has been through a person, a clipboard and whatever the app did to the
/// formatting, and the run cannot tell a truncated paste from a seat with
/// nothing to say — an empty reply is evidence of dryness, which is the one
/// thing this transport must never manufacture. So the panel parses first,
/// says what it found, and lets the client paste again.
class CarryPanel extends StatefulWidget {
  const CarryPanel({required this.hand, required this.turn, super.key});

  final HandoverCouncil hand;
  final CouncilTurn turn;

  @override
  State<CarryPanel> createState() => _CarryPanelState();
}

class _CarryPanelState extends State<CarryPanel> {
  final TextEditingController _reply = TextEditingController();
  ParsedReply? _read;

  @override
  void dispose() {
    _reply.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(CarryPanel old) {
    super.didUpdateWidget(old);
    // A new turn is a clean sheet: the last reply belongs to the last seat.
    if (old.turn.conversation != widget.turn.conversation) {
      _reply.clear();
      _read = null;
    }
  }

  void _look() {
    final String said = _reply.text.trim();
    if (said.isEmpty) return;
    setState(() => _read = CouncilReplyParser.parse(said));
  }

  void _accept() {
    final String said = _reply.text.trim();
    if (said.isEmpty) return;
    widget.hand.receive(said);
    _reply.clear();
    setState(() => _read = null);
  }

  @override
  Widget build(BuildContext context) {
    final MiColors c = MiTheme.colorsOf(context);
    final CouncilTurn turn = widget.turn;
    final ParsedReply? read = _read;
    final int queued = widget.hand.queued;

    return MiPanel(
      accent: c.ink,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              MiTag(turn.purpose),
              const SizedBox(width: MiSpace.sm),
              Expanded(
                child: Text(
                  turn.agent.id,
                  style: MiType.mono.copyWith(color: c.inkMuted),
                ),
              ),
            ],
          ),
          const SizedBox(height: MiSpace.xs),
          Text(
            <String>[
              '${turn.prompt.length} characters',
              if (widget.hand.carried > 0) '${widget.hand.carried} carried',
              if (queued > 0) '$queued waiting behind this one',
            ].join(' · '),
            style: MiType.caption.copyWith(color: c.inkFaint),
          ),
          const SizedBox(height: MiSpace.md),
          MiButton(
            label: 'Copy this turn',
            kind: MiButtonKind.primary,
            expand: true,
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: turn.prompt));
              if (context.mounted) {
                miNotice(context, 'The turn is on the clipboard');
              }
            },
          ),
          const SizedBox(height: MiSpace.sm),
          Text(
            'Paste it into your chat app, then bring the whole reply back '
            'here. A reply that arrived by hand has no more authority than '
            'one that came down a pipe: it is read by the same parser and '
            'held to the same invariants.',
            style: MiType.caption.copyWith(color: c.inkMuted),
          ),
          // The turn itself, for when the clipboard fails or the client wants
          // to see what is being said in their name.
          MiDisclosure(
            label: 'What this turn says',
            child: SelectableText(
              turn.prompt,
              style: MiType.mono.copyWith(color: c.inkMuted),
            ),
          ),
          const SizedBox(height: MiSpace.sm),
          MiWriting(
            controller: _reply,
            hint: 'Everything the reply said.',
            onSubmit: _look,
          ),
          if (read != null) ...<Widget>[
            const SizedBox(height: MiSpace.sm),
            MiRecord(
              label: 'Read back',
              value: read.foundNothing
                  ? 'Nothing the council could use. If the reply was cut off, '
                        'fetch the rest before accepting it: a truncated paste '
                        'accepted here is recorded as a seat with nothing to '
                        'say, which is what takes a run to dryness.'
                  : '${read.blocks.length} block(s): '
                        '${read.blocks.map((CouncilBlock b) => b.kind).toSet().join(', ')}'
                        '${read.unread.isEmpty ? '' : ' · ${read.unread.length} line(s) unread'}',
              style: MiType.caption,
            ),
          ],
          const SizedBox(height: MiSpace.sm),
          if (read == null)
            MiButton(label: 'Read it back', expand: true, onPressed: _look)
          else
            Row(
              children: <Widget>[
                Expanded(
                  child: MiButton(
                    label: 'Accept it',
                    kind: MiButtonKind.primary,
                    expand: true,
                    onPressed: _accept,
                  ),
                ),
                const SizedBox(width: MiSpace.sm),
                Expanded(
                  child: MiButton(
                    label: 'Paste again',
                    expand: true,
                    onPressed: () {
                      _reply.clear();
                      setState(() => _read = null);
                    },
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
