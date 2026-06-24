import 'dart:collection';
import 'package:flutter/foundation.dart';
import '../models/workbook.dart';
import '../models/sheet.dart';
import '../models/cell.dart';
import 'formula_parser.dart';

// =============================================================================
// محرك الصيغ — FormulaEngine
// =============================================================================

/// محرك الصيغ الرئيسي — يجمع بين المحلل المعجمي، المحلل النحوي، والمقيم.
///
/// يوفر:
/// - تقييم صيغة مفردة في سياق ورقة
/// - إعادة حساب جميع الصيغ في ورقة/مصنف كامل
/// - كشف الاعتماد الدوري (Circular Dependency) ← `#REF!`
/// - حساب الخلفية عبر Isolate
class FormulaEngine {
  /// مجموعة مراجع الخلايا التي يتم زيارتها حالياً — لكشف الاعتماد الدوري.
  final Set<String> _visiting = {};

  // ---------------------------------------------------------------------------
  // تقييم صيغة مفردة
  // ---------------------------------------------------------------------------

  /// يحلل ويقيم صيغة [formula] (بدون علامة =) في سياق [sheet].
  dynamic evaluate(String formula, {required Sheet sheet}) {
    final evaluator = FormulaEvaluator(
      getCellValue: (ref, visiting) => _getCellValue(ref, sheet, visiting),
      getRangeValue: (ref, visiting) => _getRangeValues(ref, sheet, visiting),
    );
    return evaluator.evaluate(formula);
  }

  /// يجلب قيمة خلية من مرجع [ref] (مثل A1) مع تتبع [visiting].
  ///
  /// إذا كانت الخلية المُشار إليها تحتوي على صيغة، يتم تقييمها (تقييم متسلسل).
  /// إذا كانت الخلية موجودة بالفعل في [visiting] → اعتماد دائري ← `#REF!`.
  dynamic _getCellValue(String ref, Sheet sheet, Set<String> visiting) {
    final parsed = Cell.parseReference(ref);
    if (parsed == null) return 0;
    final (row, col) = parsed;

    final cell = sheet.getCellAt(row, col);
    if (cell.isEmpty) return 0;

    final upperRef = ref.toUpperCase();

    // --- كشف الاعتماد الدوري ---
    if (visiting.contains(upperRef)) {
      return FormulaErrors.circularRef;
    }

    if (cell.type == CellType.formula && cell.rawValue.startsWith('=')) {
      // إذا كانت القيمة محسوبة مسبقاً (خارج سلسلة التقييم الحالية)
      if (cell.computedValue != null && !visiting.contains(upperRef)) {
        return cell.computedValue;
      }

      // تقييم متسلسل
      visiting.add(upperRef);
      try {
        final formulaText = cell.rawValue.substring(1);
        final result = evaluate(formulaText, sheet: sheet);
        return result;
      } catch (_) {
        return FormulaErrors.value;
      } finally {
        visiting.remove(upperRef);
      }
    }

    if (cell.type == CellType.number) {
      return double.tryParse(cell.rawValue) ?? 0;
    }

    return cell.rawValue;
  }

  /// يجلب نطاق قيم (مثل A1:C3) مع تتبع [visiting].
  List<List<dynamic>> _getRangeValues(
      String ref, Sheet sheet, Set<String> visiting) {
    final parts = ref.split(':');
    if (parts.length != 2) return [];

    final startParsed = Cell.parseReference(parts[0]);
    final endParsed = Cell.parseReference(parts[1]);
    if (startParsed == null || endParsed == null) return [];

    final (startRow, startCol) = startParsed;
    final (endRow, endCol) = endParsed;

    final result = <List<dynamic>>[];
    for (int r = startRow; r <= endRow; r++) {
      final row = <dynamic>[];
      for (int c = startCol; c <= endCol; c++) {
        final cellRef = '${Cell.columnLetters(c)}${r + 1}';
        row.add(_getCellValue(cellRef, sheet, visiting));
      }
      result.add(row);
    }
    return result;
  }

  // ===========================================================================
  // إعادة حساب الصيغ (مزامن)
  // ===========================================================================

