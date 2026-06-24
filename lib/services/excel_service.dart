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
    final excel = excel_lib.Excel.create();

    for (final sheet in workbook.sheets) {
      final excelSheet = excel[sheet.name];

      // تجميع جميع الخلايا
      final allCells = <String, Cell>{};
      // تقدير نطاق الخلايا
      int maxRow = 0;
      int maxCol = 0;
      for (final cell in sheet.cells.values) {
        allCells['${cell.row}:${cell.col}'] = cell;
        if (cell.row > maxRow) maxRow = cell.row;
        if (cell.col > maxCol) maxCol = cell.col;
      }

      // كتابة الخلايا
      for (int r = 0; r <= maxRow; r++) {
        for (int c = 0; c <= maxCol; c++) {
          final cell = allCells['$r:$c'];
          if (cell != null && !cell.isEmpty) {
            final cellCoord = excel_lib.CellIndex.indexByColumnRow(
              columnIndex: c,
              rowIndex: r,
            );

            // تعيين القيمة
            if (cell.type == CellType.number) {
              final numVal = double.tryParse(cell.rawValue ?? '');
              if (numVal != null) {
                excelSheet.cell(cellCoord).value = excel_lib.Data(numVal);
              }
            } else if (cell.type == CellType.formula) {
              excelSheet.cell(cellCoord).value =
                  excel_lib.TextCellValue(cell.rawValue ?? '');
            } else {
              excelSheet.cell(cellCoord).value =
                  excel_lib.TextCellValue(cell.rawValue ?? '');
            }

            // تنسيق الخلية
            final cellStyle = excel_lib.CellStyle(
              fontFamily: getFontFamily(),
              fontSize: cell.format.fontSize ?? 14,
              fontColorHex: cell.format.textColor != null
                  ? '#${cell.format.textColor!.value.toRadixString(16).substring(2).padLeft(6, '0')}'
                  : '#000000',
              backgroundColorHex: cell.format.backgroundColor != null
                  ? '#${cell.format.backgroundColor!.value.toRadixString(16).substring(2).padLeft(6, '0')}'
                  : '#FFFFFF',
              bold: cell.format.fontWeight == FontWeightOption.bold,
              italic: cell.format.italic ?? false,
              underline: cell.format.underline ?? false,
            );
            excelSheet.cell(cellCoord).style = cellStyle;
          }
        }
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
      final sheet = Sheet(
        id: excelSheet.name ?? 'ورقة',
        name: excelSheet.name ?? 'ورقة',
      );

      for (int r = 0; r < excelSheet.maxRows; r++) {
        for (int c = 0; c < excelSheet.maxColumns; c++) {
          final cellObj = excelSheet.cell(
            excel_lib.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r),
          );
          if (cellObj != null && cellObj.value != null) {
            final value = cellObj.value?.toString() ?? '';
            sheet.setCell(r, c, value);

            // تطبيق التنسيق
            final style = cellObj.style;
            if (style != null) {
              final cell = sheet.getCell(r, c);
              cell.format = cell.format.copyWith(
                fontSize: style.fontSize?.toDouble(),
                fontWeight: style.bold == true
                    ? FontWeightOption.bold
                    : FontWeightOption.normal,
                italic: style.italic,
                underline: style.underline,
              );
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

    // تجميع الخلايا
    final allCells = <String, Cell>{};
    int maxRow = 0;
    int maxCol = 0;
    for (final cell in sheet.cells.values) {
      allCells['${cell.row}:${cell.col}'] = cell;
      if (cell.row > maxRow) maxRow = cell.row;
      if (cell.col > maxCol) maxCol = cell.col;
    }

    for (int r = 0; r <= maxRow; r++) {
      for (int c = 0; c <= maxCol; c++) {
        if (c > 0) buffer.write(',');
        final cell = allCells['$r:$c'];
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

    final sheet = Sheet(
      id: 'sheet1',
      name: filePath.split('/').last.replaceAll('.csv', ''),
    );

    for (int r = 0; r < lines.length; r++) {
      if (lines[r].trim().isEmpty) continue;
      final values = _parseCsvLine(lines[r]);
      for (int c = 0; c < values.length; c++) {
        sheet.setCell(r, c, values[c]);
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
