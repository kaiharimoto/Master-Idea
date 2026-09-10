import 'package:mi_core/mi_core.dart';

/// Names for things a stored session refers to by id.
///
/// A session written by another build — an older one, a newer one, or the
/// command line with a catalog that has since moved — can name a tier or a
/// module this build does not have. The strict lookups throw, and they are
/// called while a list is being built: one such session used to red-screen the
/// sessions library and take every other session on it down. A screen prints
/// the id rather than refusing to render, which is both honest and survivable.
/// A **run** still uses the strict lookups, because a run that guessed at a
/// tier would be running at a breadth nobody chose.
String tierName(ScaleVerdict v) =>
    templateByIdOrNull(v.templateId)?.name ?? v.templateId;

String tierExpectation(ScaleVerdict v) =>
    templateByIdOrNull(v.templateId)?.expectation ??
    'This session names a tier this build does not have, so how long it '
        'should run is not something this copy can say.';
