import 'dart:io';

import 'package:master_idea/src/update/release.dart';
import 'package:master_idea/src/update/updater.dart';

/// An updater that never reaches the network.
///
/// A widget test that let the real one run would depend on GitHub being up,
/// which is the definition of a flaky test about an interface.
class OfflineTransport implements UpdateTransport {
  @override
  Future<Object?> fetch(Uri url) async => throw Exception('offline in tests');

  @override
  Future<void> download(
    Uri url,
    File target,
    void Function(int received, int total) onProgress,
  ) async {}

  @override
  Future<InstallOutcome> install(File file) async => InstallOutcome.manual;

  @override
  Future<Directory> workspace() async => throw Exception('offline in tests');
}

Updater offlineUpdater() => Updater(
  transport: OfflineTransport(),
  platform: UpdatePlatform.other,
  currentBuild: 'local',
);
