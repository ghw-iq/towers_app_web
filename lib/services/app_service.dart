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

  // ================= 7. أدوات تنسيق الإكسل الاحترافية =================

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

  /// دالة مساعدة لكتابة جدول صندوق النقد بتفاصيله الكاملة في الأعمدة المحددة
  void _writeCashBoxSection(
    Sheet sheet,
    int startCol,
    List<CashBoxTransaction> cashBoxList,
    Map<String, double> summary,
    DateFormat dateFmt,
  ) {
    final cashHeaderStyle = _headerStyle('#FF0D9488'); // لون تيل مميز للصندوق
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

    // ملخص أرصدة الصندوق أسفل الحركات
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

  /// التقرير الأول: كل برج وتحته مشتركوه المدينون فقط + عمود حركات صندوق النقد بتفاصيلها
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
    sheet.isRTL = true; // اتجاه عربي من اليمين لليسار

    sheet.setRowHeight(0, 28);
    sheet.setColumnWidth(0, 30);
    sheet.setColumnWidth(1, 18);
    sheet.setColumnWidth(2, 22);
    sheet.setColumnWidth(3, 5); // عمود فاصل أنيق

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

    // إجمالي الديون أسفل التقرير
    _styleCell(sheet, 0, leftRow, TextCellValue('إجمالي كافة الديون المستحقة'), _headerStyle('#FFDC2626'));
    _styleCell(sheet, 1, leftRow, TextCellValue(''), _headerStyle('#FFDC2626'));
    _styleCell(sheet, 2, leftRow, DoubleCellValue(grandTotalDebt), _headerStyle('#FFDC2626'));

    // كتابة جدول صندوق النقد بتفاصيله الكاملة في الأعمدة 4 إلى 7
    _writeCashBoxSection(sheet, 4, cashBoxList, summary, dateFmt);

    // استخدام encode() بدلاً من save() لمنع تنزيل نسخة FlutterExcel الثانية!
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

  /// التقرير الثاني: شامل كل برج ومشتركيه مع كافة حركاتهم التفصيلية + عمود حركات صندوق النقد بتفاصيلها
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
    sheet.setColumnWidth(1, 18);
    sheet.setColumnWidth(2, 26);
    sheet.setColumnWidth(3, 28);
    sheet.setColumnWidth(4, 24);
    sheet.setColumnWidth(5, 5); // عمود فاصل

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
          final isPay = tx.type == 'payment';
          final typeText = isPay ? 'تسديد واصل' : 'إضافة دين';
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

    // كتابة جدول صندوق النقد بتفاصيله الكاملة في الأعمدة 6 إلى 9
    _writeCashBoxSection(sheet, 6, cashBoxList, summary, dateFmt);

    // استخدام encode() بدلاً من save() لمنع تنزيل نسخة FlutterExcel الثانية!
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