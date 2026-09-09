import 'package:meta/meta.dart';

/// How two selected directions bear on each other.
@immutable
class Interaction {
  const Interaction({
    required this.a,
    required this.b,
    required this.kind,
    required this.because,
  });

  final String a;
  final String b;

  /// `reinforces` or `conflicts`.
  final String kind;

  final String because;

  bool get isConflict => kind == 'conflicts';

  Map<String, Object?> toJson() => <String, Object?>{
    'a': a,
    'b': b,
    'kind': kind,
    'because': because,
  };

  static Interaction fromJson(Map<String, Object?> j) => Interaction(
    a: '${j['a']}',
    b: '${j['b']}',
    kind: '${j['kind']}',
    because: '${j['because']}',
  );
}

/// What a selected set of directions becomes together.
///
/// Computed **across the selection**, never written into individual
/// directions. That is the whole reason Assembly exists as a stage: a dossier
/// of forty good directions each carrying its own integration story is forty
/// stories, and the client still has to do the work of seeing what their five
/// choices add up to.
///
/// An integration is bound to the exact selection it was computed for.
/// Changing the selection invalidates it — [isStaleFor] — rather than leaving
/// a plausible paragraph on screen describing a set the client no longer has.
@immutable
class Integration {
  const Integration({
    required this.forSelection,
    required this.becomes,
    required this.interactions,
    required this.by,
    required this.computedAt,
  });

  /// The direction ids this was computed over, sorted.
  final List<String> forSelection;

  /// What the combined thing is, in the integrator's own words.
  final String becomes;

  final List<Interaction> interactions;

  /// The integrator instance that computed it.
  final String by;

  final DateTime computedAt;

  List<Interaction> get reinforcements =>
      interactions.where((Interaction i) => !i.isConflict).toList();

  List<Interaction> get conflicts =>
      interactions.where((Interaction i) => i.isConflict).toList();

  bool isStaleFor(List<String> selection) {
    final List<String> now = <String>[...selection]..sort();
    return now.join(',') != forSelection.join(',');
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'forSelection': forSelection,
    'becomes': becomes,
    'interactions': interactions.map((Interaction i) => i.toJson()).toList(),
    'by': by,
    'computedAt': computedAt.toIso8601String(),
  };

  static Integration fromJson(Map<String, Object?> j) => Integration(
    forSelection: (j['forSelection']! as List<Object?>)
        .map((Object? e) => '$e')
        .toList(),
    becomes: '${j['becomes']}',
    interactions: (j['interactions'] as List<Object?>? ?? const <Object?>[])
        .map((Object? e) => Interaction.fromJson(e! as Map<String, Object?>))
        .toList(),
    by: '${j['by']}',
    computedAt: DateTime.parse('${j['computedAt']}'),
  );
}
