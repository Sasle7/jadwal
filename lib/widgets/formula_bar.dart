import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/cell.dart';
import '../providers/workbook_provider.dart';

/// قائمة دوال الصيغ الأساسية للاقتراحات.
const List<String> _builtinFunctions = [
  'SUM', 'AVERAGE', 'COUNT', 'MIN', 'MAX',
  'IF', 'CONCATENATE', 'ROUND', 'ABS', 'SQRT', 'POWER',
  'NOW', 'TODAY',
];

// =============================================================================
// FormulaBar
// =============================================================================

/// شريط الصيغ — يعرض محتوى الخلية النشطة ويسمح بتحريرها.
///
/// - عند التركيز على الخلية، يُظهر `rawValue` كاملاً (بما في ذلك `=...`).
/// - عند كتابة `=` تظهر قائمة اقتراحات بالدوال.
/// - عند الضغط على Enter يتم حفظ القيمة عبر `updateCell`.
class FormulaBar extends ConsumerStatefulWidget {
  const FormulaBar({super.key});

  @override
  ConsumerState<FormulaBar> createState() => _FormulaBarState();
}

class _FormulaBarState extends ConsumerState<FormulaBar> {
  late TextEditingController _controller;
  late FocusNode _focusNode;

  bool _isEditing = false;
  List<String> _suggestions = [];
  // قيمة الخلية الأصلية قبل بدء التحرير (تُستخدم للتراجع الصحيح)
  String _originalCellValue = '';
  // نمنع التحديث التلقائي للحقل أثناء التحرير
  bool _suppressSync = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Focus management
  // ---------------------------------------------------------------------------

  void _onFocusChanged() {
    if (!_focusNode.hasFocus) {
      _commitEdit();
      setState(() {
        _isEditing = false;
        _suggestions = [];
      });
    } else {
      // عند بدء التحرير — حفظ القيمة الأصلية للخلية للتراجع الصحيح
      _captureOriginalValue();
      setState(() {
        _isEditing = true;
      });
    }
  }

