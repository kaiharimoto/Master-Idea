import 'package:flutter/material.dart';
import 'package:mi_design/mi_design.dart';

import 'screens/home.dart';
import 'store/diagnostics.dart';
import 'store/library.dart';
import 'update/updater.dart';

/// True where a window is wide enough for the rail and a region side by side.
///
/// A **layout** gate and never a platform check — those are different
/// questions. Whether the Claude CLI can be driven is a fact about the
/// platform; whether two columns fit is a fact about the window. Confusing
/// them gives a narrow window on a desktop the phone experience, and a tablet
/// a Run button it cannot use.
bool isWide(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= MiSpace.wideGate;

class MasterIdeaApp extends StatefulWidget {
  const MasterIdeaApp({this.library, this.updater, super.key});

  /// Injected by tests. The app builds its own.
  final Library? library;
  final Updater? updater;

  @override
  State<MasterIdeaApp> createState() => _MasterIdeaAppState();
}

class _MasterIdeaAppState extends State<MasterIdeaApp> {
  late final Library _library = widget.library ?? Library();
  late final Updater _updater = widget.updater ?? Updater();

  @override
  void initState() {
    super.initState();
    _library.load().catchError((Object e) {
      Diagnostics.instance.log('The library could not be read: $e');
    });
    // Silent on purpose. Someone opening the app to put an idea before the
    // council should not be met by a network error; the menu grows a mark if
    // there is anything to say and stays quiet if there is not.
    _updater.checkQuietly();
    // A silent installer that fails is silent, and the app coming back
    // unchanged looks exactly like an update that was never taken.
    _updater.lastInstallProblem().then((String? problem) {
      if (problem != null) Diagnostics.instance.log(problem);
    });
  }

  @override
  void dispose() {
    _updater.dispose();
    _library.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _library,
      builder: (BuildContext context, _) {
        return MaterialApp(
          title: 'Master Idea',
          debugShowCheckedModeBanner: false,
          themeMode: _library.settings.themeMode,
          theme: buildMiTheme(MiColors.light, dark: false),
          darkTheme: buildMiTheme(MiColors.dark, dark: true),
          builder: (BuildContext context, Widget? child) {
            final bool dark = Theme.of(context).brightness == Brightness.dark;
            return MiTheme(
              colors: dark ? MiColors.dark : MiColors.light,
              isDark: dark,
              child: child ?? const SizedBox.shrink(),
            );
          },
          home: HomeScreen(library: _library, updater: _updater),
        );
      },
    );
  }
}
