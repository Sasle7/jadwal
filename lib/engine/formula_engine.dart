import '../models/workbook.dart';
import '../models/sheet.dart';
import '../models/cell.dart';
import 'formula_parser.dart';

/// محرك الصيغ الرئيسي - يجمع بين المحلل والمقيم
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
    final (row, col) = Cell.parseReference(ref);
    if (row < 0 || col < 0) return 0;

    final cell = sheet.getCell(row, col);
    if (cell.isEmpty) return 0;

    if (cell.type == CellType.formula) {
      if (cell.computedValue != null) return cell.computedValue;
      // تجنب الحلقات اللانهائية - تقييم بسيط
      return 0;
    }

    if (cell.type == CellType.number) {
      return double.tryParse(cell.rawValue ?? '') ?? 0;
    }

    return cell.rawValue ?? '';
  }

  /// الحصول على نطاق قيم (مثل A1:C3)
  List<List<dynamic>> _getRangeValues(String ref, Sheet sheet) {
    final parts = ref.split(':');
    if (parts.length != 2) return [];

    final (startRow, startCol) = Cell.parseReference(parts[0]);
    final (endRow, endCol) = Cell.parseReference(parts[1]);

    if (startRow < 0 || startCol < 0 || endRow < 0 || endCol < 0) return [];

    final result = <List<dynamic>>[];
    for (int r = startRow; r <= endRow; r++) {
      final row = <dynamic>[];
      for (int c = startCol; c <= endCol; c++) {
        row.add(_getCellValue('${Cell.columnLetters(c)}${r + 1}', sheet));
      }
      result.add(row);
    }
    return result;
  }

  /// إعادة حساب جميع الصيغ في الورقة
  void recalculateSheet(Sheet sheet) {
    for (final cell in sheet.cells.values) {
      if (cell.type == CellType.formula && cell.formula != null) {
        try {
          cell.computedValue = evaluate(cell.formula!, sheet: sheet);
        } catch (e) {
          cell.computedValue = '#ERROR';
        }
      }
    }
  }

  /// إعادة حساب جميع الصيغ في المصنف
  void recalculateAll() {
    for (final sheet in _workbook.sheets) {
      recalculateSheet(sheet);
    }
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
