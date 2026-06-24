import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // إعداد Hive للتخزين المحلي
  await Hive.initFlutter();
  await Hive.openBox('jadwal_settings');

  // ضبط اتجاه التطبيق (أفقي للأجهزة اللوحية) والسماح بالاتجاهات
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // إخفاء شريط الحالة في الوضع الأفقي للمساحة الأكبر
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  runApp(
    // نستخدم ProviderScope مع overrides لتمرير "مُهيَّئ" يسمح باستدعاء init
    const ProviderScope(
      child: _AppInitializer(
        child: JadwalApp(),
      ),
    ),
  );
}

/// ويدجت تهيئة تستدعي [WorkbookNotifier.init()] بعد بناء ProviderScope.
class _AppInitializer extends ConsumerStatefulWidget {
  final Widget child;
  const _AppInitializer({required this.child});

  @override
  ConsumerState<_AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends ConsumerState<_AppInitializer> {
  @override
  void initState() {
    super.initState();
    // جدولة استدعاء init بعد بناء الإطار الأول
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(workbookProvider.notifier).init();
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
