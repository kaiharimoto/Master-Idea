import 'dart:async';

import 'package:mi_core/mi_core.dart';

/// A council that answers from a script, with no process anywhere.
///
/// Enough of one to drive a whole sitting: it proposes on the first round,
/// traces every direction to an answer the prompt actually put in front of it,
/// and then says `mi-none` so the run reaches dryness instead of running for
/// as long as the test is willing to wait.
class ScriptedCouncil implements CouncilTransport {
  ScriptedCouncil({this.silentFromRound = 2, this.failOnCall, this.stopOnCall});

  final int silentFromRound;

  /// Fail for a reason that is not a limit, the way an expired login does.
  final int? failOnCall;

  /// The client stopped.
  final int? stopOnCall;

  int calls = 0;
  final List<CouncilTurn> seen = <CouncilTurn>[];

  @override
  Future<CouncilReply> ask(CouncilTurn turn) async {
    calls++;
    seen.add(turn);
    if (failOnCall == calls) {
      throw CouncilUnavailable('The CLI exited with 1: not logged in');
    }
    if (stopOnCall == calls) throw CouncilStopped(DateTime.utc(2026));

    switch (turn.purpose) {
      case 'propose':
        if (turn.agent.round >= silentFromRound) {
          return const CouncilReply(text: 'mi-none');
        }
        final String angle = turn.conversation.split('-').skip(2).join('-');
        // A different answer per angle. Two directions may share one only if
        // each also names a gap of its own, so a double that cited the same
        // answer everywhere would fail traceability for reasons that have
        // nothing to do with what is being tested.
        final String answer = _answerFor(angle, turn.prompt);
        return CouncilReply(
          text:
              'mi-direction\n'
              'cluster=What the thing is for\n'
              'ambition=ambitious\n'
              'title=Direction from $angle\n'
              'statement=Do the $angle thing, which nothing else here does.\n'
              'mechanism=Concretely, $angle is built first and the rest '
              'follows from it.\n'
              'trace-answer=$answer\n'
              'quote=the idea as the client first said it\n'
              'end',
          tokensIn: 100,
          tokensOut: 40,
        );
      case 'challenge':
        return const CouncilReply(
          text:
              'mi-challenge\n'
              'attack=The mechanism needs an audience that does not exist.\n'
              'fatal=no\n'
              'end',
        );
      case 'rate':
        final List<String> rungs = _rungsIn(turn.prompt);
        return CouncilReply(
          text:
              'mi-rating\n'
              'verdict=${rungs[rungs.length ~/ 2]}\n'
              'because=Judged on what is written, not on who wrote it.\n'
              'end',
        );
      case 'integrate':
        return const CouncilReply(
          text:
              'mi-integration\n'
              'becomes=One proceeding rather than a pile of options.\n'
              'end',
        );
      default:
        return const CouncilReply(text: 'mi-none');
    }
  }

  static String _answerFor(String angle, String prompt) {
    final List<String> ids = RegExp(
      r'^\[([a-z-]+)\]',
      multiLine: true,
    ).allMatches(prompt).map((RegExpMatch m) => m.group(1)!).toList();
    if (ids.isEmpty) return 'raw-idea';
    return ids[angle.hashCode.abs() % ids.length];
  }

  static List<String> _rungsIn(String prompt) {
    final List<String> lines = prompt.split('\n');
    final int i = lines.indexWhere(
      (String l) => l.trim() == 'ANSWER WITH EXACTLY ONE OF',
    );
    if (i < 0) return const <String>['specified'];
    return lines[i + 1].split(',').map((String s) => s.trim()).toList();
  }
}
