/// U+2060 WORD JOINER: a zero-width, invisible character that forbids a line
/// break on either side of it.
const String kWordJoiner = '⁠';

/// Korean "word-break: keep-all" for Flutter [Text]: inserts [kWordJoiner]
/// between the characters of every space-separated word so lines can only
/// break at spaces, never inside a word (no single-syllable orphans like
/// "…날이에" / "요."). Spaces are kept as-is. A word wider than the whole
/// line still falls back to a character break, so nothing overflows.
///
/// Pair with `semanticsLabel: original` on the [Text] so screen readers get
/// the plain string.
String keepAll(String s) {
  return s
      .split(' ')
      .map((word) => word.runes.map(String.fromCharCode).join(kWordJoiner))
      .join(' ');
}
