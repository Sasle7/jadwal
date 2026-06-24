import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/cell.dart';
import '../../providers/workbook_provider.dart';

// =============================================================================
// Ribbon Toolbar
// =============================================================================

/// شريط الأدوات العلوي (Ribbon-style) المخصص للأجهزة اللوحية.
///
/// يوفر أزراراً سريعة للتنسيق، الإدراج، الصيغ، والملف.
/// يعتمد على [selectedCellProvider] لتحديد الخلية النشطة و
/// [applyStyleToCell] لتطبيق التنسيقات.
class SpreadsheetToolbar extends ConsumerWidget {
  const SpreadsheetToolbar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedCellProvider);
    final activeCell = ref.watch(activeCellProvider);
    final style = activeCell?.style ?? const TextStyleModel();

    return Container(
      color: const Color(0xFFF5F5F5),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ToolbarTab(
            children: [
              // ---------- الحافظة ----------
              _ToolbarGroup(
                label: 'الحافظة',
                children: [
                  _ToolbarButton(
                    icon: Icons.content_copy,
                    tooltip: 'نسخ',
                    onTap: () => _copy(ref),
                  ),
                  _ToolbarButton(
                    icon: Icons.content_paste,
                    tooltip: 'لصق',
                    onTap: () => _paste(ref),
                  ),
                  _ToolbarButton(
                    icon: Icons.content_cut,
                    tooltip: 'قص',
                    onTap: () => _cut(ref),
                  ),
                ],
              ),

              // ---------- الخط ----------
              _ToolbarGroup(
                label: 'الخط',
                children: [
                  _ToolbarButton(
                    icon: Icons.format_bold,
                    tooltip: 'عريض',
                    isActive: style.isBold,
                    onTap: () => _toggleBold(ref, selected, style),
                  ),
                  _ToolbarButton(
                    icon: Icons.format_italic,
                    tooltip: 'مائل',
                    isActive: style.isItalic,
                    onTap: () => _toggleItalic(ref, selected, style),
                  ),
                  _ToolbarButton(
                    icon: Icons.format_underline,
                    tooltip: 'تسطير',
                    isActive: style.isUnderline,
                    onTap: () => _toggleUnderline(ref, selected, style),
                  ),
                ],
              ),

              // ---------- المحاذاة ----------
              _ToolbarGroup(
                label: 'المحاذاة',
                children: [
                  _ToolbarButton(
                    icon: Icons.format_align_left,
                    tooltip: 'يسار',
                    onTap: () => _setAlignment(ref, selected, TextAlignment.left),
                  ),
                  _ToolbarButton(
                    icon: Icons.format_align_center,
                    tooltip: 'وسط',
                    onTap: () => _setAlignment(ref, selected, TextAlignment.center),
                  ),
                  _ToolbarButton(
                    icon: Icons.format_align_right,
                    tooltip: 'يمين',
                    onTap: () => _setAlignment(ref, selected, TextAlignment.right),
                  ),
                ],
              ),

              // ---------- الصيغ ----------
              _ToolbarGroup(
                label: 'الصيغ',
                children: [
                  _ToolbarButton(
                    icon: Icons.functions,
                    tooltip: 'SUM',
                    onTap: () => _insertFormula(ref, selected, 'SUM'),
                  ),
                  _ToolbarButton(
                    icon: Icons.show_chart,
                    tooltip: 'AVERAGE',
                    onTap: () => _insertFormula(ref, selected, 'AVERAGE'),
                  ),
                  _ToolbarButton(
                    icon: Icons.format_list_numbered,
                    tooltip: 'COUNT',
                    onTap: () => _insertFormula(ref, selected, 'COUNT'),
                  ),
                ],
              ),

              // ---------- ملف ----------
              _ToolbarGroup(
                label: 'ملف',
                children: [
                  _ToolbarButton(
                    icon: Icons.save,
                    tooltip: 'حفظ',
                    onTap: () => _save(ref),
                  ),
                  _ToolbarButton(
                    icon: Icons.folder_open,
                    tooltip: 'فتح',
                    onTap: () => _open(ref),
                  ),
                  _ToolbarButton(
                    icon: Icons.add,
                    tooltip: 'ورقة جديدة',
                    onTap: () => ref.read(workbookProvider.notifier).addSheet(),
                  ),
                ],
              ),

              // ---------- تراجع ----------
              _ToolbarGroup(
                label: 'تراجع',
                children: [
                  _ToolbarButton(
                    icon: Icons.undo,
                    tooltip: 'تراجع',
                    onTap: () => ref.read(workbookProvider.notifier).undo(),
                  ),
                  _ToolbarButton(
                    icon: Icons.redo,
                    tooltip: 'إعادة',
                    onTap: () => ref.read(workbookProvider.notifier).redo(),
                  ),
                ],
              ),
            ],
          ),
          Divider(height: 1, color: Colors.grey.shade300),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // تنسيق الخط
  // ---------------------------------------------------------------------------

  void _toggleBold(WidgetRef ref, CellPosition? sel, TextStyleModel style) {
    if (sel == null) return;
    final newStyle = style.copyWith(isBold: !style.isBold);
    ref.read(workbookProvider.notifier).applyStyleToCell(
          sel.sheetId,
          sel.ref,
          newStyle,
        );
  }

  void _toggleItalic(WidgetRef ref, CellPosition? sel, TextStyleModel style) {
    if (sel == null) return;
    final newStyle = style.copyWith(isItalic: !style.isItalic);
    ref.read(workbookProvider.notifier).applyStyleToCell(
          sel.sheetId,
          sel.ref,
          newStyle,
        );
  }

  void _toggleUnderline(WidgetRef ref, CellPosition? sel, TextStyleModel style) {
    if (sel == null) return;
    final newStyle = style.copyWith(isUnderline: !style.isUnderline);
    ref.read(workbookProvider.notifier).applyStyleToCell(
          sel.sheetId,
          sel.ref,
          newStyle,
        );
  }

  void _setAlignment(
    WidgetRef ref,
    CellPosition? sel,
    TextAlignment alignment,
  ) {
    if (sel == null) return;
    final newStyle = const TextStyleModel().copyWith(alignment: alignment);
    ref.read(workbookProvider.notifier).applyStyleToCell(
          sel.sheetId,
          sel.ref,
          newStyle,
        );
  }

  // ---------------------------------------------------------------------------
  // صيغ سريعة
  // ---------------------------------------------------------------------------

  void _insertFormula(WidgetRef ref, CellPosition? sel, String name) {
    if (sel == null) return;
    ref.read(workbookProvider.notifier).updateCell(
          sel.sheetId,
          sel.ref,
          '=$name()',
        );
    ref.read(workbookProvider.notifier).setStatusMessage('📐 $name');
  }

  // ---------------------------------------------------------------------------
  // حافظة (placeholder — سيتم ربطها لاحقاً)
  // ---------------------------------------------------------------------------

  void _copy(WidgetRef ref) {
    ref.read(workbookProvider.notifier).setStatusMessage('📋 تم النسخ');
  }

  void _paste(WidgetRef ref) {
    ref.read(workbookProvider.notifier).setStatusMessage('📋 تم اللصق');
  }

  void _cut(WidgetRef ref) {
    ref.read(workbookProvider.notifier).setStatusMessage('📋 تم القص');
  }

  // ---------------------------------------------------------------------------
  // ملف (placeholder — سيتم ربطه لاحقاً)
  // ---------------------------------------------------------------------------

  void _save(WidgetRef ref) {
    ref.read(workbookProvider.notifier).setStatusMessage('💾 جاري الحفظ...');
  }

  void _open(WidgetRef ref) {
    ref.read(workbookProvider.notifier).setStatusMessage('📂 اختَر ملفاً');
  }
}

