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
      'passcode': password,
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

  // ================= 3. إدارة باقات الشركة (Subscription Plans) =================

  Future<List<SubscriptionPlan>> getSubscriptionPlans() async {
    final data = await _client
        .from('subscription_plans')
        .select()
        .order('created_at', ascending: true);

    return (data as List).map((e) => SubscriptionPlan.fromJson(e)).toList();
  }

  Future<void> addSubscriptionPlans(List<Map<String, dynamic>> validPlans) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('المستخدم غير مسجل الدخول');
    if (validPlans.isEmpty) return;

    final rows = validPlans.map((p) {
      return {
        'user_id': userId,
        'name': (p['name'] as String).trim(),
        'cost_price': p['cost_price'] as double,
      };
    }).toList();

    await _client.from('subscription_plans').insert(rows);
  }

  Future<void> updateSubscriptionPlan({
    required String planId,
    required String name,
    required double costPrice,
  }) async {
    await _client.from('subscription_plans').update({
      'name': name.trim(),
      'cost_price': costPrice,
    }).eq('id', planId);
  }

  Future<void> deleteSubscriptionPlan(String planId) async {
    await _client.from('subscription_plans').delete().eq('id', planId);
  }

  // ================= 4. إدارة الأبراج (Towers) =================

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

  // ================= 5. إدارة المشتركين والحركات والأرباح =================

  Future<void> addSubscriber({
    required String towerId,
    required String fullName,
    required String phone,
    required double initialDebt,
    SubscriptionPlan? plan,
    double? sellingPrice,
    String paymentMode = 'credit', // 'credit' (آجل) أو 'cash' (نقد)
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('المستخدم غير مسجل الدخول');

    double finalDebt = initialDebt;
    double finalPaid = 0.0;

    if (plan != null && sellingPrice != null) {
      if (paymentMode == 'cash') {
        finalPaid += sellingPrice; // يدخل لصندوق النقد مباشرة
      } else {
        finalDebt += sellingPrice; // يضاف إلى ديون المشترك
      }
    }

    final insertedSub = await _client.from(AppTables.subscribers).insert({
      'user_id': userId,
      'tower_id': towerId,
      'full_name': fullName.trim(),
      'phone': phone.trim(),
      'debt_amount': finalDebt,
      'paid_amount': finalPaid,
      'last_debt_updated_at': DateTime.now().toUtc().toIso8601String(),
    }).select().single();

    final subId = insertedSub['id'] as String;

    // 1. تسجيل الدين السابق إن وجد
    if (initialDebt > 0) {
      await _client.from('subscriber_transactions').insert({
        'user_id': userId,
        'subscriber_id': subId,
        'type': 'debt_addition',
        'amount': initialDebt,
        'remaining_debt': finalDebt,
        'notes': 'دين افتتاحي سابق عند إنشاء المشترك',
      });
    }

    // 2. تسجيل حركة تفعيل الباقة بلقطة السعر التاريخية
    if (plan != null && sellingPrice != null) {
      final profit = sellingPrice - plan.costPrice;
      final isCash = paymentMode == 'cash';

      await _client.from('subscriber_transactions').insert({
        'user_id': userId,
        'subscriber_id': subId,
        'type': isCash ? 'cash_subscription' : 'debt_addition',
        'amount': sellingPrice,
        'remaining_debt': finalDebt,
        'plan_id': plan.id,
        'plan_name': plan.name,
        'cost_price': plan.costPrice,
        'selling_price': sellingPrice,
        'profit': profit,
        'payment_mode': paymentMode,
        'notes': isCash
            ? 'تفعيل اشتراك (${plan.name}) - نقداً للصندوق'
            : 'تفعيل اشتراك (${plan.name}) - آجل على الدين',
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
    required String transactionType, // 'payment', 'debt_addition', 'cash_subscription'
    required double changeAmount,
    String? notes,
    SubscriptionPlan? plan,
    double? sellingPrice,
    String? paymentMode,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('المستخدم غير مسجل الدخول');

    final updateData = <String, dynamic>{
      'debt_amount': newDebtAmount,
      'last_debt_updated_at': DateTime.now().toUtc().toIso8601String(),
    };

    // إذا كان تسديد دين عادي أو بيع اشتراك نقداً، يزداد النقد الواصل للصندوق
    if ((transactionType == 'payment' || transactionType == 'cash_subscription') &&
        changeAmount > 0) {
      final current = await _client
          .from(AppTables.subscribers)
          .select('paid_amount')
          .eq('id', subscriberId)
          .single();
      final currentPaid = (current['paid_amount'] as num?)?.toDouble() ?? 0.0;
      updateData['paid_amount'] = currentPaid + changeAmount;
    }

    await _client.from(AppTables.subscribers).update(updateData).eq('id', subscriberId);

    final txData = <String, dynamic>{
      'user_id': userId,
      'subscriber_id': subscriberId,
      'type': transactionType,
      'amount': changeAmount,
      'remaining_debt': newDebtAmount,
      'notes': notes?.trim().isEmpty == true ? null : notes?.trim(),
    };

    // حفظ لقطة السعر التاريخية عند تفعيل باقة
    if (plan != null && sellingPrice != null) {
      txData['plan_id'] = plan.id;
      txData['plan_name'] = plan.name;
      txData['cost_price'] = plan.costPrice;
      txData['selling_price'] = sellingPrice;
      txData['profit'] = sellingPrice - plan.costPrice;
      txData['payment_mode'] = paymentMode;
    }

    await _client.from('subscriber_transactions').insert(txData);
  }

  Future<List<SubscriberTransaction>> getSubscriberTransactions(String subscriberId) async {
    final data = await _client
        .from('subscriber_transactions')
        .select()
        .eq('subscriber_id', subscriberId)
        .order('created_at', ascending: false);

    return (data as List).map((e) => SubscriberTransaction.fromJson(e)).toList();
  }

  /// جلب كافة الحركات التي تحتوي على أرباح (لشاشة الاشتراكات والأرباح)
  Future<List<SubscriberTransaction>> getProfitTransactions() async {
    final data = await _client
        .from('subscriber_transactions')
        .select('*, subscribers(full_name, tower_id, towers(name))')
        .not('profit', 'is', null)
        .order('created_at', ascending: false);

    return (data as List).map((e) => SubscriberTransaction.fromJson(e)).toList();
  }

  Future<void> deleteSubscriber(String subscriberId) async {
    await _client.from(AppTables.subscribers).delete().eq('id', subscriberId);
  }

  // ================= 6. صندوق النقد والأرشفة (Cash Box) =================

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

  // ================= 7. الإحصائيات المالية للرئيسية =================

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
      'totalPaid': netCashInBox,
    };
  }

  // ================= 8. أدوات وتقارير الإكسل =================

  void _styleCell(
    Sheet sheet,
    int col,
    int row,
    CellValue value,
    CellStyle style,
  ) {
    final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));
    cell.value = value;
    cell.cellStyle = style;
  }

  Border get _thinBorder => Border(
        borderStyle: BorderStyle.Thin,
        borderColorHex: ExcelColor.fromHexString('#FFCBD5E1'),
      );

  CellStyle _headerStyle(String hexColor) => CellStyle(
        bold: true,
        fontSize: 12,
        fontColorHex: ExcelColor.white,
        backgroundColorHex: ExcelColor.fromHexString(hexColor),
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
        topBorder: _thinBorder,
        bottomBorder: _thinBorder,
        leftBorder: _thinBorder,
        rightBorder: _thinBorder,
      );

  CellStyle get _towerStyle => CellStyle(
        bold: true,
        fontSize: 11,
        fontColorHex: ExcelColor.fromHexString('#FF1E3A8A'),
        backgroundColorHex: ExcelColor.fromHexString('#FFDBEAFE'),
        horizontalAlign: HorizontalAlign.Right,
        verticalAlign: VerticalAlign.Center,
        topBorder: _thinBorder,
        bottomBorder: _thinBorder,
        leftBorder: _thinBorder,
        rightBorder: _thinBorder,
      );

  CellStyle _bodyStyle({String? fontHex, String? bgHex, bool bold = false, HorizontalAlign align = HorizontalAlign.Right}) =>
      CellStyle(
        bold: bold,
        fontSize: 11,
        fontColorHex: fontHex != null ? ExcelColor.fromHexString(fontHex) : ExcelColor.black,
        backgroundColorHex: bgHex != null ? ExcelColor.fromHexString(bgHex) : ExcelColor.none,
        horizontalAlign: align,
        verticalAlign: VerticalAlign.Center,
        topBorder: _thinBorder,
        bottomBorder: _thinBorder,
        leftBorder: _thinBorder,
        rightBorder: _thinBorder,
      );

  void _writeCashBoxSection(
    Sheet sheet,
    int startCol,
    List<CashBoxTransaction> cashBoxList,
    Map<String, double> summary,
    DateFormat dateFmt,
  ) {
    final cashHeaderStyle = _headerStyle('#FF0D9488');
    sheet.setColumnWidth(startCol, 28);
    sheet.setColumnWidth(startCol + 1, 20);
    sheet.setColumnWidth(startCol + 2, 30);
    sheet.setColumnWidth(startCol + 3, 24);

    _styleCell(sheet, startCol, 0, TextCellValue('صندوق النقد (قيمة التسديد)'), cashHeaderStyle);
    _styleCell(sheet, startCol + 1, 0, TextCellValue('المبلغ المصروف (د.ع)'), cashHeaderStyle);
    _styleCell(sheet, startCol + 2, 0, TextCellValue('الملاحظات والتفاصيل'), cashHeaderStyle);
    _styleCell(sheet, startCol + 3, 0, TextCellValue('التاريخ والوقت'), cashHeaderStyle);

    int row = 1;
    for (var cb in cashBoxList) {
      final bg = row % 2 == 0 ? '#FFF8FAFC' : null;
      _styleCell(sheet, startCol, row, TextCellValue(cb.title), _bodyStyle(bgHex: bg, bold: true));
      _styleCell(sheet, startCol + 1, row, DoubleCellValue(cb.amount),
          _bodyStyle(bgHex: bg, fontHex: '#FFDC2626', bold: true, align: HorizontalAlign.Center));
      _styleCell(sheet, startCol + 2, row, TextCellValue(cb.notes ?? 'لا توجد ملاحظات'),
          _bodyStyle(bgHex: bg, fontHex: '#FF475569'));
      _styleCell(sheet, startCol + 3, row, TextCellValue(dateFmt.format(cb.createdAt.toLocal())),
          _bodyStyle(bgHex: bg, align: HorizontalAlign.Center));
      row++;
    }

    row++;
    final summaryLabelStyle = _bodyStyle(bgHex: '#FFF1F5F9', bold: true);
    _styleCell(sheet, startCol, row, TextCellValue('إجمالي الواصل من المشتركين'), summaryLabelStyle);
    _styleCell(sheet, startCol + 1, row, DoubleCellValue(summary['totalCollected'] ?? 0),
        _bodyStyle(bgHex: '#FFF1F5F9', fontHex: '#FF16A34A', bold: true, align: HorizontalAlign.Center));
    row++;

    _styleCell(sheet, startCol, row, TextCellValue('إجمالي مصروفات الصندوق'), summaryLabelStyle);
    _styleCell(sheet, startCol + 1, row, DoubleCellValue(summary['totalDisbursed'] ?? 0),
        _bodyStyle(bgHex: '#FFF1F5F9', fontHex: '#FFDC2626', bold: true, align: HorizontalAlign.Center));
    row++;

    _styleCell(sheet, startCol, row, TextCellValue('الصافي المتبقي بالصندوق'), _headerStyle('#FF16A34A'));
    _styleCell(sheet, startCol + 1, row, DoubleCellValue(summary['totalPaid'] ?? 0), _headerStyle('#FF16A34A'));
  }

  Future<void> exportDebtsAndCashBoxReport() async {
    final towers = await getTowers();
    final unpaidSubs = await getSubscribers(unpaidOnly: true);
    final cashBoxList = await getCashBoxTransactions();
    final summary = await getFinancialSummary();
    final dateFmt = DateFormat('yyyy-MM-dd hh:mm a');

    final excel = Excel.createExcel();
    final defaultName = excel.getDefaultSheet() ?? 'Sheet1';
    excel.rename(defaultName, 'الديون والصندوق');
    final sheet = excel['الديون والصندوق'];
    sheet.isRTL = true;

    sheet.setRowHeight(0, 28);
    sheet.setColumnWidth(0, 30);
    sheet.setColumnWidth(1, 18);
    sheet.setColumnWidth(2, 22);
    sheet.setColumnWidth(3, 5);

    final mainHeaderStyle = _headerStyle('#FF1E3A8A');
    _styleCell(sheet, 0, 0, TextCellValue('البرج / اسم المشترك'), mainHeaderStyle);
    _styleCell(sheet, 1, 0, TextCellValue('رقم الهاتف'), mainHeaderStyle);
    _styleCell(sheet, 2, 0, TextCellValue('الدين المتبقي (د.ع)'), mainHeaderStyle);

    int leftRow = 1;
    double grandTotalDebt = 0;

    for (var tower in towers) {
      final towerSubs = unpaidSubs.where((s) => s.towerId == tower.id).toList();
      if (towerSubs.isEmpty) continue;

      sheet.setRowHeight(leftRow, 22);
      _styleCell(sheet, 0, leftRow, TextCellValue('📡 برج: ${tower.name}'), _towerStyle);
      _styleCell(sheet, 1, leftRow, TextCellValue(tower.location ?? ''), _towerStyle);
      _styleCell(sheet, 2, leftRow, TextCellValue(''), _towerStyle);
      leftRow++;

      for (var sub in towerSubs) {
        grandTotalDebt += sub.debtAmount;
        _styleCell(sheet, 0, leftRow, TextCellValue('   • ${sub.fullName}'), _bodyStyle());
        _styleCell(sheet, 1, leftRow, TextCellValue(sub.phone),
            _bodyStyle(align: HorizontalAlign.Center));
        _styleCell(sheet, 2, leftRow, DoubleCellValue(sub.debtAmount),
            _bodyStyle(fontHex: '#FFDC2626', bold: true, align: HorizontalAlign.Center));
        leftRow++;
      }
      leftRow++;
    }

    _styleCell(sheet, 0, leftRow, TextCellValue('إجمالي كافة الديون المستحقة'), _headerStyle('#FFDC2626'));
    _styleCell(sheet, 1, leftRow, TextCellValue(''), _headerStyle('#FFDC2626'));
    _styleCell(sheet, 2, leftRow, DoubleCellValue(grandTotalDebt), _headerStyle('#FFDC2626'));

    _writeCashBoxSection(sheet, 4, cashBoxList, summary, dateFmt);

    final fileBytes = excel.encode();
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

  Future<void> exportFullReportWithAllTransactions() async {
    final towers = await getTowers();
    final allSubs = await getSubscribers(unpaidOnly: false);
    final rawTx = await _client
        .from('subscriber_transactions')
        .select()
        .order('created_at', ascending: false);
    final allTx = (rawTx as List).map((e) => SubscriberTransaction.fromJson(e)).toList();
    final cashBoxList = await getCashBoxTransactions();
    final summary = await getFinancialSummary();
    final dateFmt = DateFormat('yyyy-MM-dd hh:mm a');

    final excel = Excel.createExcel();
    final defaultName = excel.getDefaultSheet() ?? 'Sheet1';
    excel.rename(defaultName, 'التقرير الشامل');
    final sheet = excel['التقرير الشامل'];
    sheet.isRTL = true;

    sheet.setRowHeight(0, 28);
    sheet.setColumnWidth(0, 28);
    sheet.setColumnWidth(1, 20);
    sheet.setColumnWidth(2, 26);
    sheet.setColumnWidth(3, 28);
    sheet.setColumnWidth(4, 24);
    sheet.setColumnWidth(5, 5);

    final mainHeaderStyle = _headerStyle('#FF1E3A8A');
    _styleCell(sheet, 0, 0, TextCellValue('البرج / المشترك / الحركة'), mainHeaderStyle);
    _styleCell(sheet, 1, 0, TextCellValue('الهاتف / نوع الحركة'), mainHeaderStyle);
    _styleCell(sheet, 2, 0, TextCellValue('المبلغ / الرصيد (د.ع)'), mainHeaderStyle);
    _styleCell(sheet, 3, 0, TextCellValue('الملاحظات'), mainHeaderStyle);
    _styleCell(sheet, 4, 0, TextCellValue('التاريخ والوقت'), mainHeaderStyle);

    int leftRow = 1;
    for (var tower in towers) {
      final towerSubs = allSubs.where((s) => s.towerId == tower.id).toList();
      if (towerSubs.isEmpty) continue;

      sheet.setRowHeight(leftRow, 22);
      for (int c = 0; c <= 4; c++) {
        _styleCell(
          sheet,
          c,
          leftRow,
          TextCellValue(c == 0 ? '📡 برج: ${tower.name}' : (c == 1 ? (tower.location ?? '') : '')),
          _towerStyle,
        );
      }
      leftRow++;

      for (var sub in towerSubs) {
        final subRowStyle = _bodyStyle(bgHex: '#FFF1F5F9', bold: true);
        _styleCell(sheet, 0, leftRow, TextCellValue('👤 مشترك: ${sub.fullName}'), subRowStyle);
        _styleCell(sheet, 1, leftRow, TextCellValue(sub.phone),
            _bodyStyle(bgHex: '#FFF1F5F9', bold: true, align: HorizontalAlign.Center));
        _styleCell(
            sheet,
            2,
            leftRow,
            TextCellValue('الدين: ${sub.debtAmount.toStringAsFixed(0)} | الواصل: ${sub.paidAmount.toStringAsFixed(0)}'),
            _bodyStyle(bgHex: '#FFF1F5F9', fontHex: '#FF1E3A8A', bold: true));
        _styleCell(sheet, 3, leftRow, TextCellValue(''), subRowStyle);
        _styleCell(sheet, 4, leftRow, TextCellValue(''), subRowStyle);
        leftRow++;

        final subTx = allTx.where((t) => t.subscriberId == sub.id).toList();
        for (var tx in subTx) {
          final isPay = tx.type == 'payment' || tx.type == 'cash_subscription';
          final typeText = tx.type == 'cash_subscription'
              ? 'اشتراك نقدي'
              : (tx.type == 'payment' ? 'تسديد واصل' : 'إضافة دين');
          final colorHex = isPay ? '#FF16A34A' : '#FFDC2626';

          _styleCell(sheet, 0, leftRow, TextCellValue('     ↳ حركة مالية'), _bodyStyle(fontHex: '#FF64748B'));
          _styleCell(sheet, 1, leftRow, TextCellValue(typeText),
              _bodyStyle(fontHex: colorHex, bold: true, align: HorizontalAlign.Center));
          _styleCell(
              sheet,
              2,
              leftRow,
              TextCellValue('${tx.amount.toStringAsFixed(0)} (المتبقي: ${tx.remainingDebt.toStringAsFixed(0)})'),
              _bodyStyle(fontHex: colorHex, bold: true));
          _styleCell(sheet, 3, leftRow, TextCellValue(tx.notes ?? '-'), _bodyStyle(fontHex: '#FF475569'));
          _styleCell(sheet, 4, leftRow, TextCellValue(dateFmt.format(tx.createdAt.toLocal())),
              _bodyStyle(align: HorizontalAlign.Center));
          leftRow++;
        }
      }
      leftRow++;
    }

    _writeCashBoxSection(sheet, 6, cashBoxList, summary, dateFmt);

    final fileBytes = excel.encode();
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