import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:file_saver/file_saver.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants.dart';
import '../models/app_models.dart';

enum DebtSortType { oldestDebt, highestDebt }

class AppService {
  final SupabaseClient _client = supabase;

  String _phoneToEmail(String phone) => '${phone.trim()}@towerapp.local';

  // ================= 1. المصادقة والحساب (Auth) =================

  Future<void> signUp({
    required String phone,
    required String password,
    required String fullName,
  }) async {
    final email = _phoneToEmail(phone);
    final response = await _client.auth.signUp(
      email: email,
      password: password,
      data: {
        'full_name': fullName,
        'phone': phone,
      },
    );

    if (response.user == null) {
      throw Exception('فشل إنشاء الحساب، يرجى المحاولة لاحقاً');
    }

    await _client.from(AppTables.profiles).upsert({
      'id': response.user!.id,
      'full_name': fullName,
      'phone': phone,
    });
  }

  Future<AuthResponse> signIn({
    required String phone,
    required String password,
  }) async {
    final email = _phoneToEmail(phone);
    return await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  Future<void> updatePassword(String newPassword) async {
    await _client.auth.updateUser(
      UserAttributes(password: newPassword),
    );
  }

  Future<UserProfile> getProfile() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('المستخدم غير مسجل الدخول');

    final data = await _client
        .from(AppTables.profiles)
        .select()
        .eq('id', userId)
        .single();

    return UserProfile.fromJson(data);
  }

  Future<void> updateProfile({required String fullName, required String phone}) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('المستخدم غير مسجل الدخول');

