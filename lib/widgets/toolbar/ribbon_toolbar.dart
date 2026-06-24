import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/cell.dart';
import '../../providers/workbook_provider.dart';

// =============================================================================
// ثوابت عامة
// =============================================================================

/// الأبعاد الدنيا للأزرار في الشريط — مناسبة للمس على التابلت (40×40).
const double _kMinBtn = 40.0;

/// قائمة بأحجام الخطوط الشائعة.
const List<double> _kFontSizes = [
  8, 9, 10, 11, 12, 14, 16, 18, 20, 22, 24, 26, 28, 36, 48, 72,
];

/// أسماء خطوط مقترحة (على أجهزة المستخدم أو Google Fonts).
const List<String> _kFontFamilies = [
  'Cairo',
  'Arial',
  'Times New Roman',
  'Courier New',
  'Tahoma',
  'Georgia',
];

/// ألوان الخط الأساسية (24 لوناً).
const List<int> _kFontColors = [
  0xFF000000, 0xFF434343, 0xFF666666, 0xFF999999,
  0xFFB7B7B7, 0xFFCCCCCC, 0xFFF44336, 0xFFE91E63,
  0xFF9C27B0, 0xFF673AB7, 0xFF3F51B5, 0xFF2196F3,
  0xFF03A9F4, 0xFF00BCD4, 0xFF009688, 0xFF4CAF50,
  0xFF8BC34A, 0xFFCDDC39, 0xFFFFEB3B, 0xFFFFC107,
  0xFFFF9800, 0xFFFF5722, 0xFF795548, 0xFF607D8B,
];

/// ألوان خلفية الخلية الأساسية (24 لوناً).
const List<int> _kBgColors = [
  0xFFFFFFFF, 0xFFF5F5F5, 0xFFEEEEEE, 0xFFE0E0E0,
  0xFFBDBDBD, 0xFF9E9E9E, 0xFFFFEBEE, 0xFFFCE4EC,
  0xFFF3E5F5, 0xFFEDE7F6, 0xFFE8EAF6, 0xFFE3F2FD,
  0xFFE1F5FE, 0xFFE0F7FA, 0xFFE0F2F1, 0xFFE8F5E9,
  0xFFF1F8E9, 0xFFF9FBE7, 0xFFFFFDE7, 0xFFFFF8E1,
  0xFFFFF3E0, 0xFFFBE9E7, 0xFFEFEBE9, 0xFFECEFF1,
];

// =============================================================================
// دوال مساعدة
// =============================================================================

/// تطبيق تنسيق [newStyle] على الخلية النشطة [sel] عبر الـ [ref].
void _applyStyle(WidgetRef ref, CellPosition? sel, TextStyleModel newStyle) {
  if (sel == null) return;
  ref.read(workbookProvider.notifier).applyStyleToCell(
        sel.sheetId,
        sel.ref,
        newStyle,
      );
}

// =============================================================================
// RibbonToolbar — شريط الأدوات العلوي الرئيسي
// =============================================================================

/// شريط أدوات علوي (Ribbon) مخصص للأجهزة اللوحية.
///
/// ينقسم إلى 4 تبويبات:
/// - **الصفحة الرئيسية**: خط، ألوان، محاذاة، تراجع
/// - **إدراج**: (قريباً)
/// - **صيغ**: (قريباً)
/// - **AI**: (قريباً)
///
/// يقرأ [activeCellProvider] و [selectedCellProvider] للمزامنة،
/// ويستخدم [applyStyleToCell] لتطبيق التعديلات.
class RibbonToolbar extends ConsumerStatefulWidget {
  const RibbonToolbar({super.key});

  @override
  ConsumerState<RibbonToolbar> createState() => _RibbonToolbarState();
}

class _RibbonToolbarState extends ConsumerState<RibbonToolbar> {
  int _tabIndex = 0;

