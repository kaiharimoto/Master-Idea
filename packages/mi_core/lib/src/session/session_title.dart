/// A short name for a session, taken from the client's approved brief.
///
/// The first attempt used the brief's opening sentence whole, which produced a
/// session called *An essay arguing that unattended machine work is only
/// trustworthy when its reasoning is auditable afterwards by someone who was
/// not there* — and a directory name to match. A title is for recognising one
/// session among several in a list; the brief is what carries the meaning, and
/// it is two lines further down every screen that shows the title.
abstract final class SessionTitle {
  /// Enough to recognise, cut at a word boundary.
  static String from(String brief, {int limit = 56}) {
    final String flat = brief.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (flat.isEmpty) return 'Untitled session';
    final String sentence = flat.split(RegExp(r'(?<=[.!?])\s')).first.trim();
    final String base = sentence.endsWith('.')
        ? sentence.substring(0, sentence.length - 1)
        : sentence;
    if (base.length <= limit) return base;
    final int cut = base.lastIndexOf(' ', limit);
    return '${base.substring(0, cut > 20 ? cut : limit).trimRight()}…';
  }

  /// The kebab-case form used for the session directory.
  static String slug(String title) {
    final String base = title
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    return base.isEmpty ? 'session' : base;
  }
}
