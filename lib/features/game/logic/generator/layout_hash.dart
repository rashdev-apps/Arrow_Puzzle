import '../../domain/arrow.dart';

/// Canonical FNV-1a hashing of arrow layouts, used to guarantee
/// uniqueness across generated levels without external packages.
/// Uses 32-bit arithmetic so it is web/JavaScript compliant (JS numbers
/// only safely represent up to 53-bit integers).
class LayoutHash {
  LayoutHash._();

  static const int _fnvOffsetBasis32 = 0x811c9dc5;
  static const int _fnvPrime32 = 0x01000193;
  static const int _mask32 = 0xFFFFFFFF;

  static String of(List<Arrow> arrows) {
    final encodings = arrows.map((a) => a.encodePath()).toList()..sort();
    var hash = _fnvOffsetBasis32;
    for (final encoding in encodings) {
      for (final unit in encoding.codeUnits) {
        hash = ((hash ^ unit) * _fnvPrime32) & _mask32;
      }
      hash = ((hash ^ 0x1F) * _fnvPrime32) & _mask32;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }

  /// FNV-1a of an arbitrary string (used for deterministic level seeds).
  static int seed(String input) {
    var hash = _fnvOffsetBasis32;
    for (final unit in input.codeUnits) {
      hash = ((hash ^ unit) * _fnvPrime32) & 0x7FFFFFFF;
    }
    return hash;
  }
}
