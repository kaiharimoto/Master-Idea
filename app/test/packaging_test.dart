import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The two strings that decide where a Windows install keeps its sessions.
///
/// `path_provider_windows` builds `getApplicationSupportDirectory()` as
/// `RoamingAppData\<CompanyName>\<ProductName>`, read out of the running
/// exe's VERSIONINFO at runtime. Editing either silently relocates every
/// stored session, and the app starts up empty with nothing anywhere saying
/// why. It is the one rule in this repository that is invisible when broken,
/// and it was the one rule with no check.
void main() {
  test('the Windows resource strings are the ones the store depends on', () {
    final String rc = File('windows/runner/Runner.rc').readAsStringSync();
    expect(
      rc,
      contains('VALUE "CompanyName", "Master Idea"'),
      reason:
          'Changed, every session already stored becomes unreachable — and '
          'nothing on screen says so.',
    );
    expect(rc, contains('VALUE "ProductName", "Master Idea"'));
  });

  test('the Android manifest can still install a build and reach the net', () {
    final String manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    expect(
      manifest,
      contains('android.permission.INTERNET'),
      reason: 'Only the debug and profile manifests declare it otherwise.',
    );
    expect(
      manifest,
      contains('android.permission.REQUEST_INSTALL_PACKAGES'),
      reason: 'Without it the app cannot even ask to install its own update.',
    );
    expect(
      manifest,
      contains('android:enableOnBackInvokedCallback="true"'),
      reason:
          'Predictive back is the gesture on every current Android build, and '
          'the shell handles back itself.',
    );
  });

  test('the file provider exposes the two cache directories and no more', () {
    final String paths = File(
      'android/app/src/main/res/xml/file_paths.xml',
    ).readAsStringSync();
    expect(paths, contains('path="updates/"'));
    expect(paths, contains('path="handover/"'));
    expect(
      paths,
      isNot(contains('<files-path')),
      reason:
          'A provider over internal storage would hand every stored session — '
          'every interview answer the client gave — to any app holding the '
          'URI.',
    );
  });
}
