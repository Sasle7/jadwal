import 'package:flutter_test/flutter_test.dart';
import 'package:jadwal/models/cell.dart';
import 'package:jadwal/models/sheet.dart';
import 'package:jadwal/models/workbook.dart';

void main() {
  group('Cell Model Tests', () {
    test('create empty cell', () {
      final cell = Cell.empty(row: 0, col: 0);
      expect(cell.isEmpty, true);
      expect(cell.id, 'A1');
      expect(cell.type, CellType.empty);
    });

    test('create cell from raw text value', () {
      final cell = Cell.fromRaw(row: 0, col: 0, rawValue: 'Hello');
      expect(cell.id, 'A1');
      expect(cell.rawValue, 'Hello');
      expect(cell.type, CellType.text);
      expect(cell.computedValue, 'Hello');
    });

    test('create cell from raw number value', () {
      final cell = Cell.fromRaw(row: 0, col: 0, rawValue: '42');
      expect(cell.id, 'A1');
      expect(cell.type, CellType.number);
      expect(cell.computedValue, 42);
    });

    test('create cell from raw formula value', () {
      final cell = Cell.fromRaw(row: 0, col: 0, rawValue: '=SUM(A1:A10)');
      expect(cell.id, 'A1');
      expect(cell.type, CellType.formula);
      expect(cell.rawValue, '=SUM(A1:A10)');
      // computedValue stays null until formula engine processes it
      expect(cell.computedValue, isNull);
    });

    test('create cell from raw boolean value', () {
      final cell = Cell.fromRaw(row: 0, col: 0, rawValue: 'true');
      expect(cell.id, 'A1');
      expect(cell.type, CellType.boolean);
      expect(cell.computedValue, true);
    });

    test('empty string becomes empty cell', () {
      final cell = Cell.fromRaw(row: 0, col: 0, rawValue: '   ');
      expect(cell.type, CellType.empty);
      expect(cell.isEmpty, true);
    });

    test('column letters conversion', () {
      expect(Cell.columnLetters(0), 'A');
      expect(Cell.columnLetters(25), 'Z');
      expect(Cell.columnLetters(26), 'AA');
      expect(Cell.columnLetters(51), 'AZ');
      expect(Cell.columnLetters(701), 'ZZ');
      expect(Cell.columnLetters(702), 'AAA');
    });

    test('parse cell reference', () {
      final (row, col) = Cell.parseReference('A1')!;
      expect(row, 0);
      expect(col, 0);

      final (row2, col2) = Cell.parseReference('C5')!;
      expect(row2, 4);
      expect(col2, 2);

      final (row3, col3) = Cell.parseReference('AA10')!;
      expect(row3, 9);
      expect(col3, 26);
    });

    test('invalid reference returns null', () {
      expect(Cell.parseReference(''), isNull);
      expect(Cell.parseReference('123'), isNull);
      expect(Cell.parseReference('A'), isNull);
    });

    test('displayValue for different types', () {
      expect(Cell.fromRaw(row: 0, col: 0, rawValue: 'Hello').displayValue,
          'Hello');
      expect(Cell.fromRaw(row: 0, col: 0, rawValue: '42').displayValue, '42');
      expect(Cell.fromRaw(row: 0, col: 0, rawValue: 'true').displayValue,
          'TRUE');
      expect(Cell.empty(row: 0, col: 0).displayValue, '');
    });

    test('copyWith creates independent copy', () {
      final original = Cell.fromRaw(row: 0, col: 0, rawValue: 'Hello');
      final copy = original.copyWith(rawValue: 'World');
      expect(original.rawValue, 'Hello');
      expect(copy.rawValue, 'World');
      expect(copy.id, original.id);
    });

    test('TextStyleModel default and copyWith', () {
      final defaultStyle = const TextStyleModel();
      expect(defaultStyle.isBold, false);
      expect(defaultStyle.fontSize, 14.0);

      final boldStyle = defaultStyle.copyWith(isBold: true);
      expect(boldStyle.isBold, true);
      expect(boldStyle.fontSize, 14.0); // unchanged
    });

    test('serialization round-trip', () {
      final original = Cell.fromRaw(
        row: 2,
        col: 3,
        rawValue: 'Test',
        style: const TextStyleModel(isBold: true, fontColor: 0xFFFF0000),
      );
      final json = original.toJson();
      final restored = Cell.fromJson(json);
      expect(restored.id, original.id);
      expect(restored.rawValue, original.rawValue);
      expect(restored.type, original.type);
      expect(restored.style.isBold, true);
      expect(restored.style.fontColor, 0xFFFF0000);
    });
  });

  group('Sheet Model Tests', () {
    test('create sheet with default values', () {
      final sheet = Sheet(id: 'test', name: 'ورقة1');
      expect(sheet.id, 'test');
      expect(sheet.name, 'ورقة1');
      expect(sheet.cells, isEmpty);
      expect(sheet.rowCount, 100);
      expect(sheet.columnCount, 26);
    });

    test('setCell returns new sheet with updated cell', () {
      final sheet = Sheet(id: 'test', name: 'ورقة1');
      final updated = sheet.setCell('A1', '10');
      // Original unchanged
      expect(sheet.cells, isEmpty);
      // Updated has the cell
      expect(updated.getCell('A1').rawValue, '10');
      expect(updated.getCell('A1').type, CellType.number);
    });

    test('setCellAt by coordinates', () {
      final sheet = Sheet(id: 'test', name: 'ورقة1');
      final updated = sheet.setCellAt(0, 1, 'Hello');
      expect(updated.getCellAt(0, 1).rawValue, 'Hello');
      expect(updated.getCellAt(0, 1).id, 'B1');
    });

    test('setCells bulk update', () {
      final sheet = Sheet(id: 'test', name: 'ورقة1');
      final updated = sheet.setCells({
        'A1': '10',
        'B1': '20',
        'C1': '=SUM(A1:B1)',
      });
      expect(updated.cellCount, 3);
      expect(updated.getCell('A1').type, CellType.number);
      expect(updated.getCell('C1').type, CellType.formula);
    });

    test('safe getCell returns empty cell for missing reference', () {
      final sheet = Sheet(id: 'test', name: 'ورقة1');
      final cell = sheet.getCell('Z99');
      expect(cell.isEmpty, true);
      expect(cell.id, 'Z99');
      // Original cells map is unchanged
      expect(sheet.cells, isEmpty);
    });

    test('removeCell removes existing cell', () {
      final sheet = Sheet(id: 'test', name: 'ورقة1');
      final withCell = sheet.setCell('A1', '10');
      expect(withCell.cellCount, 1);
      final withoutCell = withCell.removeCell('A1');
      expect(withoutCell.cellCount, 0);
    });

    test('copyWith creates independent copy', () {
      final sheet = Sheet(id: 'test', name: 'ورقة1', rowCount: 50);
      final copy = sheet.copyWith(name: 'نسخة', rowCount: 100);
      expect(sheet.name, 'ورقة1');
      expect(copy.name, 'نسخة');
      expect(copy.rowCount, 100);
      expect(sheet.rowCount, 50);
    });

    test('serialization round-trip', () {
      final sheet = Sheet(id: 'test', name: 'ورقة1');
      final withData = sheet
          .setCell('A1', '10')
          .setCell('B1', '=A1*2')
          .setCell('A2', 'Hello');

      final json = withData.toJson();
      final restored = Sheet.fromJson(json);

      expect(restored.id, 'test');
      expect(restored.name, 'ورقة1');
      expect(restored.cellCount, 3);
      expect(restored.getCell('A1').rawValue, '10');
      expect(restored.getCell('B1').type, CellType.formula);
      expect(restored.getCell('A2').rawValue, 'Hello');
    });
  });

  group('Workbook Model Tests', () {
    test('create new workbook with one sheet', () {
      final workbook = Workbook.createNew();
      expect(workbook.sheets.length, 1);
      expect(workbook.activeSheet.name, 'ورقة1');
      expect(workbook.activeSheetIndex, 0);
    });

    test('activeSheet returns the sheet matching activeSheetId', () {
      final workbook = Workbook.createNew();
      expect(workbook.activeSheet.id, workbook.activeSheetId);
    });

    test('sample workbook has data and formula', () {
      final workbook = Workbook.sample();
      expect(workbook.sheets.length, 1);
      expect(workbook.activeSheet.cellCount, greaterThan(0));
      // Check that a formula cell exists
      final sumCell = workbook.activeSheet.getCell('C6');
      expect(sumCell.type, CellType.formula);
    });

    test('copyWith replaces sheets and activeSheetId', () {
      final original = Workbook.createNew(name: 'أصلي');
      final newSheet = Sheet(id: 'new_id', name: 'ورقة جديدة');
      final copy = original.copyWith(
        name: 'معدل',
        sheets: [newSheet],
        activeSheetId: 'new_id',
      );
      expect(original.name, 'أصلي');
      expect(copy.name, 'معدل');
      expect(copy.sheets.length, 1);
      expect(copy.activeSheet.name, 'ورقة جديدة');
    });

    test('serialization round-trip', () {
      final original = Workbook.sample();
      final json = original.toJson();
      final restored = Workbook.fromJson(json);

      expect(restored.name, original.name);
      expect(restored.sheets.length, original.sheets.length);
      expect(restored.activeSheetId, original.activeSheetId);

      for (final originalSheet in original.sheets) {
        final restoredSheet = restored.sheets.firstWhere(
          (s) => s.id == originalSheet.id,
        );
        expect(restoredSheet.name, originalSheet.name);
        expect(restoredSheet.cellCount, originalSheet.cellCount);
      }
    });

    test('activeSheetIndex returns correct index', () {
      final wb1 = Workbook.createNew();
      expect(wb1.activeSheetIndex, 0);

      // Build a multi-sheet workbook via copyWith
      final multiSheet = wb1.copyWith(
        sheets: [
          Sheet(id: 's1', name: 'Sheet1'),
          Sheet(id: 's2', name: 'Sheet2'),
          Sheet(id: 's3', name: 'Sheet3'),
        ],
        activeSheetId: 's2',
      );
      expect(multiSheet.activeSheetIndex, 1);
    });
  });
}
