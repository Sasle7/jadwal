import 'dart:collection';
import 'package:collection/collection.dart';
import 'cell.dart';
import 'merge_region.dart';

/// نموذج الورقة (Sheet)
///
/// تمثل ورقة عمل واحدة داخل المصنف. تحتوي على مجموعة من الخلايا
/// مخزنة في Map حيث المفتاح هو reference الخلية (مثل "A1", "B5").
///
/// توفر هذه الفئة وصولاً آمناً للخلايا عبر [getCell] الذي يعيد خلية
/// فارغة بدلاً من null لتجنب أخطاء المؤشر الفارغ (Null Pointer Exception).
class Sheet {
  /// المعرف الفريد للورقة
  final String id;

  /// اسم الورقة الظاهر (مثل "ورقة1")
  final String name;

  /// خريطة الخلايا: المفتاح = reference (مثل "A1")، القيمة = Cell
  final Map<String, Cell> cells;

  /// عدد الصفوف في الورقة
  final int rowCount;

  /// عدد الأعمدة في الورقة
  final int columnCount;

  /// قائمة المناطق المدمجة في الورقة
  final List<MergeRegion> mergedRegions;

  const Sheet({
    required this.id,
    this.name = 'ورقة1',
    this.cells = const {},
    this.rowCount = 100,
    this.columnCount = 100,
    this.mergedRegions = const [],
  });

  // ---------------------------------------------------------------------------
  // Safe cell access
  // ---------------------------------------------------------------------------

  /// يجلب خلية آمنة بواسطة reference (مثل "A1").
  ///
  /// إذا وُجدت الخلية في الخريطة تُعاد، وإلا تُعاد خلية فارغة جديدة
  /// دون تعديل الخريطة الأصلية (لضمان immutability).
  Cell getCell(String reference) {
    final upperRef = reference.toUpperCase().trim();
    final existing = cells[upperRef];
    if (existing != null) return existing;

    // Parse the reference to create an empty placeholder
    final parsed = Cell.parseReference(upperRef);
    if (parsed == null) {
      // Invalid reference — return a truly empty sentinel cell
      return Cell(id: upperRef, type: CellType.empty);
    }
    final (row, col) = parsed;
    return Cell.empty(row: row, col: col);
  }

  /// يجلب خلية آمنة بواسطة إحداثيات (row, col) 0-based.
  Cell getCellAt(int row, int col) {
    final ref = Cell.columnLetters(col) + (row + 1).toString();
    return getCell(ref);
  }

  /// يحاول إيجاد خلية موجودة فعلياً في الخريطة.
  /// يُعيد null إذا لم تكن الخلية قد أُنشئت من قبل (خلية فارغة غير مخزنة).
  Cell? getExistingCell(String reference) {
    return cells[reference.toUpperCase().trim()];
  }

  // ---------------------------------------------------------------------------
  // Mutation helpers (return new instances – immutable pattern)
  // ---------------------------------------------------------------------------

  /// يُعيد ورقة جديدة تحتوي على الخلية المحدّثة.
  /// إذا كان [rawValue] فارغاً تُزال الخلية من الخريطة.
  Sheet setCell(String reference, String rawValue) {
    final ref = reference.toUpperCase().trim();

    if (rawValue.trim().isEmpty) {
      // Remove the cell when value is empty
      final updatedCells = Map<String, Cell>.of(cells)..remove(ref);
      return copyWith(cells: updatedCells);
    }

    // Parse coordinates
    final parsed = Cell.parseReference(ref);
    if (parsed == null) return this; // ignore invalid references

    final (row, col) = parsed;
    final newCell = Cell.fromRaw(row: row, col: col, rawValue: rawValue);

    final updatedCells = Map<String, Cell>.of(cells)..[ref] = newCell;
    return copyWith(cells: updatedCells);
  }

  /// يُعيد ورقة جديدة مع خلية محدّثة مباشرة بكائن Cell.
  Sheet setCellAt(int row, int col, String rawValue) {
    final ref = Cell.columnLetters(col) + (row + 1).toString();
    return setCell(ref, rawValue);
  }

  /// يُعيد ورقة جديدة مع إزالة الخلية المحددة.
  Sheet removeCell(String reference) {
    final ref = reference.toUpperCase().trim();
    if (!cells.containsKey(ref)) return this;
    final updatedCells = Map<String, Cell>.of(cells)..remove(ref);
    return copyWith(cells: updatedCells);
  }

  /// يُعيد ورقة جديدة مع خلايا محدثة بشكل مجمع.
  Sheet setCells(Map<String, String> entries) {
    var updated = this;
    for (final entry in entries.entries) {
      updated = updated.setCell(entry.key, entry.value);
    }
    return updated;
  }

  // ---------------------------------------------------------------------------
  // Getters
  // ---------------------------------------------------------------------------

  /// جميع الخلايا غير الفارغة (قراءة فقط)
  Map<String, Cell> get nonEmptyCells => Map.unmodifiable(cells);

  /// عدد الخلايا غير الفارغة
  int get cellCount => cells.length;

  // ---------------------------------------------------------------------------
  // Cell merging
  // ---------------------------------------------------------------------------

