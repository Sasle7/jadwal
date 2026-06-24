import 'package:uuid/uuid.dart';
import 'sheet.dart';
import 'cell.dart';

/// نموذج المصنف (Workbook)
///
/// يمثل ملف جدول بيانات كاملاً يحتوي على مجموعة من الأوراق (Sheets).
/// يتم تحديد الورقة النشطة عبر [activeSheetId] (معرف نصي).
///
/// جميع الحقول نهائية (final) لدعم نمط immutable state،
/// ويتم التعديل عبر [copyWith] الذي يُعيد نسخة جديدة.
class Workbook {
  /// المعرف الفريد للمصنف
  final String id;

  /// اسم المصنف (اسم الملف)
  final String name;

  /// قائمة الأوراق في المصنف
  final List<Sheet> sheets;

  /// معرف الورقة النشطة حالياً
  final String activeSheetId;

  const Workbook({
    required this.id,
    required this.name,
    required this.sheets,
    required this.activeSheetId,
  });

  // ---------------------------------------------------------------------------
  // Factory constructors
  // ---------------------------------------------------------------------------

  /// إنشاء مصنف جديد بورقة افتراضية واحدة
  factory Workbook.createNew({String? name}) {
    final sheetId = const Uuid().v4();
    return Workbook(
      id: const Uuid().v4(),
      name: name ?? 'مصنف جديد',
      sheets: [
        Sheet(id: sheetId, name: 'ورقة1'),
      ],
      activeSheetId: sheetId,
    );
  }

  /// إنشاء مصنف تجريبي ببيانات نموذجية للعرض
  factory Workbook.sample() {
    final sheetId = const Uuid().v4();
    var sheet = Sheet(id: sheetId, name: 'بيانات تجريبية');

    final sampleData = [
      ['الاسم', 'العمر', 'الراتب', 'القسم'],
      ['أحمد محمد', '30', '5000', 'المبيعات'],
      ['سارة خالد', '25', '4500', 'التسويق'],
      ['محمد علي', '35', '6000', 'تقنية المعلومات'],
      ['نورة أحمد', '28', '4800', 'الموارد البشرية'],
    ];

    for (int r = 0; r < sampleData.length; r++) {
      for (int c = 0; c < sampleData[r].length; c++) {
        final ref = Cell.columnLetters(c) + (r + 1).toString();
        if (r == 0) {
          // Header row — bold style
          final headerCell = Cell.fromRaw(
            row: r,
            col: c,
            rawValue: sampleData[r][c],
            style: const TextStyleModel(
              isBold: true,
              fontColor: 0xFFFFFFFF,
              backgroundColor: 0xFF1B5E20,
            ),
          );
          sheet = sheet.copyWith(
            cells: Map<String, Cell>.from(sheet.cells)..[ref] = headerCell,
          );
        } else {
          sheet = sheet.setCell(ref, sampleData[r][c]);
        }
      }
    }

    // Add a SUM formula for salaries (C2:C5 → column C = index 2)
    sheet = sheet.setCell('C6', '=SUM(C2:C5)');

    return Workbook(
      id: const Uuid().v4(),
      name: 'نموذج تجريبي',
      sheets: [sheet],
      activeSheetId: sheetId,
    );
  }

  // ---------------------------------------------------------------------------
  // Computed getters
  // ---------------------------------------------------------------------------

  /// الورقة النشطة بناءً على [activeSheetId].
  /// إذا لم يُعثر عليها تُعاد الورقة الأولى احتياطياً.
  Sheet get activeSheet {
    try {
      return sheets.firstWhere((s) => s.id == activeSheetId);
    } catch (_) {
      return sheets.first;
    }
  }

  /// فهرس الورقة النشطة في القائمة
  int get activeSheetIndex {
    final idx = sheets.indexWhere((s) => s.id == activeSheetId);
    return idx >= 0 ? idx : 0;
  }

  // ---------------------------------------------------------------------------
  // Immutable copy
  // ---------------------------------------------------------------------------

  Workbook copyWith({
    String? id,
    String? name,
    List<Sheet>? sheets,
    String? activeSheetId,
    bool clearComputedValues = false,
  }) {
    List<Sheet> finalSheets = sheets ?? this.sheets;

    if (clearComputedValues) {
      finalSheets = finalSheets.map((s) {
        final clearedCells = s.cells.map((ref, cell) {
          if (cell.type == CellType.formula) {
            return MapEntry(ref, cell.copyWith(clearComputedValue: true));
          }
          return MapEntry(ref, cell);
        });
        return s.copyWith(cells: clearedCells);
      }).toList();
    }

    return Workbook(
      id: id ?? this.id,
      name: name ?? this.name,
      sheets: finalSheets,
      activeSheetId: activeSheetId ?? this.activeSheetId,
    );
  }

  // ---------------------------------------------------------------------------
  // Serialization
  // ---------------------------------------------------------------------------

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'activeSheetId': activeSheetId,
        'sheets': sheets.map((s) => s.toJson()).toList(),
      };

  factory Workbook.fromJson(Map<String, dynamic> json) {
    final sheets = (json['sheets'] as List)
        .map((s) => Sheet.fromJson(s as Map<String, dynamic>))
        .toList();
    return Workbook(
      id: json['id'] as String? ?? const Uuid().v4(),
      name: json['name'] as String? ?? 'مصنف جديد',
      sheets: sheets,
      activeSheetId: json['activeSheetId'] as String? ?? sheets.first.id,
    );
  }

  // ---------------------------------------------------------------------------
  // Equality & debug
  // ---------------------------------------------------------------------------

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Workbook && id == other.id && name == other.name;

  @override
  int get hashCode => Object.hash(id, name);

  @override
  String toString() => 'Workbook($id, "$name", ${sheets.length} sheets)';
}
