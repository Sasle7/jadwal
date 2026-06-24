import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/workbook.dart';

// =============================================================================
// HiveService — تخزين واسترجاع المصنفات محلياً
// =============================================================================

/// خدمة التخزين المحلي باستخدام Hive.
///
/// تخزّن المصنفات بصيغة JSON داخل صندوق Hive (`jadwal_settings`).
/// كما تحتفظ بقائمة تعريفات بالمصنفات المحفوظة (الاسم، المعرف، تاريخ الحفظ).
class HiveService {
  static const String _boxName = 'jadwal_settings';
  static const String _workbooksKey = 'saved_workbooks';
  static const String _metadataKey = 'workbook_metadata';

  // ---------------------------------------------------------------------------
  // حفظ مصنف
  // ---------------------------------------------------------------------------

  /// حفظ [workbook] في التخزين المحلي.
  ///
  /// [autoSave] — إذا كان true، لا يُضاف إلى قائمة المصنفات المحفوظة
  /// (للمستخدم) بل يُحفظ كآخر جلسة للاسترجاع التلقائي.
  static Future<void> saveWorkbook(Workbook workbook,
      {bool autoSave = false}) async {
    final box = await Hive.openBox(_boxName);

    // حفظ بيانات المصنف كاملًا
    final jsonStr = jsonEncode(workbook.toJson());
    await box.put('${_workbooksKey}_${workbook.id}', jsonStr);

    if (!autoSave) {
      // تحديث قائمة التعريفات
      final metadata = await _getMetadataList(box);
      final existingIdx = metadata.indexWhere((m) => m['id'] == workbook.id);
      final entry = {
        'id': workbook.id,
        'name': workbook.name,
        'lastModified': DateTime.now().toIso8601String(),
        'sheetCount': workbook.sheets.length,
      };

      if (existingIdx >= 0) {
        metadata[existingIdx] = entry;
      } else {
        metadata.add(entry);
      }
      await box.put(_metadataKey, jsonEncode(metadata));
    }

    // حفظ آخر مصنف مفتوح (للاسترجاع التلقائي)
    await box.put('last_open_workbook_id', workbook.id);
  }

  // ---------------------------------------------------------------------------
  // تحميل مصنف
  // ---------------------------------------------------------------------------

  /// تحميل مصنف من التخزين المحلي بواسطة [workbookId].
  static Future<Workbook?> loadWorkbook(String workbookId) async {
    final box = await Hive.openBox(_boxName);
    final jsonStr = box.get('${_workbooksKey}_$workbookId') as String?;
    if (jsonStr == null) return null;

    try {
      final json = jsonDecode(jsonStr) as Map<String, dynamic>;
      return Workbook.fromJson(json);
    } catch (e) {
      return null;
    }
  }

  /// تحميل آخر مصنف تم فتحه (للاسترجاع التلقائي عند بدء التشغيل).
  static Future<Workbook?> loadLastOpenedWorkbook() async {
    final box = await Hive.openBox(_boxName);
    final lastId = box.get('last_open_workbook_id') as String?;
    if (lastId == null) return null;
    return loadWorkbook(lastId);
  }

  // ---------------------------------------------------------------------------
  // قائمة المصنفات المحفوظة
  // ---------------------------------------------------------------------------

  /// جلب قائمة تعريفات المصنفات المحفوظة (دون تحميل البيانات الكاملة).
  static Future<List<Map<String, dynamic>>> listSavedWorkbooks() async {
    final box = await Hive.openBox(_boxName);
    return _getMetadataList(box);
  }

  /// حذف مصنف من التخزين المحلي.
  static Future<void> deleteWorkbook(String workbookId) async {
    final box = await Hive.openBox(_boxName);

    // حذف البيانات
    await box.delete('${_workbooksKey}_$workbookId');

    // حذف من قائمة التعريفات
    final metadata = await _getMetadataList(box);
    metadata.removeWhere((m) => m['id'] == workbookId);
    await box.put(_metadataKey, jsonEncode(metadata));
  }

  // ---------------------------------------------------------------------------
  // إدارة الجلسات
  // ---------------------------------------------------------------------------

  /// مسح جميع المصنفات المحفوظة.
  static Future<void> clearAll() async {
    final box = await Hive.openBox(_boxName);
    await box.delete(_metadataKey);

    // حذف جميع مفاتيح المصنفات
    final keys = box.keys.where((k) => k.toString().startsWith(_workbooksKey));
    for (final key in keys) {
      await box.delete(key);
    }
  }

  // ---------------------------------------------------------------------------
  // دوال مساعدة
  // ---------------------------------------------------------------------------

  /// جلب قائمة التعريفات من الصندوق.
  static Future<List<Map<String, dynamic>>> _getMetadataList(Box box) async {
    final raw = box.get(_metadataKey) as String?;
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }
}
