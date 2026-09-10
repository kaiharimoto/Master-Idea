/// `1 direction`, `2 directions`.
///
/// Small, and worth having in one place: an interface that says "1 directions"
/// reads as careless, and a council's whole claim is that it is careful.
String countOf(int n, String noun, {String? plural}) =>
    '$n ${n == 1 ? noun : (plural ?? '${noun}s')}';