  /// دمج نطاق من الخلايا. يُعيد ورقة جديدة مع المنطقة المدمجة.
  /// [startRef] مثل "A1"، [endRef] مثل "C3".
  Sheet mergeRange(String startRef, String endRef) {
    final startParsed = Cell.parseReference(startRef);
    final endParsed = Cell.parseReference(endRef);
    if (startParsed == null || endParsed == null) return this;

    final (startRow, startCol) = startParsed;
    final (endRow, endCol) = endParsed;

    // التحقق من أن النطاق صالح (على الأقل خليتان)
    if (startRow == endRow && startCol == endCol) return this;

    final region = MergeRegion(
      startRow: startRow,
      startCol: startCol,
      endRow: endRow,
      endCol: endCol,
    );

    // التحقق من عدم التداخل مع مناطق مدمجة موجودة
    for (final existing in mergedRegions) {
      if (existing.overlaps(region)) return this;
    }

    // إزالة الخلايا غير الرئيسية من النطاق (الاحتفاظ فقط بالخلية الرئيسية)
    var updatedCells = Map<String, Cell>.of(cells);
    final primaryRef = region.primaryRef.toUpperCase().trim();
    final primaryCell = getCell(primaryRef);

    for (int r = startRow; r <= endRow; r++) {
      for (int c = startCol; c <= endCol; c++) {
        final ref = '${Cell.columnLetters(c)}${r + 1}';
        final upperRef = ref.toUpperCase().trim();
        if (upperRef != primaryRef) {
          updatedCells.remove(upperRef);
        }
      }
    }

    // التأكد من وجود الخلية الرئيسية
    updatedCells[primaryRef] = primaryCell;

    return copyWith(
      cells: updatedCells,
      mergedRegions: [...mergedRegions, region],
    );
  }

  /// إلغاء دمج خلية في [ref]. يُعيد ورقة جديدة بدون المنطقة المدمجة.
  Sheet unmergeCell(String ref) {
    final parsed = Cell.parseReference(ref);
    if (parsed == null) return this;
    final (row, col) = parsed;

    final regionIdx = mergedRegions.indexWhere((r) => r.contains(row, col));
    if (regionIdx < 0) return this;

    final updatedRegions = List<MergeRegion>.of(mergedRegions)
      ..removeAt(regionIdx);

    return copyWith(mergedRegions: updatedRegions);
  }

  /// البحث عن المنطقة المدمجة التي تحتوي على الخلية في [ref].
  /// يُعيد null إذا لم تكن الخلية ضمن أي منطقة مدمجة.
  MergeRegion? findMergeRegion(String ref) {
    final parsed = Cell.parseReference(ref);
    if (parsed == null) return null;
    final (row, col) = parsed;
    try {
      return mergedRegions.firstWhere((r) => r.contains(row, col));
    } catch (_) {
      return null;
    }
  }

  /// البحث عن المنطقة المدمجة التي تحتوي على الخلية في الموقع (row, col).
  /// يُعيد null إذا لم تكن الخلية ضمن أي منطقة مدمجة.
  MergeRegion? findMergeRegionAt(int row, int col) {
    try {
      return mergedRegions.firstWhere((r) => r.contains(row, col));
    } catch (_) {
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // copyWith (immutable update)
  // ---------------------------------------------------------------------------

  Sheet copyWith({
    String? id,
    String? name,
    Map<String, Cell>? cells,
    int? rowCount,
    int? columnCount,
    List<MergeRegion>? mergedRegions,
  }) {
    return Sheet(
      id: id ?? this.id,
      name: name ?? this.name,
      cells: cells ?? this.cells,
      rowCount: rowCount ?? this.rowCount,
      columnCount: columnCount ?? this.columnCount,
      mergedRegions: mergedRegions ?? this.mergedRegions,
    );
  }

  // ---------------------------------------------------------------------------
  // Serialization
  // ---------------------------------------------------------------------------

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'rowCount': rowCount,
        'columnCount': columnCount,
        'mergedRegions': mergedRegions.map((r) => r.toJson()).toList(),
        'cells': cells.map((k, v) => MapEntry(k, v.toJson())),
      };

  factory Sheet.fromJson(Map<String, dynamic> json) {
    final rawCells = json['cells'] as Map<String, dynamic>? ?? {};
    final cells = rawCells.map(
      (k, v) => MapEntry(k, Cell.fromJson(v as Map<String, dynamic>)),
    );
    final rawRegions = json['mergedRegions'] as List? ?? [];
    final mergedRegions = rawRegions
        .map((r) => MergeRegion.fromJson(r as Map<String, dynamic>))
        .toList();
    return Sheet(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'ورقة1',
      rowCount: json['rowCount'] as int? ?? 100,
      columnCount: json['columnCount'] as int? ?? 100,
      cells: cells,
      mergedRegions: mergedRegions,
    );
  }

  // ---------------------------------------------------------------------------
  // Equality & debug
  // ---------------------------------------------------------------------------

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Sheet &&
          id == other.id &&
          name == other.name &&
          rowCount == other.rowCount &&
          columnCount == other.columnCount &&
          const ListEquality().equals(mergedRegions, other.mergedRegions) &&
          const MapEquality().equals(cells, other.cells);

  @override
  int get hashCode =>
      Object.hash(id, name, rowCount, columnCount, Object.hashAll(mergedRegions));

  @override
  String toString() => 'Sheet($id, "$name", ${cells.length} cells)';
}
