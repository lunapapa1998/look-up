/// Shortens an eBird-style spot name for display.
///
/// eBird hotspot names come as "인천--수봉공원(Incheon--Subong Park)" — a
/// region prefix + a Korean name + an English name in parentheses. The owner
/// wants just the bare place name ("수봉공원") on the map and in lists:
///   1. drop everything from the first "(" onward (the English translation),
///   2. drop the region prefix before the last "--".
///
/// Names without "(" or "--" pass through unchanged; if stripping would leave
/// an empty string, the original is returned (defensive).
String shortSpotName(String name) {
  var s = name.split('(').first.trim();
  if (s.contains('--')) {
    s = s.split('--').last.trim();
  }
  return s.isEmpty ? name : s;
}
