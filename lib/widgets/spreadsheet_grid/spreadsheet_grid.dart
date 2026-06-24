import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import '../../models/cell.dart';
import '../../models/sheet.dart';
import '../../providers/workbook_provider.dart';

// =============================================================================
// SheetDataSource
// =============================================================================

/// مصدر البيانات للشبكة — يربط [Sheet] مع [SfDataGrid].
///
/// يُعاد بناؤه بالكامل عند تغير الورقة، لكنه لا يُعاد بناء كل خلية
/// عند تعديل خلية واحدة (لأن SfDataGrid يتولى إعادة الرسم الداخلي).
class SheetDataSource extends DataGridSource {
  final String sheetId;
  final Sheet sheet;
  final WorkbookNotifier notifier;
  final CellPosition? activeCell;

  List<DataGridRow> _rows = [];

  SheetDataSource({
    required this.sheetId,
    required this.sheet,
    required this.notifier,
    required this.activeCell,
  }) {
    _buildRows();
  }

  void _buildRows() {
    _rows = List.generate(sheet.rowCount, (r) {
      final cells = <DataGridCell>[
        // عمود رقم الصف
        DataGridCell<int>(columnName: 'rowHeader', value: r + 1),
        // أعمدة البيانات
        for (int c = 0; c < sheet.columnCount; c++)
          DataGridCell<String>(
            columnName: 'col_$c',
            value: sheet.getCellAt(r, c).displayValue,
          ),
      ];
      return DataGridRow(cells: cells);
    });
  }

  @override
  List<DataGridRow> get rows => _rows;

  @override
  DataGridRowAdapter? buildRow(DataGridRow row) {
    final rowIndex = _rows.indexOf(row);
    if (rowIndex < 0) return null;

    return DataGridRowAdapter(
      cells: row.getCells().map<Widget>((dataCell) {
        // عمود ترويسة الصف
        if (dataCell.columnName == 'rowHeader') {
          return _buildRowHeader(dataCell.value as int);
        }

        final colIndex = int.parse(dataCell.columnName.split('_')[1]);
        final cellData = sheet.getCellAt(rowIndex, colIndex);

        final isActive = activeCell != null &&
            activeCell!.sheetId == sheetId &&
            activeCell!.row == rowIndex &&
            activeCell!.col == colIndex;

        return _buildCellWidget(cellData, isActive);
      }).toList(),
    );
  }

  // ---------------------------------------------------------------------------
  // Row header
  // ---------------------------------------------------------------------------