  /// تسجيل القيمة الأصلية للخلية النشطة قبل أي تعديل (للتراجع).
  void _captureOriginalValue() {
    final selected = ref.read(selectedCellProvider);
    if (selected == null) return;
    try {
      final workbook = ref.read(workbookProvider).workbook;
      final sheet = workbook.sheets.firstWhere((s) => s.id == selected.sheetId);
      final cell = sheet.getCell(selected.ref);
      _originalCellValue = cell.rawValue;
    } catch (_) {
      _originalCellValue = '';
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final activeCell = ref.watch(activeCellProvider);
    final selected = ref.watch(selectedCellProvider);

    // مزامنة الحقل مع الخلية النشطة (فقط حين لا يكون المستخدم يحرر)
    if (!_isEditing && activeCell != null && !_suppressSync) {
      _syncController(activeCell);
    }

    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      child: Row(
        textDirection: TextDirection.ltr,
        children: [
          // ----- مرجع الخلية (A1) -----
          _buildReferenceLabel(selected),

          // ----- زر fx -----
          _buildFxButton(),

          const VerticalDivider(width: 1),

          // ----- حقل الإدخال + الاقتراحات -----
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Stack(
                  children: [
                    _buildTextField(),
                    if (_suggestions.isNotEmpty && _isEditing)
                      _buildSuggestionsList(constraints),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Sub-widgets
  // ---------------------------------------------------------------------------

  Widget _buildReferenceLabel(CellPosition? selected) {
    return Container(
      width: 100,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      child: Text(
        selected?.ref ?? '',
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 13,
          fontFamily: 'Cairo',
        ),
      ),
    );
  }

  Widget _buildFxButton() {
    return GestureDetector(
      onTap: () {
        _captureOriginalValue();
        _controller.text = '=';
        _controller.selection = const TextSelection.collapsed(offset: 1);
        setState(() => _isEditing = true);
        _focusNode.requestFocus();
      },
      child: Container(
        width: 40,
        alignment: Alignment.center,
        child: const Text(
          'fx',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: Color(0xFF1B5E20),
            fontStyle: FontStyle.italic,
          ),
        ),
      ),
    );
  }

  Widget _buildTextField() {
    return TextField(
      controller: _controller,
      focusNode: _focusNode,
      textDirection: TextDirection.ltr,
      style: const TextStyle(fontSize: 14, fontFamily: 'Cairo'),
      decoration: const InputDecoration(
        border: InputBorder.none,
        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        isDense: true,
      ),
      onTap: () {
        _captureOriginalValue();
        setState(() {
          _isEditing = true;
        });
      },
      onChanged: (value) {
        // تحديث الاقتراحات للصيغ
        if (value.startsWith('=')) {
          _updateSuggestions(value.substring(1));
        } else {
          setState(() => _suggestions = []);
        }
        // تحديث الخلية في الوقت الفعلي (Real-time sync) حرفاً حرفاً
        _updateCellRealtime(value);
      },
      onSubmitted: (value) {
        _commitEdit();
        setState(() {
          _isEditing = false;
          _suggestions = [];
        });
        _focusNode.unfocus();
      },
    );
  }

  Widget _buildSuggestionsList(BoxConstraints constraints) {
    return Positioned(
      top: 38,
      left: 0,
      right: 0,
      child: Material(
        elevation: 4,
        child: Container(
          constraints: BoxConstraints(maxHeight: constraints.maxHeight * 3),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _suggestions.length,
            itemBuilder: (context, index) {
              return ListTile(
                dense: true,
                title: Text(
                  _suggestions[index],
                  style: const TextStyle(fontFamily: 'Cairo', fontSize: 13),
                ),
                onTap: () {
                  _controller.text = '=${_suggestions[index]}(';
                  _controller.selection = TextSelection.collapsed(
                    offset: _controller.text.length,
                  );
                  setState(() => _suggestions = []);
                  _focusNode.requestFocus();
                },
              );
            },
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Logic
  // ---------------------------------------------------------------------------

  /// مزامنة حقل النص مع الخلية النشطة.
  void _syncController(Cell cell) {
    _suppressSync = true;
    if (cell.type == CellType.formula) {
      // نعرض rawValue كاملاً (بما في ذلك =)
      _controller.text = cell.rawValue;
    } else {
      _controller.text = cell.rawValue;
    }
    _suppressSync = false;
  }

  /// تصفية الدوال حسب البادئة.
  void _updateSuggestions(String prefix) {
    final upper = prefix.toUpperCase();
    setState(() {
      if (upper.isEmpty) {
        _suggestions = List.of(_builtinFunctions);
      } else {
        _suggestions = _builtinFunctions
            .where((f) => f.startsWith(upper))
            .toList();
      }
    });
  }

  /// تحديث الخلية فورياً دون حفظ في undo stack (لكل حرف).
  void _updateCellRealtime(String value) {
    final selected = ref.read(selectedCellProvider);
    if (selected == null) return;

    ref.read(workbookProvider.notifier).updateCellRealtime(
          selected.sheetId,
          selected.ref,
          value,
        );
  }

  /// حفظ القيمة المدخلة في الخلية النشطة مع دعم التراجع الصحيح.
  ///
  /// تستخدم [commitCellEdit] بدلاً من [updateCell] لضمان أن undo stack
  /// يحتوي على القيمة الأصلية للخلية (قبل التحرير) وليس آخر تحديث real-time.
  void _commitEdit() {
    if (!_isEditing && !_focusNode.hasFocus) return;

    final selected = ref.read(selectedCellProvider);
    if (selected == null) return;

    final text = _controller.text.trim();

    if (text.isNotEmpty) {
      ref.read(workbookProvider.notifier).commitCellEdit(
            selected.sheetId,
            selected.ref,
            text,
            originalValue: _originalCellValue,
          );
    }

    setState(() => _suggestions = []);
  }
}
