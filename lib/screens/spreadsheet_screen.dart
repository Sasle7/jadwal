import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/workbook.dart';
import '../providers/workbook_provider.dart';
import '../services/hive_service.dart';
import '../widgets/toolbar/ribbon_toolbar.dart';
import '../widgets/formula_bar.dart';
import '../widgets/spreadsheet_grid/spreadsheet_grid.dart';
import '../widgets/sheet_tabs.dart';

/// الشاشة الرئيسية للتطبيق - تجمع كل المكونات
class SpreadsheetScreen extends ConsumerStatefulWidget {
  const SpreadsheetScreen({super.key});

  @override
  ConsumerState<SpreadsheetScreen> createState() => _SpreadsheetScreenState();
}

class _SpreadsheetScreenState extends ConsumerState<SpreadsheetScreen> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(workbookProvider);
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      // App Bar
      appBar: AppBar(
        title: Row(
          children: [
            // شعار التطبيق
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'ج',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 12),
            // اسم الملف
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  state.workbook.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Cairo',
                  ),
                ),
                if (state.isDirty)
                  const Text(
                    'غير محفوظ',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.amberAccent,
                      fontFamily: 'Cairo',
                    ),
                  ),
              ],
            ),
          ],
        ),
        actions: [
          // زر القائمة
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              _handleMenuAction(value);
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'new',
                child: Text('مصنف جديد', style: TextStyle(fontFamily: 'Cairo')),
              ),
              const PopupMenuItem(
                value: 'open',
                child: Text('فتح', style: TextStyle(fontFamily: 'Cairo')),
              ),
              const PopupMenuItem(
                value: 'save',
                child: Text('حفظ', style: TextStyle(fontFamily: 'Cairo')),
              ),
              const PopupMenuItem(
                value: 'export_xlsx',
                child: Text('تصدير XLSX', style: TextStyle(fontFamily: 'Cairo')),
              ),
              const PopupMenuItem(
                value: 'export_csv',
                child: Text('تصدير CSV', style: TextStyle(fontFamily: 'Cairo')),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'sample',
                child: Text('بيانات تجريبية', style: TextStyle(fontFamily: 'Cairo')),
              ),
            ],
          ),
        ],
        // تبويبات شريط الأدوات داخل AppBar
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(52),
          child: RibbonToolbar(),
        ),
      ),

      // جسم الشاشة
      body: Column(
        children: [
          // شريط الصيغ
          const FormulaBar(),

          // الشبكة (تملأ المساحة المتبقية)
          Expanded(
            child: Container(
              color: Colors.white,
              child: const SpreadsheetGrid(),
            ),
          ),

          // شريط الحالة
          _StatusBar(state.statusMessage),

          // علامات تبويب الأوراق
          const SheetTabs(),
        ],
      ),
    );
  }

  void _handleMenuAction(String value) async {
    final notifier = ref.read(workbookProvider.notifier);
    switch (value) {
      case 'new':
        notifier.createNewWorkbook();
        break;
      case 'sample':
        notifier.loadWorkbook(Workbook.sample());
        break;
      case 'open':
        await _showOpenDialog();
        break;
      case 'save':
        await _saveCurrentWorkbook(notifier);
        break;
      case 'export_xlsx':
        notifier.setStatusMessage('جاري التصدير إلى XLSX...');
        break;
      case 'export_csv':
        notifier.setStatusMessage('جاري التصدير إلى CSV...');
        break;
    }
  }

  Future<void> _saveCurrentWorkbook(dynamic notifier) async {
    final state = ref.read(workbookProvider);
    try {
      await HiveService.saveWorkbook(state.workbook);
      notifier.setStatusMessage('💾 تم الحفظ بنجاح');
    } catch (e) {
      notifier.setStatusMessage('❌ فشل الحفظ: $e');
    }
  }

  Future<void> _showOpenDialog() async {
    final notifier = ref.read(workbookProvider.notifier);
    try {
      final metadataList = await HiveService.listSavedWorkbooks();
      if (metadataList.isEmpty) {
        notifier.setStatusMessage('لا توجد مصنفات محفوظة');
        return;
      }

      if (!context.mounted) return;

      final selected = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            title: const Text('فتح مصنف', style: TextStyle(fontFamily: 'Cairo')),
            content: SizedBox(
              width: 400,
              height: 300,
              child: ListView.builder(
                itemCount: metadataList.length,
                itemBuilder: (context, index) {
                  final item = metadataList[index];
                  return ListTile(
                    title: Text(
                      item['name'] as String? ?? 'بدون اسم',
                      style: const TextStyle(fontFamily: 'Cairo'),
                    ),
                    subtitle: Text(
                      'آخر حفظ: ${_formatDate(item['lastModified'] as String?)}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () async {
                        await HiveService.deleteWorkbook(item['id'] as String);
                        if (ctx.mounted) Navigator.of(ctx).pop();
                        _showOpenDialog();
                      },
                    ),
                    onTap: () => Navigator.of(ctx).pop(item),
                  );
                },
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

      if (selected != null && context.mounted) {
        final workbook = await HiveService.loadWorkbook(selected['id'] as String);
        if (workbook != null) {
          notifier.loadWorkbook(workbook);
          notifier.setStatusMessage('📂 تم فتح ${workbook.name}');
        } else {
          notifier.setStatusMessage('❌ فشل تحميل المصنف');
        }
      }
    } catch (e) {
      notifier.setStatusMessage('❌ خطأ: $e');
    }
  }

  String _formatDate(String? iso) {
    if (iso == null) return 'غير معروف';
    try {
      final dt = DateTime.parse(iso);
      return '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')} '
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return 'غير معروف';
    }
  }
}

/// شريط الحالة السفلي
class _StatusBar extends StatelessWidget {
  final String? message;

  const _StatusBar(this.message);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        border: Border(
          top: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          Icon(Icons.info_outline, size: 14, color: Colors.grey.shade600),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              message ?? 'جاهز',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade700,
                fontFamily: 'Cairo',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
