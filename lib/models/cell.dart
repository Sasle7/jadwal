import 'dart:math';

/// أنواع البيانات التي يمكن للخلية تخزينها
enum CellType {
  text,
  number,
  formula,
  date,
  boolean,
  empty,
}

/// محاذاة النص داخل الخلية
enum TextAlignment {
  left,
  center,
  right,
}

/// نموذج تنسيق النص في الخلية (TextStyleModel)
class TextStyleModel {
  final bool isBold;
  final bool isItalic;
  final bool isUnderline;
  final double fontSize;
  final int fontColor; // ARGB hex value
  final int backgroundColor; // ARGB hex value
  final TextAlignment alignment;
  final String? fontFamily;

  const TextStyleModel({
    this.isBold = false,
    this.isItalic = false,
    this.isUnderline = false,
    this.fontSize = 14.0,
    this.fontColor = 0xFF000000,
    this.backgroundColor = 0xFFFFFFFF,
    this.alignment = TextAlignment.left,
    this.fontFamily,
  });

  /// Default style used for new cells
  static const defaultStyle = TextStyleModel();

  TextStyleModel copyWith({
    bool? isBold,
    bool? isItalic,
    bool? isUnderline,
    double? fontSize,
    int? fontColor,
    int? backgroundColor,
    TextAlignment? alignment,
    String? fontFamily,
  }) {
    return TextStyleModel(
      isBold: isBold ?? this.isBold,
      isItalic: isItalic ?? this.isItalic,
      isUnderline: isUnderline ?? this.isUnderline,
      fontSize: fontSize ?? this.fontSize,
      fontColor: fontColor ?? this.fontColor,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      alignment: alignment ?? this.alignment,
      fontFamily: fontFamily ?? this.fontFamily,
    );
  }

  Map<String, dynamic> toJson() => {
        'isBold': isBold,
        'isItalic': isItalic,
        'isUnderline': isUnderline,
        'fontSize': fontSize,
        'fontColor': fontColor,
        'backgroundColor': backgroundColor,
        'alignment': alignment.index,
        if (fontFamily != null) 'fontFamily': fontFamily,
      };

