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
    const ProviderScope(
      child: JadwalApp(),
    ),
  );
}
