import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/workbook.dart';
import '../models/sheet.dart';
import '../models/cell.dart';
import '../services/hive_service.dart';

// =============================================================================
// WorkbookState
// =============================================================================

/// حالة المصنف الكاملة.
///
/// تحتوي على [workbook] بالإضافة إلى حزمة التراجع/الإعادة وعلامات الحالة.
/// جميع الحقول نهائية ويتم التعديل حصراً عبر [copyWith].
class WorkbookState {
  /// المصنف الحالي
  final Workbook workbook;

  /// رصة التراجع (تحتوي على نسخ سابقة من المصنف)
  final List<Workbook> undoStack;

  /// رصة الإعادة (تحتوي على نسخ تم التراجع عنها)
  final List<Workbook> redoStack;

  /// هل هناك تغييرات غير محفوظة
  final bool isDirty;

  /// رسالة الحالة الظاهرة في شريط الحالة
  final String? statusMessage;

  const WorkbookState({
    required this.workbook,
    this.undoStack = const [],
    this.redoStack = const [],
    this.isDirty = false,
    this.statusMessage,
  });

  WorkbookState copyWith({
    Workbook? workbook,
    List<Workbook>? undoStack,
    List<Workbook>? redoStack,
    bool? isDirty,
    String? statusMessage,
    bool clearStatusMessage = false,
  }) {
    return WorkbookState(
      workbook: workbook ?? this.workbook,
      undoStack: undoStack ?? this.undoStack,
      redoStack: redoStack ?? this.redoStack,
      isDirty: isDirty ?? this.isDirty,
      statusMessage: clearStatusMessage ? null : statusMessage ?? this.statusMessage,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WorkbookState &&
          workbook == other.workbook &&
          isDirty == other.isDirty;

  @override
  int get hashCode => Object.hash(workbook, isDirty);
}

// =============================================================================
// WorkbookNotifier
// =============================================================================

/// المزود (Notifier) المسؤول عن إدارة حالة المصنف.
///
/// يستخدم نمط [Notifier] من Riverpod (بدون code-generation) ويعتمد على
/// النسخ العميق (deep copy) عبر [copyWith] لضمان اكتشاف التغييرات
/// وإعادة بناء الويدجتس المتأثرة فقط دون المساس بالأداء.
class WorkbookNotifier extends Notifier<WorkbookState> {
  /// الحد الأقصى لعدد خطوات التراجع
  static const int _maxUndoStack = 50;

  @override
  WorkbookState build() {
    // لا يمكن تحميل من Hive هنا لأن build() متزامن (synchronous)
    // يتم التحميل عبر init() الذي يُنادى من main.dart
    return WorkbookState(workbook: Workbook.createNew());
  }

  /// تهيئة المحاولة: محاولة تحميل آخر مصنف من التخزين المحلي.
  /// يُنادى من [main.dart] بعد فتح صندوق Hive.
  Future<void> init() async {
    try {
      final lastWorkbook = await HiveService.loadLastOpenedWorkbook();
      if (lastWorkbook != null) {
        state = WorkbookState(workbook: lastWorkbook);
      }
    } catch (_) {
      // تجاهل الخطأ
    }
  }

  // ---------------------------------------------------------------------------
  // Public actions
  // ---------------------------------------------------------------------------

  /// تحديث قيمة خلية محددة.
  ///
  /// [sheetId] : معرف الورقة.
  /// [cellIndex] : مرجع الخلية (مثل "A1", "B5").
  /// [newValue] : القيمة الجديدة (نص، رقم، أو صيغة تبدأ بـ =).
  void updateCell(String sheetId, String cellIndex, String newValue) {
    _pushUndo();

    final updatedSheets = state.workbook.sheets.map((sheet) {
      if (sheet.id != sheetId) return sheet;
      return sheet.setCell(cellIndex, newValue);
    }).toList();

    final updatedWorkbook = state.workbook.copyWith(
      sheets: updatedSheets,
      clearComputedValues: newValue.startsWith('='),
    );

    state = state.copyWith(
      workbook: updatedWorkbook,
      isDirty: true,
      statusMessage: '$cellIndex ← $newValue',
    );
  }

  /// تحديث خلية في الورقة النشطة.
  void updateActiveCell(String cellIndex, String newValue) {
    updateCell(state.workbook.activeSheetId, cellIndex, newValue);
  }

  /// تحديث الخلية مباشرة (بدون حفظ في الـ Undo Stack) — للاستخدام في Real-time Sync.
  ///
  /// يُستخدم هذا عندما يكتب المستخدم في شريط الصيغ حرفاً حرفاً،
  /// حتى لا يمتلئ undo stack بمئات الإدخالات المؤقتة.
  void updateCellRealtime(String sheetId, String cellIndex, String newValue) {
    final updatedSheets = state.workbook.sheets.map((sheet) {
      if (sheet.id != sheetId) return sheet;
      return sheet.setCell(cellIndex, newValue);
    }).toList();

    final updatedWorkbook = state.workbook.copyWith(
      sheets: updatedSheets,
      clearComputedValues: newValue.startsWith('='),
    );

    state = state.copyWith(
      workbook: updatedWorkbook,
      isDirty: true,
    );
  }

  /// إضافة ورقة جديدة إلى المصنف.
  void addSheet({String? name}) {
    _pushUndo();

    final newSheet = Sheet(
      id: const Uuid().v4(),
      name: name ?? 'ورقة${state.workbook.sheets.length + 1}',
    );

    final updatedSheets = [...state.workbook.sheets, newSheet];
    final updatedWorkbook = state.workbook.copyWith(
      sheets: updatedSheets,
      activeSheetId: newSheet.id,
    );

    state = state.copyWith(
      workbook: updatedWorkbook,
      isDirty: true,
      statusMessage: '➕ ${newSheet.name}',
    );
  }

  /// التبديل إلى ورقة أخرى.
  void switchSheet(String sheetId) {
    final exists = state.workbook.sheets.any((s) => s.id == sheetId);
    if (!exists) return;

    final updatedWorkbook = state.workbook.copyWith(activeSheetId: sheetId);
    state = state.copyWith(workbook: updatedWorkbook);
  }

  /// التبديل إلى الورقة التالية.
  void nextSheet() {
    final sheets = state.workbook.sheets;
    if (sheets.length <= 1) return;
    final currentIdx = state.workbook.activeSheetIndex;
    final nextIdx = (currentIdx + 1) % sheets.length;
    switchSheet(sheets[nextIdx].id);
  }

  /// التبديل إلى الورقة السابقة.
  void previousSheet() {
    final sheets = state.workbook.sheets;
    if (sheets.length <= 1) return;
    final currentIdx = state.workbook.activeSheetIndex;
    final prevIdx = (currentIdx - 1 + sheets.length) % sheets.length;
    switchSheet(sheets[prevIdx].id);
  }

  /// حذف ورقة (لا يمكن حذف الورقة الوحيدة).
  void deleteSheet(String sheetId) {
    if (state.workbook.sheets.length <= 1) return;

    _pushUndo();

    final updatedSheets = state.workbook.sheets
        .where((s) => s.id != sheetId)
        .toList();

    final newActiveId = state.workbook.activeSheetId == sheetId
        ? updatedSheets.last.id
        : state.workbook.activeSheetId;

    final updatedWorkbook = state.workbook.copyWith(
      sheets: updatedSheets,
      activeSheetId: newActiveId,
    );

    state = state.copyWith(
      workbook: updatedWorkbook,
      isDirty: true,
      statusMessage: '🗑️ تم حذف الورقة',
    );
  }

  /// إعادة تسمية ورقة.
  void renameSheet(String sheetId, String newName) {
    if (newName.trim().isEmpty) return;

    _pushUndo();

    final updatedSheets = state.workbook.sheets.map((sheet) {
      if (sheet.id != sheetId) return sheet;
      return sheet.copyWith(name: newName.trim());
    }).toList();

    final updatedWorkbook = state.workbook.copyWith(sheets: updatedSheets);
    state = state.copyWith(
      workbook: updatedWorkbook,
      isDirty: true,
      statusMessage: '✏️ $newName',
    );
  }

  // ---------------------------------------------------------------------------
  // Formatting
  // ---------------------------------------------------------------------------

  /// تطبيق تنسيق النص على خلايا محددة.
  void applyStyleToCell(String sheetId, String cellIndex, TextStyleModel style) {
    _pushUndo();

    final updatedSheets = state.workbook.sheets.map((sheet) {
      if (sheet.id != sheetId) return sheet;
      final cell = sheet.getCell(cellIndex);
      if (cell.isEmpty) return sheet;
      final updatedCell = cell.copyWith(style: style);
      final newCells = Map<String, Cell>.from(sheet.cells)
        ..[cellIndex.toUpperCase().trim()] = updatedCell;
      return sheet.copyWith(cells: newCells);
    }).toList();

    final updatedWorkbook = state.workbook.copyWith(sheets: updatedSheets);
    state = state.copyWith(
      workbook: updatedWorkbook,
      isDirty: true,
      statusMessage: '🎨 تم تطبيق التنسيق',
    );
  }

  // ---------------------------------------------------------------------------
  // Undo / Redo
  // ---------------------------------------------------------------------------

  /// تراجع عن آخر تغيير.
  void undo() {
    if (state.undoStack.isEmpty) return;

    final previousWorkbook = state.undoStack.last;
    final newUndo = List<Workbook>.from(state.undoStack)..removeLast();
    final newRedo = List<Workbook>.from(state.redoStack)
      ..add(state.workbook);

    state = state.copyWith(
      workbook: previousWorkbook,
      undoStack: newUndo,
      redoStack: newRedo,
      statusMessage: '↩️ تراجع',
    );
  }

  /// إعادة تطبيق آخر تغيير تم التراجع عنه.
  void redo() {
    if (state.redoStack.isEmpty) return;

    final nextWorkbook = state.redoStack.last;
    final newRedo = List<Workbook>.from(state.redoStack)..removeLast();
    final newUndo = List<Workbook>.from(state.undoStack)
      ..add(state.workbook);

    state = state.copyWith(
      workbook: nextWorkbook,
      undoStack: newUndo,
      redoStack: newRedo,
      statusMessage: '↪️ إعادة',
    );
  }

  /// مسح رصة الإعادة (يُستدعى عند كل تغيير جديد).
  void _pushUndo() {
    final newUndo = List<Workbook>.from(state.undoStack)
      ..add(state.workbook);

    // Limit undo stack size
    while (newUndo.length > _maxUndoStack) {
      newUndo.removeAt(0);
    }

    state = state.copyWith(
      undoStack: newUndo,
      redoStack: const [],
    );
  }

  // ---------------------------------------------------------------------------
  // Workbook lifecycle
  // ---------------------------------------------------------------------------

  /// إنشاء مصنف جديد فارغ.
  void createNewWorkbook({String? name}) {
    _pushUndo();
    state = state.copyWith(
      workbook: Workbook.createNew(name: name),
      redoStack: [],
      isDirty: false,
      statusMessage: '📄 مصنف جديد',
    );
  }

  /// تحميل مصنف من كائن Workbook جاهز.
  void loadWorkbook(Workbook workbook) {
    state = WorkbookState(
      workbook: workbook,
      isDirty: false,
      statusMessage: '📂 تم تحميل ${workbook.name}',
    );
  }

  /// تعيين رسالة مؤقتة في شريط الحالة.
  void setStatusMessage(String message) {
    state = state.copyWith(statusMessage: message);
  }

  /// مسح رسالة الحالة.
  void clearStatusMessage() {
    state = state.copyWith(clearStatusMessage: true);
  }
}

// =============================================================================
// Riverpod Providers
// =============================================================================

/// المزود الرئيسي للمصنف.
final workbookProvider = NotifierProvider<WorkbookNotifier, WorkbookState>(
  WorkbookNotifier.new,
);

/// مزود مشتق للورقة النشطة.
final activeSheetProvider = Provider<Sheet>((ref) {
  final workbook = ref.watch(workbookProvider).workbook;
  return workbook.activeSheet;
});

/// مزود مشتق لقائمة الأوراق.
final sheetsProvider = Provider<List<Sheet>>((ref) {
  return ref.watch(workbookProvider).workbook.sheets;
});

/// موقع خلية في ورقة.
class CellPosition {
  final String sheetId;
  final int row;
  final int col;
  const CellPosition({
    required this.sheetId,
    required this.row,
    required this.col,
  });

  String get ref => '${Cell.columnLetters(col)}${row + 1}';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CellPosition &&
          sheetId == other.sheetId &&
          row == other.row &&
          col == other.col;

  @override
  int get hashCode => Object.hash(sheetId, row, col);
}

/// مزود بسيط لتتبع موقع الخلية النشطة حاليًا.
final selectedCellProvider = StateProvider<CellPosition?>((ref) => null);

/// مزود مشتق للخلية النشطة (يُعيد null إن لم توجد).
final activeCellProvider = Provider<Cell?>((ref) {
  final selected = ref.watch(selectedCellProvider);
  if (selected == null) return null;
  final workbook = ref.watch(workbookProvider).workbook;
  try {
    final sheet = workbook.sheets.firstWhere((s) => s.id == selected.sheetId);
    return sheet.getCell(selected.ref);
  } catch (_) {
    return null;
  }
});

/// مزود مشتق لرسالة الحالة.
final statusMessageProvider = Provider<String?>((ref) {
  return ref.watch(workbookProvider).statusMessage;
});

/// مزود مشتق لحالة "غير محفوظ".
final isDirtyProvider = Provider<bool>((ref) {
  return ref.watch(workbookProvider).isDirty;
});
