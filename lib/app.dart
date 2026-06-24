import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/spreadsheet_screen.dart';

class JadwalApp extends StatelessWidget {
  const JadwalApp({super.key});

  @override
  Widget build(BuildContext context) {
    // ضبط الخط العربي
    final textTheme = GoogleFonts.cairoTextTheme(
      Theme.of(context).textTheme,
    );

    return MaterialApp(
      title: 'جدول',
      debugShowCheckedModeBanner: false,

      // اللغة العربية (RTL)
      locale: const Locale('ar', 'AE'),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ar', 'AE'),
        Locale('en', 'US'),
      ],

      // RTL
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child!,
        );
      },

      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1B5E20),
          brightness: Brightness.light,
        ).copyWith(
          surface: const Color(0xFFF5F5F5),
        ),
        textTheme: textTheme,
        fontFamily: GoogleFonts.cairo().fontFamily,
        scaffoldBackgroundColor: const Color(0xFFF5F5F5),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1B5E20),
          foregroundColor: Colors.white,
          elevation: 1,
        ),
        dividerTheme: const DividerThemeData(
          color: Color(0xFFBDBDBD),
          thickness: 0.5,
        ),
      ),
      home: const SpreadsheetScreen(),
    );
  }
}
