import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mi_core/mi_core.dart';
import 'package:mi_design/mi_design.dart';

import '../store/build_info.dart';
import '../store/diagnostics.dart';
import '../store/library.dart';
import '../store/settings.dart';
import '../transport/council_session.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({required this.library, super.key});

  final Library library;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _path = TextEditingController(
    text: widget.library.settings.claudePath,
  );
  late final TextEditingController _model = TextEditingController(
    text: widget.library.settings.model,
  );
  String? _probe;
  bool _probing = false;

  @override
  void dispose() {
    _path.dispose();
    _model.dispose();
    super.dispose();
  }

  Settings get _typed => widget.library.settings.copyWith(
    claudePath: _path.text.trim(),
    model: _model.text.trim(),
  );

  /// Find the CLI **and put a turn through it**.
  ///
  /// Locating the binary proves almost nothing: the failures that actually
  /// end a sitting are an expired login and a model name the CLI does not
  /// know, and neither is visible until something is asked of it. This asks
  /// the smallest thing there is, against the settings as typed rather than as
  /// last saved — typing a correct path and pressing Test used to report the
  /// old one as broken.
  Future<void> _testCouncil() async {
    setState(() {
      _probing = true;
      _probe = 'Looking…';
    });
    try {
      final CouncilSession s = await openCouncil(
        settings: _typed,
        sessionId: 'probe',
      );
      setState(
        () => _probe =
            'Found ${s.install.capabilities.version} at ${s.install.path}. '
            'Asking it something…',
      );
      final CouncilReply reply = await s.council.ask(
        const CouncilTurn(
          agent: AgentInstance(roleId: 'clerk', round: 0, ordinal: 1),
          purpose: 'probe',
          prompt:
              'Reply with exactly this and nothing else:\n'
              'mi-none',
          conversation: 'probe',
        ),
      );
      final String said = reply.text.trim().split('\n').first;
      setState(
        () => _probe =
            'It answered: ${said.isEmpty ? '(nothing)' : said}. '
            '${s.install.capabilities.version} at ${s.install.path}.',
      );
    } on NoCouncil catch (e) {
      setState(() => _probe = '$e');
    } on CouncilUnavailable catch (e) {
      setState(() => _probe = e.detail);
    } on CouncilPaused catch (e) {
      setState(
        () => _probe =
            'The provider is holding a ${e.kind} limit until '
            '${e.until.toLocal()}. The CLI itself is fine.',
      );
    } on Object catch (e) {
      setState(() => _probe = '$e');
    } finally {
      if (mounted) setState(() => _probing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final MiColors c = MiTheme.colorsOf(context);
    final Settings s = widget.library.settings;

    return SingleChildScrollView(
      child: MiLeaf(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const MiSectionHeader(title: 'Appearance'),
            const SizedBox(height: MiSpace.md),
            Wrap(
              spacing: MiSpace.sm,
              runSpacing: MiSpace.sm,
              children: <Widget>[
                for (final ThemeMode m in ThemeMode.values)
                  MiButton(
                    label: switch (m) {
                      ThemeMode.system => 'Follow the system',
                      ThemeMode.light => 'Light',
                      ThemeMode.dark => 'Dark',
                    },
                    kind: s.themeMode == m
                        ? MiButtonKind.primary
                        : MiButtonKind.secondary,
                    onPressed: () =>
                        widget.library.updateSettings(s.copyWith(themeMode: m)),
                  ),
              ],
            ),

            const SizedBox(height: MiSpace.xxl),
            MiSectionHeader(
              title: 'The council',
              subtitle: canDriveCouncil
                  ? 'This machine can drive a sitting on its own through the '
                        'Claude CLI. Leave the path empty and it asks the '
                        'operating system where the CLI is.'
                  : 'A phone has no CLI, so every turn here is carried by '
                        'hand. A sitting on this device is never unattended.',
            ),
            const SizedBox(height: MiSpace.md),
            // The panel is hidden where it can do nothing. A path field and a
            // connection test on a phone are two controls that cannot affect
            // anything, offered next to a line saying so.
            if (canDriveCouncil)
              MiPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    MiField(
                      label: 'Path to the CLI',
                      child: MiWriting(
                        controller: _path,
                        minLines: 1,
                        maxLines: 2,
                        hint: 'Empty asks the operating system.',
                      ),
                    ),
                    const SizedBox(height: MiSpace.xs),
                    Text(
                      'A directive, not a hint: when this is set it is used '
                      'alone, so a wrong path is reported rather than silently '
                      'bypassed by a working install somewhere else.',
                      style: MiType.caption.copyWith(color: c.inkMuted),
                    ),
                    const SizedBox(height: MiSpace.lg),
                    MiField(
                      label: 'Model',
                      child: MiWriting(
                        controller: _model,
                        minLines: 1,
                        maxLines: 1,
                        hint: 'opus, sonnet, haiku — or nothing.',
                      ),
                    ),
                    const SizedBox(height: MiSpace.xs),
                    Text(
                      'Empty sends no model flag at all, leaving the CLI on '
                      'whatever you chose with /model. The flag lists no '
                      'choices, so a bad one cannot be caught before it is '
                      'tried — which is what the test below is for.',
                      style: MiType.caption.copyWith(color: c.inkMuted),
                    ),
                    const SizedBox(height: MiSpace.lg),
                    MiField(
                      label: 'Turns at once',
                      child: Wrap(
                        spacing: MiSpace.sm,
                        runSpacing: MiSpace.sm,
                        children: <Widget>[
                          for (final int n in <int>[1, 2, 4, 6, 8])
                            MiButton(
                              label: '$n',
                              kind: s.concurrentTurns == n
                                  ? MiButtonKind.primary
                                  : MiButtonKind.secondary,
                              onPressed: () => widget.library.updateSettings(
                                s.copyWith(concurrentTurns: n),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: MiSpace.xs),
                    Text(
                      'How many turns the council may have in the air at once. '
                      'A round at the largest tier would otherwise start some '
                      'fifty processes together, which is itself the '
                      'commonest way to provoke a rate limit. It changes '
                      'nothing about how wide the council searches.',
                      style: MiType.caption.copyWith(color: c.inkMuted),
                    ),
                    const SizedBox(height: MiSpace.lg),
                    Wrap(
                      spacing: MiSpace.sm,
                      runSpacing: MiSpace.sm,
                      children: <Widget>[
                        MiButton(
                          label: 'Save',
                          kind: MiButtonKind.primary,
                          onPressed: () async {
                            await widget.library.updateSettings(_typed);
                            if (context.mounted) miNotice(context, 'Saved');
                          },
                        ),
                        MiButton(
                          label: 'Test the connection',
                          busy: _probing,
                          onPressed: _probing ? null : _testCouncil,
                        ),
                      ],
                    ),
                    if (_probe != null) ...<Widget>[
                      const SizedBox(height: MiSpace.md),
                      Text(
                        _probe!,
                        style: MiType.caption.copyWith(color: c.inkMuted),
                      ),
                    ],
                  ],
                ),
              ),

            const SizedBox(height: MiSpace.xxl),
            const MiSectionHeader(title: 'This build'),
            const SizedBox(height: MiSpace.md),
            MiPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  MiField(
                    label: 'Version',
                    child: Text(
                      BuildInfo.label,
                      style: MiType.numeric.copyWith(color: c.ink),
                    ),
                  ),
                  const SizedBox(height: MiSpace.md),
                  MiField(
                    label: 'Platform',
                    child: Text(
                      '${BuildInfo.platform} · ${BuildInfo.osVersion}',
                      style: MiType.body.copyWith(color: c.ink),
                    ),
                  ),
                  const SizedBox(height: MiSpace.md),
                  MiField(
                    label: 'Where builds come from',
                    child: SelectableText(
                      BuildInfo.releasePage,
                      style: MiType.mono.copyWith(color: c.inkMuted),
                    ),
                  ),
                  const SizedBox(height: MiSpace.lg),
                  MiButton(
                    label: 'Copy diagnostics',
                    onPressed: () async {
                      await Clipboard.setData(
                        ClipboardData(text: Diagnostics.instance.report()),
                      );
                      if (context.mounted) {
                        miNotice(context, 'Copied — paste it into the chat');
                      }
                    },
                  ),
                  // Readable before it is copied. Four hundred lines the
                  // client can only send blind is a report neither of us can
                  // discuss.
                  MiDisclosure(
                    label: 'What it says',
                    trailingNote: '${Diagnostics.instance.lines.length}',
                    child: SelectableText(
                      Diagnostics.instance.report(),
                      style: MiType.mono.copyWith(color: c.inkMuted),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: MiSpace.xxl),
          ],
        ),
      ),
    );
  }
}