  factory TextStyleModel.fromJson(Map<String, dynamic> json) {
    return TextStyleModel(
      isBold: json['isBold'] as bool? ?? false,
      isItalic: json['isItalic'] as bool? ?? false,
      isUnderline: json['isUnderline'] as bool? ?? false,
      fontSize: (json['fontSize'] as num?)?.toDouble() ?? 14.0,
      fontColor: json['fontColor'] as int? ?? 0xFF000000,
      backgroundColor: json['backgroundColor'] as int? ?? 0xFFFFFFFF,
      alignment: json['alignment'] != null
          ? TextAlignment.values[json['alignment'] as int]
          : TextAlignment.left,
      fontFamily: json['fontFamily'] as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TextStyleModel &&
          isBold == other.isBold &&
          isItalic == other.isItalic &&
          isUnderline == other.isUnderline &&
          fontSize == other.fontSize &&
          fontColor == other.fontColor &&
          backgroundColor == other.backgroundColor &&
          alignment == other.alignment &&
          fontFamily == other.fontFamily;

  @override
  int get hashCode => Object.hash(
        isBold,
        isItalic,
        isUnderline,
        fontSize,
        fontColor,
        backgroundColor,
        alignment,
        fontFamily,
      );

  @override
  String toString() =>
      'TextStyleModel(bold=$isBold, italic=$isItalic, size=$fontSize)';
}

/// نموذج الخلية الرئيسي
///
/// يمثل خلية واحدة في جدول البيانات.
/// يتم تحويل rawValue تلقائياً إلى النوع المناسب (نص، رقم، صيغة).
/// يبقى computedValue فارغاً (null) لحين معالجته بواسطة محرك الصيغ.
class Cell {
  /// معرف الخلية (مثل "A1", "B5", "AA10")
  final String id;

  /// القيمة الخام المدخلة من المستخدم كنص
  final String rawValue;

  /// القيمة المحسوبة (تُملأ لاحقاً بواسطة محرك الصيغ)
  final dynamic computedValue;

  /// نوع الخلية المستنتج من rawValue
  final CellType type;

  /// تنسيق النص والمظهر
  final TextStyleModel style;

  const Cell({
    required this.id,
    this.rawValue = '',
    this.computedValue,
    this.type = CellType.empty,
    this.style = TextStyleModel.defaultStyle,
  });

  // ---------------------------------------------------------------------------
  // Factory constructors with smart type inference
  // ---------------------------------------------------------------------------

  /// Creates an empty cell at the given [row] and [col].
  factory Cell.empty({required int row, required int col}) {
    return Cell(
      id: _cellReference(row, col),
      type: CellType.empty,
    );
  }

  /// Creates a cell from a [rawValue] string, automatically detecting the type.
  ///
  /// - `=...` → [CellType.formula]  (computedValue is NOT evaluated here)
  /// - parsable number → [CellType.number]
  /// - `true` / `false` → [CellType.boolean]
  /// - empty string → [CellType.empty]
  /// - anything else → [CellType.text]
  factory Cell.fromRaw({
    required int row,
    required int col,
    required String rawValue,
    TextStyleModel? style,
  }) {
    final id = _cellReference(row, col);
    final trimmed = rawValue.trim();

    if (trimmed.isEmpty) {
      return Cell(id: id, rawValue: trimmed, type: CellType.empty, style: style ?? TextStyleModel.defaultStyle);
    }

    if (trimmed.startsWith('=')) {
      return Cell(
        id: id,
        rawValue: trimmed,
        type: CellType.formula,
        style: style ?? TextStyleModel.defaultStyle,
        // computedValue remains null — handled later by the formula engine
      );
    }

    if (trimmed == 'true' || trimmed == 'false' || trimmed == 'TRUE' || trimmed == 'FALSE') {
      return Cell(
        id: id,
        rawValue: trimmed,
        type: CellType.boolean,
        computedValue: trimmed.toLowerCase() == 'true',
        style: style ?? TextStyleModel.defaultStyle,
      );
    }

    final number = num.tryParse(trimmed);
    if (number != null) {
      return Cell(
        id: id,
        rawValue: trimmed,
        type: CellType.number,
        computedValue: number,
        style: style ?? TextStyleModel.defaultStyle,
      );
    }

    // Default: treat as plain text
    return Cell(
      id: id,
      rawValue: trimmed,
      type: CellType.text,
      computedValue: trimmed,
      style: style ?? TextStyleModel.defaultStyle,
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Whether this cell holds no data.
  bool get isEmpty => type == CellType.empty && rawValue.isEmpty;

  /// The value suitable for display in the grid.
  String get displayValue {
    if (type == CellType.empty) return '';
    if (type == CellType.formula) {
      // Prefer computed value when available, otherwise show the raw formula
      if (computedValue != null) return computedValue.toString();
      return rawValue;
    }
    if (type == CellType.boolean && computedValue is bool) {
      return (computedValue as bool) ? 'TRUE' : 'FALSE';
    }
    return rawValue;
  }

  // ---------------------------------------------------------------------------
  // Column letter ↔ integer conversions (static)
  // ---------------------------------------------------------------------------

  /// Converts a column index (0-based) to letters (0 → A, 25 → Z, 26 → AA …).
  static String columnLetters(int col) {
    if (col < 0) return '';
    final buffer = StringBuffer();
    int c = col;
    while (true) {
      buffer.writeCharCode(65 + (c % 26));
      c = c ~/ 26 - 1;
      if (c < 0) break;
    }
    return buffer.toString().split('').reversed.join();
  }

  /// Parses a cell reference like "A1" or "AA10" into (row, col) 0-based.
  ///
  /// Returns `null` if the reference is invalid.
  static (int row, int col)? parseReference(String ref) {
    final upper = ref.toUpperCase().trim();
    final match = RegExp(r'^([A-Z]+)(\d+)$').firstMatch(upper);
    if (match == null) return null;

    final letters = match.group(1)!;
    final rowNum = int.parse(match.group(2)!) - 1;
    if (rowNum < 0) return null;

    int col = 0;
    for (int i = 0; i < letters.length; i++) {
      col = col * 26 + (letters.codeUnitAt(i) - 64);
    }
    col -= 1; // convert to 0-based

    return (rowNum, col);
  }

  /// Builds a cell reference string from (row, col).
  static String _cellReference(int row, int col) {
    return '${columnLetters(col)}${row + 1}';
  }

  // ---------------------------------------------------------------------------
  // Immutable copy
  // ---------------------------------------------------------------------------

  Cell copyWith({
    String? id,
    String? rawValue,
    dynamic computedValue, // use [_sentinel] to distinguish "no value"
    CellType? type,
    TextStyleModel? style,
    bool clearComputedValue = false,
  }) {
    return Cell(
      id: id ?? this.id,
      rawValue: rawValue ?? this.rawValue,
      computedValue: clearComputedValue ? null : computedValue ?? this.computedValue,
      type: type ?? this.type,
      style: style ?? this.style,
    );
  }

  // ---------------------------------------------------------------------------
  // Serialization
  // ---------------------------------------------------------------------------

  Map<String, dynamic> toJson() => {
        'id': id,
        'rawValue': rawValue,
        if (computedValue != null) 'computedValue': computedValue.toString(),
        'type': type.index,
        'style': style.toJson(),
      };

  factory Cell.fromJson(Map<String, dynamic> json) {
    return Cell(
      id: json['id'] as String,
      rawValue: json['rawValue'] as String? ?? '',
      computedValue: json['computedValue'],
      type: CellType.values[json['type'] as int? ?? CellType.empty.index],
      style: json['style'] != null
          ? TextStyleModel.fromJson(json['style'] as Map<String, dynamic>)
          : TextStyleModel.defaultStyle,
    );
  }

  // ---------------------------------------------------------------------------
  // Equality & debug
  // ---------------------------------------------------------------------------

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Cell &&
          id == other.id &&
          rawValue == other.rawValue &&
          type == other.type &&
          style == other.style;

  @override
  int get hashCode => Object.hash(id, rawValue, type, style);

  @override
  String toString() => 'Cell($id, "$rawValue", $type)';
}

/// Utility sentinel object for `copyWith` to differentiate "not passed" from null.
// ignore: non_constant_identifier_names
final _sentinel = Object();
