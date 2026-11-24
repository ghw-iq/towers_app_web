import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// --- مفاتيح الاتصال الخاصة بمشروعك في Supabase ---
class AppConfig {
  static const String supabaseUrl = 'https://anhxzajuofqkszylprwr.supabase.co';
  static const String supabaseAnonKey = 'sb_publishable_l4Ls2rk7QLa8QxZIs3zICw_-drimI0e';
}

// وصول سريع لكلاينت سوبابيز
final supabase = Supabase.instance.client;

// --- أسماء الجداول ---
class AppTables {
  static const String profiles = 'profiles';
  static const String towers = 'towers';
  static const String subscribers = 'subscribers';
}

// --- الألوان والتصميم ---
class AppColors {
  static const Color primary = Color(0xFF1E3A8A); // كحلي مالي
  static const Color secondary = Color(0xFF0D9488); // تيل / تركواز
  static const Color background = Color(0xFFF8FAFC);
  static const Color surface = Colors.white;
  static const Color debtRed = Color(0xFFDC2626); // أحمر للديون
  static const Color paidGreen = Color(0xFF16A34A); // أخضر للمدفوعات
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color border = Color(0xFFE2E8F0);
}

// --- دوال التحقق العامة (Validators) ---
class AppValidators {
  /// التحقق من رقم الهاتف العراقي (11 مرتبة ويبدأ بـ 07)
  static String? validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'يرجى إدخال رقم الهاتف';
    }
    final cleanPhone = value.trim();
    final regex = RegExp(r'^07[0-9]{9}$');
    if (!regex.hasMatch(cleanPhone)) {
      return 'يجب أن يبدأ الرقم بـ 07 ويتكون من 11 رقم بالضبط';
    }
    return null;
  }

  /// التحقق من الحقول الإلزامية
  static String? validateRequired(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return 'يرجى إدخال $fieldName';
    }
    return null;
  }

  /// التحقق من كلمة السر
  static String? validatePassword(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'يرجى إدخال كلمة السر';
    }
    if (value.length < 6) {
      return 'كلمة السر يجب ألا تقل عن 6 خانات';
    }
    return null;
  }
}