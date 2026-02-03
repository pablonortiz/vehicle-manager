/// Utility class for text normalization used in location matching.
/// Handles accent removal and case-insensitive comparisons.
class TextNormalizer {
  /// Map of accented characters to their non-accented equivalents.
  static const Map<String, String> _accentMap = {
    'á': 'a', 'à': 'a', 'ä': 'a', 'â': 'a', 'ã': 'a',
    'Á': 'a', 'À': 'a', 'Ä': 'a', 'Â': 'a', 'Ã': 'a',
    'é': 'e', 'è': 'e', 'ë': 'e', 'ê': 'e',
    'É': 'e', 'È': 'e', 'Ë': 'e', 'Ê': 'e',
    'í': 'i', 'ì': 'i', 'ï': 'i', 'î': 'i',
    'Í': 'i', 'Ì': 'i', 'Ï': 'i', 'Î': 'i',
    'ó': 'o', 'ò': 'o', 'ö': 'o', 'ô': 'o', 'õ': 'o',
    'Ó': 'o', 'Ò': 'o', 'Ö': 'o', 'Ô': 'o', 'Õ': 'o',
    'ú': 'u', 'ù': 'u', 'ü': 'u', 'û': 'u',
    'Ú': 'u', 'Ù': 'u', 'Ü': 'u', 'Û': 'u',
    'ñ': 'n', 'Ñ': 'n',
    'ç': 'c', 'Ç': 'c',
  };

  /// Normalizes text by removing accents and converting to lowercase.
  ///
  /// Examples:
  /// - "Concepción" -> "concepcion"
  /// - "CÓRDOBA" -> "cordoba"
  /// - "San José" -> "san jose"
  static String normalize(String text) {
    if (text.isEmpty) return text;

    String result = text.toLowerCase();

    // Replace accented characters
    _accentMap.forEach((accented, replacement) {
      result = result.replaceAll(accented.toLowerCase(), replacement);
    });

    return result.trim();
  }

  /// Checks if two strings match when normalized.
  ///
  /// Example:
  /// - matches("Córdoba", "cordoba") -> true
  /// - matches("CONCEPCIÓN", "concepcion") -> true
  static bool matches(String a, String b) {
    return normalize(a) == normalize(b);
  }

  /// Checks if the normalized text contains the normalized query.
  ///
  /// Example:
  /// - contains("Concepción del Uruguay", "concep") -> true
  static bool contains(String text, String query) {
    return normalize(text).contains(normalize(query));
  }

  /// Generates a SQL-safe normalized string for database storage.
  /// This is used for the name_normalized column in cities/lugares tables.
  static String forDatabase(String text) {
    return normalize(text);
  }
}
