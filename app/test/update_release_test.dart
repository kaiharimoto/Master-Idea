import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:master_idea/src/update/release.dart';

/// A GitHub release payload, in the shape the real one comes back in.
Object? release(List<Map<String, Object?>> assets) => jsonDecode(
  jsonEncode(<String, Object?>{
    'html_url': 'https://github.com/kaiharimoto/Master-Idea/releases/tag/dev',
    'assets': assets,
  }),
);

Map<String, Object?> asset(
  String name, {
  int size = 42 * 1024 * 1024,
}) => <String, Object?>{
  'name': name,
  'browser_download_url':
      'https://github.com/kaiharimoto/Master-Idea/releases/download/dev/$name',
  'size': size,
};

void main() {
  group('reading the rolling release', () {
    test('finds the Android build and reports it as newer', () {
      final UpdateCheck c = readRelease(
        release(<Map<String, Object?>>[asset('MasterIdea-57-a1b2c3d.apk')]),
        currentBuild: '56',
        platform: UpdatePlatform.android,
      );
      expect(c.outcome, UpdateOutcome.available);
      expect(c.asset!.build, 57);
      expect(c.asset!.kind, AssetKind.apk);
      expect(c.asset!.size, '42.0 MB');
    });

    test('compares build numbers numerically, not as strings', () {
      final UpdateCheck c = readRelease(
        release(<Map<String, Object?>>[asset('MasterIdea-100-a1b2c3d.apk')]),
        currentBuild: '99',
        platform: UpdatePlatform.android,
      );
      expect(
        c.outcome,
        UpdateOutcome.available,
        reason:
            'A string comparison puts "100" before "99" and reports a newer '
            'build as older, forever.',
      );
    });

    test('prefers the installer over the zip within one build', () {
      final UpdateCheck c = readRelease(
        release(<Map<String, Object?>>[
          asset('MasterIdea-windows-x64-57-a1b2c3d.zip'),
          asset('MasterIdeaSetup-57-a1b2c3d.exe'),
        ]),
        currentBuild: '56',
        platform: UpdatePlatform.windows,
      );
      expect(
        c.asset!.kind,
        AssetKind.installer,
        reason:
            'The installer is the one that can update the app without the '
            'user handling a file at all.',
      );
    });

    test('still recognises the zip when that is all there is', () {
      final UpdateCheck c = readRelease(
        release(<Map<String, Object?>>[
          asset('MasterIdea-windows-x64-57-a1b2c3d.zip'),
        ]),
        currentBuild: '56',
        platform: UpdatePlatform.windows,
      );
      expect(c.asset!.kind, AssetKind.archive);
    });

    test('says so when the release has nothing for this platform', () {
      final UpdateCheck c = readRelease(
        release(<Map<String, Object?>>[asset('MasterIdea-57-a1b2c3d.apk')]),
        currentBuild: '56',
        platform: UpdatePlatform.windows,
      );
      expect(c.outcome, UpdateOutcome.noAsset);
      expect(c.detail, contains('Windows'));
      expect(
        c.releaseUrl,
        isNotNull,
        reason: 'The client can still be handed the release page.',
      );
    });

    test('a local build is told what is published, not that it is behind', () {
      final UpdateCheck c = readRelease(
        release(<Map<String, Object?>>[asset('MasterIdea-57-a1b2c3d.apk')]),
        currentBuild: 'local',
        platform: UpdatePlatform.android,
      );
      expect(c.outcome, UpdateOutcome.unknownBuild);
      expect(c.isUpdate, isFalse);
      expect(c.asset, isNotNull);
    });

    test('the running build is not offered to itself', () {
      final UpdateCheck c = readRelease(
        release(<Map<String, Object?>>[asset('MasterIdea-57-a1b2c3d.apk')]),
        currentBuild: '57',
        platform: UpdatePlatform.android,
      );
      expect(c.outcome, UpdateOutcome.upToDate);
      expect(c.isUpdate, isFalse);
    });

    test(
      'an unreadable page is reported rather than treated as up to date',
      () {
        final UpdateCheck c = readRelease(
          'not json at all',
          currentBuild: '57',
          platform: UpdatePlatform.android,
        );
        expect(
          c.outcome,
          UpdateOutcome.unreadable,
          reason:
              'Offline must never look like "you are on the newest build" — '
              'that is how a device sits on a broken build for a month.',
        );
      },
    );

    test('an asset from another program is not mistaken for one of ours', () {
      final UpdateCheck c = readRelease(
        release(<Map<String, Object?>>[asset('MasterPrompt-57-a1b2c3d.apk')]),
        currentBuild: '56',
        platform: UpdatePlatform.android,
      );
      expect(
        c.outcome,
        UpdateOutcome.noAsset,
        reason:
            'The two halves of this pair publish similarly named files, and '
            'installing the wrong one would replace the app with the other '
            'program.',
      );
    });
  });
}
