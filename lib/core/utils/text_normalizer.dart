/// Utility class for text normalization used in location matching.
/// Handles accent removal and case-insensitive comparisons.
class TextNormalizer {
  /// Map of accented characters to their non-accented equivalents.
  static const Map<String, String> _accentMap = {
    'á': 'a', 'à': 'a', 'ä': 'a', 'â': 'a', 'ã': 'a',
    'é': 'e', 'è': 'e', 'ë': 'e', 'ê': 'e',
    'í': 'i', 'ì': 'i', 'ï': 'i', 'î': 'i',
    'ó': 'o', 'ò': 'o', 'ö': 'o', 'ô': 'o', 'õ': 'o',
    'ú': 'u', 'ù': 'u', 'ü': 'u', 'û': 'u',
    'ñ': 'n',
    'ç': 'c',
  };

  /// Normalizes text by removing accents and converting to lowercase.
  ///
  /// Examples:
  /// - "Concepción" -> "concepcion"
  /// - "CÓRDOBA" -> "cordoba"
  /// - "San José" -> "san jose"
  static String normalize(String text) {
    if (text.isEmpty) return text;

    return text
        .toLowerCase()
        .split('')
        .map((c) => _accentMap[c] ?? c)
        .join()
        .trim();
  }

  /// Normaliza un solo carácter (minúscula y sin acento), sin cambiar el
  /// largo: sirve para ubicar una coincidencia en el texto original.
  static String normalizeChar(String char) {
    final lower = char.toLowerCase();
    return _accentMap[lower] ?? lower;
  }

  /// Checks if the normalized text contains the normalized query.
  ///
  /// Example:
  /// - contains("Concepción del Uruguay", "concep") -> true
  static bool contains(String text, String query) {
    return normalize(text).contains(normalize(query));
  }
}
