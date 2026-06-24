import 'dart:io';
import 'package:excel/excel.dart' as excel_lib;
import 'package:path_provider/path_provider.dart';
import '../models/workbook.dart';
import '../models/sheet.dart';
import '../models/cell.dart';

/// خدمة التعامل مع ملفات Excel (استيراد/تصدير)
class ExcelService {
  /// تصدير المصنف إلى ملف XLSX
  Future<String> exportToXlsx(Workbook workbook) async {
    final excel = excel_lib.Excel.createExcel();

    for (final sheet in workbook.sheets) {
      final excelSheet = excel[sheet.name];

      // تحديد نطاق الخلايا
      int maxRow = 0;
      int maxCol = 0;
      final cellEntries = <(int row, int col, Cell cell)>[];
      for (final entry in sheet.cells.entries) {
        final parsed = Cell.parseReference(entry.key);
        if (parsed == null) continue;
        final (row, col) = parsed;
        cellEntries.add((row, col, entry.value));
        if (row > maxRow) maxRow = row;
        if (col > maxCol) maxCol = col;
      }

      // كتابة الخلايا
      for (final (row, col, cell) in cellEntries) {
        final cellCoord = excel_lib.CellIndex.indexByColumnRow(
          columnIndex: col,
          rowIndex: row,
        );

        final targetCell = excelSheet.cell(cellCoord);

        // تعيين القيمة
        if (cell.type == CellType.number) {
          final numVal = num.tryParse(cell.rawValue);
          if (numVal != null) {
            targetCell.value = numVal;
          } else {
            targetCell.value = cell.rawValue;
          }
        } else if (cell.type == CellType.formula) {
          targetCell.value = cell.rawValue;
        } else {
          targetCell.value = cell.rawValue;
        }

        // تنسيق الخلية — استخدام TextStyleModel
        final style = cell.style;
        targetCell.style = excel_lib.CellStyle(
          fontFamily: getFontFamily(),
          fontSize: style.fontSize,
          fontColorHex:
              '#${style.fontColor.toRadixString(16).padLeft(8, '0').substring(2)}',
          backgroundColorHex:
              '#${style.backgroundColor.toRadixString(16).padLeft(8, '0').substring(2)}',
          bold: style.isBold,
          italic: style.isItalic,
          underline: style.isUnderline,
        );
      }
    }

    // حفظ الملف
    final dir = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final filePath = '${dir.path}/$timestamp.xlsx';
    final file = File(filePath);
    final bytes = excel.encode()!;
    await file.writeAsBytes(bytes);

    return filePath;
  }

  /// استيراد مصنف من ملف XLSX
  Future<Workbook> importFromXlsx(String filePath) async {
    final file = File(filePath);
    final bytes = await file.readAsBytes();
    final excel = excel_lib.Excel.decodeBytes(bytes);

    final sheets = <Sheet>[];
    for (final excelSheet in excel.sheets.values) {
      var sheet = Sheet(
        id: excelSheet.name ?? 'ورقة',
        name: excelSheet.name ?? 'ورقة',
      );

      for (int r = 0; r < excelSheet.maxRows; r++) {
        for (int c = 0; c < excelSheet.maxColumns; c++) {
          final cellObj = excelSheet.cell(
            excel_lib.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r),
          );
          if (cellObj.value != null) {
            final value = cellObj.value?.toString() ?? '';
            sheet = sheet.setCellAt(r, c, value);

            // تطبيق التنسيق
            final xlStyle = cellObj.style;
            if (xlStyle != null) {
              final cellRef = '${Cell.columnLetters(c)}${r + 1}';
              final existingCell = sheet.getExistingCell(cellRef);
              if (existingCell != null) {
                final newStyle = existingCell.style.copyWith(
                  fontSize: xlStyle.fontSize?.toDouble(),
                  isBold: xlStyle.bold == true,
                  isItalic: xlStyle.italic == true,
                  isUnderline: xlStyle.underline == true,
                );
                final updatedCell = existingCell.copyWith(style: newStyle);
                sheet = sheet.copyWith(
                  cells: Map<String, Cell>.from(sheet.cells)
                    ..[cellRef] = updatedCell,
                );
              }
            }
          }
        }
      }

      sheets.add(sheet);
    }

    return Workbook(
      name: filePath.split('/').last.replaceAll('.xlsx', ''),
      sheets: sheets,
    );
  }

  /// تصدير إلى CSV
  Future<String> exportToCsv(Workbook workbook) async {
    final sheet = workbook.activeSheet;
    final buffer = StringBuffer();

    // تحديد نطاق الخلايا
    int maxRow = 0;
    int maxCol = 0;
    final cellMap = <String, Cell>{};
    for (final entry in sheet.cells.entries) {
      final parsed = Cell.parseReference(entry.key);
      if (parsed == null) continue;
      final (row, col) = parsed;
      cellMap['$row:$col'] = entry.value;
      if (row > maxRow) maxRow = row;
      if (col > maxCol) maxCol = col;
    }

    for (int r = 0; r <= maxRow; r++) {
      for (int c = 0; c <= maxCol; c++) {
        if (c > 0) buffer.write(',');
        final cell = cellMap['$r:$c'];
        if (cell != null && !cell.isEmpty) {
          String val = cell.displayValue;
          if (val.contains(',') || val.contains('"') || val.contains('\n')) {
            val = '"${val.replaceAll('"', '""')}"';
          }
          buffer.write(val);
        }
      }
      buffer.writeln();
    }

    final dir = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final filePath = '${dir.path}/$timestamp.csv';
    final file = File(filePath);
    await file.writeAsString(buffer.toString());

    return filePath;
  }

  /// استيراد من CSV
  Future<Workbook> importFromCsv(String filePath) async {
    final file = File(filePath);
    final content = await file.readAsString();
    final lines = content.split('\n');

    var sheet = Sheet(
      id: 'sheet1',
      name: filePath.split('/').last.replaceAll('.csv', ''),
    );

    for (int r = 0; r < lines.length; r++) {
      if (lines[r].trim().isEmpty) continue;
      final values = _parseCsvLine(lines[r]);
      for (int c = 0; c < values.length; c++) {
        sheet = sheet.setCellAt(r, c, values[c]);
      }
    }

    return Workbook(
      name: filePath.split('/').last.replaceAll('.csv', ''),
      sheets: [sheet],
    );
  }

  List<String> _parseCsvLine(String line) {
    final result = <String>[];
    bool inQuotes = false;
    String current = '';

    for (int i = 0; i < line.length; i++) {
      final ch = line[i];
      if (ch == '"') {
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          current += '"';
          i++;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (ch == ',' && !inQuotes) {
        result.add(current);
        current = '';
      } else {
        current += ch;
      }
    }
    result.add(current);
    return result;
  }

  /// حفظ المصنف بتنسيق JSON (تنسيق التطبيق الخاص)
  Future<String> saveToJson(Workbook workbook) async {
    final dir = await getApplicationDocumentsDirectory();
    final filePath = '${dir.path}/${workbook.name}.jdwl';
    final file = File(filePath);
    await file.writeAsString(workbook.toJson().toString());
    return filePath;
  }

  String getFontFamily() => 'Calibri';
}