  /// إعادة حساب جميع الصيغ في [sheet] وإرجاع ورقة جديدة بقيم `computedValue`
  /// محدّثة. يستخدم فرزاً طوبولوجياً لترتيب التقييم وكشف الاعتماد الدوري.
  Sheet recalculateSheet(Sheet sheet) {
    // 1. جمع كل الخلايا التي تحتوي على صيغ
    final formulaCells = <String, Cell>{};
    for (final entry in sheet.cells.entries) {
      if (entry.value.type == CellType.formula &&
          entry.value.rawValue.startsWith('=')) {
        formulaCells[entry.key] = entry.value;
      }
    }

    if (formulaCells.isEmpty) return sheet;

    // 2. بناء رسم بياني للاعتماديات
    final adjacency = <String, Set<String>>{};
    for (final ref in formulaCells.keys) {
      adjacency[ref] = _extractReferences(formulaCells, ref);
    }

    // 3. فرز طوبولوجي للكشف عن الاعتماد الدوري
    final sorted = _topologicalSort(adjacency);

    if (sorted == null) {
      // يوجد اعتماد دائري — ضع علامة #REF! على كل الصيغ في الحلقة
      return _markCircularRefs(sheet, formulaCells);
    }

    // 4. تقييم الصيغ بالترتيب الطوبولوجي
    var updatedSheet = sheet;
    for (final ref in sorted) {
      final cell = formulaCells[ref]!;
      final formulaText = cell.rawValue.substring(1);
      try {
        final result = evaluate(formulaText, sheet: updatedSheet);
        final updatedCell = cell.copyWith(computedValue: result);
        updatedSheet = updatedSheet.copyWith(
          cells: Map<String, Cell>.from(updatedSheet.cells)
            ..[ref] = updatedCell,
        );
      } catch (_) {
        final errorCell = cell.copyWith(computedValue: '#ERROR');
        updatedSheet = updatedSheet.copyWith(
          cells: Map<String, Cell>.from(updatedSheet.cells)
            ..[ref] = errorCell,
        );
      }
    }

    return updatedSheet;
  }

  /// إعادة حساب جميع الصيغ في [workbook] وإرجاع مصنف جديد.
  static Workbook recalculateWorkbook(Workbook workbook) {
    var updatedSheets = <Sheet>[];
    for (final sheet in workbook.sheets) {
      final engine = FormulaEngine();
      updatedSheets.add(engine.recalculateSheet(sheet));
    }
    return workbook.copyWith(sheets: updatedSheets);
  }

  // ===========================================================================
  // Isolate — حساب الخلفية
  // ===========================================================================

  /// إعادة حساب جميع الصيغ في [workbook] عبر Isolate.
  ///
  /// مناسب للاستخدام في الـ Notifier لتجنب حظر واجهة المستخدم.
  static Future<Workbook> recalculateInBackground(Workbook workbook) async {
    final data = _prepareWorkbookData(workbook);
    final result = await compute(_recalculateIsolateFn, data);
    return _applyResults(workbook, result);
  }

  /// تجهيز بيانات المصنف للإرسال إلى Isolate.
  static Map<String, dynamic> _prepareWorkbookData(Workbook workbook) {
    final sheetsData = <Map<String, dynamic>>[];
    for (final sheet in workbook.sheets) {
      final cellsData = <String, String>{};
      for (final entry in sheet.cells.entries) {
        cellsData[entry.key] = entry.value.rawValue;
      }
      sheetsData.add({
        'name': sheet.name,
        'cells': cellsData,
        'rowCount': sheet.rowCount,
        'columnCount': sheet.columnCount,
      });
    }
    return {'sheets': sheetsData};
  }

  /// تطبيق نتائج Isolate على المصنف الأصلي.
  static Workbook _applyResults(
      Workbook workbook, Map<String, dynamic> result) {
    final resultsBySheet = result['sheets'] as List<dynamic>;
    var updatedSheets = <Sheet>[];

    for (int i = 0; i < workbook.sheets.length; i++) {
      final sheet = workbook.sheets[i];
      final sheetResult = resultsBySheet[i] as Map<String, dynamic>;
      final computedValues =
          (sheetResult['computed'] as Map<String, dynamic>).cast<String, dynamic>();

      if (computedValues.isEmpty) {
        updatedSheets.add(sheet);
        continue;
      }

      var updatedSheet = sheet;
      for (final entry in computedValues.entries) {
        final ref = entry.key;
        final computedValue = entry.value;
        final cell = updatedSheet.getExistingCell(ref);
        if (cell != null && cell.type == CellType.formula) {
          final updatedCell = cell.copyWith(computedValue: computedValue);
          updatedSheet = updatedSheet.copyWith(
            cells: Map<String, Cell>.from(updatedSheet.cells)
              ..[ref] = updatedCell,
          );
        }
      }
      updatedSheets.add(updatedSheet);
    }

    return workbook.copyWith(sheets: updatedSheets);
  }

  // ===========================================================================
  // دوال مساعدة — اكتشاف الاعتماد الدوري والفرز الطوبولوجي
  // ===========================================================================

