import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:master_idea/src/update/release.dart';

/// The release page as GitHub actually served it, trimmed to the fields the
/// updater reads.
///
/// Captured from the live rolling release rather than written by hand. A
/// hand-written payload proves the parser reads the payload someone imagined;
/// this proves it reads the one a phone will actually be handed, with the
/// asset names CI actually produced. If the naming in the workflow and the
/// patterns in `release.dart` ever drift apart, an installed copy silently
/// stops seeing updates forever — and this is the test that fails first.
Object? published() => jsonDecode(
  File('test/fixtures/dev_release.json').readAsStringSync(),
);

void main() {
  group('the release CI actually published', () {
    test('an Android build sees the APK and offers it', () {
      final UpdateCheck c = readRelease(
        published(),
        currentBuild: '3',
        platform: UpdatePlatform.android,
      );
      expect(c.outcome, UpdateOutcome.available, reason: c.detail);
      expect(c.asset!.name, endsWith('.apk'));
      expect(c.asset!.kind, AssetKind.apk);
      expect(c.asset!.bytes, greaterThan(10 * 1024 * 1024),
          reason: 'The size is shown before a download on a metered phone.');
    });

    test('a Windows build is offered the installer, not the zip', () {
      final UpdateCheck c = readRelease(
        published(),
        currentBuild: '3',
        platform: UpdatePlatform.windows,
      );
      expect(c.outcome, UpdateOutcome.available, reason: c.detail);
      expect(c.asset!.kind, AssetKind.installer,
          reason:
              'Both shapes are published; the installer is the one that can '
              'replace the app without the user handling a file.');
      expect(c.asset!.name, endsWith('.exe'));
    });

    test('the build number and commit are read out of the file name', () {
      final UpdateCheck c = readRelease(
        published(),
        currentBuild: '3',
        platform: UpdatePlatform.android,
      );
      expect(c.asset!.build, greaterThan(0));
      expect(c.asset!.sha, hasLength(7));
      expect(
        c.asset!.label('0.1.0'),
        matches(RegExp(r'^0\.1\.0\+\d+ · [0-9a-f]{7}$')),
        reason:
            'It has to read the same way the running build labels itself, or '
            'the two cannot be compared by eye.',
      );
    });

    test('the copy that build published is told it is up to date', () {
      final UpdateCheck first = readRelease(
        published(),
        currentBuild: '3',
        platform: UpdatePlatform.android,
      );
      final UpdateCheck same = readRelease(
        published(),
        currentBuild: '${first.asset!.build}',
        platform: UpdatePlatform.android,
      );
      expect(same.outcome, UpdateOutcome.upToDate);
      expect(same.isUpdate, isFalse,
          reason:
              'An app that offers itself the build it is already running '
              'downloads fifty megabytes for nothing, every launch.');
    });

    test('every published asset is one the updater can name', () {
      final Map<String, Object?> payload =
          published()! as Map<String, Object?>;
      final List<Object?> assets = payload['assets']! as List<Object?>;
      final Set<String> recognised = <String>{
        for (final UpdatePlatform p in <UpdatePlatform>[
          UpdatePlatform.android,
          UpdatePlatform.windows,
        ])
          readRelease(published(), currentBuild: '0', platform: p).asset!.name,
      };
      // The zip is the third: recognised, but never preferred while an
      // installer is there.
      expect(assets, hasLength(3));
      expect(recognised, hasLength(2));
      for (final Object? a in assets) {
        final String name = (a! as Map<String, Object?>)['name']! as String;
        expect(
          RegExp(r'^MasterIdea(Setup)?(-windows-x64)?-\d+-[0-9a-f]{7}\.(apk|exe|zip)$')
              .hasMatch(name),
          isTrue,
          reason:
              '$name does not match any pattern the updater knows, so no '
              'installed copy would ever see it.',
        );
      }
    });
  });
}
