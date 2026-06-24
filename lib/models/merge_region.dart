// =============================================================================
// MergeRegion — منطقة خلايا مدمجة
// =============================================================================

/// تمثل منطقة من الخلايا المدمجة (merged cells) في ورقة العمل.
///
/// تحتفظ بإحداثيات البداية والنهاية (0-based) للمنطقة المدمجة،
/// بالإضافة إلى مرجع الخلية الرئيسية (top-left) التي تحتفظ بقيمتها.
class MergeRegion {
  /// الصف العلوي للمنطقة (0-based)
  final int startRow;

  /// العمود الأيسر للمنطقة (0-based)
  final int startCol;

  /// الصف السفلي للمنطقة (0-based)
  final int endRow;

  /// العمود الأيمن للمنطقة (0-based)
  final int endCol;

  const MergeRegion({
    required this.startRow,
    required this.startCol,
    required this.endRow,
    required this.endCol,
  });

  /// التحقق مما إذا كان هذا الدمج يحتوي على الخلية في الموقع المحدد.
  bool contains(int row, int col) =>
      row >= startRow &&
      row <= endRow &&
      col >= startCol &&
      col <= endCol;

  /// التحقق مما إذا كان هذا الدمج يتقاطع مع نطاق آخر.
  bool overlaps(MergeRegion other) =>
      !(other.endRow < startRow ||
          other.startRow > endRow ||
          other.endCol < startCol ||
          other.startCol > endCol);

  /// إرجاع مرجع الخلية الرئيسية (top-left corner).
  String get primaryRef {
    final colLetters = _columnLetters(startCol);
    return '$colLetters${startRow + 1}';
  }

  /// تحويل رقم العمود إلى حروف (مثل 0 → A, 1 → B, … 25 → Z, 26 → AA).
  static String _columnLetters(int col) {
    final buffer = StringBuffer();
    int c = col;
    while (c >= 0) {
      buffer.write(String.fromCharCode(65 + (c % 26)));
      c = (c ~/ 26) - 1;
    }
    return buffer.toString();
  }

  /// تحويل إلى JSON للتخزين.
  Map<String, dynamic> toJson() => {
        'startRow': startRow,
        'startCol': startCol,
        'endRow': endRow,
        'endCol': endCol,
      };

  /// إنشاء من JSON.
  factory MergeRegion.fromJson(Map<String, dynamic> json) => MergeRegion(
        startRow: json['startRow'] as int,
        startCol: json['startCol'] as int,
        endRow: json['endRow'] as int,
        endCol: json['endCol'] as int,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MergeRegion &&
          startRow == other.startRow &&
          startCol == other.startCol &&
          endRow == other.endRow &&
          endCol == other.endCol;

  @override
  int get hashCode => Object.hash(startRow, startCol, endRow, endCol);

  @override
  String toString() =>
      'MergeRegion($primaryRef : ${_columnLetters(endCol)}${endRow + 1})';
}