  Widget _buildRowHeader(int rowNumber) {
    return Container(
      color: const Color(0xFFF5F5F5),
      alignment: Alignment.center,
      child: Text(
        '$rowNumber',
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 12,
          color: Colors.black54,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Cell widget
  // ---------------------------------------------------------------------------

  Widget _buildCellWidget(Cell cellData, bool isActive) {
    final style = cellData.style;

    return Container(
      alignment: _mapAlignment(style.alignment),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: isActive
            ? const Color(0xFFE3F2FD)
            : Color(style.backgroundColor),
        border: Border.all(
          color: isActive ? const Color(0xFF1565C0) : const Color(0xFFE0E0E0),
          width: isActive ? 2.0 : 0.5,
        ),
      ),
      child: Text(
        cellData.displayValue,
        style: TextStyle(
          fontSize: style.fontSize,
          fontWeight: style.isBold ? FontWeight.bold : FontWeight.normal,
          color: Color(style.fontColor),
          fontStyle: style.isItalic ? FontStyle.italic : FontStyle.normal,
          decoration: style.isUnderline ? TextDecoration.underline : TextDecoration.none,
          fontFamily: 'Cairo',
        ),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Alignment _mapAlignment(TextAlignment alignment) {
    switch (alignment) {
      case TextAlignment.center:
        return Alignment.center;
      case TextAlignment.right:
        return Alignment.centerRight;
      case TextAlignment.left:
        return Alignment.centerLeft;
    }
  }

  // ---------------------------------------------------------------------------
  // Public update
  // ---------------------------------------------------------------------------

  void update({
    required Sheet newSheet,
    required CellPosition? newActiveCell,
  }) {
    _buildRows();
    notifyListeners();
  }
}

// =============================================================================
// SpreadsheetGrid widget
// =============================================================================

/// ويدجت شبكة البيانات الرئيسية.
///
/// تعرض [SfDataGrid] وترتبط بـ [activeSheetProvider] و [selectedCellProvider]
/// لعرض الخلايا وتحديثها.
class SpreadsheetGrid extends ConsumerStatefulWidget {
  const SpreadsheetGrid({super.key});

  @override
  ConsumerState<SpreadsheetGrid> createState() => _SpreadsheetGridState();
}

class _SpreadsheetGridState extends ConsumerState<SpreadsheetGrid> {
  late DataGridController _controller;
  SheetDataSource? _source;

  @override
  void initState() {
    super.initState();
    _controller = DataGridController();
  }

  /// بناء أو تحديث المصدر.
  void _rebuildSource() {
    final sheet = ref.read(activeSheetProvider);
    final notifier = ref.read(workbookProvider.notifier);
    final active = ref.read(selectedCellProvider);

    if (_source == null) {
      _source = SheetDataSource(
        sheetId: sheet.id,
        sheet: sheet,
        notifier: notifier,
        activeCell: active,
      );
    } else {
      _source!.update(
        newSheet: sheet,
        newActiveCell: active,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // الاستماع إلى تغيرات الورقة النشطة أو الخلية المحددة
    ref.listen<Sheet>(activeSheetProvider, (_, sheet) {
      _source?.update(
        newSheet: sheet,
        newActiveCell: ref.read(selectedCellProvider),
      );
    });

    ref.listen<CellPosition?>(selectedCellProvider, (_, pos) {
      if (_source != null) {
        _source!.update(
          newSheet: ref.read(activeSheetProvider),
          newActiveCell: pos,
        );
      }
    });

    // بناء أولي
    _rebuildSource();

    final sheet = ref.watch(activeSheetProvider);

    return SfDataGrid(
      source: _source!,
      controller: _controller,
      columnWidthMode: ColumnWidthMode.fitByCellValue,
      gridLinesVisibility: GridLinesVisibility.both,
      headerGridLinesVisibility: GridLinesVisibility.both,
      selectionMode: SelectionMode.single,
      navigationMode: GridNavigationMode.cell,
      allowSwiping: true,
      frozenColumnsCount: 1,
      frozenRowsCount: 1,
      columnResizeMode: ColumnResizeMode.onResizeEnd,
      defaultColumnWidth: 120,
      cellPadding: const EdgeInsets.all(2),

      // أعمدة
      columns: [
        GridColumn(
          columnName: 'rowHeader',
          width: 50,
          columnBuilder: (context) => _buildColumnHeader('#'),
        ),
        for (int c = 0; c < sheet.columnCount; c++)
          GridColumn(
            columnName: 'col_$c',
            label: _buildColumnHeader(Cell.columnLetters(c)),
          ),
      ],

      onQueryRowHeight: (details) => 30.0,
      headerRowHeight: 30.0,

      // نقر الخلية → تحديث الخلية النشطة
      onCellTap: (details) {
        final col = details.rowColumnIndex.columnIndex - 1; // ناقص عمود الترويسة
        final row = details.rowColumnIndex.rowIndex;
        if (col >= 0 && row >= 0) {
          ref.read(selectedCellProvider.notifier).state = CellPosition(
            sheetId: sheet.id,
            row: row,
            col: col,
          );
        }
      },
    );
  }

  Widget _buildColumnHeader(String text) {
    return Container(
      color: const Color(0xFFF5F5F5),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 12,
          color: Colors.black54,
        ),
      ),
    );
  }
}