  static const _tabs = ['الصفحة الرئيسية', 'إدراج', 'صيغ', 'AI'];

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF5F5F5),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // شريط التبويبات
          _TabBar(
            selectedIndex: _tabIndex,
            labels: _tabs,
            onChanged: (i) => setState(() => _tabIndex = i),
          ),
          // محتوى التبويب الحالي
          _buildBody(),
          const Divider(height: 1, color: Color(0xFFE0E0E0)),
        ],
      ),
    );
  }

  Widget _buildBody() {
    switch (_tabIndex) {
      case 0:
        return const _HomeTab();
      case 1:
        return const _PlaceholderTab(Icons.add_circle_outline, 'إدراج — قريباً');
      case 2:
        return const _PlaceholderTab(Icons.functions, 'الصيغ — قريباً');
      case 3:
        return const _PlaceholderTab(Icons.auto_awesome, 'المساعد الذكي — قريباً');
      default:
        return const SizedBox.shrink();
    }
  }
}

// =============================================================================
// _TabBar — شريط التبويبات الأفقي
// =============================================================================

class _TabBar extends StatelessWidget {
  final int selectedIndex;
  final List<String> labels;
  final ValueChanged<int> onChanged;

  const _TabBar({
    required this.selectedIndex,
    required this.labels,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFEEEEEE),
        border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        reverse: true,
        child: Row(
          textDirection: TextDirection.rtl,
          children: List.generate(labels.length, (i) {
            final sel = i == selectedIndex;
            return GestureDetector(
              onTap: () => onChanged(i),
              child: Container(
                height: 34,
                constraints: const BoxConstraints(minWidth: 80),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: sel ? Colors.white : Colors.transparent,
                  border: Border(
                    bottom: BorderSide(
                      color: sel ? const Color(0xFF1B5E20) : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
                child: Text(
                  labels[i],
                  style: TextStyle(
                    fontSize: 12,
                    fontFamily: 'Cairo',
                    fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                    color: sel ? const Color(0xFF1B5E20) : Colors.black87,
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

// =============================================================================
// التبويب: الصفحة الرئيسية (Home)
// =============================================================================

class _HomeTab extends ConsumerWidget {
  const _HomeTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sel = ref.watch(selectedCellProvider);
    final cell = ref.watch(activeCellProvider);
    final style = cell?.style ?? const TextStyleModel();

    return Container(
      height: 110,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        reverse: true,
        child: Row(
          textDirection: TextDirection.rtl,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // =============================================================
            // الخط
            // =============================================================
            _Section(
              label: 'الخط',
              children: [
                _FontFamilyDropdown(
                  current: style.fontFamily,
                  onChanged: (v) => _applyStyle(ref, sel, style.copyWith(fontFamily: v)),
                ),
                const SizedBox(width: 2),
                _FontSizeControl(
                  current: style.fontSize,
                  onChanged: (v) => _applyStyle(ref, sel, style.copyWith(fontSize: v)),
                ),
                const SizedBox(width: 2),
                _ToggleBtn(
                  icon: Icons.format_bold,
                  tooltip: 'عريض (Bold)',
                  active: style.isBold,
                  onTap: () => _applyStyle(ref, sel, style.copyWith(isBold: !style.isBold)),
                ),
                _ToggleBtn(
                  icon: Icons.format_italic,
                  tooltip: 'مائل (Italic)',
                  active: style.isItalic,
                  onTap: () => _applyStyle(ref, sel, style.copyWith(isItalic: !style.isItalic)),
                ),
                _ToggleBtn(
                  icon: Icons.format_underline,
                  tooltip: 'تسطير (Underline)',
                  active: style.isUnderline,
                  onTap: () => _applyStyle(ref, sel, style.copyWith(isUnderline: !style.isUnderline)),
                ),
              ],
            ),

            // =============================================================
            // الألوان
            // =============================================================
            _Section(
              label: 'الألوان',
              children: [
                _ColorBtn(
                  color: Color(style.fontColor),
                  tooltip: 'لون الخط',
                  palette: _kFontColors,
                  onSelected: (c) => _applyStyle(ref, sel, style.copyWith(fontColor: c)),
                ),
                const SizedBox(width: 2),
                _ColorBtn(
                  color: Color(style.backgroundColor),
                  tooltip: 'لون الخلفية',
                  palette: _kBgColors,
                  isBg: true,
                  onSelected: (c) => _applyStyle(ref, sel, style.copyWith(backgroundColor: c)),
                ),
              ],
            ),

            // =============================================================
            // المحاذاة
            // =============================================================
            _Section(
              label: 'المحاذاة',
              children: [
                _ToggleBtn(
                  icon: Icons.format_align_right,
                  tooltip: 'يمين',
                  active: style.alignment == TextAlignment.right,
                  onTap: () => _applyStyle(ref, sel, style.copyWith(alignment: TextAlignment.right)),
                ),
                _ToggleBtn(
                  icon: Icons.format_align_center,
                  tooltip: 'وسط',
                  active: style.alignment == TextAlignment.center,
                  onTap: () => _applyStyle(ref, sel, style.copyWith(alignment: TextAlignment.center)),
                ),
                _ToggleBtn(
                  icon: Icons.format_align_left,
                  tooltip: 'يسار',
                  active: style.alignment == TextAlignment.left,
                  onTap: () => _applyStyle(ref, sel, style.copyWith(alignment: TextAlignment.left)),
                ),
              ],
            ),

            // =============================================================
            // تراجع / إعادة
            // =============================================================
            _Section(
              label: 'تراجع',
              children: [
                _ToggleBtn(
                  icon: Icons.undo,
                  tooltip: 'تراجع (Ctrl+Z)',
                  onTap: () => ref.read(workbookProvider.notifier).undo(),
                ),
                _ToggleBtn(
                  icon: Icons.redo,
                  tooltip: 'إعادة (Ctrl+Y)',
                  onTap: () => ref.read(workbookProvider.notifier).redo(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// عنصر نائب للتبويبات غير المكتملة
// =============================================================================

class _PlaceholderTab extends StatelessWidget {
  final IconData icon;
  final String message;

  const _PlaceholderTab(this.icon, this.message);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 110,
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          textDirection: TextDirection.rtl,
          children: [
            Icon(icon, size: 28, color: Colors.grey.shade400),
            const SizedBox(width: 8),
            Text(
              message,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
                fontFamily: 'Cairo',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// المكونات الأساسية
// =============================================================================

// ---------------------------------------------------------------------------
// _Section — مجموعة أدوات مع تسمية سفلية
// ---------------------------------------------------------------------------

class _Section extends StatelessWidget {
  final String label;
  final List<Widget> children;

  const _Section({required this.label, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(textDirection: TextDirection.rtl, mainAxisSize: MainAxisSize.min, children: children),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 9, color: Colors.black54, fontFamily: 'Cairo'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _ToggleBtn — زر تنسيق مع حالة Active/Inactive (Bold, Italic, إلخ)
// ---------------------------------------------------------------------------

class _ToggleBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool active;

  const _ToggleBtn({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      preferBelow: false,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: _kMinBtn,
          height: _kMinBtn,
          margin: const EdgeInsets.all(1),
          decoration: BoxDecoration(
            color: active ? const Color(0xFFE3F2FD) : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: active
                ? Border.all(color: const Color(0xFF1565C0), width: 1.5)
                : null,
          ),
          alignment: Alignment.center,
          child: Icon(
            icon,
            size: 22,
            color: active ? const Color(0xFF1565C0) : Colors.black87,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _FontFamilyDropdown — قائمة اختيار نوع الخط
// ---------------------------------------------------------------------------

class _FontFamilyDropdown extends StatelessWidget {
  final String? current;
  final ValueChanged<String> onChanged;

  const _FontFamilyDropdown({required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final val = _kFontFamilies.contains(current) ? current! : _kFontFamilies.first;
    return Tooltip(
      message: 'نوع الخط',
      preferBelow: false,
      child: Container(
        width: 90,
        height: _kMinBtn,
        margin: const EdgeInsets.all(1),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade400),
          borderRadius: BorderRadius.circular(6),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: val,
            isExpanded: true,
            isDense: true,
            iconSize: 18,
            style: const TextStyle(fontSize: 12, color: Colors.black87, fontFamily: 'Cairo'),
            items: _kFontFamilies.map((f) {
              return DropdownMenuItem<String>(
                value: f,
                alignment: AlignmentDirectional.centerStart,
                child: Text(f, style: const TextStyle(fontFamily: 'Cairo')),
              );
            }).toList(),
            onChanged: (v) {
              if (v != null) onChanged(v);
            },
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _FontSizeControl — أزرار +/- لحجم الخط + عرض القيمة
// ---------------------------------------------------------------------------

class _FontSizeControl extends StatelessWidget {
  final double current;
  final ValueChanged<double> onChanged;

  const _FontSizeControl({required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'حجم الخط',
      preferBelow: false,
      child: Container(
        height: _kMinBtn,
        margin: const EdgeInsets.all(1),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade400),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          _SizeBtn(
            Icons.remove,
            onTap: () => _adjust(-1),
          ),
          SizedBox(
            width: 32,
            child: Center(
              child: Text(
                '${current.round()}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                  fontFamily: 'Cairo',
                ),
              ),
            ),
          ),
          _SizeBtn(
            Icons.add,
            onTap: () => _adjust(1),
          ),
        ]),
      ),
    );
  }

  void _adjust(int dir) {
    final idx = _kFontSizes.indexOf(current);
    final next = dir > 0
        ? (idx < _kFontSizes.length - 1 ? idx + 1 : idx)
        : (idx > 0 ? idx - 1 : idx);
    final newSize = _kFontSizes[next];
    if (newSize != current) onChanged(newSize);
  }
}

/// زر داخل عنصر التحكم بحجم الخط (+ أو -).
class _SizeBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _SizeBtn(this.icon, {required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: _kMinBtn,
        alignment: Alignment.center,
        child: Icon(icon, size: 16, color: Colors.black54),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _ColorBtn — زر اختيار اللون مع نافذة منبثقة
// ---------------------------------------------------------------------------

class _ColorBtn extends StatelessWidget {
  final Color color;
  final String tooltip;
  final List<int> palette;
  final bool isBg;
  final ValueChanged<int> onSelected;

  const _ColorBtn({
    required this.color,
    required this.tooltip,
    required this.palette,
    required this.onSelected,
    this.isBg = false,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      preferBelow: false,
      child: GestureDetector(
        onTap: () => _showPicker(context),
        child: Container(
          width: _kMinBtn,
          height: _kMinBtn,
          margin: const EdgeInsets.all(1),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade400),
            borderRadius: BorderRadius.circular(6),
            color: isBg ? color : Colors.white,
          ),
          alignment: Alignment.center,
          child: Icon(
            isBg ? Icons.format_color_fill : Icons.format_color_text,
            size: 20,
            color: isBg ? Colors.black54 : color,
          ),
        ),
      ),
    );
  }

  void _showPicker(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(tooltip, style: const TextStyle(fontFamily: 'Cairo', fontSize: 14)),
          content: SizedBox(
            width: 260,
            child: Wrap(
              spacing: 4,
              runSpacing: 4,
              textDirection: TextDirection.rtl,
              children: palette.map((c) {
                final sel = color.value == c;
                return GestureDetector(
                  onTap: () {
                    onSelected(c);
                    Navigator.of(ctx).pop();
                  },
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Color(c),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: sel ? const Color(0xFF1565C0) : Colors.grey.shade400,
                        width: sel ? 2.5 : 1,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo')),
            ),
          ],
        );
      },
    );
  }
}
