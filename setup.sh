#!/bin/bash
# =============================================================================
# 🏗️ إعداد مشروع جدول للبناء
# =============================================================================
# هذا السكريبت يُنشئ ملفات المنصات (Android/iOS) اللازمة لبناء التطبيق.
# قم بتشغيله في مجلد المشروع الرئيسي (jadwal/).
# =============================================================================

set -e

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  🏗️  إعداد مشروع جدول للبناء"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# التحقق من وجود Flutter
if ! command -v flutter &> /dev/null; then
    echo "❌ Flutter غير مثبت. قم بتثبيته أولاً:"
    echo "   https://docs.flutter.dev/get-started/install"
    exit 1
fi

echo "📋 Flutter version: $(flutter --version | head -1)"

# إنشاء ملفات المنصات
echo ""
echo "⏳ إنشاء ملفات Android..."
flutter create --project-name jadwal --platforms=android .

echo ""
echo "⏳ الحصول على التبعيات..."
flutter pub get

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ✅ تم الإعداد بنجاح!"
echo ""
echo "  ▶️  للتشغيل المباشر:"
echo "     flutter run"
echo ""
echo "  ▶️  لبناء APK Debug:"
echo "     flutter build apk --debug"
echo ""
echo "  ▶️  لبناء APK Release:"
echo "     flutter build apk --release"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
