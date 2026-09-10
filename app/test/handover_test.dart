import 'package:flutter_test/flutter_test.dart';
import 'package:master_idea/src/transport/handover_council.dart';
import 'package:mi_core/mi_core.dart';

CouncilTurn turn(String id) => CouncilTurn(
  agent: const AgentInstance(roleId: 'prospector', round: 1, ordinal: 1),
  purpose: 'propose',
  prompt: 'You are a prospector on a council.',
  conversation: id,
);

/// The phone's transport, under the concurrency a real round produces.
///
/// A round fans out four angles at the smallest tier and pipelines every
/// direction through challenge and rating, so the second turn arrives while
/// the first is still on screen. Refusing it with an error ended the sitting —
/// the error is not a pause, so it left the run — after the client had already
/// carried the first turn by hand.
void main() {
  test('turns queue rather than colliding, and are served in order', () async {
    final HandoverCouncil hand = HandoverCouncil();
    final List<String> answered = <String>[];

    final List<Future<void>> asking = <Future<void>>[
      for (final String id in <String>['a', 'b', 'c', 'd'])
        hand.ask(turn(id)).then((CouncilReply r) => answered.add(r.text)),
    ];

    expect(hand.waiting!.conversation, 'a');
    expect(hand.queued, 3, reason: 'The client is told what is behind this.');

    hand.receive('reply to a');
    expect(hand.waiting!.conversation, 'b');
    hand.receive('reply to b');
    hand.receive('reply to c');
    hand.receive('reply to d');
    await Future.wait(asking);

    expect(answered, <String>[
      'reply to a',
      'reply to b',
      'reply to c',
      'reply to d',
    ]);
    expect(hand.carried, 4);
    expect(hand.isWaiting, isFalse);
  });

  test('a stop fails every turn, on screen and behind it', () async {
    final HandoverCouncil hand = HandoverCouncil();
    final List<Future<CouncilReply>> asking = <Future<CouncilReply>>[
      hand.ask(turn('a')),
      hand.ask(turn('b')),
    ];

    hand.stop();

    for (final Future<CouncilReply> f in asking) {
      await expectLater(
        f,
        throwsA(isA<CouncilStopped>()),
        reason:
            'A stop is the client. Signalled as a pause it was waited out and '
            'retried, so the same turn came back on screen while the '
            'interface believed the sitting had ended.',
      );
    }
    await expectLater(hand.ask(turn('c')), throwsA(isA<CouncilStopped>()));
    expect(hand.isWaiting, isFalse);
  });

  test('a whole round can be carried by hand', () async {
    final HandoverCouncil hand = HandoverCouncil();
    hand.addListener(() {
      final CouncilTurn? t = hand.waiting;
      if (t == null) return;
      // Answer whatever is on screen, the way a client would.
      Future<void>.microtask(
        () => hand.receive(
          t.purpose == 'propose'
              ? 'mi-none'
              : 'mi-rating\nverdict=specified\nbecause=nothing\nend',
        ),
      );
    });

    // Nothing to assert beyond arriving: before the queue, the second
    // concurrent turn of the first round threw and took the sitting with it.
    final List<CouncilReply> replies = await Future.wait(<Future<CouncilReply>>[
      for (final String id in <String>['a', 'b', 'c', 'd']) hand.ask(turn(id)),
    ]);
    expect(replies, hasLength(4));
  });
}