  /// يستخرج جميع مراجع الخلايا من صيغة خلية [cellRef].
  static Set<String> _extractReferences(
      Map<String, Cell> formulaCells, String cellRef) {
    final refs = <String>{};
    final cell = formulaCells[cellRef];
    if (cell == null || !cell.rawValue.startsWith('=')) return refs;

    final formula = cell.rawValue.substring(1).toUpperCase();
    final regex = RegExp(r'([A-Z]+)(\d+)');
    for (final match in regex.allMatches(formula)) {
      final fullRef = match.group(0)!;
      if (formulaCells.containsKey(fullRef)) {
        refs.add(fullRef);
      }
    }
    return refs;
  }

  /// فرز طوبولوجي باستخدام DFS. يُعيد `null` إذا وُجد اعتماد دائري.
  static List<String>? _topologicalSort(Map<String, Set<String>> adjacency) {
    final visited = <String>{};
    final stack = <String>{};
    final result = <String>[];

    bool dfs(String node) {
      if (stack.contains(node)) return false; // اعتماد دائري
      if (visited.contains(node)) return true;

      visited.add(node);
      stack.add(node);

      for (final neighbor in adjacency[node] ?? <String>{}) {
        if (!dfs(neighbor)) return false;
      }

      stack.remove(node);
      result.add(node);
      return true;
    }

    for (final node in adjacency.keys) {
      if (!visited.contains(node)) {
        if (!dfs(node)) return null;
      }
    }

    return result;
  }

  /// يضع علامة `#REF!` على كل خلية في حلقة الاعتماد الدائري.
  static Sheet _markCircularRefs(
      Sheet sheet, Map<String, Cell> formulaCells) {
    var updatedSheet = sheet;
    for (final entry in formulaCells.entries) {
      final ref = entry.key;
      final cell = entry.value;
      if (cell.computedValue == null) {
        final errorCell =
            cell.copyWith(computedValue: FormulaErrors.circularRef);
        updatedSheet = updatedSheet.copyWith(
          cells: Map<String, Cell>.from(updatedSheet.cells)
            ..[ref] = errorCell,
        );
      }
    }
    return updatedSheet;
  }

