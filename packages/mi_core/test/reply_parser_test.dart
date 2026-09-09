import 'package:mi_core/mi_core.dart';
import 'package:test/test.dart';

void main() {
  group('the block grammar survives what a real reply looks like', () {
    test('reads a plain block', () {
      final ParsedReply r = CouncilReplyParser.parse('''
mi-direction
cluster=What it is for
ambition=reckless
title=Sell the archive
statement=Give the case file away and charge for the index.
mechanism=The index is regenerated per client, the archive is static.
trace-answer=ceiling
quote=as far as it possibly could go
end
''');
      expect(r.of('mi-direction'), hasLength(1));
      expect(r.of('mi-direction').first.get('title'), 'Sell the archive');
    });

    test('reads a block wrapped in prose, fences and bullets', () {
      final ParsedReply r = CouncilReplyParser.parse('''
Here is what my angle found. I have kept it short.

```
- mi-direction
- cluster=What it refuses
- **ambition**=conservative
- title=Refuse the second draft
- statement=The tool never edits its own output.
- mechanism=Every stage writes once and is read-only afterwards.
- trace-answer=constraints
- quote=only the ones that are actually immovable
- end
```

That is all I have.
''');
      expect(r.of('mi-direction'), hasLength(1));
      expect(r.of('mi-direction').first.get('ambition'), 'conservative');
    });

    test('keeps a block whose closing line never arrived', () {
      final ParsedReply r = CouncilReplyParser.parse('''
mi-direction
title=Cut off mid-sentence
statement=The reply stopped here because a limit landed.
mechanism=Nothing follows.
''');
      expect(
        r.of('mi-direction'),
        hasLength(1),
        reason:
            'A missing `end` is the commonest way a reply is truncated, and '
            'throwing the block away turns one lost line into a lost '
            'direction.',
      );
    });

    test('keeps nine good blocks when the tenth is broken', () {
      final StringBuffer b = StringBuffer();
      for (int i = 0; i < 9; i++) {
        b
          ..writeln('mi-direction')
          ..writeln('title=Direction $i')
          ..writeln('statement=Something specific number $i.')
          ..writeln('end');
      }
      b
        ..writeln('mi-direction')
        ..writeln('title=The one that was cut');
      final ParsedReply r = CouncilReplyParser.parse(b.toString());
      expect(r.of('mi-direction'), hasLength(10));
    });

    test('folds a wrapped paragraph into the field above it', () {
      final ParsedReply r = CouncilReplyParser.parse('''
mi-direction
title=Long mechanism
mechanism=First the index is built,
then the archive is frozen,
and only then is anything shown.
end
''');
      expect(r.of('mi-direction').first.get('mechanism'), contains('frozen'));
    });

    test('keeps what it could not read rather than dropping it', () {
      final ParsedReply r = CouncilReplyParser.parse('''
mi-direction
This line is prose with no field at all, before any key.
title=Something
end
''');
      expect(r.unread, isNotEmpty);
      expect(r.raw, contains('This line is prose'));
    });

    test('reads a refusal to propose as a real answer', () {
      final ParsedReply r = CouncilReplyParser.parse(
        'My angle is exhausted.\n\nmi-none\n',
      );
      expect(r.of('mi-none'), hasLength(1));
      expect(r.of('mi-direction'), isEmpty);
    });

    test('keeps repeated integration lines apart', () {
      final ParsedReply r = CouncilReplyParser.parse('''
mi-integration
becomes=One proceeding rather than three tools.
reinforces=d-1|d-2|Both assume the client is absent.
reinforces=d-2|d-3|Both need the ledger to be readable in thirty seconds.
conflicts=d-1|d-4|One wants six hours, the other wants an afternoon.
end
''');
      final CouncilBlock b = r.of('mi-integration').first;
      expect(b.all('reinforces'), hasLength(2));
      expect(b.all('conflicts'), hasLength(1));
    });
  });
}
