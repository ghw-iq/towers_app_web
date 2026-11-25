import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:file_saver/file_saver.dart';
import 'package:intl/intl.dart';
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
      'passcode': password, // حفظ الرمز ليتمكن الأدمن من كشفه عند الحاجة
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
    final userId = _client.auth.currentUser?.id;
    await _client.auth.updateUser(
      UserAttributes(password: newPassword),
    );
    if (userId != null) {
      await _client
          .from(AppTables.profiles)
          .update({'passcode': newPassword}).eq('id', userId);
    }
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

  // ================= 2. عمليات الأدمن (Admin RPCs) =================

  Future<List<UserProfile>> adminGetAllUsers() async {
    final data = await _client.rpc('admin_get_all_users');
    return (data as List).map((e) => UserProfile.fromJson(e)).toList();
  }

  Future<void> adminUpdateUserPassword({
    required String targetUserId,
    required String newPassword,
  }) async {
    await _client.rpc('admin_update_user_password', params: {
      'target_user_id': targetUserId,
      'new_password': newPassword,
    });
  }

  Future<void> adminSetUserRole({
    required String targetUserId,
    required String newRole,
  }) async {
    await _client.rpc('admin_set_user_role', params: {
      'target_user_id': targetUserId,
      'new_role': newRole,
    });
  }

  // ================= 3. إدارة الأبراج (Towers) =================

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

  // ================= 4. إدارة المشتركين والحركات =================

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

  Future<void> updateSubscriberDebt({
    required String subscriberId,
    required double newDebtAmount,
    required String transactionType,
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

    await _client.from(AppTables.subscribers).update(updateData).eq('id', subscriberId);

    await _client.from('subscriber_transactions').insert({
      'user_id': userId,
      'subscriber_id': subscriberId,
      'type': transactionType,
      'amount': changeAmount,
      'remaining_debt': newDebtAmount,
      'notes': notes?.trim().isEmpty == true ? null : notes?.trim(),
    });
  }

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

  // ================= 5. صندوق النقد والأرشفة (Cash Box) =================

  Future<List<CashBoxTransaction>> getCashBoxTransactions() async {
    final data = await _client
        .from('cash_box_transactions')
        .select()
        .order('created_at', ascending: false);

    return (data as List).map((e) => CashBoxTransaction.fromJson(e)).toList();
  }

  Future<void> addCashBoxPayment({
    required String title,
    required double amount,
    String? notes,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('المستخدم غير مسجل الدخول');

    await _client.from('cash_box_transactions').insert({
      'user_id': userId,
      'title': title.trim(),
      'amount': amount,
      if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
    });
  }

  // ================= 6. الإحصائيات المالية للرئيسية =================

  Future<Map<String, double>> getFinancialSummary() async {
    final subData = await _client
        .from(AppTables.subscribers)
        .select('debt_amount, paid_amount');

    double totalDebt = 0;
    double totalCollected = 0;

    for (var row in (subData as List)) {
      totalDebt += (row['debt_amount'] as num?)?.toDouble() ?? 0;
      totalCollected += (row['paid_amount'] as num?)?.toDouble() ?? 0;
    }

    // خصم التسديدات المنصرفة من صندوق النقد
    final cashBoxData = await _client
        .from('cash_box_transactions')
        .select('amount');

    double totalDisbursed = 0;
    for (var row in (cashBoxData as List)) {
      totalDisbursed += (row['amount'] as num?)?.toDouble() ?? 0;
    }

    final netCashInBox = totalCollected - totalDisbursed;

    return {
      'totalDebt': totalDebt,
      'totalCollected': totalCollected,
      'totalDisbursed': totalDisbursed,
      'totalPaid': netCashInBox, // الصافي المتاح في صندوق النقد
    };
  }

  // ================= 7. تقارير الإكسل (التقرير الأول والتقرير الثاني) =================

  /// التقرير الأول: كل برج وتحته مشتركوه المدينون فقط + عمود ثانٍ لحركات صندوق النقد
  Future<void> exportDebtsAndCashBoxReport() async {
    final towers = await getTowers();
    final unpaidSubs = await getSubscribers(unpaidOnly: true);
    final cashBoxList = await getCashBoxTransactions();
    final dateFmt = DateFormat('yyyy-MM-dd hh:mm a');

    final excel = Excel.createExcel();
    final sheet = excel[excel.getDefaultSheet() ?? 'Sheet1'];

    // --- القسم الأول (الأعمدة 0 إلى 2): الأبراج ومشتركو الديون فقط ---
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0)).value =
        TextCellValue('البرج / اسم المشترك');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 0)).value =
        TextCellValue('رقم الهاتف');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: 0)).value =
        TextCellValue('مبلغ الدين المتبقي (د.ع)');

    int leftRow = 1;
    for (var tower in towers) {
      final towerSubs = unpaidSubs.where((s) => s.towerId == tower.id).toList();
      if (towerSubs.isEmpty) continue;

      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: leftRow)).value =
          TextCellValue('برج: ${tower.name}');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: leftRow)).value =
          TextCellValue(tower.location ?? '');
      leftRow++;

      for (var sub in towerSubs) {
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: leftRow)).value =
            TextCellValue('   - ${sub.fullName}');
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: leftRow)).value =
            TextCellValue(sub.phone);
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: leftRow)).value =
            DoubleCellValue(sub.debtAmount);
        leftRow++;
      }
      leftRow++; // سطر فاصل بين كل برج
    }

    // --- القسم الثاني (الأعمدة 4 إلى 6): حركات صندوق النقد ---
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: 0)).value =
        TextCellValue('حركة صندوق النقد (قيمة التسديد)');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: 0)).value =
        TextCellValue('المبلغ المصروف (د.ع)');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: 0)).value =
        TextCellValue('تاريخ ووقت التسديد');

    int rightRow = 1;
    for (var cb in cashBoxList) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: rightRow)).value =
          TextCellValue(cb.title);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: rightRow)).value =
          DoubleCellValue(cb.amount);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: rightRow)).value =
          TextCellValue(dateFmt.format(cb.createdAt.toLocal()));
      rightRow++;
    }

    final fileBytes = excel.save();
    if (fileBytes != null) {
      final now = DateTime.now();
      await FileSaver.instance.saveFile(
        name: 'تقرير_الديون_والصندوق_${now.year}_${now.month}_${now.day}',
        bytes: Uint8List.fromList(fileBytes),
        ext: 'xlsx',
        mimeType: MimeType.microsoftExcel,
      );
    }
  }

  /// التقرير الثاني: شامل كل برج ومشتركيه مع كافة حركاتهم التفصيلية + عمود حركات صندوق النقد
  Future<void> exportFullReportWithAllTransactions() async {
    final towers = await getTowers();
    final allSubs = await getSubscribers(unpaidOnly: false);
    final rawTx = await _client
        .from('subscriber_transactions')
        .select()
        .order('created_at', ascending: false);
    final allTx = (rawTx as List).map((e) => SubscriberTransaction.fromJson(e)).toList();
    final cashBoxList = await getCashBoxTransactions();
    final dateFmt = DateFormat('yyyy-MM-dd hh:mm a');

    final excel = Excel.createExcel();
    final sheet = excel[excel.getDefaultSheet() ?? 'Sheet1'];

    // --- القسم الأول (الأعمدة 0 إلى 4): الأبراج + المشتركين + كل حركاتهم ---
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0)).value =
        TextCellValue('البرج / المشترك / الحركة');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 0)).value =
        TextCellValue('الهاتف / نوع الحركة');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: 0)).value =
        TextCellValue('المبلغ / الرصيد المتبقي (د.ع)');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: 0)).value =
        TextCellValue('الملاحظات');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: 0)).value =
        TextCellValue('التاريخ والوقت');

    int leftRow = 1;
    for (var tower in towers) {
      final towerSubs = allSubs.where((s) => s.towerId == tower.id).toList();
      if (towerSubs.isEmpty) continue;

      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: leftRow)).value =
          TextCellValue('برج: ${tower.name}');
      leftRow++;

      for (var sub in towerSubs) {
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: leftRow)).value =
            TextCellValue('   مشترك: ${sub.fullName}');
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: leftRow)).value =
            TextCellValue(sub.phone);
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: leftRow)).value =
            TextCellValue('الدين: ${sub.debtAmount.toStringAsFixed(0)} | الواصل: ${sub.paidAmount.toStringAsFixed(0)}');
        leftRow++;

        final subTx = allTx.where((t) => t.subscriberId == sub.id).toList();
        for (var tx in subTx) {
          final typeText = tx.type == 'payment' ? 'تسديد واصل' : 'إضافة دين';
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: leftRow)).value =
              TextCellValue('      • حركة مالية');
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: leftRow)).value =
              TextCellValue(typeText);
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: leftRow)).value =
              TextCellValue('${tx.amount.toStringAsFixed(0)} (المتبقي: ${tx.remainingDebt.toStringAsFixed(0)})');
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: leftRow)).value =
              TextCellValue(tx.notes ?? '-');
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: leftRow)).value =
              TextCellValue(dateFmt.format(tx.createdAt.toLocal()));
          leftRow++;
        }
      }
      leftRow++;
    }

    // --- القسم الثاني (الأعمدة 6 إلى 8): حركات صندوق النقد ---
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: 0)).value =
        TextCellValue('حركة صندوق النقد (قيمة التسديد)');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: 0)).value =
        TextCellValue('المبلغ المصروف (د.ع)');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: 0)).value =
        TextCellValue('تاريخ ووقت التسديد');

    int rightRow = 1;
    for (var cb in cashBoxList) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: rightRow)).value =
          TextCellValue(cb.title);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: rightRow)).value =
          DoubleCellValue(cb.amount);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: rightRow)).value =
          TextCellValue(dateFmt.format(cb.createdAt.toLocal()));
      rightRow++;
    }

    final fileBytes = excel.save();
    if (fileBytes != null) {
      final now = DateTime.now();
      await FileSaver.instance.saveFile(
        name: 'التقرير_الشامل_بالحركات_${now.year}_${now.month}_${now.day}',
        bytes: Uint8List.fromList(fileBytes),
        ext: 'xlsx',
        mimeType: MimeType.microsoftExcel,
      );
    }
  }
}