  /// التحقق من صحة الصيغة.
  static bool isValidFormula(String formula) {
    try {
      final parser = FormulaParser();
      parser.parse(formula);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// اقتراح إكمال الدوال.
  static List<String> suggestFunctions(String prefix) {
    const allFunctions = [
      'SUM', 'AVERAGE', 'AVG', 'COUNT', 'MIN', 'MAX',
      'IF', 'CONCATENATE', 'CONCAT', 'ROUND', 'ABS',
      'SQRT', 'POWER', 'NOW', 'TODAY',
    ];
    if (prefix.isEmpty) return allFunctions;
    final upper = prefix.toUpperCase();
    return allFunctions.where((f) => f.startsWith(upper)).toList();
  }
}

// =============================================================================
// دوال Isolate المستقلة (يجب أن تكون دوال مستوى أعلى / top-level)
// =============================================================================

/// دالة تُنفّذ داخل Isolate لحساب الصيغ.
///
/// [data] هي خريطة تحتوي على بيانات الأوراق (مُعدّة عبر _prepareWorkbookData).
/// تُعيد خريطة بنفس الهيكل ولكن مع إضافة `computed` لكل ورقة.
Map<String, dynamic> _recalculateIsolateFn(Map<String, dynamic> data) {
  final sheetsData = data['sheets'] as List<dynamic>;
  final resultSheets = <Map<String, dynamic>>[];

  for (final sheetData in sheetsData) {
    final cells = (sheetData['cells'] as Map<String, dynamic>)
        .map((k, v) => MapEntry(k, v as String));
    final rowCount = sheetData['rowCount'] as int;
    final columnCount = sheetData['columnCount'] as int;

    // بناء Sheet مؤقت للتقييم
    final sheetCells = <String, Cell>{};
    for (final entry in cells.entries) {
      final parsed = Cell.parseReference(entry.key);
      if (parsed != null) {
        final (row, col) = parsed;
        final cell = Cell.fromRaw(row: row, col: col, rawValue: entry.value);
        sheetCells[entry.key] = cell;
      }
    }

    final tempSheet = Sheet(
      id: 'temp',
      cells: sheetCells,
      rowCount: rowCount,
      columnCount: columnCount,
    );

    // تقييم كل صيغة وجمع computedValues
    final computed = <String, dynamic>{};
    final formulaCells = <String, String>{};
    for (final entry in cells.entries) {
      if (entry.value.startsWith('=')) {
        formulaCells[entry.key] = entry.value;
      }
    }

    // فرز طوبولوجي للصيغ
    if (formulaCells.isNotEmpty) {
      final formulaCellMap = <String, Cell>{};
      for (final entry in formulaCells.entries) {
        formulaCellMap[entry.key] =
            Cell.fromRaw(row: 0, col: 0, rawValue: entry.value);
      }

      final adjacency = <String, Set<String>>{};
      for (final ref in formulaCells.keys) {
        final refs = <String>{};
        final formula = formulaCells[ref]!.substring(1).toUpperCase();
        final regex = RegExp(r'([A-Z]+)(\d+)');
        for (final match in regex.allMatches(formula)) {
          final fullRef = match.group(0)!;
          if (formulaCells.containsKey(fullRef)) refs.add(fullRef);
        }
        adjacency[ref] = refs;
      }

      // DFS لكشف الاعتماد الدوري
      final visited = <String>{};
      final stack = <String>{};

      bool dfs(String node, List<String> order) {
        if (stack.contains(node)) {
          computed[node] = FormulaErrors.circularRef;
          return false;
        }
        if (visited.contains(node)) return true;
        visited.add(node);
        stack.add(node);
        for (final neighbor in adjacency[node] ?? <String>{}) {
          if (!dfs(neighbor, order)) {
            computed[node] = FormulaErrors.circularRef;
          }
        }
        stack.remove(node);
        order.add(node);
        return true;
      }

      // تقييم بالترتيب (مع كشف الاعتماد الدوري)
      final order = <String>[];
      for (final ref in formulaCells.keys) {
        if (!visited.contains(ref)) {
          dfs(ref, order);
        }
      }

      // تقييم الصيغ بالترتيب
      for (final ref in order) {
        if (computed.containsKey(ref)) continue; // خطأ سابق
        final formulaText = formulaCells[ref]!.substring(1);
        try {
          final visiting = <String>{};
          final evaluator = FormulaEvaluator(
            getCellValue: (cref, v) =>
                _isoGetCellValue(cref, tempSheet, v, formulaCells, computed),
            getRangeValue: (cref, v) =>
                _isoGetRangeValue(cref, tempSheet, v, formulaCells, computed),
          );
          computed[ref] = evaluator.evaluate(formulaText);
        } catch (_) {
          computed[ref] = FormulaErrors.value;
        }
      }
    }

    resultSheets.add({
      'name': sheetData['name'],
      'computed': computed,
    });
  }

  return {'sheets': resultSheets};
}

/// دالة مساعدة لـ Isolate — تجلب قيمة خلية (مع دعم الصيغ المتسلسلة).
dynamic _isoGetCellValue(
  String ref,
  Sheet sheet,
  Set<String> visiting,
  Map<String, String> formulaCells,
  Map<String, dynamic> computed,
) {
  if (visiting.contains(ref.toUpperCase())) {
    return FormulaErrors.circularRef;
  }

  final parsed = Cell.parseReference(ref);
  if (parsed == null) return 0;
  final (row, col) = parsed;

  final cell = sheet.getCellAt(row, col);
  if (cell.isEmpty) return 0;

  // إذا كانت صيغة وتم حسابها مسبقاً
  if (computed.containsKey(ref)) return computed[ref];

  if (cell.type == CellType.formula && cell.rawValue.startsWith('=')) {
    visiting.add(ref.toUpperCase());
    try {
      final formulaText = cell.rawValue.substring(1);
      final evaluator = FormulaEvaluator(
        getCellValue: (cref, v) =>
            _isoGetCellValue(cref, sheet, v, formulaCells, computed),
        getRangeValue: (cref, v) =>
            _isoGetRangeValue(cref, sheet, v, formulaCells, computed),
      );
      final result = evaluator.evaluate(formulaText);
      computed[ref] = result;
      return result;
    } catch (_) {
      return FormulaErrors.value;
    } finally {
      visiting.remove(ref.toUpperCase());
    }
  }

  if (cell.type == CellType.number) {
    return double.tryParse(cell.rawValue) ?? 0;
  }

  return cell.rawValue;
}

/// دالة مساعدة لـ Isolate — تجلب نطاق قيم.
List<List<dynamic>> _isoGetRangeValue(
  String ref,
  Sheet sheet,
  Set<String> visiting,
  Map<String, String> formulaCells,
  Map<String, dynamic> computed,
) {
  final parts = ref.split(':');
  if (parts.length != 2) return [];

  final startParsed = Cell.parseReference(parts[0]);
  final endParsed = Cell.parseReference(parts[1]);
  if (startParsed == null || endParsed == null) return [];

  final (startRow, startCol) = startParsed;
  final (endRow, endCol) = endParsed;

  final result = <List<dynamic>>[];
  for (int r = startRow; r <= endRow; r++) {
    final row = <dynamic>[];
    for (int c = startCol; c <= endCol; c++) {
      final cellRef = '${Cell.columnLetters(c)}${r + 1}';
      row.add(
          _isoGetCellValue(cellRef, sheet, visiting, formulaCells, computed));
    }
    result.add(row);
  }
  return result;
}
