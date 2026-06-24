import '../models/workbook.dart';
import '../models/sheet.dart';
import '../models/cell.dart';
import 'formula_parser.dart';

/// محرك الصيغ الرئيسي - يجمع بين المحلل والمقيم.
///
/// ملاحظة: هذا المحرك مؤقت لحين اكتمال دمج computedValue مع Cell.
/// حالياً يقوم بتقييم الصيغ وإرجاع القيم دون تعديل الخلايا مباشرة
/// (لأن computedValue أصبح حقلاً نهائياً في Cell).
class FormulaEngine {
  final Workbook _workbook;

  FormulaEngine(this._workbook);

  /// تقييم صيغة في سياق المصنف الحالي
  dynamic evaluate(String formula, {Sheet? sheet}) {
    final targetSheet = sheet ?? _workbook.activeSheet;

    final evaluator = FormulaEvaluator(
      getCellValue: (ref) => _getCellValue(ref, targetSheet),
      getRangeValue: (ref) => _getRangeValues(ref, targetSheet),
    );

    return evaluator.evaluate(formula);
  }

  /// الحصول على قيمة خلية من مرجع (مثل A1)
  dynamic _getCellValue(String ref, Sheet sheet) {
    final parsed = Cell.parseReference(ref);
    if (parsed == null) return 0;
    final (row, col) = parsed;

    final cell = sheet.getCellAt(row, col);
    if (cell.isEmpty) return 0;

    if (cell.type == CellType.formula) {
      // إذا كانت القيمة محسوبة مسبقاً نعيدها
      if (cell.computedValue != null) return cell.computedValue;
      // تجنب الحلقات اللانهائية
      return 0;
    }

    if (cell.type == CellType.number) {
      return double.tryParse(cell.rawValue) ?? 0;
    }

    return cell.rawValue;
  }

  /// الحصول على نطاق قيم (مثل A1:C3)
  List<List<dynamic>> _getRangeValues(String ref, Sheet sheet) {
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
        row.add(_getCellValue(cellRef, sheet));
      }
      result.add(row);
    }
    return result;
  }

  /// إعادة حساب جميع الصيغ في ورقة (يُعيد ورقة جديدة بخلايا محدّثة)
  Sheet recalculateSheet(Sheet sheet) {
    var updatedSheet = sheet;
    for (final cell in sheet.cells.values) {
      if (cell.type == CellType.formula && cell.rawValue.startsWith('=')) {
        final formulaText = cell.rawValue.substring(1); // إزالة =
        try {
          final result = evaluate(formulaText, sheet: updatedSheet);
          final updatedCell = cell.copyWith(computedValue: result);
          updatedSheet = updatedSheet.copyWith(
            cells: Map<String, Cell>.from(updatedSheet.cells)
              ..[cell.id] = updatedCell,
          );
        } catch (e) {
          final errorCell = cell.copyWith(computedValue: '#ERROR');
          updatedSheet = updatedSheet.copyWith(
            cells: Map<String, Cell>.from(updatedSheet.cells)
              ..[cell.id] = errorCell,
          );
        }
      }
    }
    return updatedSheet;
  }

  /// إعادة حساب جميع الصيغ في المصنف (يُعيد مصنفاً جديداً)
  Workbook recalculateAll() {
    var updatedSheets = <Sheet>[];
    for (final sheet in _workbook.sheets) {
      updatedSheets.add(recalculateSheet(sheet));
    }
    return _workbook.copyWith(sheets: updatedSheets);
  }

  /// التحقق من صحة الصيغة
  bool isValidFormula(String formula) {
    try {
      final parser = FormulaParser();
      parser.parse(formula);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// اقتراح إكمال الصيغة بناءً على النص المدخل
  static List<String> suggestFunctions(String prefix) {
    final allFunctions = [
      'SUM', 'AVERAGE', 'AVG', 'COUNT', 'MIN', 'MAX',
      'IF', 'CONCATENATE', 'CONCAT', 'ROUND', 'ABS',
      'SQRT', 'POWER', 'NOW', 'TODAY',
    ];

    if (prefix.isEmpty) return allFunctions;

    final upper = prefix.toUpperCase();
    return allFunctions.where((f) => f.startsWith(upper)).toList();
  }
}