    await _client.from(AppTables.profiles).update({
      'full_name': fullName,
      'phone': phone,
    }).eq('id', userId);
  }

  // ================= 2. إدارة الأبراج (Towers) =================

  Future<List<Tower>> getTowers() async {
    final data = await _client
        .from(AppTables.towers)
        .select()
        .order('name', ascending: true);

    return (data as List).map((e) => Tower.fromJson(e)).toList();
  }

  Future<void> addTower({required String name, String? location}) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('المستخدم غير مسجل الدخول');

    await _client.from(AppTables.towers).insert({
      'user_id': userId,
      'name': name.trim(),
      'location': location?.trim(),
    });
  }

  Future<void> deleteTower(String towerId) async {
    await _client.from(AppTables.towers).delete().eq('id', towerId);
  }

  // ================= 3. إدارة المشتركين والحركات (Subscribers & Transactions) =================

  Future<void> addSubscriber({
    required String towerId,
    required String fullName,
    required String phone,
    required double initialDebt,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('المستخدم غير مسجل الدخول');

    final insertedSub = await _client.from(AppTables.subscribers).insert({
      'user_id': userId,
      'tower_id': towerId,
      'full_name': fullName.trim(),
      'phone': phone.trim(),
      'debt_amount': initialDebt,
      'paid_amount': 0.0,
      'last_debt_updated_at': DateTime.now().toUtc().toIso8601String(),
    }).select().single();

    // تسجيل الدين الافتتاحي في جدول الحركات إن وجد
    if (initialDebt > 0) {
      await _client.from('subscriber_transactions').insert({
        'user_id': userId,
        'subscriber_id': insertedSub['id'],
        'type': 'debt_addition',
        'amount': initialDebt,
        'remaining_debt': initialDebt,
        'notes': 'دين افتتاحي سابق عند إنشاء المشترك',
      });
    }
  }

  Future<List<Subscriber>> getSubscribers({
    String? towerId,
    bool unpaidOnly = false,
    DebtSortType sortType = DebtSortType.oldestDebt,
    String? searchQuery,
    int? limit,
  }) async {
    PostgrestFilterBuilder filter = _client.from(AppTables.subscribers).select('*, towers(name)');

    if (towerId != null && towerId.isNotEmpty) {
      filter = filter.eq('tower_id', towerId);
    }

    if (unpaidOnly) {
      filter = filter.gt('debt_amount', 0);
    }

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final query = searchQuery.trim();
      filter = filter.or('full_name.ilike.%$query%,phone.ilike.%$query%');
    }

    PostgrestTransformBuilder transform = filter;

    if (unpaidOnly) {
      if (sortType == DebtSortType.highestDebt) {
        transform = transform.order('debt_amount', ascending: false);
      } else {
        transform = transform.order('last_debt_updated_at', ascending: true);
      }
    } else {
      transform = transform.order('created_at', ascending: false);
    }

    if (limit != null) {
      transform = transform.limit(limit);
    }

    final data = await transform;
    return (data as List).map((e) => Subscriber.fromJson(e)).toList();
  }

  /// تحديث دين المشترك مع تدوين الملاحظة والحركة المالية
  Future<void> updateSubscriberDebt({
    required String subscriberId,
    required double newDebtAmount,
    required String transactionType, // 'payment' أو 'debt_addition'
    required double changeAmount,
    String? notes,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('المستخدم غير مسجل الدخول');

    final updateData = <String, dynamic>{
      'debt_amount': newDebtAmount,
      'last_debt_updated_at': DateTime.now().toUtc().toIso8601String(),
    };

    if (transactionType == 'payment' && changeAmount > 0) {
      final current = await _client
          .from(AppTables.subscribers)
          .select('paid_amount')
          .eq('id', subscriberId)
          .single();
      final currentPaid = (current['paid_amount'] as num?)?.toDouble() ?? 0.0;
      updateData['paid_amount'] = currentPaid + changeAmount;
    }

    // تحديث بيانات المشترك
    await _client.from(AppTables.subscribers).update(updateData).eq('id', subscriberId);

    // تسجيل العملية في جدول الحركات والملاحظات
    await _client.from('subscriber_transactions').insert({
      'user_id': userId,
      'subscriber_id': subscriberId,
      'type': transactionType,
      'amount': changeAmount,
      'remaining_debt': newDebtAmount,
      'notes': notes?.trim().isEmpty == true ? null : notes?.trim(),
    });
  }

  /// جلب سجل الحركات والملاحظات لمشترك معين
  Future<List<SubscriberTransaction>> getSubscriberTransactions(String subscriberId) async {
    final data = await _client
        .from('subscriber_transactions')
        .select()
        .eq('subscriber_id', subscriberId)
        .order('created_at', ascending: false);

    return (data as List).map((e) => SubscriberTransaction.fromJson(e)).toList();
  }

  Future<void> deleteSubscriber(String subscriberId) async {
    await _client.from(AppTables.subscribers).delete().eq('id', subscriberId);
  }

  // ================= 4. الإحصائيات وتصدير الإكسل =================

  Future<Map<String, double>> getFinancialSummary() async {
    final data = await _client
        .from(AppTables.subscribers)
        .select('debt_amount, paid_amount');

    double totalDebt = 0;
    double totalPaid = 0;

    for (var row in (data as List)) {
      totalDebt += (row['debt_amount'] as num?)?.toDouble() ?? 0;
      totalPaid += (row['paid_amount'] as num?)?.toDouble() ?? 0;
    }

    return {
      'totalDebt': totalDebt,
      'totalPaid': totalPaid,
    };
  }

  /// تصدير قائمة الديون فقط على شكل ملف إكسل بدون تفاصيل
  Future<void> exportDebtsToExcel() async {
    final subscribers = await getSubscribers(unpaidOnly: true);

    final excel = Excel.createExcel();
    final sheet = excel[excel.getDefaultSheet() ?? 'Sheet1'];

    // ترويسة الجدول
    sheet.appendRow([
      TextCellValue('اسم المشترك'),
      TextCellValue('رقم الهاتف'),
      TextCellValue('البرج'),
      TextCellValue('مبلغ الدين المتبقي (د.ع)'),
    ]);

    // تعبئة البيانات
    for (var sub in subscribers) {
      sheet.appendRow([
        TextCellValue(sub.fullName),
        TextCellValue(sub.phone),
        TextCellValue(sub.towerName ?? 'غير محدد'),
        DoubleCellValue(sub.debtAmount),
      ]);
    }

    final fileBytes = excel.save();
    if (fileBytes != null) {
      final now = DateTime.now();
      final fileName = 'ديون_المشتركين_${now.year}_${now.month}_${now.day}';

      await FileSaver.instance.saveFile(
        name: fileName,
        bytes: Uint8List.fromList(fileBytes),
        ext: 'xlsx',
        mimeType: MimeType.microsoftExcel,
      );
    }
  }
}