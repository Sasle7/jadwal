import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/workbook_provider.dart';

/// علامات تبويب الأوراق - تعرض الأوراق وتسمح بالتنقل بينها
class SheetTabs extends ConsumerWidget {
  const SheetTabs({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(workbookProvider);
    final sheets = state.workbook.sheets;
    final activeIndex = state.workbook.activeSheetIndex;

    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: const Color(0xFFEEEEEE),
        border: Border(
          top: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          // زر إضافة ورقة جديدة
          GestureDetector(
            onTap: () {
              ref.read(workbookProvider.notifier).addSheet();
            },
            child: Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(color: Colors.grey.shade300),
                ),
              ),
              child: const Icon(
                Icons.add,
                size: 18,
                color: Color(0xFF1B5E20),
              ),
            ),
          ),

          // قائمة الأوراق
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              reverse: true, // RTL
              itemCount: sheets.length,
              itemBuilder: (context, index) {
                final sheet = sheets[index];
                final isActive = index == activeIndex;
                return _SheetTab(
                  name: sheet.name,
                  isActive: isActive,
                  onTap: () {
                    ref.read(workbookProvider.notifier).switchSheet(sheet.id);
                  },
                  onDoubleTap: () {
                    _showRenameDialog(context, ref, index, sheet.name);
                  },
                  onDelete: sheets.length > 1
                      ? () {
                          ref
                              .read(workbookProvider.notifier)
                              .deleteSheet(sheet.id);
                        }
                      : null,
                );
              },
            ),
          ),

          // عداد الأوراق
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            alignment: Alignment.center,
            child: Text(
              '${sheets.length} ورقة',
              style: const TextStyle(
                fontSize: 11,
                color: Colors.black54,
                fontFamily: 'Cairo',
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showRenameDialog(
    BuildContext context,
    WidgetRef ref,
    int index,
    String currentName,
  ) {
    final controller = TextEditingController(text: currentName);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'إعادة تسمية الورقة',
          style: TextStyle(fontFamily: 'Cairo'),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(fontFamily: 'Cairo'),
          decoration: const InputDecoration(
            labelText: 'اسم الورقة',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'إلغاء',
              style: TextStyle(fontFamily: 'Cairo'),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                final sheetId = ref.read(sheetsProvider)[index].id;
                ref
                    .read(workbookProvider.notifier)
                    .renameSheet(sheetId, controller.text.trim());
                Navigator.pop(context);
              }
            },
            child: const Text(
              'موافق',
              style: TextStyle(fontFamily: 'Cairo'),
            ),
          ),
        ],
      ),
    );
  }
}

/// ويدجت ورقة واحدة في شريط التبويب
class _SheetTab extends StatelessWidget {
  final String name;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onDoubleTap;
  final VoidCallback? onDelete;

  const _SheetTab({
    required this.name,
    required this.isActive,
    required this.onTap,
    required this.onDoubleTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onDoubleTap: onDoubleTap,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: isActive ? Colors.white : const Color(0xFFE0E0E0),
          border: Border(
            top: isActive
                ? const BorderSide(color: Color(0xFF1B5E20), width: 2)
                : BorderSide.none,
            left: const BorderSide(color: Color(0xFFBDBDBD), width: 0.5),
            right: const BorderSide(color: Color(0xFFBDBDBD), width: 0.5),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (onDelete != null)
              GestureDetector(
                onTap: onDelete,
                child: const Padding(
                  padding: EdgeInsets.only(left: 4),
                  child: Icon(Icons.close, size: 14, color: Colors.black38),
                ),
              ),
            Text(
              name,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                color: isActive ? Colors.black87 : Colors.black54,
                fontFamily: 'Cairo',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