// =============================================================================
// Helper widgets
// =============================================================================

/// مجموعة أدوات في الشريط (مجموعة أزرار + تسمية).
class _ToolbarGroup extends StatelessWidget {
  final String label;
  final List<Widget> children;

  const _ToolbarGroup({required this.label, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(mainAxisSize: MainAxisSize.min, children: children),
          Text(
            label,
            style: const TextStyle(
              fontSize: 9,
              color: Colors.black54,
              fontFamily: 'Cairo',
            ),
          ),
        ],
      ),
    );
  }
}

/// زر فردي في شريط الأدوات.
class _ToolbarButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool isActive;

  const _ToolbarButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 32,
          height: 28,
          margin: const EdgeInsets.all(1),
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFFE3F2FD) : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
            border: isActive
                ? Border.all(color: const Color(0xFF1565C0))
                : null,
          ),
          alignment: Alignment.center,
          child: Icon(
            icon,
            size: 18,
            color: isActive ? const Color(0xFF1565C0) : Colors.black87,
          ),
        ),
      ),
    );
  }
}

/// تبويب أفقي قابل للتمرير في شريط الأدوات.
class _ToolbarTab extends StatelessWidget {
  final List<Widget> children;

  const _ToolbarTab({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        reverse: true, // RTL
        child: Row(
          textDirection: TextDirection.rtl,
          children: children,
        ),
      ),
    );
  }
}
