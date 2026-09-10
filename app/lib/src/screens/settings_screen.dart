import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  @override
  void dispose() {
    _path.dispose();
    _model.dispose();
    super.dispose();
  }

  Future<void> _testCouncil() async {
    setState(() => _probe = 'Looking…');
    try {
      final CouncilSession s = await openCouncil(
        settings: widget.library.settings,
        sessionId: 'probe',
      );
      setState(
        () => _probe =
            'Answered: ${s.install.capabilities.version} at ${s.install.path}',
      );
    } on NoCouncil catch (e) {
      setState(() => _probe = '$e');
    } on Object catch (e) {
      setState(() => _probe = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final MiColors c = MiTheme.colorsOf(context);
    final Settings s = widget.library.settings;

    return SingleChildScrollView(
      child: MiLeaf(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const MiEyebrow('Settings'),
            const SizedBox(height: MiSpace.lg),
            Text('Appearance', style: MiType.title.copyWith(color: c.ink)),
            const SizedBox(height: MiSpace.sm),
            Wrap(
              spacing: MiSpace.sm,
              children: <Widget>[
                for (final ThemeMode m in ThemeMode.values)
                  MiAction(
                    label: switch (m) {
                      ThemeMode.system => 'Follow the system',
                      ThemeMode.light => 'Daylight',
                      ThemeMode.dark => 'Lamplight',
                    },
                    secondary: s.themeMode != m,
                    onPressed: () =>
                        widget.library.updateSettings(s.copyWith(themeMode: m)),
                  ),
              ],
            ),
            const SizedBox(height: MiSpace.xl),
            MiRule(strong: true),
            const SizedBox(height: MiSpace.lg),
            Text('The council', style: MiType.title.copyWith(color: c.ink)),
            const SizedBox(height: MiSpace.xs),
            Text(
              canDriveCouncil
                  ? 'This machine can drive a sitting on its own through the '
                        'Claude CLI. Leave the path empty and it will ask the '
                        'operating system where the CLI is.'
                  : 'A phone has no CLI, so every turn here is carried by hand. '
                        'A sitting on this device is never unattended.',
              style: MiType.prose.copyWith(color: c.inkMuted),
            ),
            const SizedBox(height: MiSpace.md),
            MiWriting(
              controller: _path,
              minLines: 1,
              maxLines: 2,
              hint: 'An explicit path to the claude binary.',
            ),
            const SizedBox(height: MiSpace.xs),
            Text(
              'A directive, not a hint: when this is set it is used alone, so '
              'a wrong path is reported rather than silently bypassed by a '
              'working install somewhere else.',
              style: MiType.caption.copyWith(color: c.inkMuted),
            ),
            const SizedBox(height: MiSpace.md),
            MiWriting(
              controller: _model,
              minLines: 1,
              maxLines: 1,
              hint: 'A model alias — opus, sonnet, haiku — or nothing.',
            ),
            const SizedBox(height: MiSpace.xs),
            Text(
              'Empty sends no model flag at all, leaving the CLI on whatever '
              'you chose with /model. The flag lists no choices, so a bad one '
              'cannot be caught before it fails a turn.',
              style: MiType.caption.copyWith(color: c.inkMuted),
            ),
            const SizedBox(height: MiSpace.md),
            Row(
              children: <Widget>[
                MiAction(
                  label: 'Save',
                  onPressed: () => widget.library.updateSettings(
                    s.copyWith(
                      claudePath: _path.text.trim(),
                      model: _model.text.trim(),
                    ),
                  ),
                ),
                const SizedBox(width: MiSpace.md),
                MiAction(
                  label: 'Test the connection',
                  secondary: true,
                  onPressed: _testCouncil,
                ),
              ],
            ),
            if (_probe != null) ...<Widget>[
              const SizedBox(height: MiSpace.sm),
              Text(
                _probe!,
                style: MiType.caption.copyWith(color: c.inkMuted),
              ),
            ],
            const SizedBox(height: MiSpace.xl),
            MiRule(strong: true),
            const SizedBox(height: MiSpace.lg),
            Text('This build', style: MiType.title.copyWith(color: c.ink)),
            const SizedBox(height: MiSpace.sm),
            MiRecord(label: 'Version', value: BuildInfo.label),
            MiRecord(
              label: 'Platform',
              value: '${BuildInfo.platform} · ${BuildInfo.osVersion}',
            ),
            const SizedBox(height: MiSpace.md),
            MiAction(
              label: 'Copy diagnostics',
              secondary: true,
              onPressed: () => Clipboard.setData(
                ClipboardData(text: Diagnostics.instance.report()),
              ),
            ),
            const SizedBox(height: MiSpace.xxl),
          ],
        ),
      ),
    );
  }
}
